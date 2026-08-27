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
                Text("This creates an empty local profile. You will sign in normally in Claude; "
                    + "no cookies or credentials are copied.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Profile name")
                    .font(.headline)
                TextField("Work, personal, client…", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameIsFocused)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create & Open") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
        }
        .padding(24)
        .frame(width: 430)
        .onAppear { nameIsFocused = true }
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
