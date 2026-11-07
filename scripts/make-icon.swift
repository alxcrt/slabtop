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

func png(pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    context.setShouldAntialias(true)

    let tile = rounded(NSRect(x: 64, y: 64, width: 896, height: 896), 202)
    NSGraphicsContext.saveGraphicsState()
    let tileShadow = NSShadow()
    tileShadow.shadowColor = color(0x092C72, alpha: 0.25)
    tileShadow.shadowBlurRadius = 24
    tileShadow.shadowOffset = NSSize(width: 0, height: -12)
    tileShadow.set()
    color(0x1663D4).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    gradient(tile, 0x16BFE0, 0x244BC8)

    color(0xFFFFFF, alpha: 0.3).setStroke()
    tile.lineWidth = 2
    tile.stroke()

    let frontLeft = NSPoint(x: 318, y: 245)
    let frontRight = NSPoint(x: 871, y: 416)
    let backLeft = NSPoint(x: 184, y: 654)
    let backRight = NSPoint(x: 683, y: 810)

    func point(_ x: CGFloat, _ y: CGFloat, drop: CGFloat = 0) -> NSPoint {
        let u = x / 760
        let v = y / 550
        let left = NSPoint(x: frontLeft.x + (backLeft.x - frontLeft.x) * v, y: frontLeft.y + (backLeft.y - frontLeft.y) * v)
        let right = NSPoint(x: frontRight.x + (backRight.x - frontRight.x) * v, y: frontRight.y + (backRight.y - frontRight.y) * v)
        return NSPoint(x: left.x + (right.x - left.x) * u, y: left.y + (right.y - left.y) * u - drop)
    }

    func surface(_ rect: NSRect, radius: CGFloat, drop: CGFloat = 0) -> NSBezierPath {
        let p = NSBezierPath()
        let r = min(radius, min(rect.width, rect.height) / 2)
        let c = r * 0.55228475
        let x = rect.minX
        let y = rect.minY
        let w = rect.width
        let h = rect.height
        p.move(to: point(x + r, y, drop: drop))
        p.line(to: point(x + w - r, y, drop: drop))
        p.curve(to: point(x + w, y + r, drop: drop), controlPoint1: point(x + w - r + c, y, drop: drop), controlPoint2: point(x + w, y + r - c, drop: drop))
        p.line(to: point(x + w, y + h - r, drop: drop))
        p.curve(to: point(x + w - r, y + h, drop: drop), controlPoint1: point(x + w, y + h - r + c, drop: drop), controlPoint2: point(x + w - r + c, y + h, drop: drop))
        p.line(to: point(x + r, y + h, drop: drop))
        p.curve(to: point(x, y + h - r, drop: drop), controlPoint1: point(x + r - c, y + h, drop: drop), controlPoint2: point(x, y + h - r + c, drop: drop))
        p.line(to: point(x, y + r, drop: drop))
        p.curve(to: point(x + r, y, drop: drop), controlPoint1: point(x, y + r - c, drop: drop), controlPoint2: point(x + r - c, y, drop: drop))
        p.close()
        return p
    }

    let bodyRect = NSRect(x: 0, y: 0, width: 760, height: 550)
    let bottom = surface(bodyRect, radius: 32, drop: 27)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x092B77, alpha: 0.65)
    shadow.shadowBlurRadius = 40
    shadow.shadowOffset = NSSize(width: 1, height: -26)
    shadow.set()
    color(0x637787).setFill()
    bottom.fill()
    NSGraphicsContext.restoreGraphicsState()
    gradient(bottom, 0xAAB9C5, 0x667D91)

    let bevel = surface(bodyRect, radius: 32, drop: 11)
    gradient(bevel, 0xD8E1E9, 0x94A7B7)
    let deck = surface(bodyRect, radius: 32)
    gradient(deck, 0xF1F6FA, 0xB8CDD9)
    color(0xFFFFFF, alpha: 0.85).setStroke()
    deck.lineWidth = 2.5
    deck.stroke()

    NSGraphicsContext.saveGraphicsState()
    deck.addClip()
    let sheen = NSBezierPath()
    sheen.move(to: point(0, 550))
    sheen.line(to: point(760, 550))
    sheen.line(to: point(760, 330))
    sheen.line(to: point(0, 110))
    sheen.close()
    NSGradient(starting: color(0xFFFFFF, alpha: 0), ending: color(0xFFFFFF, alpha: 0.3))!.draw(in: sheen, angle: 110)
    NSGraphicsContext.restoreGraphicsState()

    let hinge = surface(NSRect(x: 58, y: 516, width: 644, height: 14), radius: 6)
    gradient(hinge, 0x708696, 0x374E61)
    for x: CGFloat in [40, 698] {
        let cap = surface(NSRect(x: x, y: 510, width: 22, height: 24), radius: 7)
        gradient(cap, 0xFFFFFF, 0xB1C2CE)
    }

    let keyboard = surface(NSRect(x: 74, y: 242, width: 612, height: 245), radius: 17)
    color(0x708696).setFill()
    keyboard.fill()
    let keyboardInset = surface(NSRect(x: 77, y: 245, width: 606, height: 239), radius: 14)
    gradient(keyboardInset, 0x203C50, 0x0C263D)
    color(0xFFFFFF, alpha: 0.45).setStroke()
    keyboard.lineWidth = 1.8
    keyboard.stroke()

    let rows: [[CGFloat]] = [
        [1.35, 1.1, 1.1, 1.1, 5.5, 1.1, 1.1, 1.1, 1.35],
        [1.7, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.0],
        [1.45, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.25],
        [1.05, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.65],
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.7],
        [1.45, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.25]
    ]
    for (row, widths) in rows.enumerated() {
        let y = CGFloat(254 + row * 37)
        let height: CGFloat = row == 5 ? 28 : 30
        let gap: CGFloat = 6
        let unit = (586 - CGFloat(widths.count - 1) * gap) / widths.reduce(0, +)
        var x: CGFloat = 87
        for width in widths {
            let keyWidth = width * unit
            let key = surface(NSRect(x: x, y: y, width: keyWidth, height: height), radius: 5)
            gradient(key, row == 5 ? 0x38576B : 0x34536A, 0x17354C)
            let edge = NSBezierPath()
            edge.move(to: point(x + 5, y + height - 2))
            edge.line(to: point(x + keyWidth - 5, y + height - 2))
            color(0x86A4B7, alpha: 0.45).setStroke()
            edge.lineWidth = 1.4
            edge.stroke()
            x += keyWidth + gap
        }
    }

    for x: CGFloat in [38, 708] {
        for row in 0..<28 {
            let grille = surface(NSRect(x: x, y: CGFloat(255 + row * 8), width: 14, height: 2.4), radius: 1.2)
            color(0x728F9F, alpha: 0.55).setFill()
            grille.fill()
        }
    }

    let trackpad = surface(NSRect(x: 235, y: 44, width: 290, height: 167), radius: 15)
    gradient(trackpad, 0xBCD0DC, 0xC8D9E3)
    color(0x7695A8, alpha: 0.9).setStroke()
    trackpad.lineWidth = 2
    trackpad.stroke()
    let trackpadHighlight = surface(NSRect(x: 238, y: 47, width: 284, height: 161), radius: 13)
    color(0xFFFFFF, alpha: 0.36).setStroke()
    trackpadHighlight.lineWidth = 1.3
    trackpadHighlight.stroke()

    let notch = surface(NSRect(x: 324, y: -1, width: 112, height: 6), radius: 3, drop: 5)
    color(0x55768D, alpha: 0.65).setFill()
    notch.fill()
    let frontHighlight = NSBezierPath()
    frontHighlight.move(to: point(34, 0, drop: 5))
    frontHighlight.line(to: point(309, 0, drop: 5))
    frontHighlight.move(to: point(451, 0, drop: 5))
    frontHighlight.line(to: point(726, 0, drop: 5))
    color(0xFFFFFF, alpha: 0.6).setStroke()
    frontHighlight.lineWidth = 1.5
    frontHighlight.stroke()

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
