// MikanRemote/MikanRemote/ContentView.swift
import SwiftUI
import MikanProtocol

struct ContentView: View {
    @Bindable var connectionManager: ConnectionManager

    var body: some View {
        VStack {
            if connectionManager.isConnected {
                Text("Connected to \(connectionManager.hostname ?? "Mac")")
            } else if connectionManager.discoveredServers.isEmpty {
                ProgressView("Scanning for Mikan servers...")
            } else {
                ServerPickerView(
                    servers: connectionManager.discoveredServers,
                    onSelect: { connectionManager.connect(to: $0) }
                )
            }
        }
    }
}
