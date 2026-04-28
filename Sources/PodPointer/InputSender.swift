import ApplicationServices
import CoreGraphics

/// Sends keys and clicks to the Mac. Needs Accessibility access.
enum InputSender {
    private static let rightArrow: CGKeyCode = 124
