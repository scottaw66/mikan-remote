# Utilities Sheet & Share Extension Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the iPhone screenshot button into a new "Utilities" sheet, add clipboard / textbox / iOS-share-sheet paths for sending a URL to the Mac, all transported via the existing `openURL` WebSocket message.

**Architecture:** New iPhone `UtilitiesView` sheet launched from a top-bar icon (matches the YouTube popup pattern). New `MikanRemoteShare` Share Extension target writes the shared URL to an App Group `UserDefaults` slot and opens the main app via a `mikanremote://share` URL scheme. A new `PendingShareDispatcher` in the main app drains the slot when the WebSocket is fully ready (`isConnected && hostname != nil`), with a 10-second timeout and a Retry affordance. Single-slot semantics — latest URL wins.

**Tech Stack:** SwiftUI, UIKit (share extension), `Network.framework` (existing WebSocket), App Groups, xcodegen, XCTest.

---

## Spec

`docs/superpowers/specs/2026-05-10-utilities-sheet-and-share-extension-design.md` is the source of truth for behavior. This plan implements it.

## File Structure

**Created:**
- `MikanRemote/Shared/SharedDefaults.swift` — App Group `UserDefaults` wrapper for `pendingShareURL`. Included as source by both the main app and the Share Extension targets.
- `MikanRemote/MikanRemote/PendingShareDispatcher.swift` — `@MainActor @Observable` state machine that drains the slot when the WebSocket is ready.
- `MikanRemote/MikanRemote/UtilitiesView.swift` — the new sheet (Tools section, then Open URL on Mac section).
- `MikanRemote/MikanRemote/TopBarIconStyle.swift` — small view modifier to keep the YouTube/Utilities/gear icons consistently sized.
- `MikanRemote/MikanRemote/Banner.swift` — small SwiftUI view rendering the dispatcher's `.sending`/`.sent`/`.failed` states above the trackpad.
- `MikanRemote/MikanRemote.entitlements` — App Group entitlement for the main app.
- `MikanRemote/MikanRemoteShare/ShareViewController.swift` — Share Extension principal class. URL extraction → App Group write → open `mikanremote://share` → `completeRequest`.
- `MikanRemote/MikanRemoteShare/Info.plist` — extension Info.plist with URL-only activation rule.
- `MikanRemote/MikanRemoteShare.entitlements` — App Group entitlement for the extension.
- `MikanRemote/MikanRemoteTests/SharedDefaultsTests.swift`
- `MikanRemote/MikanRemoteTests/PendingShareDispatcherTests.swift`

**Modified:**
- `MikanRemote/project.yml` — add Shared/ to main-app sources; add `MikanRemoteShare` extension target; add `MikanRemoteTests` test target; add App Group capability to both app and extension; add URL scheme + App Group identifier to main-app Info.plist.
- `MikanRemote/MikanRemote/Info.plist` — register `mikanremote://` URL scheme; add `MikanAppGroupIdentifier` key.
- `MikanRemote/MikanRemote/MikanRemoteApp.swift` — instantiate `PendingShareDispatcher`; install `.onOpenURL` and `.onChange(of: scenePhase)` hooks.
- `MikanRemote/MikanRemote/ContentView.swift` — add Utilities launcher button to top safe-area inset; bump icon sizes via `TopBarIconStyle`; render banner above trackpad.
- `MikanRemote/MikanRemote/SettingsView.swift` — remove "Utilities" section (and its lone screenshot button).

**Untouched:**
- `MikanProtocol/` — no protocol changes.
- `MikanRemoteServer/` — no server changes.

---

## Task 1: Wire App Group, URL scheme, Share Extension target, and test target into project.yml

This task is pure project plumbing. It compiles to no runtime behavior change but unlocks every later task.

**Files:**
- Modify: `MikanRemote/project.yml`
- Create: `MikanRemote/MikanRemote.entitlements`
- Create: `MikanRemote/MikanRemoteShare.entitlements`
- Create: `MikanRemote/MikanRemoteShare/Info.plist`
- Create: `MikanRemote/MikanRemoteShare/ShareViewController.swift` (stub — full impl in Task 8)
- Create: `MikanRemote/Shared/.gitkeep`
- Create: `MikanRemote/MikanRemoteTests/Stub.swift` (placeholder; real tests added in later tasks — XCTest needs at least one source file)
- Modify: `MikanRemote/MikanRemote/Info.plist`

