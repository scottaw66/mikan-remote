// MikanRemote/MikanRemote/MikanRemoteApp.swift
import SwiftUI

@main
struct MikanRemoteApp: App {
    @State private var connectionManager = ConnectionManager()

    var body: some Scene {
        WindowGroup {
            ContentView(connectionManager: connectionManager)
                .onAppear {
                    connectionManager.startBrowsing()
                }
        }
    }
}
