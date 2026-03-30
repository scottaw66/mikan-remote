// MikanRemote/MikanRemote/ContentView.swift
import SwiftUI
import MikanProtocol

struct ContentView: View {
    @Bindable var connectionManager: ConnectionManager

    var body: some View {
        VStack(spacing: 0) {
            if !connectionManager.isConnected {
                if connectionManager.discoveredServers.isEmpty {
                    Spacer()
                    ProgressView("Scanning for Mikan servers...")
                        .padding()
                    Spacer()
                } else if connectionManager.discoveredServers.count > 1 {
                    ServerPickerView(
                        servers: connectionManager.discoveredServers,
                        onSelect: { connectionManager.connect(to: $0) }
                    )
                } else {
                    Spacer()
                    ProgressView("Connecting...")
                        .padding()
                    Spacer()
                }
            } else {
                // Status bar
                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text(connectionManager.hostname ?? "Connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Trackpad
                TrackpadView(
                    onMove: { dx, dy in
                        connectionManager.send(.mouseMove(deltaX: dx, deltaY: dy))
                    },
                    onTap: {
                        connectionManager.send(.mouseClick(button: .left))
                    },
                    onTwoFingerTap: {
                        connectionManager.send(.mouseClick(button: .right))
                    },
                    onScroll: { dx, dy in
                        connectionManager.send(.mouseScroll(deltaX: dx, deltaY: dy))
                    }
                )
                .padding(.horizontal)
                .padding(.vertical, 4)

                // Action buttons
                ActionButtonsView(
                    actions: connectionManager.actions,
                    onCommand: { connectionManager.send(.performCommand(command: $0)) },
                    onOpenURL: { connectionManager.send(.openURL(url: $0)) }
                )
            }
        }
    }
}
