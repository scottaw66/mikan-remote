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
                                cursorGapSize: connectionManager.cursorGapSize,
                                youtubePopupMode: connectionManager.youtubePopupMode
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
                                cursorGapSize: connectionManager.cursorGapSize,
                                youtubePopupMode: connectionManager.youtubePopupMode
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
                                cursorGapSize: connectionManager.cursorGapSize,
                                youtubePopupMode: connectionManager.youtubePopupMode
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
                                cursorGapSize: connectionManager.cursorGapSize,
                                youtubePopupMode: connectionManager.youtubePopupMode
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
                                cursorGapSize: connectionManager.cursorGapSize,
                                youtubePopupMode: connectionManager.youtubePopupMode
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
                                cursorGapSize: connectionManager.cursorGapSize,
                                youtubePopupMode: connectionManager.youtubePopupMode
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
                                cursorGapSize: newVal,
                                youtubePopupMode: connectionManager.youtubePopupMode
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
                                cursorGapSize: newVal,
                                youtubePopupMode: connectionManager.youtubePopupMode
                            )
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(connectionManager.cursorGapSize >= 45)
                    }
                }

                Section("YouTube Controls") {
                    Picker("Show button", selection: Binding(
                        get: { connectionManager.youtubePopupMode },
                        set: { newMode in
                            connectionManager.sendUpdateSettings(
                                sensitivity: connectionManager.sensitivity,
                                cursorSize: connectionManager.cursorSize,
                                cursorDotSize: connectionManager.cursorDotSize,
                                cursorGapSize: connectionManager.cursorGapSize,
                                youtubePopupMode: newMode
                            )
                        }
                    )) {
                        Text("Auto").tag("auto")
                        Text("Always On").tag("on")
                        Text("Always Off").tag("off")
                    }
                    .pickerStyle(.segmented)

                    Text("Auto shows the button when a YouTube link is in your action buttons.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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

                Section {
                    LabeledContent("Version", value: AppBuildInfo.versionString)
                    LabeledContent("Build", value: AppBuildInfo.buildStamp)
                } header: {
                    Text("About")
                } footer: {
                    Text("The build is the git commit this app was compiled from; + means it included uncommitted changes.")
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

/// Identifies exactly which build is running, so "is the fix on this phone?"
/// is answerable from the Settings screen. The git SHA and build date come
/// from build-info.json, written into the bundle by the "Stamp build info"
/// build phase in project.yml (NOT Info.plist — ProcessInfoPlistFile runs
/// after script phases and overwrites any stamp there). A trailing "+" on
/// the SHA means the working tree had uncommitted changes.
enum AppBuildInfo {
    private static let stamp: [String: String] = {
        guard let url = Bundle.main.url(forResource: "build-info", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }()

    /// "0.1.0 (1)"
    static var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }

    /// "bd7b38b — 2026-08-05 23:30" (or "unstamped" for builds that skipped
    /// the stamp phase).
    static var buildStamp: String {
        guard let sha = stamp["sha"] else { return "unstamped" }
        return stamp["date"].map { "\(sha) — \($0)" } ?? sha
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
