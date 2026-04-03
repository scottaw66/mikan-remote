// MikanRemote/MikanRemote/ContentView.swift
import SwiftUI
import MikanProtocol

struct ContentView: View {
    @Bindable var connectionManager: ConnectionManager
    @State private var pairingCode = ""

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
            } else if connectionManager.pairingRequired {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 40))
                        .foregroundStyle(.tint)

                    Text("Enter Pairing Code")
                        .font(.headline)

                    Text("Check your Mac for the 4-digit code.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Code", text: $pairingCode)
                        .keyboardType(.numberPad)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .frame(width: 160)
                        .textFieldStyle(.roundedBorder)

                    if connectionManager.pairingFailed {
                        Text("Wrong code. Try again.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button("Pair") {
                        connectionManager.submitPairingCode(pairingCode)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pairingCode.count < 4)
                }
                .padding()
                Spacer()
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
