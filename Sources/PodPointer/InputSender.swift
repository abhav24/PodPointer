import ApplicationServices
import CoreGraphics

/// Sends keys and clicks to the Mac. Needs Accessibility access.
enum InputSender {
    private static let rightArrow: CGKeyCode = 124
    private static let leftArrow: CGKeyCode = 123

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func nextSlide() { press(rightArrow) }
    static func previousSlide() { press(leftArrow) }

    static func click(count: Int) {
        guard let location = CGEvent(source: nil)?.location else { return }
        for clickNumber in 1...count {
            for type in [CGEventType.leftMouseDown, .leftMouseUp] {
                let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: .left)
                event?.setIntegerValueField(.mouseEventClickState, value: Int64(clickNumber))
                event?.post(tap: .cghidEventTap)
            }
        }
    }

    private static func press(_ key: CGKeyCode) {
        CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)?.post(tap: .cghidEventTap)
    }
}
