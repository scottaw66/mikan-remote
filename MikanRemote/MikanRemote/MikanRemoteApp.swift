// MikanRemote/MikanRemote/MikanRemoteApp.swift
import SwiftUI
import MikanProtocol

@main
struct MikanRemoteApp: App {
    @State private var connectionManager: ConnectionManager
    @State private var dispatcher: PendingShareDispatcher
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Single instance captured by both the State and the dispatcher closures.
        let cm = ConnectionManager()
        _connectionManager = State(initialValue: cm)
        _dispatcher = State(initialValue: PendingShareDispatcher(
            store: SharedDefaults.shared,
            send: { [weak cm] url in
                cm?.send(.openURL(url: url))
            },
            isReady: { [weak cm] in
                guard let cm else { return false }
                return cm.isConnected && cm.hostname != nil
            }
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(connectionManager: connectionManager, dispatcher: dispatcher)
                .onAppear {
                    connectionManager.startBrowsing()
                }
                .onOpenURL { url in
                    if url.scheme == "mikanremote" {
                        dispatcher.consumePending()
                    }
                }
                .onChange(of: connectionManager.isConnected) { _, _ in
                    dispatcher.connectionBecameReady()
                }
                .onChange(of: connectionManager.hostname) { _, _ in
                    dispatcher.connectionBecameReady()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                connectionManager.attemptReconnect()
                dispatcher.consumePending()
            }
        }
    }
}
