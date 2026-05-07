import SwiftUI
import UIKit

struct YouTubePopupView: View {
    let onCommand: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    pairedButton(label: "Prev Video", icon: "backward.end.fill", command: "ytPrevVideo")
                    pairedButton(label: "Next Video", icon: "forward.end.fill", command: "ytNextVideo")
                }

                HStack(spacing: 12) {
                    pairedButton(label: "Prev Chapter", icon: "backward.frame.fill", command: "ytPrevChapter")
                    pairedButton(label: "Next Chapter", icon: "forward.frame.fill", command: "ytNextChapter")
                }

                fullWidthButton(label: "Captions", icon: "captions.bubble", command: "ytToggleCaptions")

                HStack(spacing: 12) {
                    pairedButton(label: "Slower <", icon: "tortoise.fill", command: "ytSlowDown")
                    pairedButton(label: "> Faster", icon: "hare.fill", command: "ytSpeedUp")
                }

                fullWidthButton(label: "Fullscreen", icon: "arrow.up.left.and.arrow.down.right", command: "ytFullscreen")

                Spacer()
            }
            .padding()
            .navigationTitle("YouTube Controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { feedbackGenerator.prepare() }
        }
    }

    private func tap(_ command: String) {
        feedbackGenerator.impactOccurred()
        feedbackGenerator.prepare()
        onCommand(command)
    }

    private func pairedButton(label: String, icon: String, command: String) -> some View {
        Button {
            tap(command)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    private func fullWidthButton(label: String, icon: String, command: String) -> some View {
        Button {
            tap(command)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }
}
