import Foundation

enum ClaudeUpdaterPolicyError: LocalizedError {
    case incompatibleVersion
    case invalidConfiguration
    case managedPolicyConflict
    case restartRequired

    var errorDescription: String? {
        switch self {
        case .incompatibleVersion:
            "This Claude build has not been validated for safe profile copies. "
                + "Update Claude Profiles before opening this profile."
        case .invalidConfiguration:
            "This profile's Claude update policy is damaged. Its account data was not changed."
        case .managedPolicyConflict:
            "Your Mac's managed Claude policy may enable updates. Profile copies cannot "
                + "be launched safely."
        case .restartRequired:
            "This Claude copy needs one restart to apply update protection. Quit it with "
                + "⌘Q, then open the profile again. Its account data will be preserved."
        }
    }
}
