import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: make-icon.swift OUTPUT.png\n", stderr)
    exit(2)
}

let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()

let canvas = NSRect(x: 32, y: 32, width: 960, height: 960)
let background = NSBezierPath(roundedRect: canvas, xRadius: 210, yRadius: 210)
NSGradient(
    starting: NSColor(calibratedRed: 0.19, green: 0.16, blue: 0.43, alpha: 1),
    ending: NSColor(calibratedRed: 0.11, green: 0.55, blue: 0.59, alpha: 1)
)!.draw(in: background, angle: -42)

func drawGlow(center: NSPoint, radius: CGFloat) {
    NSColor.white.withAlphaComponent(0.08).setFill()
    NSBezierPath(ovalIn: NSRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    )).fill()
}

drawGlow(center: NSPoint(x: 820, y: 810), radius: 230)
drawGlow(center: NSPoint(x: 160, y: 190), radius: 180)

func drawCard(_ rect: NSRect, opacity: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 34
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()

    let card = NSBezierPath(roundedRect: rect, xRadius: 64, yRadius: 64)
    NSColor(calibratedWhite: 0.98, alpha: opacity).setFill()
    card.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedWhite: 0.12, alpha: 0.16).setStroke()
    card.lineWidth = 5
    card.stroke()

    let avatarSize = rect.height * 0.23
    let avatar = NSRect(
        x: rect.minX + rect.width * 0.11,
        y: rect.maxY - rect.height * 0.18 - avatarSize,
        width: avatarSize,
        height: avatarSize
    )
    NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.55, alpha: 0.85).setFill()
    NSBezierPath(ovalIn: avatar).fill()

    NSColor(calibratedWhite: 0.18, alpha: 0.24).setFill()
    let lineX = avatar.maxX + rect.width * 0.08
    let lineWidth = rect.maxX - lineX - rect.width * 0.1
    for offset in [CGFloat(0), -72, -144] {
        let line = NSRect(x: lineX, y: avatar.midY + offset, width: lineWidth, height: 24)
        NSBezierPath(roundedRect: line, xRadius: 12, yRadius: 12).fill()
    }
}

drawCard(NSRect(x: 168, y: 312, width: 540, height: 430), opacity: 0.78)
drawCard(NSRect(x: 320, y: 210, width: 540, height: 430), opacity: 0.96)
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("could not render icon\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
