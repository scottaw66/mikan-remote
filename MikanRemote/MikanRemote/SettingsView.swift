// MikanRemote/MikanRemote/SettingsView.swift
import SwiftUI
import MikanProtocol

struct SettingsView: View {
    @Bindable var connectionManager: ConnectionManager
    @Environment(\.dismiss) private var dismiss
    @State private var editingActions: [Action] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Mouse") {
                    HStack {
                        Text("Sensitivity")
                        Spacer()
                        Button {
                            let newVal = max(3.0, connectionManager.sensitivity - 0.5)
                            connectionManager.sendUpdateSettings(
                                sensitivity: newVal,
                                cursorSize: connectionManager.cursorSize
                            )
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(connectionManager.sensitivity <= 3.0)

                        Text(String(format: "%.1fx", connectionManager.sensitivity))
                            .monospacedDigit()
                            .frame(width: 46)

                        Button {
                            let newVal = min(20.0, connectionManager.sensitivity + 0.5)
                            connectionManager.sendUpdateSettings(
                                sensitivity: newVal,
                                cursorSize: connectionManager.cursorSize
                            )
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(connectionManager.sensitivity >= 20.0)
                    }

                    HStack {
                        Text("Cursor Size")
                        Spacer()
                        Button {
                            let newVal = max(60.0, connectionManager.cursorSize - 20)
                            connectionManager.sendUpdateSettings(
                                sensitivity: connectionManager.sensitivity,
                                cursorSize: newVal
                            )
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(connectionManager.cursorSize <= 60)

                        Text("\(Int(connectionManager.cursorSize))pt")
                            .monospacedDigit()
                            .frame(width: 50)

                        Button {
                            let newVal = min(300.0, connectionManager.cursorSize + 20)
                            connectionManager.sendUpdateSettings(
                                sensitivity: connectionManager.sensitivity,
                                cursorSize: newVal
                            )
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(connectionManager.cursorSize >= 300)
                    }
                }

                Section("Action Buttons") {
                    ForEach($editingActions, id: \.id) { $action in
                        ActionEditorRow(action: $action)
                    }
                    .onDelete { indices in
                        editingActions.remove(atOffsets: indices)
                    }
                    .onMove { source, destination in
                        editingActions.move(fromOffsets: source, toOffset: destination)
                    }

                    if editingActions.count < 6 {
                        Button {
                            editingActions.append(
                                Action(id: UUID().uuidString, label: "New Shortcut", url: "https://example.com")
                            )
                        } label: {
                            Label("Add Action", systemImage: "plus.circle")
                        }
                    }
                }

                Section {
                    Button("Reset Actions to Defaults") {
                        editingActions = Action.defaults
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        connectionManager.sendUpdateActions(editingActions)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .onAppear {
                editingActions = connectionManager.actions
            }
        }
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

private struct ActionEditorRow: View {
    @Binding var action: Action

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Label", text: Binding(
                get: { action.label },
                set: { action = Action(id: action.id, label: $0, url: action.url, icon: action.icon) }
            ))
            .font(.body.bold())

            TextField("URL", text: Binding(
                get: { action.url },
                set: { action = Action(id: action.id, label: action.label, url: $0, icon: action.icon) }
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)

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
            .font(.caption)
        }
        .padding(.vertical, 2)
    }
}
