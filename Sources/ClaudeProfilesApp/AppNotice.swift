import Foundation

struct AppNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    static func error(_ error: Error) -> AppNotice {
        AppNotice(
            title: "Claude Profiles",
            message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        )
    }

    static func setup(name: String) -> AppNotice {
        AppNotice(
            title: "Set up \(name)",
            message: "Before signing in, quit every other Claude app with ⌘Q. macOS has one global "
                + "claude:// OAuth callback, so another open Claude app can receive this profile's "
                + "sign-in. Then sign in inside \(name)'s Claude window and verify the account before "
                + "starting an agent."
        )
    }

    static func accountAlreadyRunning(profileName: String, runningName: String) -> AppNotice {
        AppNotice(
            title: "Account already open",
            message: "The saved Desktop account mapping for \(profileName) matches \(runningName). "
                + "Quit every Claude app with ⌘Q, then open \(profileName) by itself and verify "
                + "the account. If it is wrong, sign out and sign back in to the intended account "
                + "while every other Claude app remains quit. If OAuth opens the wrong Claude app, "
                + "quit them all and retry from \(profileName)."
        )
    }

    static func exclusiveSignInRequired(profileName: String? = nil) -> AppNotice {
        if let profileName {
            return AppNotice(
                title: "Quit other Claude apps first",
                message: "\(profileName) has not completed its first sign-in. Quit every other "
                    + "Claude app with ⌘Q, then open this profile again. macOS has one global "
                    + "claude:// OAuth callback, so another app can receive and save its sign-in."
            )
        }
        return AppNotice(
            title: "Quit Claude before creating a profile",
            message: "Quit every Claude app with ⌘Q, then create the profile again. macOS has one "
                + "global claude:// OAuth callback, so another app can receive and save the new "
                + "profile's sign-in. No profile was created."
        )
    }

    static var launchInProgress: AppNotice {
        AppNotice(
            title: "Claude is still opening",
            message: "Wait for the Claude app that is opening, then try again."
        )
    }

    static func legacyIndexesBackedUp(profileName: String) -> AppNotice {
        AppNotice(
            title: "Old session indexes backed up",
            message: "Before isolating \(profileName), Claude Profiles moved its previously shared "
                + "local session indexes into Legacy Shared Session Indexes inside the profile data. "
                + "Nothing was deleted, and global transcripts were left untouched. Use Show "
                + "Profile Data to view the recoverable backup."
        )
    }
}
