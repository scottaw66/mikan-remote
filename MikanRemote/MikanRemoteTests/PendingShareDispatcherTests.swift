import XCTest
@testable import MikanRemote

@MainActor
final class PendingShareDispatcherTests: XCTestCase {
    private final class MemStore: PendingURLStore {
        var pendingShareURL: String?
    }

    private final class Recorder {
        var sentURLs: [String] = []
    }

    private func makeDispatcher(
        store: MemStore = MemStore(),
        ready: Bool = false,
        timeout: TimeInterval = 0.05,
        sentDisplay: TimeInterval = 0.05,
        recorder: Recorder = Recorder()
    ) -> (PendingShareDispatcher, MemStore, Recorder) {
        var isReadyFlag = ready
        let dispatcher = PendingShareDispatcher(
            store: store,
            send: { recorder.sentURLs.append($0) },
            isReady: { isReadyFlag },
            timeoutDuration: timeout,
            sentDisplayDuration: sentDisplay
        )
        // Closure capture above lets us flip readiness in tests via setReady.
        dispatcher._setIsReady = { isReadyFlag = $0 }
        return (dispatcher, store, recorder)
    }

    func testConsumePendingWithNoURLStaysIdle() {
        let (d, _, recorder) = makeDispatcher(ready: true)
        d.consumePending()
        XCTAssertEqual(d.state, .idle)
        XCTAssertTrue(recorder.sentURLs.isEmpty)
    }

    func testConsumePendingWhenReadyTransitionsToSent() {
        let (d, store, recorder) = makeDispatcher(ready: true)
        store.pendingShareURL = "https://example.com/a"
        d.consumePending()
        XCTAssertEqual(recorder.sentURLs, ["https://example.com/a"])
        XCTAssertNil(store.pendingShareURL)
        XCTAssertEqual(d.state, .sent)
    }

    func testConsumePendingWhenNotReadySitsInSending() {
        let (d, store, recorder) = makeDispatcher(ready: false, timeout: 5.0)
        store.pendingShareURL = "https://example.com/b"
        d.consumePending()
        XCTAssertEqual(d.state, .sending(url: "https://example.com/b"))
        XCTAssertTrue(recorder.sentURLs.isEmpty)
    }

    func testConnectionBecameReadyDrains() async {
        let (d, store, recorder) = makeDispatcher(ready: false, timeout: 5.0)
        store.pendingShareURL = "https://example.com/c"
        d.consumePending()
        XCTAssertEqual(d.state, .sending(url: "https://example.com/c"))

        d._setIsReady(true)
        d.connectionBecameReady()
        XCTAssertEqual(recorder.sentURLs, ["https://example.com/c"])
        XCTAssertEqual(d.state, .sent)
    }

    func testTimeoutTransitionsToFailed() async {
        let (d, store, _) = makeDispatcher(ready: false, timeout: 0.05)
        store.pendingShareURL = "https://example.com/d"
        d.consumePending()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(d.state, .failed)
        XCTAssertEqual(store.pendingShareURL, "https://example.com/d", "URL must remain in slot for retry")
    }

    func testRetryFromFailedRestartsCycle() async {
        let (d, store, recorder) = makeDispatcher(ready: false, timeout: 0.05)
        store.pendingShareURL = "https://example.com/e"
        d.consumePending()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(d.state, .failed)

        d._setIsReady(true)
        d.retry()
        XCTAssertEqual(recorder.sentURLs, ["https://example.com/e"])
        XCTAssertEqual(d.state, .sent)
    }

    func testSlotMutationWhilePendingSendsLatestURL() async {
        let (d, store, recorder) = makeDispatcher(ready: false, timeout: 5.0)
        store.pendingShareURL = "https://example.com/old"
        d.consumePending()
        XCTAssertEqual(d.state, .sending(url: "https://example.com/old"))

        store.pendingShareURL = "https://example.com/new"
        d._setIsReady(true)
        d.connectionBecameReady()
        XCTAssertEqual(recorder.sentURLs, ["https://example.com/new"])
    }

    func testSentClearsToIdleAfterDisplay() async {
        let (d, store, _) = makeDispatcher(ready: true, sentDisplay: 0.05)
        store.pendingShareURL = "https://example.com/f"
        d.consumePending()
        XCTAssertEqual(d.state, .sent)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(d.state, .idle)
    }
}
