import Foundation
import ServiceManagement
import os

/// One-time carry-over from the app as it was before 1.2.0, when it was
/// signed by Scott's personal team as `blue.dragonfly.MikanRemoteServer`. On 2026-10-16 it moved to
/// the BlueDragonfly LLC team as `com.bluedragonfly.MikanRemoteServer`; macOS keys preferences and
/// login items by bundle ID, so without this the re-signed app would start
/// with factory settings. Modeled on VOB's LegacyMigration.swift.
///
/// Runs once, before anything reads UserDefaults, and copies every key the
/// old domain holds that the new one doesn't have yet. The old domain belongs
/// to this app alone (its window frames and status-item position included),
/// so nothing in it is foreign. Privacy permissions (Accessibility and the
/// like) can't be carried: macOS asks for them again.
enum LegacyMigration {
    static let oldBundleID = "blue.dragonfly.MikanRemoteServer"
    private static let doneKey = "legacyMigrated"
    private static let logger = Logger(subsystem: "com.bluedragonfly.MikanRemoteServer", category: "migration")

    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        defaults.set(true, forKey: doneKey)
        guard let old = defaults.persistentDomain(forName: oldBundleID), !old.isEmpty else { return }
        var copied = 0
        for (key, value) in old where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
            copied += 1
        }
        logger.notice("Copied \(copied) settings from \(oldBundleID, privacy: .public)")
        // The new app is a different login item to macOS, and the old one's
        // state isn't readable, so assume it was on (as VOB does); turning it
        // off is one click.
        if SMAppService.mainApp.status != .enabled {
            do { try SMAppService.mainApp.register() } catch {
                logger.error("Login item not registered: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
