import SwiftUI

struct ProfileHeaderView: View {
    let canAdd: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 30))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text("Claude Profiles")
                    .font(.title2.weight(.semibold))
                Text("Run separate Claude Desktop accounts side by side.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onAdd) {
                Label("New Profile", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAdd)
        }
        .padding(18)
    }
}
