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
            guard release.isUsable else {
                if !silent { showMessage("没有可用更新", "最新 GitHub Release 仍是草稿或预发布版本。") }
                return
            }

            let current = currentVersion
            guard Self.compare(release.cleanVersion, current) == .orderedDescending else {
                if !silent { showMessage("已是最新版本", "当前版本 \(current) 已经是 GitHub Releases 上的最新版本。") }
                return
            }

            guard let asset = release.preferredDMGAsset else {
                if !silent {
                    showMessage("发现新版本 \(release.tagName)", "但这个 Release 里没有找到适合当前 Mac 的 DMG 安装包。")
                }
                return
            }

            promptForUpdate(release: release, asset: asset)
        } catch {
            if !silent { showMessage("检查更新失败", error.localizedDescription) }
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ListenMark", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw UpdaterError.badResponse
        }
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    private func promptForUpdate(release: GitHubRelease, asset: GitHubAsset) {
        let size = ByteCountFormatter.string(fromByteCount: Int64(asset.size), countStyle: .file)
        let alert = NSAlert()
        alert.messageText = "发现新版本 \(release.tagName)"
        alert.informativeText = """
        当前版本：\(currentVersion)
        安装包：\(asset.name)（\(size)）

        下载后会自动打开 DMG，你可以把 ListenMark 拖到 Applications 里完成更新。
        """
        alert.addButton(withTitle: "下载并打开")
        alert.addButton(withTitle: "查看发布页")
        alert.addButton(withTitle: "稍后")
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
                showMessage("下载更新失败", error.localizedDescription)
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
        alert.addButton(withTitle: "好")
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
        value
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split { !$0.isNumber }
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
        tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    var isUsable: Bool { !draft && !prerelease }

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
    case badResponse
    case badDownloadURL

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "GitHub 返回了无法使用的响应。"
        case .badDownloadURL:
            return "GitHub Release 资产缺少有效下载地址。"
        }
    }
}
