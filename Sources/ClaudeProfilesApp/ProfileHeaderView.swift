import SwiftUI

struct ProfileHeaderView: View {
    let canAdd: Bool
    let onAdd: () -> Void
    let onHelp: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 30))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Claude Profiles")
                    .font(.title2.weight(.semibold))
                Text("A managed Claude app and separate Desktop storage for each account.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onHelp) {
                Label("Help", systemImage: "questionmark.circle")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Help and limitations")
            Button(action: onAdd) {
                Label("New Profile", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAdd)
        }
        .padding(18)
    }
}
