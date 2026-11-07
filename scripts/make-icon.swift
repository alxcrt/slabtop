import AppKit

let arguments = CommandLine.arguments
if arguments.count != 2 {
    fputs("Usage: swift scripts/make-icon.swift <out.icns>\n", stderr)
    exit(2)
}

let output = URL(fileURLWithPath: arguments[1])
let iconset = output.deletingPathExtension().appendingPathExtension("iconset")
let assets = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("assets")
let sizes = [16, 32, 128, 256, 512]

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func gradient(_ path: NSBezierPath, _ top: UInt32, _ bottom: UInt32) {
    NSGradient(starting: color(bottom), ending: color(top))!.draw(in: path, angle: 90)
}

func polygon(_ points: [NSPoint]) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: points[0])
    for point in points.dropFirst() { path.line(to: point) }
    path.close()
    return path
}

func png(pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

    let tile = rounded(NSRect(x: 64, y: 64, width: 896, height: 896), 202)
    NSGraphicsContext.saveGraphicsState()
    let tileShadow = NSShadow()
    tileShadow.shadowColor = color(0x573F18, alpha: 0.18)
    tileShadow.shadowBlurRadius = 24
    tileShadow.shadowOffset = NSSize(width: 0, height: -12)
    tileShadow.set()
    color(0xEBC66B).setFill()
    tile.fill()
    gradient(tile, 0xFBE9B4, 0xEBC66B)
    NSGraphicsContext.restoreGraphicsState()
    color(0xFFFFFF, alpha: 0.45).setStroke()
    tile.lineWidth = 3
    tile.stroke()

    let cable = NSBezierPath()
    cable.move(to: NSPoint(x: 323, y: 501))
    cable.curve(to: NSPoint(x: 211, y: 441), controlPoint1: NSPoint(x: 218, y: 501), controlPoint2: NSPoint(x: 211, y: 500))
    cable.curve(to: NSPoint(x: 286, y: 358), controlPoint1: NSPoint(x: 211, y: 393), controlPoint2: NSPoint(x: 230, y: 358))
    cable.lineWidth = 25
    cable.lineCapStyle = .round
    color(0x9A793A, alpha: 0.30).setStroke()
    cable.stroke()
    let cableHighlight = AffineTransform(translationByX: 0, byY: 5)
    cable.transform(using: cableHighlight)
    color(0xFFF6D9).setStroke()
    cable.lineWidth = 17
    cable.stroke()

    let stand = rounded(NSRect(x: 543, y: 381, width: 64, height: 143), 15)
    gradient(stand, 0xD9DADD, 0xA8ACB2)
    let foot = rounded(NSRect(x: 488, y: 375, width: 174, height: 28), 14)
    gradient(foot, 0xF6F7F6, 0xCDD0D2)

    let display = rounded(NSRect(x: 307, y: 460, width: 542, height: 351), 42)
    NSGraphicsContext.saveGraphicsState()
    let displayShadow = NSShadow()
    displayShadow.shadowColor = color(0x755521, alpha: 0.26)
    displayShadow.shadowBlurRadius = 23
    displayShadow.shadowOffset = NSSize(width: 0, height: -16)
    displayShadow.set()
    color(0xD3D6D7).setFill()
    display.fill()
    gradient(display, 0xFCFDF9, 0xD3D6D7)
    NSGraphicsContext.restoreGraphicsState()
    color(0xFFFFFF, alpha: 0.8).setStroke()
    display.lineWidth = 3
    display.stroke()

    let screen = rounded(NSRect(x: 328, y: 497, width: 500, height: 293), 26)
    gradient(screen, 0x41474A, 0x242A2D)
    NSGraphicsContext.saveGraphicsState()
    screen.addClip()
    let glow = NSBezierPath(ovalIn: NSRect(x: 430, y: 420, width: 310, height: 310))
    gradient(glow, 0xFBE8A2, 0xE6AC45)
    let horizon = NSBezierPath()
    horizon.move(to: NSPoint(x: 328, y: 560))
    horizon.line(to: NSPoint(x: 828, y: 560))
    color(0x333A3D).setStroke()
    horizon.lineWidth = 24
    horizon.stroke()
    color(0x2A3134).setFill()
    NSRect(x: 328, y: 497, width: 500, height: 51).fill()
    NSGraphicsContext.restoreGraphicsState()

    let rearLip = rounded(NSRect(x: 247, y: 387, width: 419, height: 35), 12)
    gradient(rearLip, 0x7F878C, 0x4A5358)
    for x in [269, 610] {
        gradient(rounded(NSRect(x: x, y: 406, width: 34, height: 22), 8), 0xF7F7F2, 0xC0C4C7)
    }

    let base = polygon([
        NSPoint(x: 247, y: 396), NSPoint(x: 665, y: 396),
        NSPoint(x: 764, y: 235), NSPoint(x: 752, y: 210),
        NSPoint(x: 170, y: 210), NSPoint(x: 158, y: 235)
    ])
    NSGraphicsContext.saveGraphicsState()
    let baseShadow = NSShadow()
    baseShadow.shadowColor = color(0x77551D, alpha: 0.28)
    baseShadow.shadowBlurRadius = 25
    baseShadow.shadowOffset = NSSize(width: 0, height: -17)
    baseShadow.set()
    color(0xB6BDC2).setFill()
    base.fill()
    gradient(base, 0xF7F8F5, 0xB6BDC2)
    NSGraphicsContext.restoreGraphicsState()

    let deck = polygon([
        NSPoint(x: 247, y: 398), NSPoint(x: 665, y: 398),
        NSPoint(x: 764, y: 237), NSPoint(x: 158, y: 237)
    ])
    gradient(deck, 0xF5F6F2, 0xD9DEE0)
    color(0xFFFFFF, alpha: 0.9).setStroke()
    deck.lineWidth = 3
    deck.lineJoinStyle = .round
    deck.stroke()

    let keyboard = polygon([
        NSPoint(x: 271, y: 374), NSPoint(x: 640, y: 374),
        NSPoint(x: 678, y: 310), NSPoint(x: 235, y: 310)
    ])
    gradient(keyboard, 0x515A60, 0x353F45)
    for y in [330, 352] {
        let row = NSBezierPath()
        row.move(to: NSPoint(x: y == 352 ? 271 : 258, y: y))
        row.line(to: NSPoint(x: y == 352 ? 643 : 656, y: y))
        color(0x849097, alpha: 0.8).setStroke()
        row.lineWidth = 5
        row.stroke()
    }
    let trackpad = polygon([
        NSPoint(x: 391, y: 292), NSPoint(x: 524, y: 292),
        NSPoint(x: 539, y: 252), NSPoint(x: 375, y: 252)
    ])
    color(0xBFC6C9).setFill()
    trackpad.fill()
    color(0xFFFFFF, alpha: 0.7).setStroke()
    trackpad.lineWidth = 2
    trackpad.stroke()
    let notch = rounded(NSRect(x: 410, y: 223, width: 94, height: 8), 4)
    color(0x88949B).setFill()
    notch.fill()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
for size in sizes {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        try png(pixels: size * scale).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
try png(pixels: 1024).write(to: assets.appendingPathComponent("AppIcon.png"))
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { exit(process.terminationStatus) }
try FileManager.default.removeItem(at: iconset)
