// MikanRemote/MikanRemote/MikanRemoteApp.swift
import SwiftUI

@main
struct MikanRemoteApp: App {
    @State private var connectionManager = ConnectionManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(connectionManager: connectionManager)
                .onAppear {
                    connectionManager.startBrowsing()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                connectionManager.attemptReconnect()
            }
        }
    }
}
