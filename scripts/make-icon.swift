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
    beam.addLine(to: CGPoint(x: dot.x - 12, y: dot.y + 12))
    beam.addLine(to: CGPoint(x: dot.x + 12, y: dot.y - 12))
    beam.addLine(to: CGPoint(x: beamStart.x + 18, y: beamStart.y - 44))
    beam.closeSubpath()
    context.saveGState()
    context.addPath(beam)
    context.clip()
    let beamFade = CGGradient(colorsSpace: space, colors: [color(255, 70, 80, 0.05), color(255, 70, 80, 0.75)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(beamFade, start: beamStart, end: dot, options: [])
    context.restoreGState()

    // The target ring and the glowing dot.
    context.setStrokeColor(color(255, 255, 255, 0.4))
    context.setLineWidth(10)
    context.strokeEllipse(in: CGRect(x: dot.x - 100, y: dot.y - 100, width: 200, height: 200))
    let glow = CGGradient(colorsSpace: space, colors: [color(255, 70, 80, 0.9), color(255, 70, 80, 0)] as CFArray, locations: [0, 1])!
    context.drawRadialGradient(glow, startCenter: dot, startRadius: 0, endCenter: dot, endRadius: 92, options: [])
    context.setFillColor(color(255, 90, 95))
    context.fillEllipse(in: CGRect(x: dot.x - 36, y: dot.y - 36, width: 72, height: 72))
    context.setFillColor(color(255, 225, 225))
    context.fillEllipse(in: CGRect(x: dot.x - 14, y: dot.y - 14, width: 28, height: 28))

    // The case, tilted to point at the dot.
    context.saveGState()
    context.translateBy(x: 370, y: 370)
    context.rotate(by: -CGFloat.pi / 4)
    let body = CGRect(x: -150, y: -125, width: 300, height: 250)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 86, cornerHeight: 86, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: color(0, 0, 0, 0.45))
    context.addPath(bodyPath)
    context.setFillColor(color(245, 245, 250))
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(bodyPath)
    context.clip()
    let shine = CGGradient(colorsSpace: space, colors: [color(255, 255, 255), color(205, 207, 222)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(shine, start: CGPoint(x: 0, y: 125), end: CGPoint(x: 0, y: -125), options: [])
    context.setStrokeColor(color(120, 122, 145, 0.65))
    context.setLineWidth(6)
    context.move(to: CGPoint(x: -150, y: 42))
    context.addLine(to: CGPoint(x: 150, y: 42))
    context.strokePath()
    context.restoreGState()
    context.setFillColor(color(70, 215, 130))
    context.fillEllipse(in: CGRect(x: -11, y: -22, width: 22, height: 22))
    context.restoreGState()

    context.restoreGState()
}

func png(size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    draw(in: context)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count == 2 else {
    print("Usage: swift scripts/make-icon.swift OUTPUT.icns")
    exit(2)
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try png(size: size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try png(size: size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", CommandLine.arguments[1]]
try iconutil.run()
iconutil.waitUntilExit()
try FileManager.default.removeItem(at: iconset)
exit(iconutil.terminationStatus)
