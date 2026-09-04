import Foundation

/// Every word the app says, as one value.
///
/// A pure Swift catalogue rather than `.lproj` bundles, for three reasons the
/// app already depends on:
///
/// - **The language changes without relaunching.** Bundle-based lookup answers
///   for whatever language the process started in; switching it at runtime
///   means swapping `Bundle` under `Foundation`'s feet. Here the language is
///   just a value in the environment, so a change redraws the screen.
/// - **Nothing can be missing.** Each nested type has no default values, so a
///   string added to one language and forgotten in the other does not compile.
///   A `.strings` key typo is found by a user; this one is found by the build.
/// - **It is testable.** `Strings.english` is a value a test can hold, with no
///   bundle, no process language and no `Locale` involved.
///
/// Copy that depends on the partner takes their first name as `String?` rather
/// than a pre-resolved string. The fallback wording differs by language and by
/// position in the sentence — "sua pessoa" is not capitalised mid-sentence the
/// way "Your person" is — so the catalogue is the only place that can choose
/// it correctly.
nonisolated struct Strings: Sendable {
    let language: AppLanguage
    let brand: Brand
    let common: Common
    let languageMenu: LanguageMenu
    let welcome: Welcome
    let invite: Invite
    let auth: Auth
    let session: Session
    let identity: Identity
    let couple: Couple
    let home: Home
    let world: World
    let today: Today
    let market: Market
    let chores: Chores
    let decisions: Decisions
    let errors: Errors

    static func of(_ language: AppLanguage) -> Strings {
        switch language {
        case .english: .english
        case .portugueseBrazil: .portugueseBrazil
        }
    }
}

// MARK: - Shared

extension Strings {
    nonisolated struct Brand: Sendable {
        /// The product's name, which is the same in every language.
        let wordmark: String
        let accessibleName: String
    }

    nonisolated struct Common: Sendable {
        let tryAgain: String
        let continueAction: String
        let back: String
        let close: String
        let remove: String
        let clear: String
        let working: String
        let signOut: String
        let errorPrefix: String
        let successPrefix: String
        let or: String
        /// The partner in subject position, or the neutral stand-in.
        let person: @Sendable (String?) -> String
        /// The same, mid-sentence, where the stand-in is not capitalised.
        let personInline: @Sendable (String?) -> String
    }

    nonisolated struct LanguageMenu: Sendable {
        let title: String
        let automatic: @Sendable (AppLanguage) -> String
        let accessibilityLabel: @Sendable (AppLanguage) -> String
    }
}

// MARK: - Before the couple

extension Strings {
    nonisolated struct Welcome: Sendable {
        let openingYourWorld: String
        let heroTitle: String
        let heroSubtitle: String
        let createWorld: String
        let haveAccount: String
        let haveInvite: String
    }

    nonisolated struct Invite: Sendable {
        let manualTitle: String
        let manualSubtitle: String
        let linkLabel: String
        let linkPlaceholder: String
        let manualPrivacy: String
        let invitationTitle: String
        let invitationSubtitle: String
        let joinTheirWorld: String
        let invitationPrivacy: String
        let choiceTitle: String
        let choiceSubtitle: String
        let createAccount: String
        let signIn: String
    }

    nonisolated struct Auth: Sendable {
        let loginTitle: String
        let loginSubtitle: String
        let emailLabel: String
        let emailPlaceholder: String
        let passwordLabel: String
        let passwordPlaceholder: String
        let showPassword: String
        let hidePassword: String
        let forgotPassword: String
        let resetLinkSent: String
        let signUpTitle: String
        let signUpSubtitle: String
        let createAccount: String
        let signUpPrivacy: String
        let invalidEmail: String
        let shortPassword: @Sendable (Int) -> String
        let missingName: String
    }

    nonisolated struct Session: Sendable {
        let openingYourWorld: String
        let worldStillHere: String
        let finishingYourSpace: String
        let accountSafe: String
    }

    nonisolated struct Identity: Sendable {
        let title: String
        let subtitle: String
        let nameLabel: String
        let namePlaceholder: String
        let privacy: String
        let recoveryTitle: String
        let recoverySubtitle: String
        let recoveryPrivacy: String
    }

