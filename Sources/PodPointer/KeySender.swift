import ApplicationServices
import CoreGraphics

/// Sends slide-navigation keys to the frontmost app. Needs Accessibility access.
enum KeySender {
    private static let rightArrow: CGKeyCode = 124
    private static let leftArrow: CGKeyCode = 123

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
