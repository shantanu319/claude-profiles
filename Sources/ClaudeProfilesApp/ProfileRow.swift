import SwiftUI

struct ProfileRow: View {
    let name: String
    let detail: String
    let isStandard: Bool
    let isRunning: Bool
    let isLaunching: Bool
    let needsRestart: Bool
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            status
            Button(action: onOpen) {
                if isLaunching {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 42)
                        .accessibilityHidden(true)
                } else {
                    Text(needsRestart ? "Fix" : (isRunning ? "Show" : "Open"))
                        .frame(minWidth: 42)
                }
            }
            .buttonStyle(.bordered)
            .disabled(isLaunching)
            .accessibilityLabel(isLaunching
                ? "Opening \(name)"
                : "\(needsRestart ? "Finish upgrading" : (isRunning ? "Show" : "Open")) \(name)")
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .disabled(isLaunching)
                .help("Delete \(name)")
                .accessibilityLabel("Delete \(name)")
            }
            menu
        }
        .padding(.vertical, 7)
    }

    private var avatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.accentColor.opacity(isStandard ? 0.12 : 0.2))
            if isStandard {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(.headline)
            }
        }
        .frame(width: 42, height: 42)
        .foregroundStyle(Color.accentColor)
        .accessibilityHidden(true)
    }

    private var status: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(needsRestart ? Color.orange
                    : (isRunning ? Color.green : Color.secondary.opacity(0.45)))
                .frame(width: 7, height: 7)
            Text(needsRestart ? "Restart needed" : (isRunning ? "Claude open" : "Not open"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 104, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(needsRestart
            ? "Restart needed to finish upgrading"
            : (isRunning ? "Claude open" : "Claude not open"))
    }

    private var menu: some View {
        Menu {
            Button("Show Profile Data in Finder", action: onReveal)
        } label: {
            Image(systemName: "ellipsis.circle")
                .accessibilityLabel("More actions for \(name)")
        }
        .menuStyle(.borderlessButton)
        .frame(width: 24)
    }
}