    nonisolated struct Couple: Sendable {
        let preparingTitle: String
        let preparingSubtitle: String
        let waitingTitle: String
        let waitingSubtitle: String
        let shareInvite: String
        let shareSubject: String
        let shareMessage: String
        let copyLink: String
        let linkCopied: String
        let sharedTitle: String
        let sharedSubtitle: String
        let worldStillHere: String
        let joiningTitle: String
        let joiningSubtitle: String
        let joinedSubtitle: String
        let couldNotJoinTitle: String
    }
}

// MARK: - The couple's world

extension Strings {
    nonisolated struct Home: Sendable {
        let privateSpace: String
        let signOut: String
        let partnerLoading: String
        let retryPartner: String
        let welcomeBack: @Sendable (String) -> String
        let openingSharedWorld: String
        let worldStillHere: String
        let bothNames: @Sendable (String, String) -> String
        let nowSection: String
        let ourWorldSection: String
        let quiet: String
        let signalAccessibility: @Sendable (_ eyebrow: String, _ title: String, _ detail: String) -> String
        let areaAccessibility: @Sendable (_ title: String, _ status: String) -> String
        let urgencyEyebrow: @Sendable (HomeSignal.Urgency) -> String
        let moduleTitle: @Sendable (CoupleModule) -> String
    }

    nonisolated struct World: Sendable {
        /// What the orb reads as to VoiceOver, before and after there are two.
        let soloDescription: String
        let description: @Sendable (SharedWorldView.Activity) -> String
        /// The line under the orb when the loudest signal has no voice of its own.
        let urgencyCaption: @Sendable (HomeSignal.Urgency) -> String
        let bothHere: String
    }

    nonisolated struct Today: Sendable {
        let eyebrow: String
        let saving: String
        let leaveThisHere: String
        let reconnect: String
        let backToOurWorld: String
        let waitingTitle: String
        let waitingDetail: String
        let revealTitle: String
        let you: String
        let yourPerson: String
        let statusReconnect: String
        let statusOpenForBoth: String
        let statusWaitingForYou: String
        let statusWaitingForPartner: @Sendable (String?) -> String
        let statusRevealed: String
        let statusOpening: String
        let detailAvailable: String
        let detailWaitingForMe: @Sendable (String?) -> String
        let detailWaitingForPartner: @Sendable (String?) -> String
        let detailRevealAvailable: String
        /// The daily question, said in this language.
        let promptEveryday: String
        let optionsEveryday: [String]
    }

    nonisolated struct Market: Sendable {
        let title: String
        let openingList: String
        let listStillHere: String
        let runEyebrowIdle: String
        let runEyebrowMine: String
        let runEyebrowTheirs: String
        let runHeadlineIdle: @Sendable (String?) -> String
        let runHeadlineAllGathered: String
        let runHeadlineRemaining: @Sendable (Int) -> String
        let runHeadlineTheirs: @Sendable (String?) -> String
        let finishRun: String
        let startRun: String
        let composerPlaceholderIdle: String
        let composerPlaceholderShopping: String
        let addToList: String
        let askDirectly: @Sendable (String?) -> String
        let toBringSection: String
        let basketSection: String
        let clearBasket: String
        let dismissMessageHint: String
        let emptyTitle: String
        let emptyDetail: String
        let waitingAMonthOrMore: String
        let waitingDays: @Sendable (Int) -> String
        let youAskedForThis: String
        let personAskedForThis: @Sendable (String?) -> String
        let addedByPerson: @Sendable (String?) -> String
        let stillToBring: String
        let inTheBasket: String
        let signalPartnerRunTitle: @Sendable (String?) -> String
        let signalRunDetailEmpty: String
        let signalRunDetailPending: @Sendable (Int) -> String
        let captionPartnerRun: @Sendable (String?) -> String
        let signalMyRunTitle: String
        let signalMyRunDetailEmpty: String
        let signalMyRunDetailPending: @Sendable (Int) -> String
        let captionMyRun: @Sendable (String?) -> String
        let signalAsksTitle: @Sendable (String?, Int) -> String
        let signalAsksDetailMany: @Sendable (_ name: String, _ others: Int) -> String
        let signalAsksDetailOne: @Sendable (String?) -> String
        let captionAsks: @Sendable (String?) -> String
        let statusReconnect: String
        let statusPartnerThere: @Sendable (String?) -> String
        let statusYouThere: String
        let statusNothingToBring: String
        let statusNothingCurrent: String
        let statusToBring: @Sendable (Int) -> String
    }

