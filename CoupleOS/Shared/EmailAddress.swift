import Foundation

/// Shape check for the sign-in and sign-up forms.
///
/// This is deliberately permissive: the only authority on whether an address
/// exists is Firebase, which answers with `.invalidEmail`. The goal here is to
/// catch an obvious typo before spending a network round trip on it.
nonisolated enum EmailAddress {
    static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isWellFormed(_ email: String) -> Bool {
        let parts = normalized(email).split(separator: "@")
        guard parts.count == 2, let domain = parts.last else { return false }
        guard let lastDot = domain.lastIndex(of: ".") else { return false }
        return domain[domain.index(after: lastDot)...].count >= 2
    }
}
