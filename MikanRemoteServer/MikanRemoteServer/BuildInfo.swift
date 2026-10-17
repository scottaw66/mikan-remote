import Foundation

/// The running app's version, build number and source commit, for Settings
/// (Scott, 2026-10-15: every app shows its version and git commit there).
/// The commit comes from `build-info.json`, which scripts/stamp-build-info.sh
/// writes into the app bundle at build time. Copied from TZed's on 2026-10-16.
enum BuildInfo {
    /// "Version 0.3.2 (5) · 1a2b3c4". Builds without the stamp (SwiftUI
    /// previews, tests) say "unknown" for the commit.
    static func summary(bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "Version \(version) (\(build)) · \(commit(bundle: bundle))"
    }

    static func commit(bundle: Bundle = .main) -> String {
        guard let url = bundle.url(forResource: "build-info", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let info = try? JSONDecoder().decode([String: String].self, from: data),
              let commit = info["commit"], !commit.isEmpty
        else { return "unknown" }
        return commit
    }
}