    nonisolated struct Chores: Sendable {
        let title: String
        let openingChores: String
        let listStillHere: String
        let composerPlaceholder: String
        let addChore: String
        let yourTurnSection: String
        let withPartnerSection: @Sendable (String?) -> String
        let comingUpSection: String
        let startsWithYou: String
        let startsWithPartner: @Sendable (String?) -> String
        let emptyTitle: String
        let emptyDetail: String
        let markDoneHint: String
        let cadenceOnce: String
        let cadenceDaily: String
        let cadenceWeekly: String
        let cadenceEveryTwoWeeks: String
        let cadenceMonthly: String
        let cadenceEveryDays: @Sendable (Int) -> String
        let rotationAlternates: String
        let rotationFixed: String
        let rotationAnyone: String
        let turnEither: String
        let turnYours: String
        let turnPartner: @Sendable (String?) -> String
        let standingLate: @Sendable (Int) -> String
        let standingToday: String
        let standingUpcoming: @Sendable (Int) -> String
        let standingDone: String
        let rowSubtitle: @Sendable (_ turn: String, _ standing: String) -> String
        let signalMineTitleMany: @Sendable (Int) -> String
        let detailLate: @Sendable (Int) -> String
        let detailOthersToday: @Sendable (_ title: String, _ others: Int) -> String
        let detailYourTurnToday: String
        let captionOverdue: String
        let signalTheirsTitleMany: @Sendable (_ count: Int, _ partner: String?) -> String
        let signalTheirsDetail: @Sendable (String?) -> String
        let signalSettledDetail: @Sendable (String?) -> String
        let statusReconnect: String
        let statusForYou: @Sendable (Int) -> String
        let statusWithPartner: @Sendable (_ count: Int, _ partner: String?) -> String
        let statusNothingSetUp: String
        let statusAllCaughtUp: String
    }

    nonisolated struct Decisions: Sendable {
        let title: String
        let newDecision: String
        let newDecisionHint: String
        let needsYouSection: String
        let waitingSection: String
        let recentSection: String
        let needsYouDetail: @Sendable (String?) -> String
        let waitingRowDetail: @Sendable (String?) -> String
        let recentDetail: @Sendable (String?) -> String
        let reconnect: String
        let rowHint: String
        let createEyebrow: String
        let createTitle: String
        let createSubtitle: String
        let decisionLabel: String
        let decisionPlaceholder: String
        let choicesLabel: String
        let choicePlaceholder: String
        let addChoice: String
        let removeChoice: @Sendable (Int) -> String
        let submit: String
        let missingTitle: String
        let titleTooLong: @Sendable (Int) -> String
        let emptyChoice: String
        let choiceTooLong: @Sendable (Int) -> String
        let duplicateChoices: String
        let eyebrowNeedsYou: String
        let eyebrowWaiting: String
        let eyebrowDecided: String
        let eyebrowDecision: String
        let chooseThis: String
        let leftWithPartnerTitle: String
        let leftWithPartnerDetail: String
        let unavailableTitle: String
        let unavailableDetail: String
        let decidedTogether: String
        let resolvedNote: String
        let signalNeedsDetail: @Sendable (String?) -> String
        let signalWaitingTitleMany: @Sendable (_ count: Int, _ partner: String?) -> String
        let signalWaitingDetailOne: @Sendable (String?) -> String
        let signalWaitingDetailMany: String
        let signalSettledDetail: String
        let statusReconnect: String
        let statusForYou: @Sendable (Int) -> String
        let statusWithPartner: @Sendable (_ count: Int, _ partner: String?) -> String
        let statusNothingOpen: String
        let statusAllSettled: String
    }
}

// MARK: - Failures

