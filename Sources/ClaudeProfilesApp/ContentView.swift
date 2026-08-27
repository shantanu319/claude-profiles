import ClaudeProfilesCore
import Combine
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showAddProfile = false
    @State private var showHelp = false
    @State private var renameCandidate: ClaudeProfile?
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
            Text("Before a profile's first sign-in, quit every other Claude app. "
                + "OAuth links are global on macOS.")
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
        .sheet(item: $renameCandidate) { profile in
            RenameProfileView(profile: profile) { name in
                model.rename(profile, to: name)
            }
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
            if model.isRunning(profile) {
                Button("Done", role: .cancel) { deleteCandidate = nil }
            } else {
                Button("Move Profile to Trash", role: .destructive) {
                    model.delete(profile)
                    deleteCandidate = nil
                }
                Button("Cancel", role: .cancel) { deleteCandidate = nil }
            }
        } message: { profile in
            if model.isRunning(profile) {
                Text("Quit this Claude app with ⌘Q before deleting it; closing its windows is not enough.")
            } else {
                Text("The cloned app, Desktop data, Claude Code history, plugins, and any legacy "
                    + "session-index backup will move to Trash. Your Claude account will not be "
                    + "deleted or signed out on other devices.")
            }
        }
        .onReceive(statusTimer) { _ in model.refreshStatus() }
    }

    private func row(for profile: ClaudeProfile?) -> some View {
        ProfileRow(
            name: profile?.name ?? "Existing Claude",
            detail: profile == nil
                ? "Installed Claude app and existing Desktop storage"
                : "Managed Claude app • separate Desktop & Code storage",
            isStandard: profile == nil,
            isRunning: model.isRunning(profile),
            isLaunching: model.isLaunching(profile),
            needsRestart: model.needsRestart(profile),
            onOpen: { Task { await model.open(profile) } },
            onReveal: { model.reveal(profile) },
            onRename: profile.map { value in { renameCandidate = value } },
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

private struct RenameProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var errorMessage: String?
    @FocusState private var nameIsFocused: Bool
    let onRename: (String) -> String?

    init(profile: ClaudeProfile, onRename: @escaping (String) -> String?) {
        self.onRename = onRename
        _name = State(initialValue: profile.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Rename Claude Profile")
                .font(.title2.weight(.semibold))
            TextField("Profile name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameIsFocused)
                .accessibilityLabel("Profile name")
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Rename") {
                    errorMessage = onRename(name)
                    if errorMessage == nil { dismiss() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear { nameIsFocused = true }
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
                text: "Each profile gets a managed copy of Claude and its own Claude Desktop and "
                    + "Claude Code storage. Cookies and credentials are not copied between profiles."
            )
            helpSection(
                title: "First sign-in",
                symbol: "person.badge.key",
                text: "Quit every other Claude app with ⌘Q, then open and sign in to this profile. "
                    + "Closing windows is not enough: macOS has one global claude:// OAuth callback, "
                    + "so an open Claude app can receive the sign-in intended for another profile."
            )
            helpSection(
                title: "What can remain shared",
                symbol: "exclamationmark.shield",
                text: "Profiles are not a hard security boundary. macOS permissions, Keychain access, "
                    + "global shortcuts, notifications, URL links, and other system integrations can remain shared. "
                    + "Copies also look identical in the Dock, so verify the account inside each window."
            )
            helpSection(
                title: "Safe updates",
                symbol: "arrow.triangle.2.circlepath",
                text: "Profile copies cannot update themselves. The installed Claude app remains canonical, "
                    + "and a new build is blocked until Claude Profiles has validated it."
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
