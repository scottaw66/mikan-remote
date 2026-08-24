// MikanRemote/MikanRemote/ContentView.swift
import SwiftUI
import UIKit
import MikanProtocol

struct ContentView: View {
    @Bindable var connectionManager: ConnectionManager
    @Bindable var dispatcher: PendingShareDispatcher
    @State private var showSettings = false
    @State private var showYouTubePopup = false
    @State private var showUtilities = false

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
                Spacer()
                ProgressView("Authenticating...")
                    .padding()
                Spacer()
            } else {
                Spacer()

                DispatcherBanner(
                    state: dispatcher.state,
                    hostname: connectionManager.hostname,
                    onRetry: { dispatcher.retry() }
                )

                VolumeButtonsView(
                    onCommand: { connectionManager.send(.performCommand(command: $0)) }
                )
                .padding(.bottom, 4)

                HStack(spacing: 8) {
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

                    // Page scroll: reuses mouseScroll (pixel scroll under the cursor)
                    // rather than Page Up/Down keystrokes, which die when keyboard
                    // focus lands somewhere unexpected (see yt* diagnostics note).
                    // Positive deltaY = natural-scroll up, matching the trackpad.
                    VStack(spacing: 8) {
                        PageScrollButton(icon: "chevron.up.2") {
                            connectionManager.send(.mouseScroll(deltaX: 0, deltaY: 750))
                        }
                        PageScrollButton(icon: "chevron.down.2") {
                            connectionManager.send(.mouseScroll(deltaX: 0, deltaY: -750))
                        }
                    }
                    .frame(width: 44)
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.35)
                .padding(.horizontal)
                .padding(.vertical, 4)

                ActionButtonsView(
                    actions: connectionManager.actions,
                    onCommand: { connectionManager.send(.performCommand(command: $0)) },
                    onOpenURL: { connectionManager.send(.openURL(url: $0)) }
                )

                Spacer()
                Spacer()
            }
        }
        .safeAreaInset(edge: .top) {
            if connectionManager.isConnected && connectionManager.hostname != nil {
                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text(connectionManager.hostname ?? "Connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if YouTubeVisibility.effectiveYouTubeButtonVisible(
                        mode: connectionManager.youtubePopupMode,
                        actions: connectionManager.actions
                    ) {
                        Button {
                            showYouTubePopup = true
                        } label: {
                            Image(systemName: "play.rectangle.fill")
                                .topBarIcon(tint: .red)
                        }
                        .padding(.trailing, 8)
                    }
                    Button {
                        showUtilities = true
                    } label: {
                        Image(systemName: "wrench.and.screwdriver")
                            .topBarIcon()
                    }
                    .padding(.trailing, 8)
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .topBarIcon()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 0)
                .padding(.bottom, 2)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(connectionManager: connectionManager)
        }
        .sheet(isPresented: $showYouTubePopup) {
            YouTubePopupView(
                onCommand: { connectionManager.send(.performCommand(command: $0)) }
            )
        }
        .sheet(isPresented: $showUtilities) {
            UtilitiesView(connectionManager: connectionManager)
        }
    }
}

private struct PageScrollButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
    }
}

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
