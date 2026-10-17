import AppKit
import CryptoKit
import Foundation
import os
import Security

/// The app's own updater (added in 1.2.0, 2026-10-16), copied from TZed's
/// (tzed/apps/TZed-macOS/Updater.swift, itself from Voices of BabbleOn's and
/// Claude Usage's, which chose this over Sparkle to keep third-party code
/// out). Scott asked for it in every Mac app once they moved to the
/// BlueDragonfly team (2026-10-16); the files live on mikansoftware.app beside
/// the other apps', in their own unlisted folder. It replaces this bundle in
/// /Applications and runs ditto/spctl, which the App Sandbox forbids, so this
/// app must not be sandboxed.
///
/// Once a day, and whenever someone presses Check Now, it reads `feedURL`.
/// That's a small JSON file written by scripts/publish-update.sh and served,
/// with the zip and DMG, from Scott's own server. The folder is unlisted:
/// an unguessable path that no page links to and the server won't list
/// (Scott, 2026-10-11: the DMG shouldn't be findable with a browser). That
/// hides it; it doesn't lock it, since anyone holding the app can read this URL. If the feed
/// names a higher build, the menu-bar window offers to install it. Nothing
/// installs until someone presses Install. Install downloads the zip and goes
/// no further unless every check below passes:
///   1. the zip's SHA-256 matches the feed's;
///   2. the app inside is signed with Developer ID by this running app's own
///      team, has this app's bundle ID, and validates strictly, nested code
///      included;
///   3. Gatekeeper accepts it as notarized (spctl, which reads the stapled
///      ticket);
///   4. its build number is higher than this one's.
/// It then replaces this bundle in place and relaunches. The bundle ID and
/// team don't change, so privacy permissions and the login item carry over.
@MainActor final class Updater: ObservableObject {
    static let shared = Updater()

    /// The feed. Every shipped copy has this URL built in, so it must keep
    /// working for as long as old copies are installed. For testing,
    /// `defaults write com.bluedragonfly.MikanRemoteServer UpdateFeedURL https://…`
    /// points one Mac at another feed; every install check below still applies.
    /// scripts/publish-update.sh reads `releasePath` from this line; keep the
    /// two in step by changing it only here.
    static let releasePath = "u/aed9f2bf6a11b1df8dccc3ad/mikanremote"
    static let defaultFeedURL = URL(string: "https://mikansoftware.app/\(releasePath)/appcast.json")!
    static var feedURL: URL {
        if let text = UserDefaults.standard.string(forKey: "UpdateFeedURL"), let url = URL(string: text), url.scheme == "https" { return url }
        return defaultFeedURL
    }
    static let checkInterval: TimeInterval = 24 * 60 * 60
    /// The real zip is a few MB; this cap only stops a runaway download.
    static let maxDownloadBytes: Int64 = 200 * 1024 * 1024

    struct Release: Codable, Equatable {
        let version: String
        let build: Int
        let url: URL
        let sha256: String
        let notes: String?
        let minimumSystemVersion: String?
    }

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case installing(String)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    /// Why the last automatic check failed, shown quietly in Settings; nil
    /// after any check that reaches the feed.
    @Published private(set) var lastError: String?
    @Published private(set) var lastCheck: Date? {
        didSet { UserDefaults.standard.set(lastCheck, forKey: Self.lastCheckKey) }
    }
    @Published var automatic: Bool {
        didSet { UserDefaults.standard.set(automatic, forKey: Self.automaticKey) }
    }

    /// Debug builds never update themselves: they run from build folders, and
    /// installing a release over one would be wrong.
    #if DEBUG
    let enabled = false
    #else
    let enabled = true
    #endif

    private static let lastCheckKey = "updateLastCheck"
    private static let automaticKey = "updateAutomaticCheck"
    private var loop: Task<Void, Never>?

    private init() {
        lastCheck = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
        automatic = UserDefaults.standard.object(forKey: Self.automaticKey) as? Bool ?? true
    }

    var isInstalling: Bool { if case .installing = state { return true } else { return false } }
    var isFailed: Bool { if case .failed = state { return true } else { return false } }

    var available: Release? {
        if case .available(let release) = state { return release }
        return nil
    }

