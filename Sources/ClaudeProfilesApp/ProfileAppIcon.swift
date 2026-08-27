import AppKit
import ClaudeProfilesCore

enum ProfileAppIconError: LocalizedError {
    case couldNotApply

    var errorDescription: String? {
        "Could not apply the profile's Dock icon."
    }
}

@MainActor
struct ProfileAppIcon {
    private let colors: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemTeal, .systemBlue, .systemPurple, .systemPink,
    ]

    func apply(to appURL: URL, profile: ClaudeProfile, sourceAppURL: URL) throws {
        let sourceIcon = NSWorkspace.shared.icon(forFile: sourceAppURL.path)
        guard NSWorkspace.shared.setIcon(
            badgedIcon(sourceIcon, profile: profile),
            forFile: appURL.path,
            options: []
        ) else {
            throw ProfileAppIconError.couldNotApply
        }
    }

    private func badgedIcon(_ source: NSImage, profile: ClaudeProfile) -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)
        image.lockFocus()
        source.draw(in: NSRect(origin: .zero, size: size))

        let badgeRect = NSRect(x: 326, y: 26, width: 154, height: 154)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = .black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 16
        shadow.shadowOffset = NSSize(width: 0, height: -5)
        shadow.set()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: badgeRect.insetBy(dx: -7, dy: -7)).fill()
        NSGraphicsContext.restoreGraphicsState()

        color(for: profile).setFill()
        NSBezierPath(ovalIn: badgeRect).fill()
        let initial = String(profile.name.prefix(1)).uppercased() as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 82, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = initial.size(withAttributes: attributes)
        initial.draw(
            at: NSPoint(x: badgeRect.midX - textSize.width / 2,
                        y: badgeRect.midY - textSize.height / 2 + 5),
            withAttributes: attributes
        )
        image.unlockFocus()
        return image
    }

    private func color(for profile: ClaudeProfile) -> NSColor {
        let prefix = profile.id.uuidString.prefix(2)
        let value = Int(prefix, radix: 16) ?? 0
        return colors[value % colors.count]
    }
}
