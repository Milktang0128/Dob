import AppKit
import Foundation

@MainActor
final class GitHubReleaseUpdater {
    static let shared = GitHubReleaseUpdater()

    private let owner = "Milktang0128"
    private let repo = "ListenMark"
    private let lastCheckKey = "githubReleaseUpdater.lastCheckAt"
    private let checkInterval: TimeInterval = 24 * 60 * 60
    private var isDownloading = false

    private init() {}

    func checkAutomaticallyIfNeeded() {
        let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date
        guard last == nil || Date().timeIntervalSince(last!) > checkInterval else { return }
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)

        Task { await check(silent: true) }
    }

    func checkNow() {
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)
        Task { await check(silent: false) }
    }

    private func check(silent: Bool) async {
        do {
            let release = try await fetchLatestRelease()
            guard release.isUsableForCurrentFlavor else {
                if !silent {
                    showMessage(AppFlavor.text("没有可用更新", "No Update Available"),
                                AppFlavor.text("当前发布通道没有可安装的新版本。", "There is no installable release on the current update channel."))
                }
                return
            }

            let current = currentVersion
            guard Self.compare(release.cleanVersion, current) == .orderedDescending else {
                if !silent {
                    showMessage(AppFlavor.text("已是最新版本", "You're Up to Date"),
                                AppFlavor.text("当前版本 \(current) 已经是 GitHub Releases 上的最新版本。", "Version \(current) is already the newest release on this channel."))
                }
                return
            }

            guard let asset = release.preferredDMGAsset else {
                if !silent {
                    showMessage(AppFlavor.text("发现新版本 \(release.tagName)", "New Version Found \(release.tagName)"),
                                AppFlavor.text("但这个 Release 里没有找到适合当前 Mac 的 DMG 安装包。", "This release does not include a DMG installer for this Mac."))
                }
                return
            }

            promptForUpdate(release: release, asset: asset)
        } catch {
            if !silent { showMessage(AppFlavor.text("检查更新失败", "Update Check Failed"), error.localizedDescription) }
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        let releases: [GitHubRelease] = try await fetch("https://api.github.com/repos/\(owner)/\(repo)/releases?per_page=30")
        guard let release = releases.first(where: { $0.isUsableForCurrentFlavor }) else {
            throw UpdaterError.noUsableRelease
        }
        return release
    }

    private func fetch<T: Decodable>(_ rawURL: String) async throws -> T {
        let url = URL(string: rawURL)!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ListenMark", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw UpdaterError.badResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func promptForUpdate(release: GitHubRelease, asset: GitHubAsset) {
        let size = ByteCountFormatter.string(fromByteCount: Int64(asset.size), countStyle: .file)
        let alert = NSAlert()
        alert.messageText = AppFlavor.text("发现新版本 \(release.tagName)", "New Version Found \(release.tagName)")
        alert.informativeText = AppFlavor.text(
            """
            当前版本：\(currentVersion)
            安装包：\(asset.name)（\(size)）

            下载后会自动打开 DMG，你可以把「过耳不忘」拖到 Applications 里完成更新。
            """,
            """
            Current version: \(currentVersion)
            Installer: \(asset.name) (\(size))

            After download, the DMG opens automatically. Drag ListenMark into Applications to update.
            """
        )
        alert.addButton(withTitle: AppFlavor.text("下载并打开", "Download and Open"))
        alert.addButton(withTitle: AppFlavor.text("查看发布页", "View Release Page"))
        alert.addButton(withTitle: AppFlavor.text("稍后", "Later"))
        NSApp.activate(ignoringOtherApps: true)

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            downloadAndOpen(asset)
        case .alertSecondButtonReturn:
            if let url = URL(string: release.htmlURL) { NSWorkspace.shared.open(url) }
        default:
            break
        }
    }

    private func downloadAndOpen(_ asset: GitHubAsset) {
        guard !isDownloading else { return }
        isDownloading = true

        Task {
            defer { isDownloading = false }
            do {
                let destination = try await download(asset)
                NSWorkspace.shared.open(destination)
            } catch {
                showMessage(AppFlavor.text("下载更新失败", "Update Download Failed"), error.localizedDescription)
            }
        }
    }

    private func download(_ asset: GitHubAsset) async throws -> URL {
        guard let url = URL(string: asset.downloadURL) else { throw UpdaterError.badDownloadURL }
        var request = URLRequest(url: url)
        request.setValue("ListenMark", forHTTPHeaderField: "User-Agent")

        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw UpdaterError.badResponse
        }

        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let destination = downloads.appendingPathComponent(asset.name)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private func showMessage(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: AppFlavor.text("好", "OK"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let l = versionParts(lhs)
        let r = versionParts(rhs)
        let count = max(l.count, r.count)
        for i in 0..<count {
            let lv = i < l.count ? l[i] : 0
            let rv = i < r.count ? r[i] : 0
            if lv > rv { return .orderedDescending }
            if lv < rv { return .orderedAscending }
        }
        return .orderedSame
    }

    private static func versionParts(_ value: String) -> [Int] {
        let core = value.split(separator: "-", maxSplits: 1).first.map(String.init) ?? value
        return core
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split { !$0.isNumber }
            .prefix(3)
            .compactMap { Int($0) }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let htmlURL: String
    let draft: Bool
    let prerelease: Bool
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case draft
        case prerelease
        case assets
    }

    var cleanVersion: String {
        var value = tagName
        if value.hasPrefix(AppFlavor.releaseTagPrefix) {
            value.removeFirst(AppFlavor.releaseTagPrefix.count)
            return value
        }
        return tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    var isUsableForCurrentFlavor: Bool {
        guard !draft else { return false }
        if AppFlavor.isInternational {
            return tagName.hasPrefix(AppFlavor.releaseTagPrefix)
        }
        return !prerelease && tagName.hasPrefix(AppFlavor.releaseTagPrefix)
    }

    var preferredDMGAsset: GitHubAsset? {
        let dmgs = assets.filter { $0.name.lowercased().hasSuffix(".dmg") }
        let arch = Hardware.currentReleaseArch
        return dmgs.first { $0.name.lowercased().contains(arch) } ?? dmgs.first
    }
}

private struct GitHubAsset: Decodable {
    let name: String
    let size: Int
    let downloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case downloadURL = "browser_download_url"
    }
}

private enum Hardware {
    static var currentReleaseArch: String {
        #if arch(arm64)
        "arm64"
        #else
        "x86_64"
        #endif
    }
}

private enum UpdaterError: LocalizedError {
    case noUsableRelease
    case badResponse
    case badDownloadURL

    var errorDescription: String? {
        switch self {
        case .noUsableRelease:
            return AppFlavor.text("当前发布通道没有可用的 GitHub Release。", "No usable GitHub release exists on the current channel.")
        case .badResponse:
            return AppFlavor.text("GitHub 返回了无法使用的响应。", "GitHub returned an unusable response.")
        case .badDownloadURL:
            return AppFlavor.text("GitHub Release 资产缺少有效下载地址。", "The GitHub release asset is missing a valid download URL.")
        }
    }
}
