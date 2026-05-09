// MikanRemoteServer/MikanRemoteServer/ActionEditorView.swift
import SwiftUI
import MikanProtocol

struct ActionEditorView: View {
    @Bindable var store: ActionStore
    var onSave: () -> Void
    @State private var selection: Action.ID?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach($store.actions, id: \.id) { $action in
                    ActionRow(action: $action)
                }
                .onDelete { indices in
                    store.actions.remove(atOffsets: indices)
                }
                .onMove { source, destination in
                    store.actions.move(fromOffsets: source, toOffset: destination)
                }
            }

            Divider()

            HStack {
                Button {
                    let new = Action(
                        id: UUID().uuidString,
                        label: "New Shortcut",
                        url: "https://example.com"
                    )
                    store.actions.append(new)
                } label: {
                    Image(systemName: "plus")
                }

                Button {
                    if let sel = selection {
                        store.actions.removeAll { $0.id == sel }
                        selection = nil
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)

                Spacer()

                Button("Reset to Defaults") {
                    store.actions = Action.defaults
                }

                Button("Save") {
                    try? store.save()
                    onSave()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(12)
        }
        .frame(minWidth: 400, minHeight: 250)
    }
}

private let iconChoices: [(name: String, symbol: String)] = [
    ("None", ""),
    ("Apple TV", "appletv"),
    ("Play TV", "play.tv"),
    ("Play Rectangle", "play.rectangle"),
    ("Film", "film"),
    ("Music Note", "music.note"),
    ("Globe", "globe"),
    ("Star", "star"),
    ("Heart", "heart"),
    ("Bookmark", "bookmark"),
    ("House", "house"),
    ("Gamecontroller", "gamecontroller"),
    ("Photo", "photo"),
    ("Camera", "camera"),
    ("Cart", "cart"),
    ("Newspaper", "newspaper"),
    ("Book", "book"),
    ("Envelope", "envelope"),
    ("Cloud", "cloud"),
    ("Cup and Saucer", "cup.and.saucer"),
    ("Fork and Knife", "fork.knife"),
    ("Figure Walk", "figure.walk"),
    ("Bicycle", "bicycle"),
    ("Car", "car"),
    ("Airplane", "airplane"),
]

struct ActionRow: View {
    @Binding var action: Action

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Label", text: Binding(
                get: { action.label },
                set: { action = Action(id: action.id, label: $0, url: action.url, icon: action.icon) }
            ))
            .textFieldStyle(.plain)
            .font(.headline)

            TextField("URL", text: Binding(
                get: { action.url },
                set: { action = Action(id: action.id, label: action.label, url: $0, icon: action.icon) }
            ))
            .textFieldStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)

            Picker("Icon", selection: Binding(
                get: { action.icon ?? "" },
                set: { action = Action(id: action.id, label: action.label, url: action.url, icon: $0.isEmpty ? nil : $0) }
            )) {
                ForEach(iconChoices, id: \.symbol) { choice in
                    if choice.symbol.isEmpty {
                        Text(choice.name).tag("")
                    } else {
                        Label(choice.name, systemImage: choice.symbol).tag(choice.symbol)
                    }
                }
            }
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
