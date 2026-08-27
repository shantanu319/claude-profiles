import SwiftUI

struct AddProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isSubmitting = false
    @FocusState private var nameIsFocused: Bool
    let onCreate: (String) async -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("New Claude Profile")
                    .font(.title2.weight(.semibold))
                Text("This creates a managed Claude app with separate Claude Desktop storage. "
                    + "You will sign in normally; no cookies or credentials are copied.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Profile name")
                    .font(.headline)
                TextField("Work, personal, client…", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameIsFocused)
                    .accessibilityLabel("Profile name")
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Before the first sign-in")
                        .font(.headline)
                    Text("Quit every other Claude app with ⌘Q; closing its windows is not enough. "
                        + "After signing in, verify the account before starting an agent.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            HStack {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isSubmitting)
                Button("Create & Open") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
        }
        .padding(24)
        .frame(width: 470)
        .onAppear { nameIsFocused = true }
        .interactiveDismissDisabled(isSubmitting)
    }

    private func create() {
        isSubmitting = true
        Task {
            if await onCreate(name) {
                dismiss()
            } else {
                isSubmitting = false
            }
        }
    }
}
