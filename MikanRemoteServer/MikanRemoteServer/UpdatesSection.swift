import SwiftUI

/// Settings' "Updates" section, from TZed's Settings → General (2026-10-16).
/// It goes first, as in Claude Usage, VOB and TZed (Scott, 2026-10-11: lower
/// down, the result of Check Now landed out of sight).
struct UpdatesSection: View {
    var body: some View {
        Section("Updates") { UpdatesControls() }
    }
}

/// The section's rows, for a Settings view that isn't a Form.
struct UpdatesControls: View {
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        Group {
            if let release = updater.available {
                Text("MikanRemoteServer \(release.version) is available").font(.headline)
                if let notes = release.notes, !notes.isEmpty {
                    Text(notes).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 8) {
                if let release = updater.available {
                    Button("Install and Relaunch") { updater.install(release) }
                        .buttonStyle(.borderedProminent)
                }
                Button("Check Now") { Task { await updater.check(manual: true) } }
                    .disabled(!updater.enabled || updater.state == .checking || updater.isInstalling)
                if updater.state == .checking || updater.isInstalling {
                    ProgressView().controlSize(.small)
                }
            }
            Text(status).font(.caption)
                .foregroundStyle(updater.isFailed ? .orange : .secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Check for updates daily", isOn: $updater.automatic)
        }
    }

    private var status: String {
        guard updater.enabled else { return "Development builds don't update themselves." }
        let checked = updater.lastCheck.map {
            "Last checked \($0.formatted(date: .abbreviated, time: .shortened))."
        } ?? "Not checked yet."
        switch updater.state {
        case .idle, .upToDate:
            if updater.state == .idle, let error = updater.lastError {
                return "The last check didn't work: \(error) It tries again within the hour."
            }
            return (updater.state == .upToDate ? "You have the latest version. " : "") + checked
        case .checking: return "Checking…"
        case .available: return "It's checked as signed and notarized by MikanRemoteServer's developer before anything is replaced."
        case .installing(let step): return step
        case .failed(let message): return message
        }
    }
}
