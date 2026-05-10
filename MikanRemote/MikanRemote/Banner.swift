import SwiftUI

struct DispatcherBanner: View {
    let state: PendingShareDispatcher.State
    let hostname: String?
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .sending:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Sending to \(hostname ?? "Mac")…").font(.caption)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .padding(.horizontal)
        case .sent:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Sent").font(.caption)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .padding(.horizontal)
        case .failed:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("Couldn't reach Mac").font(.caption)
                Spacer()
                Button("Retry", action: onRetry).font(.caption)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
}