- [ ] **Step 1: Create the main app entitlements file**

Create `MikanRemote/MikanRemote.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.$(BUNDLE_PREFIX).mikanremote</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 2: Create the share extension entitlements file**

Create `MikanRemote/MikanRemoteShare.entitlements` with identical content to the main entitlements (same App Group, same identifier substitution):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.$(BUNDLE_PREFIX).mikanremote</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 3: Create the share extension Info.plist**

Create `MikanRemote/MikanRemoteShare/Info.plist`. The activation rule restricts the extension to URL shares only:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>MikanRemote</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>XPC!</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>MikanAppGroupIdentifier</key>
	<string>group.$(BUNDLE_PREFIX).mikanremote</string>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionAttributes</key>
		<dict>
			<key>NSExtensionActivationRule</key>
			<string>SUBQUERY (extensionItems, $extensionItem, SUBQUERY ($extensionItem.attachments, $a, ANY $a.registeredTypeIdentifiers UTI-CONFORMS-TO &quot;public.url&quot;).@count &gt; 0).@count &gt; 0</string>
		</dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.share-services</string>
		<key>NSExtensionPrincipalClass</key>
		<string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
	</dict>
</dict>
</plist>
```

- [ ] **Step 4: Create the stub ShareViewController so the target compiles**

Create `MikanRemote/MikanRemoteShare/ShareViewController.swift`:

```swift
import UIKit

@objc(ShareViewController)
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Real implementation lands in Task 8.
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
```

- [ ] **Step 5: Create empty Shared/ directory placeholder**

Run:

```bash
mkdir -p MikanRemote/Shared && touch MikanRemote/Shared/.gitkeep
```

- [ ] **Step 6: Create test target stub source**

Create `MikanRemote/MikanRemoteTests/Stub.swift`:

```swift
import XCTest

final class StubTests: XCTestCase {
    func testStub() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 7: Modify the main app Info.plist to register the URL scheme and App Group identifier**

Replace `MikanRemote/MikanRemote/Info.plist` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>MikanRemote</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>mikanremote</string>
			</array>
		</dict>
	</array>
	<key>MikanAppGroupIdentifier</key>
	<string>group.$(BUNDLE_PREFIX).mikanremote</string>
	<key>NSBonjourServices</key>
	<array>
		<string>_mikan._tcp</string>
	</array>
	<key>NSLocalNetworkUsageDescription</key>
	<string>MikanRemote needs local network access to find and connect to your Mac.</string>
	<key>UILaunchScreen</key>
	<dict/>
</dict>
</plist>
```

- [ ] **Step 8: Replace `MikanRemote/project.yml` with the full target layout**

Replace the entire file with:

```yaml
name: MikanRemote
options:
  bundleIdPrefix: com.example
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "15"

configFiles:
  Debug: ../Project.xcconfig
  Release: ../Project.xcconfig

packages:
  MikanProtocol:
    path: ../MikanProtocol

schemes:
  MikanRemote:
    build:
      targets:
        MikanRemote: all
        MikanRemoteShare: all
    run:
      config: Release
      debugEnabled: false
    test:
      config: Debug
      targets:
        - MikanRemoteTests
    profile:
      config: Release
    analyze:
      config: Debug
    archive:
      config: Release

targets:
  MikanRemote:
    type: application
    platform: iOS
    sources:
      - MikanRemote
      - Shared
    dependencies:
      - package: MikanProtocol
      - target: MikanRemoteShare
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(BUNDLE_PREFIX).MikanRemote
        SWIFT_VERSION: "5.9"
        IPHONEOS_DEPLOYMENT_TARGET: "17.0"
        INFOPLIST_FILE: MikanRemote/Info.plist
        CODE_SIGN_STYLE: Automatic
        CODE_SIGN_ENTITLEMENTS: MikanRemote.entitlements
    info:
      path: MikanRemote/Info.plist

  MikanRemoteShare:
    type: app-extension
    platform: iOS
    sources:
      - MikanRemoteShare
      - Shared
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(BUNDLE_PREFIX).MikanRemote.Share
        SWIFT_VERSION: "5.9"
        IPHONEOS_DEPLOYMENT_TARGET: "17.0"
        INFOPLIST_FILE: MikanRemoteShare/Info.plist
        CODE_SIGN_STYLE: Automatic
        CODE_SIGN_ENTITLEMENTS: MikanRemoteShare.entitlements

  MikanRemoteTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - MikanRemoteTests
    dependencies:
      - target: MikanRemote
      - package: MikanProtocol
    settings:
      base:
        SWIFT_VERSION: "5.9"
        IPHONEOS_DEPLOYMENT_TARGET: "17.0"
        BUNDLE_LOADER: $(TEST_HOST)
        TEST_HOST: $(BUILT_PRODUCTS_DIR)/MikanRemote.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MikanRemote
```

