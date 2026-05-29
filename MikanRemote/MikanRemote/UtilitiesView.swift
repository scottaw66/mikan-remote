import SwiftUI
import UIKit
import MikanProtocol

struct UtilitiesView: View {
    @Bindable var connectionManager: ConnectionManager
    @Environment(\.dismiss) private var dismiss

    @State private var typedURL: String = ""
    @State private var lastSendOK: Bool = false
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        NavigationStack {
            List {
                Section("Tools") {
                    Button {
                        sendCommand("screenshot")
                    } label: {
                        Label("Take Screenshot (\u{21E7}\u{2318}3)", systemImage: "camera.viewfinder")
                    }
                }

                Section("Audio Output") {
                    if connectionManager.audioDevices.isEmpty {
                        Text("No devices")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(connectionManager.audioDevices) { device in
                            Button {
                                selectAudioDevice(device)
                            } label: {
                                HStack {
                                    Text(device.name)
                                    Spacer()
                                    if device.id == connectionManager.currentAudioDeviceId {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .disabled(!connectionManager.isConnected)
                        }
                    }
                }

                Section("Open URL on Mac") {
                    PasteButton(payloadType: URL.self) { urls in
                        guard let url = urls.first else { return }
                        sendURL(url.absoluteString)
                    }
                    .buttonBorderShape(.capsule)
                    .disabled(!connectionManager.isConnected)

                    HStack {
                        TextField("https://…", text: $typedURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.send)
                            .onSubmit { sendTypedIfValid() }

                        Button("Send") { sendTypedIfValid() }
                            .disabled(!isTypedURLValid || !connectionManager.isConnected)
                    }

                    if lastSendOK {
                        Label("Sent", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .transition(.opacity)
                    }
                }
            }
            .navigationTitle("Utilities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { feedbackGenerator.prepare() }
        }
    }

    private var isTypedURLValid: Bool {
        guard let url = URL(string: typedURL.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return url.scheme != nil && url.host != nil
    }

    private func sendTypedIfValid() {
        let trimmed = typedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else { return }
        sendURL(url.absoluteString)
        typedURL = ""
    }

    private func sendURL(_ url: String) {
        feedbackGenerator.impactOccurred()
        feedbackGenerator.prepare()
        connectionManager.send(.openURL(url: url))
        flashSent()
    }

    private func sendCommand(_ command: String) {
        feedbackGenerator.impactOccurred()
        feedbackGenerator.prepare()
        connectionManager.send(.performCommand(command: command))
    }

    private func selectAudioDevice(_ device: AudioDevice) {
        feedbackGenerator.impactOccurred()
        feedbackGenerator.prepare()
        connectionManager.sendSetAudioDevice(device.id)
    }

    private func flashSent() {
        withAnimation { lastSendOK = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                withAnimation { lastSendOK = false }
            }
        }
    }
}
