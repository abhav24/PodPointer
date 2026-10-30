// Draws the app icon and writes it to the path given as the first argument.
// Run with: swift scripts/make-icon.swift Resources/AppIcon.icns
import AppKit

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func draw(in context: CGContext) {
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0, 0, 0, 0.35))
    context.addPath(tilePath)
    context.setFillColor(color(30, 30, 90))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    let background = CGGradient(colorsSpace: space, colors: [color(82, 76, 214), color(24, 22, 72)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(background, start: CGPoint(x: 300, y: 924), end: CGPoint(x: 700, y: 100), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    let dot = CGPoint(x: 700, y: 700)
    let beamStart = CGPoint(x: 430, y: 470)

    // The beam from the case to the laser dot.
    let beam = CGMutablePath()
    beam.move(to: CGPoint(x: beamStart.x - 44, y: beamStart.y + 18))
