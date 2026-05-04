import SwiftUI

@main
struct MikanServerApp: App {
    @State private var manager = MenuBarManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(manager: manager)
                .frame(width: 220)
        } label: {
            Image(systemName: manager.isConnected
                  ? "antenna.radiowaves.left.and.right"
                  : "antenna.radiowaves.left.and.right.slash")
        }
        .menuBarExtraStyle(.window)

        Window("Edit Actions", id: "action-editor") {
            ActionEditorView(store: manager.actionStore, onSave: { manager.pushActions() })
        }
        .defaultSize(width: 500, height: 400)

    }
}

private struct AccessibilityWarningView: View {
    let onGrant: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Accessibility permission required")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            Text("Trackpad control needs accessibility access. Click + in System Settings, then drag MikanRemoteServer from the Finder window that opens.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Grant Permission", action: onGrant)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct MenuBarContentView: View {
    @Bindable var manager: MenuBarManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            if !manager.isAccessibilityGranted {
                AccessibilityWarningView {
                    manager.openAccessibilitySettings()
                }
                Divider()
            }

            Text(manager.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Text("Sensitivity")
                Spacer()
                Button {
                    manager.sensitivity = max(3.0, manager.sensitivity - 0.5)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(manager.sensitivity <= 3.0)

                Text(String(format: "%.1fx", manager.sensitivity))
                    .monospacedDigit()
                    .frame(width: 40)

                Button {
                    manager.sensitivity = min(20.0, manager.sensitivity + 0.5)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(manager.sensitivity >= 20.0)
            }

            Text("Cursor")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("Size")
                Spacer()
                Button {
                    manager.cursorSize = max(60, manager.cursorSize - 20)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(manager.cursorSize <= 60)

                Text("\(Int(manager.cursorSize))pt")
                    .monospacedDigit()
                    .frame(width: 46)

                Button {
                    manager.cursorSize = min(300, manager.cursorSize + 20)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(manager.cursorSize >= 300)
            }

            HStack {
                Text("Dot Size")
                Spacer()
                Button {
                    manager.cursorDotSize = max(1, manager.cursorDotSize - 1)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(manager.cursorDotSize <= 1)

                Text("\(Int(manager.cursorDotSize))%")
                    .monospacedDigit()
                    .frame(width: 36)

                Button {
                    manager.cursorDotSize = min(15, manager.cursorDotSize + 1)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(manager.cursorDotSize >= 15)
            }

            HStack {
                Text("Gap Size")
                Spacer()
                Button {
                    manager.cursorGapSize = max(10, manager.cursorGapSize - 1)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(manager.cursorGapSize <= 10)

                Text("\(Int(manager.cursorGapSize))%")
                    .monospacedDigit()
                    .frame(width: 36)

                Button {
                    manager.cursorGapSize = min(45, manager.cursorGapSize + 1)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(manager.cursorGapSize >= 45)
            }

            Divider()

            Button("Edit Actions...") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "action-editor")
                dismiss()
            }

            if !manager.pairingStore.pairedDeviceIds.isEmpty {
                Button("Unpair All Devices") {
                    manager.pairingStore.unpairAll()
                }
            }

            Divider()

            Toggle("Launch at Login", isOn: $manager.launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.small)

            Button("Quit") {
                manager.server.stop()
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
    }
}
