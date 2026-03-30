// MikanRemote/MikanRemote/ActionButtonsView.swift
import SwiftUI
import MikanProtocol

struct ActionButtonsView: View {
    let actions: [Action]
    let onCommand: (String) -> Void
    let onOpenURL: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Command buttons — fixed, not editable
            HStack(spacing: 10) {
                CommandButton(label: "Fullscreen", icon: "arrow.up.left.and.arrow.down.right") {
                    onCommand("fullscreen")
                }
                CommandButton(label: "Esc", icon: "escape") {
                    onCommand("escape")
                }
            }

            // URL shortcut buttons — configurable from server
            if !actions.isEmpty {
                HStack(spacing: 10) {
                    ForEach(actions) { action in
                        URLButton(action: action) {
                            onOpenURL(action.url)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

private struct CommandButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
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
            HStack(spacing: 6) {
                if let icon = action.icon, !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(action.label)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
        }
        .buttonStyle(.bordered)
        .tint(.accentColor)
    }
}
