import AppKit
import Vision

final class ScreenOCR {
    static let shared = ScreenOCR()

    private var window: OCRSelectionWindow?

    private init() {}

    func start(completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            guard self.window == nil else {
                completion(nil)
                return
            }
            if !CGPreflightScreenCaptureAccess() {
                _ = CGRequestScreenCaptureAccess()
            }
            let mouse = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
            guard let screen else {
                completion(nil)
                return
            }

            let window = OCRSelectionWindow(screen: screen)
            let view = OCRSelectionView(screen: screen) { [weak self, weak window] rect in
                window?.orderOut(nil)
                self?.window = nil
                guard let rect else {
                    completion(nil)
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let text = Self.recognizeText(in: rect, on: screen)
                    DispatchQueue.main.async { completion(text) }
                }
            }
            window.contentView = view
            self.window = window
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
        }
    }

    private static func recognizeText(in rect: CGRect, on screen: NSScreen) -> String? {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let fullImage = CGDisplayCreateImage(CGDirectDisplayID(displayID.uint32Value)) else { return nil }

        let scaleX = CGFloat(fullImage.width) / screen.frame.width
        let scaleY = CGFloat(fullImage.height) / screen.frame.height
        let cropRect = CGRect(x: rect.minX * scaleX,
                              y: (screen.frame.height - rect.maxY) * scaleY,
                              width: rect.width * scaleX,
                              height: rect.height * scaleY)
            .integral
        guard cropRect.width >= 8, cropRect.height >= 8,
              let cropped = fullImage.cropping(to: cropRect) else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = AppFlavor.isInternational ? ["en-US", "zh-Hans", "zh-Hant"] : ["zh-Hans", "zh-Hant", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cropped, options: [:])
        do {
            try handler.perform([request])
            let lines = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            NSLog("ListenMark · OCR 失败：\(error)")
            return nil
        }
    }
}

private final class OCRSelectionWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = false
    }

    override var canBecomeKey: Bool { true }
}

private final class OCRSelectionView: NSView {
    private let screen: NSScreen
    private let onComplete: (CGRect?) -> Void
    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?

    init(screen: NSScreen, onComplete: @escaping (CGRect?) -> Void) {
        self.screen = screen
        self.onComplete = onComplete
        super.init(frame: NSRect(origin: .zero, size: screen.frame.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = event.locationInWindow
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = event.locationInWindow
        let rect = selectionRect
        onComplete(rect.width >= 8 && rect.height >= 8 ? rect : nil)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onComplete(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let startPoint, let currentPoint else { return }
        let rect = NSRect(x: min(startPoint.x, currentPoint.x),
                          y: min(startPoint.y, currentPoint.y),
                          width: abs(startPoint.x - currentPoint.x),
                          height: abs(startPoint.y - currentPoint.y))

        NSColor.controlAccentColor.withAlphaComponent(0.16).setFill()
        rect.fill()
        NSColor.controlAccentColor.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.stroke()
    }

    private var selectionRect: CGRect {
        guard let startPoint, let currentPoint else { return .zero }
        return CGRect(x: min(startPoint.x, currentPoint.x),
                      y: min(startPoint.y, currentPoint.y),
                      width: abs(startPoint.x - currentPoint.x),
                      height: abs(startPoint.y - currentPoint.y))
            .intersection(CGRect(origin: .zero, size: screen.frame.size))
    }
}
