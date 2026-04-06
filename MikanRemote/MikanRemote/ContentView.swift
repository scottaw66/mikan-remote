// MikanRemote/MikanRemote/ContentView.swift
import SwiftUI
import UIKit
import MikanProtocol

struct ContentView: View {
    @Bindable var connectionManager: ConnectionManager
    @State private var showSettings = false

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

                    AutoFocusCodeField { code in
                        connectionManager.submitPairingCode(code)
                    }
                    .frame(width: 160, height: 50)

                    if connectionManager.pairingFailed {
                        Text("Wrong code. Try again.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                Spacer()
            } else if connectionManager.hostname == nil {
                // Connected but waiting for server handshake
                Spacer()
                ProgressView("Authenticating...")
                    .padding()
                Spacer()
            } else {
                // Status bar + volume
                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text(connectionManager.hostname ?? "Connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 2)

                VolumeButtonsView(
                    onCommand: { connectionManager.send(.performCommand(command: $0)) }
                )
                .padding(.bottom, 4)

                // Trackpad
                TrackpadView(
                    onMove: { dx, dy in
                        connectionManager.send(.mouseMove(deltaX: dx, deltaY: dy))
                    },
                    onTap: {
                        connectionManager.send(.mouseClick)
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
        .sheet(isPresented: $showSettings) {
            SettingsView(connectionManager: connectionManager)
        }
    }
}

// UIKit wrapper — becomeFirstResponder() via didMoveToWindow is the only reliable auto-focus on iOS
private class AutoFocusTextField: UITextField {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            becomeFirstResponder()
        }
    }
}

private struct AutoFocusCodeField: UIViewRepresentable {
    let onSubmit: (String) -> Void

    func makeUIView(context: Context) -> UITextField {
        let tf = AutoFocusTextField()
        tf.keyboardType = .numberPad
        tf.font = UIFont.monospacedSystemFont(ofSize: 32, weight: .bold)
        tf.textAlignment = .center
        tf.borderStyle = .roundedRect
        tf.placeholder = "Code"
        tf.delegate = context.coordinator
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onSubmit: onSubmit) }

    class Coordinator: NSObject, UITextFieldDelegate {
        let onSubmit: (String) -> Void
        init(onSubmit: @escaping (String) -> Void) { self.onSubmit = onSubmit }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = textField.text ?? ""
            let updated = (current as NSString).replacingCharacters(in: range, with: string)
            let filtered = String(updated.prefix(4).filter(\.isNumber))
            if filtered.count == 4 {
                textField.text = filtered
                onSubmit(filtered)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    textField.text = ""
                }
                return false
            }
            return filtered == updated
        }
    }
}
