import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1])

func drawIcon(size: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(size) / 1024)
    transform.concat()

    let tile = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 192, yRadius: 192)
    NSGradient(starting: NSColor(srgbRed: 0.09, green: 0.14, blue: 0.21, alpha: 1), ending: NSColor(srgbRed: 0.18, green: 0.23, blue: 0.32, alpha: 1))!.draw(in: tile, angle: 75)
    NSColor.white.withAlphaComponent(0.10).setStroke()
    tile.lineWidth = 2
    tile.stroke()

    NSColor.white.withAlphaComponent(0.25).setFill()
    for x in [156, 198, 240] {
        NSBezierPath(ovalIn: NSRect(x: x, y: 813, width: 16, height: 16)).fill()
    }
    NSColor.white.withAlphaComponent(0.11).setFill()
    NSBezierPath(roundedRect: NSRect(x: 154, y: 760, width: 716, height: 12), xRadius: 6, yRadius: 6).fill()
    let blue = NSColor(srgbRed: 0.42, green: 0.72, blue: 1, alpha: 1)
    blue.setFill()
    NSBezierPath(roundedRect: NSRect(x: 154, y: 760, width: 497, height: 12), xRadius: 6, yRadius: 6).fill()

    let center = CGPoint(x: 512, y: 456)
    let ring = NSBezierPath(ovalIn: NSRect(x: 302, y: 246, width: 420, height: 420))
    NSColor.white.withAlphaComponent(0.10).setStroke()
    ring.lineWidth = 25
    ring.stroke()
    blue.setStroke()
    let progress = NSBezierPath()
    progress.lineWidth = 25
    progress.lineCapStyle = .round
    progress.appendArc(withCenter: center, radius: 210, startAngle: 90, endAngle: -155, clockwise: true)
    progress.stroke()

    NSColor.white.withAlphaComponent(0.88).setStroke()
    let hand = NSBezierPath()
    hand.lineWidth = 23
    hand.lineCapStyle = .round
    hand.move(to: CGPoint(x: 512, y: 576))
    hand.line(to: center)
    hand.line(to: CGPoint(x: 594, y: 413))
    hand.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 1 ? "" : "@2x"
        let path = destination.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
        try drawIcon(size: points * scale).write(to: path)
    }
}
