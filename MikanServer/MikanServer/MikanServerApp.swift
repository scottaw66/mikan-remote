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

private struct MenuBarContentView: View {
    @Bindable var manager: MenuBarManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
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

            Divider()

            Button("Edit Actions...") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "action-editor")
                dismiss()
            }

            Button("Quit") {
                manager.server.stop()
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
    }
}
