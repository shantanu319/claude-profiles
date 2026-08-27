import Foundation
import Security

enum ClaudeSignatureError: LocalizedError {
    case invalidSignature

    var errorDescription: String? {
        "Claude Desktop is not validly signed by Anthropic. Reinstall it from claude.com."
    }
}

struct ClaudeSignatureVerifier {
    private let requirementText = """
        anchor apple generic and identifier "com.anthropic.claudefordesktop" \
        and certificate leaf[subject.OU] = "Q6L2SF6YDW"
        """

    func verify(_ appURL: URL) throws {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(appURL as CFURL, [], &code) == errSecSuccess,
              let code else {
            throw ClaudeSignatureError.invalidSignature
        }

        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(
            requirementText as CFString,
            [],
            &requirement
        ) == errSecSuccess, let requirement else {
            throw ClaudeSignatureError.invalidSignature
        }

        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate)
        guard SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess else {
            throw ClaudeSignatureError.invalidSignature
        }
    }
}