- [ ] **Step 9: Regenerate the Xcode project**

Run:

```bash
cd MikanRemote && xcodegen generate
```

Expected output: `Loaded project: ...` and `Created project at MikanRemote.xcodeproj`. No errors.

- [ ] **Step 10: Build to verify the project structure compiles**

Run:

```bash
cd MikanRemote && xcodebuild -scheme MikanRemote -destination 'generic/platform=iOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`. If signing-related errors appear without `CODE_SIGNING_ALLOWED=NO`, that's expected without a real device — the flag is only for plan-level verification that source compiles.

- [ ] **Step 11: Commit**

```bash
git add MikanRemote/MikanRemote.entitlements MikanRemote/MikanRemoteShare.entitlements \
        MikanRemote/MikanRemoteShare/Info.plist MikanRemote/MikanRemoteShare/ShareViewController.swift \
        MikanRemote/Shared/.gitkeep MikanRemote/MikanRemoteTests/Stub.swift \
        MikanRemote/MikanRemote/Info.plist MikanRemote/project.yml
git commit -m "build: add Share Extension target, App Group, URL scheme, test target

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: SharedDefaults wrapper

A tiny App Group `UserDefaults` wrapper used by both targets. TDD: round-trip the slot using an injected `UserDefaults` so the test doesn't depend on the App Group entitlement at runtime.

**Files:**
- Create: `MikanRemote/Shared/SharedDefaults.swift`
- Create: `MikanRemote/MikanRemoteTests/SharedDefaultsTests.swift`
- Delete: `MikanRemote/MikanRemoteTests/Stub.swift`

- [ ] **Step 1: Write the failing test**

Create `MikanRemote/MikanRemoteTests/SharedDefaultsTests.swift`:

```swift
import XCTest
@testable import MikanRemote

final class SharedDefaultsTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testPendingShareURLStartsNil() {
        let s = SharedDefaults(defaults: userDefaults)
        XCTAssertNil(s.pendingShareURL)
    }

    func testPendingShareURLRoundTrips() {
        let s = SharedDefaults(defaults: userDefaults)
        s.pendingShareURL = "https://example.com/foo"
        XCTAssertEqual(s.pendingShareURL, "https://example.com/foo")
    }

    func testPendingShareURLClears() {
        let s = SharedDefaults(defaults: userDefaults)
        s.pendingShareURL = "https://example.com"
        s.pendingShareURL = nil
        XCTAssertNil(s.pendingShareURL)
    }

    func testTwoInstancesShareSameStorage() {
        let a = SharedDefaults(defaults: userDefaults)
        let b = SharedDefaults(defaults: userDefaults)
        a.pendingShareURL = "https://example.com/share"
        XCTAssertEqual(b.pendingShareURL, "https://example.com/share")
    }
}
```

Then delete the stub:

```bash
rm MikanRemote/MikanRemoteTests/Stub.swift
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd MikanRemote && xcodebuild test -scheme MikanRemote -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MikanRemoteTests/SharedDefaultsTests
```

Expected: build error — `Cannot find 'SharedDefaults' in scope`. (If no iPhone 15 simulator is installed, substitute any installed iOS simulator name. Run `xcrun simctl list devices available` to list them.)

- [ ] **Step 3: Implement SharedDefaults**

Create `MikanRemote/Shared/SharedDefaults.swift`:

```swift
import Foundation

