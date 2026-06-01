import AppKit

enum PermissionsManager {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func checkOrPrompt() {
        guard !isTrusted else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
