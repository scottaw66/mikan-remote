// MikanRemote/MikanRemote/ActionButtonsView.swift
import SwiftUI
import MikanProtocol

struct ActionButtonsView: View {
    let actions: [Action]
    let onAction: (Action) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(actions) { action in
                    Button {
                        onAction(action)
                    } label: {
                        VStack(spacing: 6) {
                            if let icon = action.icon, !icon.isEmpty {
                                Image(systemName: icon)
                                    .font(.title2)
                            }
                            Text(action.label)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(width: 72, height: 64)
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 80)
    }
}
