import Foundation

/// A field the couple filled in wrong, as a fact rather than a sentence.
///
/// Validation used to assign an English string straight into feature state.
/// That made the reducer a place copy lived, which is both untranslatable and
/// untestable in any language but one. The reducer now decides *what* is
/// wrong; the catalogue decides how to say it.
nonisolated enum FieldValidation: Equatable, Hashable, Sendable {
    case invalidEmail
    case shortPassword(minimum: Int)
    case missingName
}

/// The same, for the one form with rules of its own.
nonisolated enum DecisionValidation: Equatable, Hashable, Sendable {
    case missingTitle
    case titleTooLong(maximum: Int)
    case emptyChoice
    case choiceTooLong(maximum: Int)
    case duplicateChoices
}

/// A password shorter than this is refused before the network is touched.
nonisolated enum CredentialRules {
    static let minimumPasswordLength = 6
}
