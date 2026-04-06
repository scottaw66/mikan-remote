// MikanRemote/MikanRemote/ActionButtonsView.swift
import SwiftUI
import MikanProtocol

struct VolumeButtonsView: View {
    let onCommand: (String) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button { onCommand("closeTab") } label: {
                Image(systemName: "xmark.square")
                    .font(.caption)
                    .frame(width: 48, height: 36)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Spacer()

            Button { onCommand("volumeDown") } label: {
                Image(systemName: "speaker.minus")
                    .font(.caption)
                    .frame(width: 48, height: 36)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Button { onCommand("volumeUp") } label: {
                Image(systemName: "speaker.plus")
                    .font(.caption)
                    .frame(width: 48, height: 36)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
        .padding(.horizontal)
    }
}

struct ActionButtonsView: View {
    let actions: [Action]
    let onCommand: (String) -> Void
    let onOpenURL: (String) -> Void

    var body: some View {
        VStack(spacing: 6) {
            // Command buttons — 4 across
            HStack(spacing: 8) {
                IconButton(icon: "arrow.up.left.and.arrow.down.right") { onCommand("fullscreen") }
                IconButton(icon: "arrowtriangle.backward.fill") { onCommand("arrowLeft") }
                IconButton(icon: "arrowtriangle.forward.fill") { onCommand("arrowRight") }
                IconButton(icon: "escape") { onCommand("escape") }
            }

            // URL shortcut buttons — 2 per row, max 6
            let capped = Array(actions.prefix(6))
            ForEach(0..<((capped.count + 1) / 2), id: \.self) { row in
                HStack(spacing: 8) {
                    let start = row * 2
                    ForEach(capped[start..<min(start + 2, capped.count)]) { action in
                        URLButton(action: action) {
                            onOpenURL(action.url)
                        }
                    }
                    if start + 1 >= capped.count {
                        Spacer().frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

private struct IconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
    }
}

private struct URLButton: View {
    let action: Action
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if let icon = action.icon, !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(action.label)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
        }
        .buttonStyle(.bordered)
        .tint(.accentColor)
    }
}