final class SharedDefaults {
    static let shared: SharedDefaults = {
        let id = Bundle.main.object(forInfoDictionaryKey: "MikanAppGroupIdentifier") as? String ?? ""
        let defaults = UserDefaults(suiteName: id) ?? .standard
        return SharedDefaults(defaults: defaults)
    }()

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var pendingShareURL: String? {
        get { defaults.string(forKey: Keys.pendingShareURL) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Keys.pendingShareURL)
            } else {
                defaults.removeObject(forKey: Keys.pendingShareURL)
            }
        }
    }

    private enum Keys {
        static let pendingShareURL = "pendingShareURL"
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
cd MikanRemote && xcodebuild test -scheme MikanRemote -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MikanRemoteTests/SharedDefaultsTests
```

Expected: `Test Suite 'SharedDefaultsTests' passed. Executed 4 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add MikanRemote/Shared/SharedDefaults.swift MikanRemote/MikanRemoteTests/SharedDefaultsTests.swift
git rm MikanRemote/MikanRemoteTests/Stub.swift
git commit -m "feat: SharedDefaults wrapper for pendingShareURL App Group slot

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: PendingShareDispatcher

State machine that drains the slot when the WebSocket is ready, with timeout and retry. The most testable unit in the feature; the rest is mostly UI.

**Files:**
- Create: `MikanRemote/MikanRemote/PendingShareDispatcher.swift`
- Create: `MikanRemote/MikanRemoteTests/PendingShareDispatcherTests.swift`

- [ ] **Step 1: Define the storage protocol on the existing SharedDefaults**

Modify `MikanRemote/Shared/SharedDefaults.swift` — add a protocol so tests can substitute an in-memory store, and conform `SharedDefaults` to it. Add at the top of the file (above the class):

```swift
protocol PendingURLStore: AnyObject {
    var pendingShareURL: String? { get set }
}
```

And at the bottom of the file (after the class):

```swift
extension SharedDefaults: PendingURLStore {}
```

- [ ] **Step 2: Write the failing tests**

Create `MikanRemote/MikanRemoteTests/PendingShareDispatcherTests.swift`:

```swift
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
```

- [ ] **Step 3: Run the tests to verify they fail**

Run:

```bash
cd MikanRemote && xcodebuild test -scheme MikanRemote -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MikanRemoteTests/PendingShareDispatcherTests
```

Expected: build error — `Cannot find 'PendingShareDispatcher' in scope`.

- [ ] **Step 4: Implement PendingShareDispatcher**

Create `MikanRemote/MikanRemote/PendingShareDispatcher.swift`:

```swift
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
    private var isReady: () -> Bool
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
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:

```bash
cd MikanRemote && xcodebuild test -scheme MikanRemote -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MikanRemoteTests/PendingShareDispatcherTests
```

Expected: `Test Suite 'PendingShareDispatcherTests' passed. Executed 8 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add MikanRemote/Shared/SharedDefaults.swift MikanRemote/MikanRemote/PendingShareDispatcher.swift MikanRemote/MikanRemoteTests/PendingShareDispatcherTests.swift
git commit -m "feat: PendingShareDispatcher state machine with timeout and retry

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: UtilitiesView sheet

The new sheet. Tools section first (screenshot), Open URL section second (PasteButton + textbox + Send).

**Files:**
- Create: `MikanRemote/MikanRemote/UtilitiesView.swift`

- [ ] **Step 1: Create the view**

Create `MikanRemote/MikanRemote/UtilitiesView.swift`:

```swift
import SwiftUI
import UIKit
import MikanProtocol

struct UtilitiesView: View {
    @Bindable var connectionManager: ConnectionManager
    @Environment(\.dismiss) private var dismiss

    @State private var typedURL: String = ""
    @State private var lastSendOK: Bool = false
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        NavigationStack {
            List {
                Section("Tools") {
                    Button {
                        sendCommand("screenshot")
                    } label: {
                        Label("Take Screenshot (\u{21E7}\u{2318}3)", systemImage: "camera.viewfinder")
                    }
                }

                Section("Open URL on Mac") {
                    PasteButton(payloadType: URL.self) { urls in
                        guard let url = urls.first else { return }
                        sendURL(url.absoluteString)
                    }
                    .buttonBorderShape(.capsule)

                    HStack {
                        TextField("https://…", text: $typedURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.send)
                            .onSubmit { sendTypedIfValid() }

                        Button("Send") { sendTypedIfValid() }
                            .disabled(!isTypedURLValid)
                    }

                    if lastSendOK {
                        Label("Sent", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .transition(.opacity)
                    }
                }
            }
            .navigationTitle("Utilities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { feedbackGenerator.prepare() }
        }
    }

    private var isTypedURLValid: Bool {
        guard let url = URL(string: typedURL.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return url.scheme != nil && url.host != nil
    }

    private func sendTypedIfValid() {
        let trimmed = typedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else { return }
        sendURL(url.absoluteString)
        typedURL = ""
    }

    private func sendURL(_ url: String) {
        feedbackGenerator.impactOccurred()
        feedbackGenerator.prepare()
        connectionManager.send(.openURL(url: url))
        flashSent()
    }

    private func sendCommand(_ command: String) {
        feedbackGenerator.impactOccurred()
        feedbackGenerator.prepare()
        connectionManager.send(.performCommand(command: command))
    }

    private func flashSent() {
        withAnimation { lastSendOK = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                withAnimation { lastSendOK = false }
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run:

```bash
cd MikanRemote && xcodebuild -scheme MikanRemote -destination 'generic/platform=iOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`. (No runtime test — UI sheet is exercised manually after Task 5 wires the launcher.)

- [ ] **Step 3: Commit**

```bash
git add MikanRemote/MikanRemote/UtilitiesView.swift
git commit -m "feat(client): UtilitiesView sheet (screenshot + paste + URL textbox)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Top-bar icon style helper, banner view, ContentView wiring

Adds the Utilities launcher button next to the gear, bumps the three top-bar icons to a consistent ~14pt, and renders a transient banner above the trackpad while the dispatcher is doing its thing.

**Files:**
- Create: `MikanRemote/MikanRemote/TopBarIconStyle.swift`
- Create: `MikanRemote/MikanRemote/Banner.swift`
- Modify: `MikanRemote/MikanRemote/ContentView.swift`

- [ ] **Step 1: Create the icon style helper**

Create `MikanRemote/MikanRemote/TopBarIconStyle.swift`:

```swift
import SwiftUI

private struct TopBarIconModifier: ViewModifier {
    let tint: Color
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14))
            .foregroundStyle(tint)
    }
}

