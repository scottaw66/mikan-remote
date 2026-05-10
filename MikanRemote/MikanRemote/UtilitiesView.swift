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

                Section("Open URL on Mac") {
                    PasteButton(payloadType: URL.self) { urls in
                        guard let url = urls.first else { return }
                        sendURL(url.absoluteString)
                    }
                    .buttonBorderShape(.capsule)

                    HStack {
                        TextField("https://…", text: $typedURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.send)
                            .onSubmit { sendTypedIfValid() }

                        Button("Send") { sendTypedIfValid() }
                            .disabled(!isTypedURLValid)
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
