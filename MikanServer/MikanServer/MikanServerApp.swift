import SwiftUI

@main
struct MikanServerApp: App {
    @State private var manager = MenuBarManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(manager: manager)
        } label: {
            Image(systemName: manager.isConnected
                  ? "antenna.radiowaves.left.and.right"
                  : "antenna.radiowaves.left.and.right.slash")
        }

        Window("Edit Actions", id: "action-editor") {
            ActionEditorView(store: manager.actionStore, onSave: { manager.pushActions() })
        }
        .defaultSize(width: 500, height: 400)
    }
}

private struct MenuBarContentView: View {
    var manager: MenuBarManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(manager.statusText)
            .font(.caption)
        Divider()
        HStack {
            Text("Sensitivity")
            Slider(value: Bindable(manager).sensitivity, in: 0.5...3.0, step: 0.25)
                .frame(width: 120)
            Text(String(format: "%.1fx", manager.sensitivity))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        Divider()
        Button("Edit Actions...") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "action-editor")
        }
        Divider()
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .onAppear {
            try? manager.start()
        }
    }
}
