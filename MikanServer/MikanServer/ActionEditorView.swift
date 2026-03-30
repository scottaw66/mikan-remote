// MikanServer/MikanServer/ActionEditorView.swift
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
                        label: "New Action",
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
        .frame(minWidth: 450, minHeight: 300)
    }
}

struct ActionRow: View {
    @Binding var action: Action

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: action.icon ?? "questionmark.square.dashed")
                .font(.title2)
                .foregroundStyle(action.icon != nil ? .primary : .tertiary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
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
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "apple.logo")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                TextField("Icon name", text: Binding(
                    get: { action.icon ?? "" },
                    set: { action = Action(id: action.id, label: action.label, url: action.url, icon: $0.isEmpty ? nil : $0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)
            }
        }
        .padding(.vertical, 4)
    }
}
