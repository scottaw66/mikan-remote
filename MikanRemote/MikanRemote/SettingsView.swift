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
                                cursorSize: connectionManager.cursorSize,
                                cursorDotSize: connectionManager.cursorDotSize,
                                cursorGapSize: connectionManager.cursorGapSize
                            )
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(connectionManager.sensitivity <= 3.0)

                        Text(String(format: "%.1fx", connectionManager.sensitivity))
                            .monospacedDigit()
                            .frame(width: 70)

                        Button {
                            let newVal = min(20.0, connectionManager.sensitivity + 0.5)
                            connectionManager.sendUpdateSettings(
                                sensitivity: newVal,
                                cursorSize: connectionManager.cursorSize,
                                cursorDotSize: connectionManager.cursorDotSize,
                                cursorGapSize: connectionManager.cursorGapSize
                            )
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(connectionManager.sensitivity >= 20.0)
                    }
                }

                Section("Cursor") {
                    HStack {
                        Text("Size")
                        Spacer()
                        Button {
                            let newVal = max(60.0, connectionManager.cursorSize - 20)
                            connectionManager.sendUpdateSettings(
                                sensitivity: connectionManager.sensitivity,
                                cursorSize: newVal,
                                cursorDotSize: connectionManager.cursorDotSize,
                                cursorGapSize: connectionManager.cursorGapSize
                            )
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(connectionManager.cursorSize <= 60)

                        Text("\(Int(connectionManager.cursorSize)) pt")
                            .monospacedDigit()
                            .frame(width: 70)

                        Button {
                            let newVal = min(300.0, connectionManager.cursorSize + 20)
                            connectionManager.sendUpdateSettings(
                                sensitivity: connectionManager.sensitivity,
                                cursorSize: newVal,
                                cursorDotSize: connectionManager.cursorDotSize,
                                cursorGapSize: connectionManager.cursorGapSize
                            )
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(connectionManager.cursorSize >= 300)
                    }

                    HStack {
                        Text("Dot Size")
                        Spacer()
                        Button {
                            let newVal = max(1.0, connectionManager.cursorDotSize - 1)
                            connectionManager.sendUpdateSettings(
                                sensitivity: connectionManager.sensitivity,
                                cursorSize: connectionManager.cursorSize,
                                cursorDotSize: newVal,
                                cursorGapSize: connectionManager.cursorGapSize
                            )
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(connectionManager.cursorDotSize <= 1)

                        Text("\(Int(connectionManager.cursorDotSize))%")
                            .monospacedDigit()
                            .frame(width: 70)

                        Button {
                            let newVal = min(15.0, connectionManager.cursorDotSize + 1)
                            connectionManager.sendUpdateSettings(
                                sensitivity: connectionManager.sensitivity,
                                cursorSize: connectionManager.cursorSize,
                                cursorDotSize: newVal,
                                cursorGapSize: connectionManager.cursorGapSize
                            )
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(connectionManager.cursorDotSize >= 15)
                    }

                    HStack {
                        Text("Gap Size")
                        Spacer()
                        Button {
                            let newVal = max(10.0, connectionManager.cursorGapSize - 1)
                            connectionManager.sendUpdateSettings(
                                sensitivity: connectionManager.sensitivity,
                                cursorSize: connectionManager.cursorSize,
                                cursorDotSize: connectionManager.cursorDotSize,
                                cursorGapSize: newVal
                            )
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(connectionManager.cursorGapSize <= 10)

                        Text("\(Int(connectionManager.cursorGapSize))%")
                            .monospacedDigit()
                            .frame(width: 70)

                        Button {
                            let newVal = min(45.0, connectionManager.cursorGapSize + 1)
                            connectionManager.sendUpdateSettings(
                                sensitivity: connectionManager.sensitivity,
                                cursorSize: connectionManager.cursorSize,
                                cursorDotSize: connectionManager.cursorDotSize,
                                cursorGapSize: newVal
                            )
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(connectionManager.cursorGapSize >= 45)
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
        VStack(alignment: .leading, spacing: 8) {
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

            HStack {
                Text("Icon")
                    .font(.caption)
                Spacer()
                Menu {
                    ForEach(iconChoices, id: \.symbol) { choice in
                        Button {
                            action = Action(id: action.id, label: action.label, url: action.url, icon: choice.symbol.isEmpty ? nil : choice.symbol)
                        } label: {
                            if choice.symbol.isEmpty {
                                Text(choice.name)
                            } else {
                                Label(choice.name, systemImage: choice.symbol)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let icon = action.icon, !icon.isEmpty {
                            Image(systemName: icon)
                        }
                        Text(iconChoices.first(where: { $0.symbol == (action.icon ?? "") })?.name ?? "None")
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 170, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
