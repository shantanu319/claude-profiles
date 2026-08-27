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
            message: "Sign in inside this profile's Claude window, then verify the account before "
                + "starting an agent. If a sign-in link reaches another Claude app, quit every "
                + "Claude app with ⌘Q and restart this one-time sign-in."
        )
    }
}