extension View {
    func topBarIcon(tint: Color = .secondary) -> some View {
        modifier(TopBarIconModifier(tint: tint))
    }
}
```

- [ ] **Step 2: Create the banner view**

Create `MikanRemote/MikanRemote/Banner.swift`:

```swift
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
```

- [ ] **Step 3: Modify ContentView**

Replace `MikanRemote/MikanRemote/ContentView.swift` with:

```swift
// MikanRemote/MikanRemote/ContentView.swift
import SwiftUI
import UIKit
import MikanProtocol

struct ContentView: View {
    @Bindable var connectionManager: ConnectionManager
    @Bindable var dispatcher: PendingShareDispatcher
    @State private var showSettings = false
    @State private var showYouTubePopup = false
    @State private var showUtilities = false

    var body: some View {
        VStack(spacing: 0) {
            if !connectionManager.isConnected {
                if connectionManager.discoveredServers.isEmpty {
                    Spacer()
                    ProgressView("Scanning for Mikan servers...")
                        .padding()
                    Spacer()
                } else if connectionManager.discoveredServers.count > 1 {
                    ServerPickerView(
                        servers: connectionManager.discoveredServers,
                        onSelect: { connectionManager.connect(to: $0) }
                    )
                } else {
                    Spacer()
                    ProgressView("Connecting...")
                        .padding()
                    Spacer()
                }
            } else if connectionManager.pairingRequired {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 40))
                        .foregroundStyle(.tint)

                    Text("Enter Pairing Code")
                        .font(.headline)

                    Text("Check your Mac for the 4-digit code.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    AutoFocusCodeField { code in
                        connectionManager.submitPairingCode(code)
                    }
                    .frame(width: 160, height: 50)

                    if connectionManager.pairingFailed {
                        Text("Wrong code. Try again.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                Spacer()
            } else if connectionManager.hostname == nil {
                Spacer()
                ProgressView("Authenticating...")
                    .padding()
                Spacer()
            } else {
                Spacer()

                DispatcherBanner(
                    state: dispatcher.state,
                    hostname: connectionManager.hostname,
                    onRetry: { dispatcher.retry() }
                )

                VolumeButtonsView(
                    onCommand: { connectionManager.send(.performCommand(command: $0)) }
                )
                .padding(.bottom, 4)

                TrackpadView(
                    onMove: { dx, dy in
                        connectionManager.send(.mouseMove(deltaX: dx, deltaY: dy))
                    },
                    onTap: {
                        connectionManager.send(.mouseClick)
                    },
                    onScroll: { dx, dy in
                        connectionManager.send(.mouseScroll(deltaX: dx, deltaY: dy))
                    }
                )
                .frame(maxHeight: UIScreen.main.bounds.height * 0.35)
                .padding(.horizontal)
                .padding(.vertical, 4)

                ActionButtonsView(
                    actions: connectionManager.actions,
                    onCommand: { connectionManager.send(.performCommand(command: $0)) },
                    onOpenURL: { connectionManager.send(.openURL(url: $0)) }
                )

                Spacer()
                Spacer()
            }
        }
        .safeAreaInset(edge: .top) {
            if connectionManager.isConnected && connectionManager.hostname != nil {
                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text(connectionManager.hostname ?? "Connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if YouTubeVisibility.effectiveYouTubeButtonVisible(
                        mode: connectionManager.youtubePopupMode,
                        actions: connectionManager.actions
                    ) {
                        Button {
                            showYouTubePopup = true
                        } label: {
                            Image(systemName: "play.rectangle.fill")
                                .topBarIcon(tint: .red)
                        }
                        .padding(.trailing, 8)
                    }
                    Button {
                        showUtilities = true
                    } label: {
                        Image(systemName: "wrench.and.screwdriver")
                            .topBarIcon()
                    }
                    .padding(.trailing, 8)
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .topBarIcon()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 0)
                .padding(.bottom, 2)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(connectionManager: connectionManager)
        }
        .sheet(isPresented: $showYouTubePopup) {
            YouTubePopupView(
                onCommand: { connectionManager.send(.performCommand(command: $0)) }
            )
        }
        .sheet(isPresented: $showUtilities) {
            UtilitiesView(connectionManager: connectionManager)
        }
    }
}

