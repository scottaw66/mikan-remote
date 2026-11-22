import SwiftUI
import UIKit

struct YouTubePopupView: View {
    let onCommand: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        NavigationStack {
            // A ScrollView so every row stays reachable on a shorter iPhone;
            // on a tall one nothing scrolls.
            ScrollView {
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
                        pairedButton(label: "- Slower", icon: "tortoise.fill", command: "ytSlowDown")
                        pairedButton(label: "Faster +", icon: "hare.fill", command: "ytSpeedUp")
                    }

                    fullWidthButton(label: "Fullscreen", icon: "arrow.up.left.and.arrow.down.right", command: "ytFullscreen")

                    HStack(spacing: 12) {
                        pairedButton(label: "Back 5s", icon: "gobackward.5", command: "arrowLeft")
                        pairedButton(label: "Forward 5s", icon: "goforward.5", command: "arrowRight")
                    }

                    fullWidthButton(label: "Play / Pause", icon: "playpause.fill", command: "ytPlayPause")

                    // Navigates the *current* tab to youtube.com (server types the
                    // URL into the address bar). Not openURL — that opens a new tab.
                    fullWidthButton(label: "YouTube Home", icon: "house.fill", command: "ytHome")

                    // Last row, with a gap above it, so nothing sits under
                    // Save / Unsave: when this row was above YouTube Home, the
                    // phone sent ytHome a few seconds after every toggle and
                    // the video was gone (2026-11-22, the server's command
                    // log). Scott felt no tap, so the likely cause is the
                    // swipe-down that closes the sheet starting on the bottom
                    // button; hence also the empty space below this row.
                    HStack(spacing: 12) {
                        // The Watch Later playlist, in the current tab (same
                        // address-bar route as YouTube Home).
                        pairedButton(label: "Watch Later", icon: "clock", command: "ytWatchLater")
                        // Adds the open video to Watch Later or removes it. The
                        // server sends a key chord that the Watch Later Solo
                        // Safari extension handles on the page; the result shows
                        // on the Mac's screen, not here.
                        pairedButton(label: "Save / Unsave", icon: "clock.badge.checkmark", command: "ytToggleWatchLater")
                    }
                    .padding(.top, 20)

                    // Empty space for the thumb: a swipe-down to close the
                    // sheet, or a finger resting there, hits no button.
                    Color.clear.frame(height: 100)
                }
                .padding()
            }
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
        fullWidthButton(label: label, icon: icon) { onCommand(command) }
    }

    private func fullWidthButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            feedbackGenerator.impactOccurred()
            feedbackGenerator.prepare()
            action()
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
