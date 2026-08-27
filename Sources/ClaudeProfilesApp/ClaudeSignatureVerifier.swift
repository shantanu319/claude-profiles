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
        _ = try validatedCode(at: appURL)
    }

    func identity(of appURL: URL) throws -> Data {
        let code = try validatedCode(at: appURL)
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information
        ) == errSecSuccess,
        let dictionary = information as? [String: Any],
        let identity = dictionary[kSecCodeInfoUnique as String] as? Data else {
            throw ClaudeSignatureError.invalidSignature
        }
        return identity
    }

    private func validatedCode(at appURL: URL) throws -> SecStaticCode {
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

        let flags = SecCSFlags(
            rawValue: kSecCSCheckAllArchitectures
                | kSecCSCheckNestedCode
                | kSecCSStrictValidate
        )
        guard SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess else {
            throw ClaudeSignatureError.invalidSignature
        }
        return code
    }
}