private class AutoFocusTextField: UITextField {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            becomeFirstResponder()
        }
    }
}

private struct AutoFocusCodeField: UIViewRepresentable {
    let onSubmit: (String) -> Void

    func makeUIView(context: Context) -> UITextField {
        let tf = AutoFocusTextField()
        tf.keyboardType = .numberPad
        tf.font = UIFont.monospacedSystemFont(ofSize: 32, weight: .bold)
        tf.textAlignment = .center
        tf.borderStyle = .roundedRect
        tf.placeholder = "Code"
        tf.delegate = context.coordinator
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onSubmit: onSubmit) }

    class Coordinator: NSObject, UITextFieldDelegate {
        let onSubmit: (String) -> Void
        init(onSubmit: @escaping (String) -> Void) { self.onSubmit = onSubmit }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = textField.text ?? ""
            let updated = (current as NSString).replacingCharacters(in: range, with: string)
            let filtered = String(updated.prefix(4).filter(\.isNumber))
            if filtered.count == 4 {
                textField.text = filtered
                onSubmit(filtered)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    textField.text = ""
                }
                return false
            }
            return filtered == updated
        }
    }
}
```

- [ ] **Step 4: Build to verify it compiles**

Run:

```bash
cd MikanRemote && xcodebuild -scheme MikanRemote -destination 'generic/platform=iOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`. (`ContentView` now requires a `dispatcher` argument — `MikanRemoteApp.swift` will be updated in Task 7. Until then, the build will fail at the call site in `MikanRemoteApp.swift`. Defer the build verification to the end of Task 7.)

- [ ] **Step 5: Commit**

```bash
git add MikanRemote/MikanRemote/TopBarIconStyle.swift MikanRemote/MikanRemote/Banner.swift MikanRemote/MikanRemote/ContentView.swift
git commit -m "feat(client): top-bar icon helper, banner view, Utilities launcher

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Remove Utilities section from SettingsView

**Files:**
- Modify: `MikanRemote/MikanRemote/SettingsView.swift`

- [ ] **Step 1: Delete the Utilities section**

In `MikanRemote/MikanRemote/SettingsView.swift`, find this block (currently around lines 222–228):

```swift
                Section("Utilities") {
                    Button {
                        connectionManager.send(.performCommand(command: "screenshot"))
                    } label: {
                        Label("Take Screenshot (\u{21E7}\u{2318}3)", systemImage: "camera.viewfinder")
                    }
                }
