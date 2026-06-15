import SwiftUI

struct AboutView: View {
    private static let repositoryURL = URL(string: "https://github.com/Milktang0128/Dob")!

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return AppFlavor.text("版本 \(version)（\(build)）", "Version \(version) (\(build))")
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .cornerRadius(16)

            VStack(spacing: 6) {
                Text(AppFlavor.appName)
                    .font(.system(size: 24, weight: .semibold))
                Text(versionText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Text(AppFlavor.tagline)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                Link(destination: Self.repositoryURL) {
                    Label("github.com/Milktang0128/Dob", systemImage: "link")
                        .font(.system(size: 13, weight: .medium))
                }

                Text(AppFlavor.text("作者：Milk Tang", "By Milk Tang"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 26)
        .frame(width: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
