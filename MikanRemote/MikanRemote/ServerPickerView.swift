// MikanRemote/MikanRemote/ServerPickerView.swift
import SwiftUI
import Network

struct ServerPickerView: View {
    let servers: [NWBrowser.Result]
    let onSelect: (NWBrowser.Result) -> Void

    var body: some View {
        List(servers, id: \.endpoint) { server in
            Button(server.endpoint.debugDescription) {
                onSelect(server)
            }
        }
        .navigationTitle("Select Server")
    }
}