```

Delete it entirely. The Section above it ("Reset Actions to Defaults") is the new last section before the navigation toolbar.

- [ ] **Step 2: Commit**

```bash
git add MikanRemote/MikanRemote/SettingsView.swift
git commit -m "refactor(client): drop Utilities section from Settings (moved to UtilitiesView)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: MikanRemoteApp wiring — instantiate dispatcher, hook .onOpenURL and scenePhase

**Files:**
- Modify: `MikanRemote/MikanRemote/MikanRemoteApp.swift`

- [ ] **Step 1: Replace MikanRemoteApp.swift**

Replace the entire file with:

```swift
// MikanRemote/MikanRemote/MikanRemoteApp.swift
import SwiftUI
import MikanProtocol

@main
struct MikanRemoteApp: App {
    @State private var connectionManager: ConnectionManager
    @State private var dispatcher: PendingShareDispatcher
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Single instance captured by both the State and the dispatcher closures.
        let cm = ConnectionManager()
        _connectionManager = State(initialValue: cm)
        _dispatcher = State(initialValue: PendingShareDispatcher(
            store: SharedDefaults.shared,
            send: { [weak cm] url in
                cm?.send(.openURL(url: url))
            },
            isReady: { [weak cm] in
                guard let cm else { return false }
                return cm.isConnected && cm.hostname != nil
            }
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(connectionManager: connectionManager, dispatcher: dispatcher)
                .onAppear {
                    connectionManager.startBrowsing()
                }
                .onOpenURL { url in
                    if url.scheme == "mikanremote" {
                        dispatcher.consumePending()
                    }
                }
                .onChange(of: connectionManager.isConnected) { _, _ in
                    dispatcher.connectionBecameReady()
                }
                .onChange(of: connectionManager.hostname) { _, _ in
                    dispatcher.connectionBecameReady()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                connectionManager.attemptReconnect()
                dispatcher.consumePending()
            }
        }
    }
}
```

Note: the `init()` pattern (creating `cm` once and capturing it in both `State` initializers) is needed because the dispatcher's closures must reference the same `ConnectionManager` instance that `connectionManager` holds. SwiftUI's `@State` semantics mean we can't initialize one from another at the property-wrapper level.

- [ ] **Step 2: Build to verify everything compiles**

Run:

```bash
cd MikanRemote && xcodebuild -scheme MikanRemote -destination 'generic/platform=iOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run all unit tests**

Run:

```bash
cd MikanRemote && xcodebuild test -scheme MikanRemote -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: `Test Suite 'All tests' passed.` All `SharedDefaultsTests` and `PendingShareDispatcherTests` cases pass.

- [ ] **Step 4: Commit**

```bash
git add MikanRemote/MikanRemote/MikanRemoteApp.swift
git commit -m "feat(client): wire PendingShareDispatcher into MikanRemoteApp

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Real ShareViewController implementation

**Files:**
- Modify: `MikanRemote/MikanRemoteShare/ShareViewController.swift`

- [ ] **Step 1: Replace the stub with the full implementation**

Replace `MikanRemote/MikanRemoteShare/ShareViewController.swift` with:

```swift
import UIKit
import UniformTypeIdentifiers

@objc(ShareViewController)
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task { await processInput() }
    }

    private func processInput() async {
        defer {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
        guard let url = await extractFirstURL() else { return }
        SharedDefaults.shared.pendingShareURL = url.absoluteString
        await openContainingApp()
    }

    private func extractFirstURL() async -> URL? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let obj = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
                       let url = obj as? URL {
                        return url
                    }
                }
            }
            // Fallback: parse URL out of plain text
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let obj = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
                       let text = obj as? String,
                       let detected = firstURL(in: text) {
                        return detected
                    }
                }
            }
        }
        return nil
    }

    private func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, options: [], range: range)?.url
    }

    @MainActor
    private func openContainingApp() {
        guard let url = URL(string: "mikanremote://share") else { return }
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = current.next
        }
        // Responder-chain walk failed. URL is already in the App Group slot;
        // when the user manually returns to MikanRemote, scenePhase = .active
        // will trigger consumePending() and the URL will be sent.
    }
}
```

- [ ] **Step 2: Build to verify the extension compiles**

Run:

```bash
cd MikanRemote && xcodebuild -scheme MikanRemote -destination 'generic/platform=iOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`. Both targets (`MikanRemote.app` and `MikanRemoteShare.appex`) build.

- [ ] **Step 3: Commit**

