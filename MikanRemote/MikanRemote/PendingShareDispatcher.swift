import Foundation
import Observation

@MainActor
@Observable
final class PendingShareDispatcher {
    enum State: Equatable {
        case idle
        case sending(url: String)
        case sent
        case failed
    }

    private(set) var state: State = .idle

    private let store: any PendingURLStore
    private let sendHandler: (String) -> Void
    private let isReady: () -> Bool
    private let timeoutDuration: TimeInterval
    private let sentDisplayDuration: TimeInterval

    private var timeoutTask: Task<Void, Never>?
    private var sentClearTask: Task<Void, Never>?

    // Test seam — production code never assigns this.
    var _setIsReady: (Bool) -> Void = { _ in }

    init(
        store: any PendingURLStore,
        send: @escaping (String) -> Void,
        isReady: @escaping () -> Bool,
        timeoutDuration: TimeInterval = 10.0,
        sentDisplayDuration: TimeInterval = 1.2
    ) {
        self.store = store
        self.sendHandler = send
        self.isReady = isReady
        self.timeoutDuration = timeoutDuration
        self.sentDisplayDuration = sentDisplayDuration
    }

    func consumePending() {
        guard let url = store.pendingShareURL else {
            cancelTimers()
            state = .idle
            return
        }
        beginSending(initialURL: url)
    }

    func connectionBecameReady() {
        guard case .sending = state else { return }
        if isReady() {
            attemptSend()
        }
    }

    func retry() {
        guard case .failed = state else { return }
        consumePending()
    }

    private func beginSending(initialURL: String) {
        cancelTimers()
        state = .sending(url: initialURL)
        if isReady() {
            attemptSend()
        } else {
            startTimeoutTask()
        }
    }

    private func attemptSend() {
        // Re-read slot — overwrites since beginSending may have happened.
        guard let url = store.pendingShareURL else {
            cancelTimers()
            state = .idle
            return
        }
        sendHandler(url)
        store.pendingShareURL = nil
        cancelTimers()
        state = .sent
        startSentClearTask()
    }

    private func startTimeoutTask() {
        timeoutTask?.cancel()
        let duration = timeoutDuration
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.handleTimeout()
            }
        }
    }

    private func handleTimeout() {
        guard case .sending = state else { return }
        state = .failed
    }

    private func startSentClearTask() {
        sentClearTask?.cancel()
        let duration = sentDisplayDuration
        sentClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if self.state == .sent {
                    self.state = .idle
                }
            }
        }
    }

    private func cancelTimers() {
        timeoutTask?.cancel()
        timeoutTask = nil
        sentClearTask?.cancel()
        sentClearTask = nil
    }
}
