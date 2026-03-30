import SwiftUI

@main
struct MikanServerApp: App {
    var body: some Scene {
        MenuBarExtra("Mikan Server", systemImage: "antenna.radiowaves.left.and.right") {
            Text("Mikan Server")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