    /// Checks every hour whether a day has passed since the last check, so a
    /// Mac that sleeps through the due time still checks soon after it wakes.
    func start() {
        guard enabled, loop == nil else { return }
        removeLeftovers()
        loop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30)) // let launch and the permission checks go first
            while !Task.isCancelled {
                guard let self else { return }
                if self.automatic, Date().timeIntervalSince(self.lastCheck ?? .distantPast) >= Self.checkInterval {
                    await self.check(manual: false)
                }
                try? await Task.sleep(for: .seconds(60 * 60))
            }
        }
    }

    /// An automatic check that fails stays quiet: it's logged, and Settings
    /// shows it in its small status line only. A manual one shows the error.
    func check(manual: Bool) async {
        guard enabled else { return }
        switch state {
        case .checking, .installing: return
        default: break
        }
        state = .checking
        do {
            let release = try await fetchFeed()
            lastCheck = Date()
            lastError = nil
            if release.build > Self.currentBuild, Self.supportsThisMac(release) {
                if available != release { log("Update available: \(release.version) (\(release.build))") }
                state = .available(release)
            } else {
                state = .upToDate
            }
        } catch {
            log("Update check failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            state = manual ? .failed(error.localizedDescription) : .idle
        }
    }

    func install(_ release: Release) {
        guard enabled else { return }
        if case .installing = state { return }
        Task {
            do {
                log("Installing update \(release.version) (\(release.build))")
                try await performInstall(release)
            } catch {
                log("Update failed: \(error.localizedDescription)")
                state = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: Feed

    private func fetchFeed() async throws -> Release {
        var request = URLRequest(url: Self.feedURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        request.setValue("MikanRemoteServer/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await Self.session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure("The update feed couldn't be read (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)).") }
        let release = try JSONDecoder().decode(Release.self, from: data)
        guard release.url.scheme == "https" else { throw Failure("The update feed points somewhere other than an https address.") }
        return release
    }

    // MARK: Install

    private func performInstall(_ release: Release) async throws {
        let current = Bundle.main.bundleURL
        guard !Self.isTranslocated else {
            throw Failure("MikanRemoteServer is running from the disk image, so it can't update itself. Move it to Applications first.")
        }
        guard FileManager.default.isWritableFile(atPath: current.deletingLastPathComponent().path) else {
            throw Failure("MikanRemoteServer can't replace itself in \(current.deletingLastPathComponent().path). Ask for the new version's DMG and install it by hand.")
        }

        state = .installing("Downloading \(release.version)…")
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("MikanRemoteServer-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        let zip = work.appendingPathComponent("update.zip")
        let (downloaded, response) = try await Self.session.download(for: URLRequest(url: release.url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 120))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure("The download failed (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)).") }
        try FileManager.default.moveItem(at: downloaded, to: zip)
        let size = (try FileManager.default.attributesOfItem(atPath: zip.path)[.size] as? NSNumber)?.int64Value ?? 0
        guard size > 0, size <= Self.maxDownloadBytes else { throw Failure("The download was an unexpected size (\(size) bytes).") }

        state = .installing("Checking the download…")
        // 1. Checksum.
        let digest = try await Task.detached { SHA256.hash(data: try Data(contentsOf: zip, options: .mappedIfSafe)) }.value
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        guard hex == release.sha256.lowercased() else { throw Failure("The download doesn't match the published checksum, so it wasn't installed.") }

        // Unpack next to the installed app, so the swap below is a rename on
        // one volume rather than a copy across volumes.
        let unpacked = current.deletingLastPathComponent().appendingPathComponent(".MikanRemoteServer-update-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: unpacked) }
        try await Self.run("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path])
        let candidate = unpacked.appendingPathComponent(current.lastPathComponent)
        guard FileManager.default.fileExists(atPath: candidate.path) else { throw Failure("The download doesn't contain \(current.lastPathComponent).") }

        // 2. Signature: same team, same bundle ID, Developer ID, strict, nested code.
        try Self.verifySignature(of: candidate)
        // 3. Notarization, as Gatekeeper sees it.
        do { try await Self.run("/usr/sbin/spctl", ["--assess", "--type", "execute", candidate.path]) }
        catch { throw Failure("Gatekeeper didn't accept the download as notarized, so it wasn't installed.") }
        // 4. Newer than this build.
        guard let info = Bundle(url: candidate)?.infoDictionary,
              info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              let build = (info["CFBundleVersion"] as? String).flatMap(Int.init), build > Self.currentBuild else {
            throw Failure("The download isn't a newer build of MikanRemoteServer.")
        }

        state = .installing("Installing \(release.version)…")
        // Swap the bundle in place; the running copy keeps its open files.
        _ = try FileManager.default.replaceItemAt(current, withItemAt: candidate)
        log("Installed update \(release.version) (\(build)); relaunching")
        // terminate() below exits without running the defers above, so clean
        // up here. (Claude Usage 1.1.1 relied on the defers and left an empty
        // /Applications/.ClaudeUsage-update-<uuid> folder behind each time;
        // removeLeftovers() clears those at launch.)
        try? FileManager.default.removeItem(at: unpacked)
        try? FileManager.default.removeItem(at: work)

        // Relaunch once this process has exited.
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "while /bin/kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$0\"", current.path]
        try relaunch.run()
        NSApplication.shared.terminate(nil)
    }

    /// Staging folders an earlier install or move left behind (a crash
    /// mid-install, say). Only our own `.MikanRemoteServer-update-` / `.MikanRemoteServer-move-` /
    /// `MikanRemoteServer-update-` prefixes are touched.
    private func removeLeftovers() {
        let fm = FileManager.default
        let places: [(URL, [String])] = [
            (Bundle.main.bundleURL.deletingLastPathComponent(), [".MikanRemoteServer-update-", ".MikanRemoteServer-move-"]),
            (fm.temporaryDirectory, ["MikanRemoteServer-update-"]),
        ]
        for (folder, prefixes) in places {
            guard let names = try? fm.contentsOfDirectory(atPath: folder.path) else { continue }
            for name in names where prefixes.contains(where: name.hasPrefix) {
                if (try? fm.removeItem(at: folder.appendingPathComponent(name))) != nil {
                    log("Removed leftover \(folder.appendingPathComponent(name).path)")
                }
            }
        }
    }

    // MARK: Running from the disk image

    /// Opened straight from the DMG (or from Downloads with quarantine), macOS
    /// runs the app from a read-only randomized path, where it can't replace
    /// itself. Idea from Hostbar's Translocation.swift.
    static var isTranslocated: Bool {
        let path = Bundle.main.bundlePath
        return path.contains("/AppTranslocation/") || path.hasPrefix("/Volumes/")
    }

    /// At launch: when running from the disk image, offer to copy this app into
    /// /Applications and relaunch from there. Asks first; replacing an older
    /// copy already in /Applications is part of what it asks.
    func offerMoveToApplications() {
        guard enabled, Self.isTranslocated else { return }
        let destination = URL(fileURLWithPath: "/Applications").appendingPathComponent(Bundle.main.bundleURL.lastPathComponent)
        let exists = FileManager.default.fileExists(atPath: destination.path)
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Move MikanRemoteServer to Applications?"
        alert.informativeText = "It's running from the disk image, where it can't keep itself up to date."
            + (exists ? " This replaces the copy already in Applications." : "")
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            let staging = destination.deletingLastPathComponent().appendingPathComponent(".MikanRemoteServer-move-\(UUID().uuidString).app")
            try? FileManager.default.removeItem(at: staging)
            try FileManager.default.copyItem(at: Bundle.main.bundleURL, to: staging)
            if exists {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: staging)
            } else {
                try FileManager.default.moveItem(at: staging, to: destination)
            }
            log("Moved to \(destination.path) from the disk image; relaunching")
            let relaunch = Process()
            relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
            relaunch.arguments = ["-c", "while /bin/kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$0\"", destination.path]
            try relaunch.run()
            NSApplication.shared.terminate(nil)
        } catch {
            let failure = NSAlert()
            failure.messageText = "Couldn't move MikanRemoteServer"
            failure.informativeText = "\(error.localizedDescription) Drag it from the disk image to Applications yourself."
            failure.runModal()
        }
    }

    // MARK: Checks

    static var currentBuild: Int {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String).flatMap(Int.init) ?? 0
    }

    private static func supportsThisMac(_ release: Release) -> Bool {
        guard let minimum = release.minimumSystemVersion else { return true }
        let parts = minimum.split(separator: ".").compactMap { Int($0) }
        let required = OperatingSystemVersion(majorVersion: parts.first ?? 0, minorVersion: parts.count > 1 ? parts[1] : 0, patchVersion: parts.count > 2 ? parts[2] : 0)
        return ProcessInfo.processInfo.isOperatingSystemAtLeast(required)
    }

    /// The running app's own Developer ID team. Without one (an unsigned or
    /// development build) nothing can be verified, so nothing installs.
    private static func ownTeam() throws -> String {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let team = (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String, !team.isEmpty else {
            throw Failure("This copy of MikanRemoteServer isn't signed with a team ID, so it can't verify updates.")
        }
        return team
    }

    private static func verifySignature(of app: URL) throws {
        guard let bundleID = Bundle.main.bundleIdentifier else { throw Failure("This copy of MikanRemoteServer has no bundle ID.") }
        let team = try ownTeam()
        // Developer ID Application leaf (OID 1.2.840.113635.100.6.1.13), issued
        // under Apple's root, to this team, for this bundle ID.
        let text = "anchor apple generic and identifier \"\(bundleID)\" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"\(team)\""
        var requirement: SecRequirement?
        var staticCode: SecStaticCode?
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(app as CFURL, [], &staticCode) == errSecSuccess, let staticCode else {
            throw Failure("The download's signature couldn't be read.")
        }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        var error: Unmanaged<CFError>?
        guard SecStaticCodeCheckValidityWithErrors(staticCode, flags, requirement, &error) == errSecSuccess else {
            let detail = error?.takeRetainedValue().localizedDescription ?? "unknown error"
            throw Failure("The download isn't signed by MikanRemoteServer's developer (\(detail)), so it wasn't installed.")
        }
    }

    // MARK: Plumbing

    private static let logger = Logger(subsystem: "com.bluedragonfly.MikanRemoteServer", category: "updater")
    private func log(_ message: String) { Self.logger.notice("\(message, privacy: .public)") }

    /// No cookies, cache or credentials: the feed and download need none.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    private static func run(_ tool: String, _ arguments: [String]) async throws {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw Failure("\(URL(fileURLWithPath: tool).lastPathComponent) exited with status \(process.terminationStatus).")
            }
        }.value
    }

    struct Failure: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
