// MikanRemote/MikanRemote/RemoteKeyboardView.swift
import SwiftUI
import UIKit

/// Invisible, zero-size view that owns the iOS keyboard for the remote-typing
/// feature. It adopts `UIKeyInput` instead of wrapping a `UITextField` so no
/// text is ever stored on the phone: every character iOS inserts is forwarded
/// immediately as `typeText`, Return as `performCommand("return")`, and
/// delete as `performCommand("backspace")`. `isActive` drives first-responder
/// status (keyboard shown/hidden) and is written back to `false` whenever the
/// view resigns for any reason, so the toggle button never gets out of sync.
struct RemoteKeyboardView: UIViewRepresentable {
    @Binding var isActive: Bool
    var onText: (String) -> Void
    var onReturn: () -> Void
    var onBackspace: () -> Void

    func makeUIView(context: Context) -> RemoteKeyInputView {
        let view = RemoteKeyInputView()
        view.onText = onText
        view.onReturn = onReturn
        view.onBackspace = onBackspace
        view.onResign = {
            // Deferred: this can fire from inside updateUIView (our own
            // resignFirstResponder call), and writing state mid-update warns.
            DispatchQueue.main.async {
                if isActive { isActive = false }
            }
        }
        return view
    }

    func updateUIView(_ uiView: RemoteKeyInputView, context: Context) {
        uiView.onText = onText
        uiView.onReturn = onReturn
        uiView.onBackspace = onBackspace
        if isActive, !uiView.isFirstResponder, uiView.window != nil {
            uiView.becomeFirstResponder()
        } else if !isActive, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }
}

final class RemoteKeyInputView: UIView, UIKeyInput {
    var onText: ((String) -> Void)?
    var onReturn: (() -> Void)?
    var onBackspace: (() -> Void)?
    var onResign: (() -> Void)?

    // UITextInputTraits — autocorrect/prediction are off because there is no
    // local text for iOS to correct against; what you tap is what the Mac gets.
    var autocorrectionType: UITextAutocorrectionType = .no
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var spellCheckingType: UITextSpellCheckingType = .no
    var smartQuotesType: UITextSmartQuotesType = .no
    var smartDashesType: UITextSmartDashesType = .no
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .no
    var keyboardType: UIKeyboardType = .default
    var returnKeyType: UIReturnKeyType = .default
    var enablesReturnKeyAutomatically: Bool = false

    override var canBecomeFirstResponder: Bool { true }

    // Always true so iOS keeps calling deleteBackward — with no local buffer
    // there is nothing to check, and the Mac decides whether a delete applies.
    var hasText: Bool { true }

    func insertText(_ text: String) {
        // Return arrives as "\n" through insertText, not as a separate key.
        // Split so text and newlines keep their original order.
        var pending = ""
        for ch in text {
            if ch == "\n" || ch == "\r" {
                if !pending.isEmpty { onText?(pending); pending = "" }
                onReturn?()
            } else {
                pending.append(ch)
            }
        }
        if !pending.isEmpty { onText?(pending) }
    }

    func deleteBackward() {
        onBackspace?()
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onResign?() }
        return resigned
    }
}
