import SwiftUI

struct PairingCodeView: View {
    let code: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            Text("Pairing Code")
                .font(.headline)

            Text(code)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .kerning(8)

            Text("Enter this code on your iPhone to pair.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(width: 300)
    }
}
