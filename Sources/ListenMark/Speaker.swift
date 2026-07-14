import AVFoundation

enum SpeechPlaybackStatus: Equatable {
    case idle
    case preparing(String)
    case playing(String)
    case paused(String)
}

/// Voice-first output with streaming support.
/// - One-shot `speak` for first playback / 试听.
/// - `replay` reuses the last generated cloud audio when possible.
/// - `startStream` → `feed(sentence)` × N → `endStream` for speaking as text arrives.
/// Local engine queues utterances natively; cloud engines synthesize each sentence
/// or chunk and play them back-to-back through a serial audio queue. Cloud failure
/// falls back to the local voice.
final class Speaker: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = Speaker()

    private struct QueuedCloudAudio {
        let index: Int
        let data: Data
    }

    private let synth = AVSpeechSynthesizer()
    @Published private(set) var status: SpeechPlaybackStatus = .idle
    private var player: AVAudioPlayer?
    private var lastGeneratedAudio: (text: String, chunks: [Data], complete: Bool)?
    private var playbackGeneration = 0

    private var streaming = false
    private var cloudQueue: [String] = []
    private var cloudAudioQueue: [QueuedCloudAudio] = []
    private var cloudSynthesizing = false
    private var cloudDraining = false
    private var activeCloudProvider: CloudTTSProvider?
    private var activeCloudGeneration = 0
    private var activeCacheText: String?
    private var activeGeneratedChunks: [Data] = []
    private var currentCloudChunkIndex: Int?
    private var replayAudioChunks: [Data] = []
    private var currentReplayChunkIndex: Int?
    private var replayingCachedAudio = false
    private var onFinishPlay: (() -> Void)?
    private var speechFinishTimer: Timer?

    private var cloudProvider: CloudTTSProvider? { CloudTTS.currentProvider() }

    // MARK: One-shot

    func speak(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        stop()
        let generation = nextPlaybackGeneration()
        if let provider = cloudProvider {
            lastGeneratedAudio = (t, [], false)
            setStatus(.preparing(provider.displayName))
            enqueueCloud(CloudTTS.textChunks(t, provider: provider),
                         provider: provider,
                         generation: generation,
                         cacheText: t)
        } else {
            lastGeneratedAudio = nil
            localSpeak(t)
        }
    }

    func replay(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        stop()
        if let audio = lastGeneratedAudio, audio.text == t, audio.complete {
            setStatus(.playing(AppFlavor.text("已缓存语音", "cached speech")))
            playSequence(audio.chunks) {}
        } else {
            speak(t)
        }
    }

    // MARK: Streaming

    func startStream() {
        stop()
        streaming = true
        activeCloudProvider = cloudProvider
        activeCloudGeneration = playbackGeneration
    }

    func feed(_ sentence: String) {
        let s = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard streaming, !s.isEmpty else { return }
        if let provider = activeCloudProvider {
            cloudQueue.append(contentsOf: CloudTTS.textChunks(s, provider: provider))
            if !cloudDraining {
                setStatus(.preparing(provider.displayName))
            }
            startDrainIfNeeded()
        } else {
            localSpeak(s)   // AVSpeechSynthesizer queues
        }
    }

    func endStream() { streaming = false }

    // MARK: Playback Controls

    func pause() {
        guard case .playing(let provider) = status else { return }

        if let player {
            player.pause()
            setStatus(.paused(provider))
            return
        }

        if synth.isSpeaking && !synth.isPaused {
            synth.pauseSpeaking(at: .immediate)
            setStatus(.paused(provider))
        }
    }

    func resume() {
        guard case .paused(let provider) = status else { return }

        if let player {
            player.play()
            setStatus(.playing(provider))
            return
        }

        if synth.isPaused {
            synth.continueSpeaking()
            setStatus(.playing(provider))
            monitorLocalSpeechCompletion()
            return
        }

        setStatus(.idle)
    }

    func stop() {
        playbackGeneration += 1
        streaming = false
        if synth.isSpeaking || synth.isPaused { synth.stopSpeaking(at: .immediate) }
        player?.stop(); player = nil
        cloudQueue.removeAll()
        cloudAudioQueue.removeAll()
        cloudSynthesizing = false
        cloudDraining = false
        activeCloudProvider = nil
        activeCacheText = nil
        activeGeneratedChunks = []
        currentCloudChunkIndex = nil
        replayAudioChunks = []
        currentReplayChunkIndex = nil
        replayingCachedAudio = false
        onFinishPlay = nil
        speechFinishTimer?.invalidate()
        speechFinishTimer = nil
        setStatus(.idle)
    }

    func refreshPlaybackRate() {
        player?.enableRate = true
        player?.rate = Settings.playbackSpeed
    }

    /// Moves through generated cloud audio without making another TTS request.
    /// System speech has no seek API, so the UI enables this only for audio with
    /// a real timeline.
    func skip(by seconds: TimeInterval) {
        guard abs(seconds) > 0.001, let player else { return }

        if replayingCachedAudio, let index = currentReplayChunkIndex {
            seekCachedAudio(from: player, index: index, by: seconds)
        } else if let index = currentCloudChunkIndex {
            seekLiveCloudAudio(from: player, index: index, by: seconds)
        }
    }

    // MARK: Internals

    private func utterance(for t: String) -> AVSpeechUtterance {
        let u = AVSpeechUtterance(string: t)
        u.voice = AVSpeechSynthesisVoice(language: t.containsCJK ? "zh-CN" : "en-US")
        u.rate = Settings.effectiveSpeechRate
        return u
    }

    private func localSpeak(_ t: String) {
        setStatus(.playing(AppFlavor.text("macOS 本地语音", "macOS Speech")))
        synth.speak(utterance(for: t))
        monitorLocalSpeechCompletion()
    }

    private func nextPlaybackGeneration() -> Int {
        playbackGeneration += 1
        return playbackGeneration
    }

    private func startDrainIfNeeded() {
        guard activeCloudProvider != nil else { return }
        cloudDraining = true
        synthesizeNextCloudChunkIfNeeded()
        playNextCloudChunkIfNeeded()
    }

    private func enqueueCloud(_ chunks: [String],
                              provider: CloudTTSProvider,
                              generation: Int,
                              cacheText: String?) {
        activeCloudProvider = provider
        activeCloudGeneration = generation
        activeCacheText = cacheText
        activeGeneratedChunks = []
        cloudQueue.append(contentsOf: chunks)
        startDrainIfNeeded()
    }

    private func synthesizeNextCloudChunkIfNeeded() {
        guard playbackGeneration == activeCloudGeneration else { return }
        guard !cloudSynthesizing, !cloudQueue.isEmpty else { return }
        let next = cloudQueue.removeFirst()
        guard let provider = activeCloudProvider else {
            localSpeak(next)
            synthesizeNextCloudChunkIfNeeded()
            return
        }
        cloudSynthesizing = true
        if player == nil && cloudAudioQueue.isEmpty && !isPaused {
            setStatus(.preparing(provider.displayName))
        }
        Task { [weak self] in
            do {
                let data = try await provider.synthesize(next)
                guard let self else { return }
                await MainActor.run {
                    guard self.playbackGeneration == self.activeCloudGeneration else { return }
                    self.cloudSynthesizing = false
                    self.activeGeneratedChunks.append(data)
                    if let text = self.activeCacheText {
                        self.lastGeneratedAudio = (text, self.activeGeneratedChunks, false)
                    }
                    self.cloudAudioQueue.append(QueuedCloudAudio(
                        index: self.activeGeneratedChunks.count - 1,
                        data: data
                    ))
                    self.playNextCloudChunkIfNeeded()
                    self.synthesizeNextCloudChunkIfNeeded()
                }
            } catch {
                NSLog("Dob · \(provider.displayName) 失败，回退本地语音：\(error)")
                guard let self else { return }
                await MainActor.run {
                    guard self.playbackGeneration == self.activeCloudGeneration else { return }
                    self.cloudSynthesizing = false
                    let remaining = ([next] + self.cloudQueue).joined(separator: "\n")
                    self.cloudQueue.removeAll()
                    self.cloudAudioQueue.removeAll()
                    self.cloudDraining = false
                    self.activeCloudProvider = nil
                    self.player?.stop()
                    self.player = nil
                    self.lastGeneratedAudio = nil
                    self.localSpeak(remaining)
                }
            }
        }
    }

    private func playNextCloudChunkIfNeeded() {
        guard playbackGeneration == activeCloudGeneration else { return }
        guard player == nil, !isPaused else { return }
        guard !cloudAudioQueue.isEmpty else {
            finishCloudPipelineIfPossible()
            return
        }
        let chunk = cloudAudioQueue.removeFirst()
        let label = activeCloudProvider?.displayName ?? AppFlavor.text("云语音", "Cloud Speech")
        setStatus(.playing(label))
        playThen(chunk.data, chunkIndex: chunk.index) { [weak self] in
            self?.playNextCloudChunkIfNeeded()
        }
    }

    private func finishCloudPipelineIfPossible() {
        guard player == nil, cloudAudioQueue.isEmpty else { return }
        if cloudSynthesizing {
            if let label = activeCloudProvider?.displayName, !isPaused {
                setStatus(.preparing(label))
            }
            return
        }
        if !cloudQueue.isEmpty {
            synthesizeNextCloudChunkIfNeeded()
            if let label = activeCloudProvider?.displayName, !isPaused {
                setStatus(.preparing(label))
            }
            return
        }
        guard !streaming else { return }
        cloudDraining = false
        if let text = activeCacheText {
            lastGeneratedAudio = (text, activeGeneratedChunks, true)
        }
        activeCloudProvider = nil
        activeCacheText = nil
        setStatus(.idle)
    }

    private func playSequence(_ chunks: [Data], _ done: @escaping () -> Void) {
        guard !chunks.isEmpty else {
            setStatus(.idle)
            done()
            return
        }
        replayingCachedAudio = true
        replayAudioChunks = chunks
        playCachedChunk(at: 0, startingAt: 0, done: done)
    }

    private func playCachedChunk(at index: Int,
                                 startingAt time: TimeInterval,
                                 autoplay: Bool = true,
                                 done: @escaping () -> Void) {
        guard replayAudioChunks.indices.contains(index) else {
            replayingCachedAudio = false
            currentReplayChunkIndex = nil
            setStatus(.idle)
            done()
            return
        }
        playThen(replayAudioChunks[index],
                 startingAt: time,
                 replayIndex: index,
                 autoplay: autoplay) { [weak self] in
            self?.playCachedChunk(at: index + 1, startingAt: 0, done: done)
        }
    }

    private func playThen(_ data: Data,
                          startingAt time: TimeInterval = 0,
                          chunkIndex: Int? = nil,
                          replayIndex: Int? = nil,
                          autoplay: Bool = true,
                          _ done: @escaping () -> Void) {
        do {
            let p = try AVAudioPlayer(data: data)
            p.delegate = self
            p.enableRate = true
            p.rate = Settings.playbackSpeed
            p.currentTime = min(max(time, 0), max(p.duration - 0.001, 0))
            player = p
            currentCloudChunkIndex = chunkIndex
            currentReplayChunkIndex = replayIndex
            onFinishPlay = done
            if autoplay {
                p.play()
            }
        } catch {
            NSLog("Dob · 音频播放失败：\(error)")
            done()
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard self.player === player else { return }
        self.player = nil
        currentCloudChunkIndex = nil
        currentReplayChunkIndex = nil
        let done = onFinishPlay
        onFinishPlay = nil
        done?()
    }

    private func seekLiveCloudAudio(from player: AVAudioPlayer,
                                    index: Int,
                                    by seconds: TimeInterval) {
        guard let target = targetPosition(in: activeGeneratedChunks,
                                          currentIndex: index,
                                          currentTime: player.currentTime,
                                          currentDuration: player.duration,
                                          by: seconds) else { return }
        let shouldPlay = isPlaying
        abandonCurrentPlayer()

        // Requeue every generated chunk after the destination. The text queue
        // remains intact, so chunks not synthesized yet still arrive normally.
        cloudAudioQueue = activeGeneratedChunks.indices
            .filter { $0 > target.index }
            .map { QueuedCloudAudio(index: $0, data: activeGeneratedChunks[$0]) }
        playThen(activeGeneratedChunks[target.index],
                 startingAt: target.time,
                 chunkIndex: target.index,
                 autoplay: shouldPlay) { [weak self] in
            self?.playNextCloudChunkIfNeeded()
        }
        restorePlaybackStatus(autoplay: shouldPlay)
    }

    private func seekCachedAudio(from player: AVAudioPlayer,
                                 index: Int,
                                 by seconds: TimeInterval) {
        guard let target = targetPosition(in: replayAudioChunks,
                                          currentIndex: index,
                                          currentTime: player.currentTime,
                                          currentDuration: player.duration,
                                          by: seconds) else { return }
        let shouldPlay = isPlaying
        abandonCurrentPlayer()
        playCachedChunk(at: target.index, startingAt: target.time, autoplay: shouldPlay) {}
        restorePlaybackStatus(autoplay: shouldPlay)
    }

    private func targetPosition(in chunks: [Data],
                                currentIndex: Int,
                                currentTime: TimeInterval,
                                currentDuration: TimeInterval,
                                by seconds: TimeInterval) -> (index: Int, time: TimeInterval)? {
        guard chunks.indices.contains(currentIndex) else { return nil }
        let durations = chunks.enumerated().map { offset, data in
            if offset == currentIndex { return currentDuration }
            return (try? AVAudioPlayer(data: data))?.duration ?? 0
        }
        let total = durations.reduce(0, +)
        guard total > 0 else { return nil }

        let elapsed = durations.prefix(currentIndex).reduce(0, +) + currentTime
        let destination = min(max(elapsed + seconds, 0), max(total - 0.001, 0))
        var cursor: TimeInterval = 0
        for (index, duration) in durations.enumerated() {
            if destination < cursor + duration || index == durations.indices.last {
                return (index, max(destination - cursor, 0))
            }
            cursor += duration
        }
        return nil
    }

    private func abandonCurrentPlayer() {
        let active = player
        player = nil
        currentCloudChunkIndex = nil
        currentReplayChunkIndex = nil
        onFinishPlay = nil
        active?.stop()
    }

    private func restorePlaybackStatus(autoplay: Bool) {
        let label: String
        switch status {
        case .playing(let value), .paused(let value): label = value
        default: label = AppFlavor.text("云语音", "Cloud Speech")
        }
        setStatus(autoplay ? .playing(label) : .paused(label))
    }

    private func monitorLocalSpeechCompletion() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.speechFinishTimer?.invalidate()
            self.speechFinishTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }
                guard self.canMarkLocalSpeechIdle else { return }
                timer.invalidate()
                self.speechFinishTimer = nil
                self.setStatus(.idle)
            }
        }
    }

    private var canMarkLocalSpeechIdle: Bool {
        !synth.isSpeaking &&
        !synth.isPaused &&
        player == nil &&
        activeCloudProvider == nil &&
        !cloudSynthesizing &&
        !cloudDraining &&
        cloudQueue.isEmpty
    }

    private func setStatus(_ status: SpeechPlaybackStatus) {
        if Thread.isMainThread {
            self.status = status
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.status = status
            }
        }
    }
}

extension Speaker {
    var isIdle: Bool {
        if case .idle = status { return true }
        return false
    }

    var isPreparing: Bool {
        if case .preparing = status { return true }
        return false
    }

    var isPlaying: Bool {
        if case .playing = status { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = status { return true }
        return false
    }

    var canSeek: Bool {
        player != nil && (currentCloudChunkIndex != nil || currentReplayChunkIndex != nil)
    }
}