```bash
git add MikanRemote/MikanRemoteShare/ShareViewController.swift
git commit -m "feat(share): extract URL, write to App Group, open host app

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Manual smoke test on a real device

This task is an explicit checklist for the human running it. Build, install, and walk through the manual cases from the spec. No automated coverage replaces these.

- [ ] **Step 1: Open the project in Xcode**

```bash
cd MikanRemote && open MikanRemote.xcodeproj
```

- [ ] **Step 2: Confirm the App Group capability is registered**

In Xcode, select the `MikanRemote` target → Signing & Capabilities → confirm "App Groups" is present and shows `group.<your-bundle-prefix>.mikanremote`. Repeat for `MikanRemoteShare`. If either is missing, click `+ Capability`, add App Groups, then add the same group ID to both targets. (xcodegen wires the entitlements file but Xcode/the developer portal must also register the App Group — first build to a real device may prompt you to register it.)

- [ ] **Step 3: Build and run on physical iPhone (Cmd+R)**

The MikanRemoteServer must be running on the Mac and on the same Wi-Fi.

- [ ] **Step 4: Path A happy** — In Safari on the iPhone, share a YouTube link → MikanRemote → expect Mac browser to open the URL within ~1s.

- [ ] **Step 5: Path A cold reconnect** — Force-quit MikanRemote (swipe up from app switcher). Share a URL from Safari. Expect: app launches, banner reads "Sending to <hostname>…" briefly, then "Sent" briefly, then disappears. Mac browser opens the URL.

- [ ] **Step 6: Path A timeout** — Disable Mac Wi-Fi. Force-quit MikanRemote. Share a URL. Wait ≥10s. Expect: banner shows "Couldn't reach Mac — Retry". Re-enable Mac Wi-Fi (wait for the iPhone to reconnect — green dot in top bar). Tap Retry. Mac opens the URL.

- [ ] **Step 7: Path A overwrite** — Disable Mac Wi-Fi. Share URL #1 from Safari. Without re-enabling Wi-Fi, share URL #2. Re-enable Wi-Fi. Expect: only URL #2 opens on the Mac.

- [ ] **Step 8: Paste path** — Copy a URL in Safari. Open MikanRemote. Tap the wrench icon. Tap "Paste". Expect: no iOS privacy toast (because `PasteButton`), URL opens on Mac.

- [ ] **Step 9: Textbox path** — In Utilities sheet, type `https://example.com`, tap Send. Expect: opens on Mac, field clears, "Sent" indicator briefly appears. Try empty text and `not a url` — Send button is disabled.

- [ ] **Step 10: Screenshot path** — In Utilities sheet, tap Take Screenshot. Expect: ⇧⌘3 fires on Mac (you'll hear the camera-shutter sound and see a screenshot land on the desktop).

- [ ] **Step 11: Settings cleanup** — Open Settings (gear). Confirm there is no "Utilities" section anywhere.

- [ ] **Step 12: Icon sizing** — Compare the YouTube, wrench, and gear icons in the top bar. They should all be visibly larger than before this change (~17%) and visually consistent.

- [ ] **Step 13: Final commit if any tweaks were needed during smoke** (optional)

If you adjusted UI layout, padding, or icon sizing during the smoke, commit those tweaks now. Otherwise, the feature is complete.

---

## Self-review notes

- Spec coverage: every numbered behavior in §Data flow of the spec maps to a task. Path A → Tasks 7 + 8 + 9. Path B (PasteButton) → Task 4 + Step 8 of Task 9. Path C (textbox) → Task 4 + Step 9 of Task 9. Path D (screenshot) → Task 4 + Step 10 of Task 9. Settings cleanup → Task 6 + Step 11 of Task 9. Icon sizing → Task 5 + Step 12 of Task 9. No-protocol-change and no-server-change requirements are implicit in the file list (no MikanProtocol or MikanRemoteServer touches anywhere).

- Testability: `PendingShareDispatcher` is the only stateful unit and it is fully unit-tested (8 cases, including timeout and slot-mutation). `SharedDefaults` is round-tripped. UI is manually tested.

- Type consistency: state enum `.idle | .sending(url:) | .sent | .failed` is used identically in `PendingShareDispatcher`, `PendingShareDispatcherTests`, `Banner`, and `ContentView`. The `PendingURLStore` protocol name is consistent across `SharedDefaults`, the dispatcher, and the test mock.
