import ClaudeProfilesCore
import Combine
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showAddProfile = false
    @State private var showHelp = false
    @State private var deleteCandidate: ClaudeProfile?
    private let statusTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ProfileHeaderView(
                canAdd: model.registryAvailable,
                onAdd: { showAddProfile = true },
                onHelp: { showHelp = true }
            )
            Divider()
            List {
                Section("Profiles") {
                    row(for: nil)
                    ForEach(model.profiles) { profile in
                        row(for: profile)
                    }
                }
            }
            .listStyle(.inset)
            Divider()
            Text("Profiles separate Claude Desktop storage, not your macOS identity. "
                + "Verify the account before starting agents.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
        .sheet(isPresented: $showAddProfile) {
            AddProfileView { name in
                await model.addAndOpen(named: name)
            }
        }
        .sheet(isPresented: $showHelp) {
            HelpLimitationsView()
        }
        .alert(item: $model.notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message))
        }
        .confirmationDialog(
            deleteCandidate.map { "Delete \($0.name)?" } ?? "Delete profile?",
            isPresented: deleteConfirmation,
            titleVisibility: .visible,
            presenting: deleteCandidate
        ) { profile in
            Button("Move to Trash", role: .destructive) {
                model.delete(profile)
                deleteCandidate = nil
            }
            Button("Cancel", role: .cancel) { deleteCandidate = nil }
        } message: { profile in
            if model.isRunning(profile) {
                Text("Quit this Claude app with ⌘Q before deleting it; closing its windows is not enough.")
            } else {
                Text("The managed Claude app and its local Desktop data will move to Trash. "
                    + "This does not sign the server account out.")
            }
        }
        .onReceive(statusTimer) { _ in model.refreshStatus() }
    }

    private func row(for profile: ClaudeProfile?) -> some View {
        ProfileRow(
            name: profile?.name ?? "Existing Claude",
            detail: profile == nil
                ? "Installed Claude app and existing Desktop storage"
                : "Managed Claude app • separate Desktop storage",
            isStandard: profile == nil,
            isRunning: model.isRunning(profile),
            isLaunching: model.isLaunching(profile),
            onOpen: { Task { await model.open(profile) } },
            onReveal: { model.reveal(profile) },
            onDelete: profile.map { value in { deleteCandidate = value } }
        )
    }

    private var deleteConfirmation: Binding<Bool> {
        Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        )
    }
}

private struct HelpLimitationsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Help & Limitations")
                    .font(.title2.weight(.semibold))
                Text("Claude Profiles is a convenience tool for using more than one account on one Mac.")
                    .foregroundStyle(.secondary)
            }

            helpSection(
                title: "How profiles work",
                symbol: "square.stack.3d.up",
                text: "Each profile gets a managed copy of Claude and its own Claude Desktop storage. "
                    + "Cookies and credentials are not copied between profiles."
            )
            helpSection(
                title: "First sign-in",
                symbol: "person.badge.key",
                text: "Quit every other Claude app with ⌘Q, then open and sign in to this profile. "
                    + "Closing windows is not enough. Verify the account before starting an agent."
            )
            helpSection(
                title: "What can remain shared",
                symbol: "exclamationmark.shield",
                text: "Profiles are not a hard security boundary. macOS permissions, Keychain access, "
                    + "global shortcuts, notifications, URL links, and other system integrations can remain shared."
            )

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func helpSection(title: String, symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
