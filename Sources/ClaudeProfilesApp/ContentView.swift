import ClaudeProfilesCore
import Combine
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showAddProfile = false
    @State private var deleteCandidate: ClaudeProfile?
    private let statusTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ProfileHeaderView(canAdd: model.registryAvailable) {
                showAddProfile = true
            }
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
            Text("Profile sign-ins and local agent data are separate. macOS permissions, "
                + "global shortcuts, and some system integrations remain shared.")
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
        } message: { _ in
            Text("Local browser and agent data will move to Trash. This does not revoke the "
                + "server session, so sign out in Claude first if you no longer want it active.")
        }
        .onReceive(statusTimer) { _ in model.refreshStatus() }
    }

    private func row(for profile: ClaudeProfile?) -> some View {
        ProfileRow(
            name: profile?.name ?? "Existing Claude",
            detail: profile == nil ? "Your current Claude Desktop profile" : "Separate sign-in and local data",
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
