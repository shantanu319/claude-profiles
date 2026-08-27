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
            message: "Sign in inside the new Claude window, then verify the account name before "
                + "starting an agent. If a sign-in link reaches the wrong window, quit the other "
                + "Claude windows during this one-time setup."
        )
    }
}