extension Strings {
    /// Every failure the couple can be shown, in one place per language.
    ///
    /// The domain used to answer this itself, with an English `message` on each
    /// error enum. That put presentation copy inside types that are meant to
    /// know nothing about being displayed — and made a translated error
    /// impossible without translating the domain. The enums now carry only the
    /// *fact*; the words live here.
    nonisolated struct Errors: Sendable {
        let authentication: @Sendable (AuthenticationError) -> String
        let user: @Sendable (UserClientError) -> String
        let couple: @Sendable (CoupleClientError) -> String
        let invite: @Sendable (InviteClientError) -> String
        let dailyExperience: @Sendable (DailyExperienceError) -> String
        let decision: @Sendable (DecisionClientError) -> String
        let market: @Sendable (MarketClientError) -> String
        let chore: @Sendable (ChoreClientError) -> String
    }
}

// MARK: - Resolving domain facts into words
//
// Each catalogue stores the pieces; these turn a value the reducer produced
// into the one sentence that fits it. They live beside the declarations rather
// than in each language file so the mapping is written once and cannot drift
// between languages.

extension Strings.Auth {
    func validation(_ validation: FieldValidation) -> String {
        switch validation {
        case .invalidEmail: invalidEmail
        case let .shortPassword(minimum): shortPassword(minimum)
        case .missingName: missingName
        }
    }
}

extension Strings.Decisions {
    func validation(_ validation: DecisionValidation) -> String {
        switch validation {
        case .missingTitle: missingTitle
        case let .titleTooLong(maximum): titleTooLong(maximum)
        case .emptyChoice: emptyChoice
        case let .choiceTooLong(maximum): choiceTooLong(maximum)
        case .duplicateChoices: duplicateChoices
        }
    }
}

extension Strings.Today {
    /// The question this phone should show.
    ///
    /// Falls back to whatever the backend wrote whenever the prompt is one this
    /// build has no words for, so a question shipped from the server later
    /// still reads as itself instead of disappearing.
    func prompt(_ experience: DailyExperience) -> String {
        switch experience.promptID {
        case .everyday: promptEveryday
        case nil: experience.prompt
        }
    }

    /// The answers, in the order the backend listed them.
    ///
    /// An answer is stored as an index into the server's list, so a translation
    /// that is not the same length cannot safely stand in for it — one person
    /// would be choosing a different thing from the one their partner sees.
    func options(_ experience: DailyExperience) -> [String] {
        guard let promptID = experience.promptID else { return experience.options }
        let translated: [String]
        switch promptID {
        case .everyday: translated = optionsEveryday
        }
        return translated.count == experience.options.count ? translated : experience.options
    }
}

extension Strings.Chores {
    func cadence(_ cadence: ChoresFeature.DraftCadence) -> String {
        switch cadence {
        case .once: cadenceOnce
        case .daily: cadenceDaily
        case .everyDays(7): cadenceWeekly
        case .everyDays(14): cadenceEveryTwoWeeks
        case .everyDays(30): cadenceMonthly
        case let .everyDays(days): cadenceEveryDays(days)
        }
    }

    func rotation(_ rotation: Chore.Rotation) -> String {
        switch rotation {
        case .alternates: rotationAlternates
        case .fixed: rotationFixed
        case .anyone: rotationAnyone
        }
    }

    /// Whose turn it is, said from the point of view of whoever is looking.
    func turn(_ chore: Chore, currentUserID: String?, partnerName: String?) -> String {
        switch chore.rotation {
        case .anyone: turnEither
        case .alternates, .fixed:
            chore.ownerID == currentUserID ? turnYours : turnPartner(partnerName)
        }
    }

    func standing(_ standing: Chore.Standing) -> String {
        switch standing {
        case let .overdue(days): standingLate(days)
        case .dueToday: standingToday
        case let .upcoming(days): standingUpcoming(days)
        case .settled: standingDone
        }
    }
}

extension Strings.Couple {
    func preparationError(
        _ error: ReadyForPartnerFeature.PreparationError,
        _ errors: Strings.Errors
    ) -> String {
        switch error {
        case let .couple(error): errors.couple(error)
        case let .invite(error): errors.invite(error)
        }
    }
}
