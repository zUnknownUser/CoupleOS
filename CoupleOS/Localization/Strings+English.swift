import Foundation

/// The app's original voice, and the reference the other languages are written
/// against. Deliberate and a little poetic: "your person" rather than "your
/// partner", "Couple World", "Alive because you're both here."
extension Strings {
    static let english = Strings(
        language: .english,
        brand: englishBrand,
        common: englishCommon,
        languageMenu: englishLanguageMenu,
        welcome: englishWelcome,
        invite: englishInvite,
        auth: englishAuth,
        session: englishSession,
        identity: englishIdentity,
        couple: englishCouple,
        home: englishHome,
        world: englishWorld,
        today: englishToday,
        market: englishMarket,
        chores: englishChores,
        decisions: englishDecisions,
        errors: englishErrors
    )
}

/// The neutral stand-in, in the two positions a sentence can put it.
private let person: @Sendable (String?) -> String = { $0 ?? "Your person" }
private let personInline: @Sendable (String?) -> String = { $0 ?? "your person" }

private let englishBrand = Strings.Brand(
    wordmark: "COUPLE OS",
    accessibleName: "Couple OS"
)

private let englishCommon = Strings.Common(
    tryAgain: "Try again",
    continueAction: "Continue",
    back: "Back",
    close: "Close",
    remove: "Remove",
    clear: "Clear",
    working: "Working",
    signOut: "Sign out",
    errorPrefix: "Error",
    successPrefix: "Success",
    or: "OR",
    person: person,
    personInline: personInline
)

private let englishLanguageMenu = Strings.LanguageMenu(
    title: "Language",
    automatic: { "Automatic · \($0.endonym)" },
    accessibilityLabel: { "Language, currently \($0.endonym)" }
)

private let englishWelcome = Strings.Welcome(
    openingYourWorld: "Opening your world…",
    heroTitle: "Your world.\nJust the two of you.",
    heroSubtitle: "A private space to stay close, share life and build something that's only yours.",
    createWorld: "Create our world",
    haveAccount: "I already have an account",
    haveInvite: "I have an invite"
)

private let englishInvite = Strings.Invite(
    manualTitle: "Step into your world.",
    manualSubtitle: "Use the private invite your person shared with you.",
    linkLabel: "INVITE LINK",
    linkPlaceholder: "Paste your private link",
    manualPrivacy: "The link reveals no private information before you sign in.",
    invitationTitle: "You\u{2019}ve been invited into someone\u{2019}s world.",
    invitationSubtitle: "A private Couple OS space is waiting for both of you.",
    joinTheirWorld: "Join their world",
    invitationPrivacy: "You'll see who invited you only after your account is verified.",
    choiceTitle: "How would you like to enter?",
    choiceSubtitle: "Your invite will stay with you through sign in.",
    createAccount: "Create account",
    signIn: "Sign in"
)

private let englishAuth = Strings.Auth(
    loginTitle: "Welcome back",
    loginSubtitle: "Your world has been waiting.",
    emailLabel: "EMAIL",
    emailPlaceholder: "you@example.com",
    passwordLabel: "PASSWORD",
    passwordPlaceholder: "Your password",
    showPassword: "Show password",
    hidePassword: "Hide password",
    forgotPassword: "Forgot password?",
    resetLinkSent: "Check your inbox for a reset link.",
    signUpTitle: "Create your account",
    signUpSubtitle: "A quiet key to the world you're about to make.",
    createAccount: "Create account",
    signUpPrivacy: "Your account is personal. Your shared world belongs to both of you.",
    invalidEmail: "Enter a valid email address.",
    shortPassword: { "Password must have at least \($0) characters." },
    missingName: "Tell us what we should call you."
)

private let englishSession = Strings.Session(
    openingYourWorld: "Opening your world…",
    worldStillHere: "Your world is still here.",
    finishingYourSpace: "Finishing your space…",
    accountSafe: "Your account is safe."
)

private let englishIdentity = Strings.Identity(
    title: "Let's start with you.",
    subtitle: "One person begins. The world becomes yours when the other arrives.",
    nameLabel: "YOUR NAME",
    namePlaceholder: "What should we call you?",
    privacy: "Private by design. Nothing here is public.",
    recoveryTitle: "Let's finish your space.",
    recoverySubtitle: "Your account is safe. We just need the name that belongs inside your world.",
    recoveryPrivacy: "We found your account and will continue exactly where you left off."
)

private let englishCouple = Strings.Couple(
    preparingTitle: "Preparing your world…",
    preparingSubtitle: "A private space is taking shape.",
    waitingTitle: "Waiting for your person.",
    waitingSubtitle: "Your world changes when they arrive.",
    shareInvite: "Share invite",
    shareSubject: "A private Couple OS invite",
    shareMessage: "Join me in our private Couple World.",
    copyLink: "Copy link",
    linkCopied: "Link copied",
    sharedTitle: "Your world is now shared.",
    sharedSubtitle: "Two presences. One private place.",
    worldStillHere: "Your world is still here.",
    joiningTitle: "Joining your world…",
    joiningSubtitle: "Connecting both of you securely.",
    joinedSubtitle: "This private place belongs to both of you.",
    couldNotJoinTitle: "We couldn't join this world."
)

private let englishHome = Strings.Home(
    privateSpace: "Private shared space",
    signOut: "Sign out",
    partnerLoading: "Partner profile loading",
    retryPartner: "Try partner profile again",
    welcomeBack: { "Welcome back, \($0)." },
    openingSharedWorld: "Opening your shared world…",
    worldStillHere: "Your shared world is still here.",
    bothNames: { "\($0) & \($1)" },
    nowSection: "NOW",
    ourWorldSection: "OUR WORLD",
    quiet: "Nothing needs either of you right now.",
    signalAccessibility: { "\($0). \($1). \($2)." },
    areaAccessibility: { "\($0). \($1)." },
    urgencyEyebrow: { urgency in
        switch urgency {
        case .live: "RIGHT NOW"
        case .needsYou: "NEEDS YOU"
        case .needsBoth: "NEEDS BOTH"
        case .waiting: "WAITING"
        case .settled: "JUST NOW"
        }
    },
    moduleTitle: { module in
        switch module {
        case .market: "Market"
        case .chores: "Home"
        case .decisions: "Decisions"
        case .today: "Today"
        }
    }
)

private let englishWorld = Strings.World(
    soloDescription: "One presence waiting for its person",
    description: { activity in
        switch activity {
        case .calm: "Two presences connected inside their private world"
        case .needsBoth: "Your shared world has something waiting for both of you"
        case .needsYou: "Your person left something waiting for you in your shared world"
        case .waiting: "Your presence is waiting quietly for your person"
        case .sharedMoment: "Your two presences completed a shared moment"
        case .live: "One of you is out in the world right now"
        }
    },
    urgencyCaption: { urgency in
        switch urgency {
        case .live: "Something is happening right now."
        case .needsYou: "Your person left something here for you."
        case .needsBoth: "A small moment is waiting for both of you."
        case .waiting: "Your part is done. Nothing else is required."
        case .settled: "Something just became yours together."
        }
    },
    bothHere: "Alive because you\u{2019}re both here."
)

private let englishToday = Strings.Today(
    eyebrow: "TODAY",
    saving: "Saving…",
    leaveThisHere: "Leave this here",
    reconnect: "Reconnect",
    backToOurWorld: "Back to our world",
    waitingTitle: "Your answer is here.",
    waitingDetail: "It stays private until your person leaves theirs. You can keep using your world meanwhile.",
    revealTitle: "You both left a mark here.",
    you: "You",
    yourPerson: "Your person",
    statusReconnect: "Tap to reconnect",
    statusOpenForBoth: "Open for both",
    statusWaitingForYou: "Waiting for you",
    statusWaitingForPartner: { "Waiting for \(person($0))" },
    statusRevealed: "Revealed",
    statusOpening: "Opening…",
    detailAvailable: "A small choice for each of you",
    detailWaitingForMe: { "\(person($0)) left something here" },
    detailWaitingForPartner: { "Your answer is in — waiting for \(person($0))" },
    detailRevealAvailable: "You both answered — see what it means",
    promptEveryday: "What would feel most like us today?",
    optionsEveryday: [
        "Stay in and make it cozy",
        "Go somewhere new",
        "Watch something together",
        "Just talk for a while",
        "Let the other person choose",
    ]
)

private let englishMarket = Strings.Market(
    title: "Market",
    openingList: "Opening your list",
    listStillHere: "Your list is still here.",
    runEyebrowIdle: "MARKET RUN",
    runEyebrowMine: "YOU'RE THERE",
    runEyebrowTheirs: "THEY'RE THERE",
    runHeadlineIdle: { "Going to the store? Tell \(person($0)) — they can still add something." },
    runHeadlineAllGathered: "Everything is gathered.",
    runHeadlineRemaining: { "\($0) still to gather." },
    runHeadlineTheirs: { "\(person($0)) is at the market right now." },
    finishRun: "I'm done",
    startRun: "I'm at the market",
    composerPlaceholderIdle: "Add to the list",
    composerPlaceholderShopping: "Quick — add something",
    addToList: "Add to the list",
    askDirectly: { "Ask \(personInline($0)) for this directly" },
    toBringSection: "TO BRING",
    basketSection: "IN THE BASKET",
    clearBasket: "Clear",
    dismissMessageHint: "Dismisses this message",
    emptyTitle: "Nothing on the list.",
    emptyDetail: "Add what the house needs. Whoever gets there first will see it.",
    waitingAMonthOrMore: "Waiting a month or more",
    waitingDays: { "Waiting \($0) days" },
    youAskedForThis: "You asked for this",
    personAskedForThis: { "\(person($0)) asked for this" },
    addedByPerson: { "Added by \(personInline($0))" },
    stillToBring: "still to bring",
    inTheBasket: "in the basket",
    signalPartnerRunTitle: { "\(person($0)) is at the market" },
    signalRunDetailEmpty: "Nothing on the list yet — ask for something",
    signalRunDetailPending: { "\($0) \($0 == 1 ? "thing" : "things") to bring · add anything?" },
    captionPartnerRun: { "\(person($0)) is out in the world. Now is the moment." },
    signalMyRunTitle: "You're at the market",
    signalMyRunDetailEmpty: "Everything is gathered",
    signalMyRunDetailPending: { "\($0) still to gather" },
    captionMyRun: { "You're out there. \(person($0)) can still reach you." },
    signalAsksTitle: { "\(person($0)) asked for \($1) things" },
    signalAsksDetailMany: { "\($0) and \($1) more" },
    signalAsksDetailOne: { "\(person($0)) asked you to bring this" },
    captionAsks: { "\(person($0)) is counting on you for something small." },
    statusReconnect: "Tap to reconnect",
    statusPartnerThere: { "\(person($0)) is there now" },
    statusYouThere: "You're there now",
    statusNothingToBring: "Nothing to bring",
    statusNothingCurrent: "Nothing current",
    statusToBring: { "\($0) to bring" }
)

private let englishChores = Strings.Chores(
    title: "Home",
    openingChores: "Opening your chores",
    listStillHere: "Your list is still here.",
    composerPlaceholder: "Add something the home needs",
    addChore: "Add this chore",
    yourTurnSection: "YOUR TURN",
    withPartnerSection: { $0.map { "WITH \($0.uppercased())" } ?? "WITH YOUR PERSON" },
    comingUpSection: "COMING UP",
    startsWithYou: "Starts with you",
    startsWithPartner: { "Starts with \(personInline($0))" },
    emptyTitle: "Nothing set up yet.",
    emptyDetail: "Add the things that keep coming back. Whose turn it is takes care of itself.",
    markDoneHint: "Marks this as done",
    cadenceOnce: "Once",
    cadenceDaily: "Daily",
    cadenceWeekly: "Weekly",
    cadenceEveryTwoWeeks: "Every 2 weeks",
    cadenceMonthly: "Monthly",
    cadenceEveryDays: { "Every \($0) days" },
    rotationAlternates: "Take turns",
    rotationFixed: "Always one of us",
    rotationAnyone: "Whoever gets there",
    turnEither: "Either of you",
    turnYours: "Your turn",
    turnPartner: { "\(person($0))'s turn" },
    standingLate: { $0 == 1 ? "1 day late" : "\($0) days late" },
    standingToday: "today",
    standingUpcoming: { $0 == 1 ? "in 1 day" : "in \($0) days" },
    standingDone: "Done",
    rowSubtitle: { "\($0) · \($1)" },
    signalMineTitleMany: { "\($0) things at home" },
    detailLate: { $0 == 1 ? "Late" : "\($0) of them late" },
    detailOthersToday: { "\($0) and \($1) more today" },
    detailYourTurnToday: "Your turn today",
    captionOverdue: "The house is waiting on you.",
    signalTheirsTitleMany: { "\($0) things with \(personInline($1))" },
    signalTheirsDetail: { "\(person($0))'s turn" },
    signalSettledDetail: { "\(person($0)) took care of this" },
    statusReconnect: "Tap to reconnect",
    statusForYou: { "\($0) for you" },
    statusWithPartner: { "\($0) with \(personInline($1))" },
    statusNothingSetUp: "Nothing set up",
    statusAllCaughtUp: "All caught up"
)

private let englishDecisions = Strings.Decisions(
    title: "Decisions",
    newDecision: "New decision",
    newDecisionHint: "Creates something for your person to choose",
    needsYouSection: "NEEDS YOU",
    waitingSection: "WAITING",
    recentSection: "RECENT",
    needsYouDetail: { "\(person($0)) needs your choice" },
    waitingRowDetail: { "Waiting quietly for \(personInline($0)) to choose" },
    recentDetail: { $0.map { "You decided together · \($0)" } ?? "Decided together" },
    reconnect: "Reconnect decisions",
    rowHint: "Opens this decision",
    createEyebrow: "NEW DECISION",
    createTitle: "What do you need their choice on?",
    createSubtitle: "Keep it small. One question, a few real options.",
    decisionLabel: "THE DECISION",
    decisionPlaceholder: "What should we decide?",
    choicesLabel: "CHOICES",
    choicePlaceholder: "Add a choice",
    addChoice: "Add another choice",
    removeChoice: { "Remove choice \($0)" },
    submit: "Send for their choice",
    missingTitle: "Add what you want to decide.",
    titleTooLong: { "Keep the question under \($0) characters." },
    emptyChoice: "Give each choice a name.",
    choiceTooLong: { "Keep each choice under \($0) characters." },
    duplicateChoices: "Make each choice different.",
    eyebrowNeedsYou: "NEEDS YOU",
    eyebrowWaiting: "WAITING",
    eyebrowDecided: "DECIDED",
    eyebrowDecision: "DECISION",
    chooseThis: "Choose this",
    leftWithPartnerTitle: "You left this with your person.",
    leftWithPartnerDetail: "It will settle here when they choose.",
    unavailableTitle: "This decision isn't available.",
    unavailableDetail: "It may have changed while your world was updating.",
    decidedTogether: "Decided together",
    resolvedNote: "One small thing settled inside your shared world.",
    signalNeedsDetail: { "\(person($0)) is waiting on your pick" },
    signalWaitingTitleMany: { "\($0) decisions with \(personInline($1))" },
    signalWaitingDetailOne: { "Waiting for \(person($0))" },
    signalWaitingDetailMany: "Waiting quietly",
    signalSettledDetail: "You settled this together",
    statusReconnect: "Tap to reconnect",
    statusForYou: { "\($0) for you" },
    statusWithPartner: { "\($0) with \(personInline($1))" },
    statusNothingOpen: "Nothing open",
    statusAllSettled: "All settled"
)

private let englishErrors = Strings.Errors(
    authentication: { error in
        switch error {
        case .invalidCredentials: "That email or password doesn't look right."
        case .invalidEmail: "Enter a valid email address."
        case .emailAlreadyInUse: "An account already exists for this email."
        case .weakPassword: "Choose a password with at least 6 characters."
        case .networkUnavailable: "You're offline. Check your connection and try again."
        case .cancelled: "Sign in was cancelled."
        case .unavailable: "Sign in isn't available right now."
        case .unknown: "Something went wrong. Please try again."
        }
    },
    user: { error in
        switch error {
        case .documentNotFound: "We couldn't find your profile."
        case .invalidData: "Your profile needs attention before we can open your world."
        case .networkUnavailable: "You're offline. Your account is safe—try again when you're connected."
        case .permissionDenied: "We couldn't access your profile. Please sign in again."
        case .unavailable: "Your profile is temporarily unavailable. Please try again."
        case .unknown: "We couldn't finish setting up your profile. Please try again."
        }
    },
    couple: { error in
        switch error {
        case .profileRequired: "Finish your profile before creating your world."
        case .alreadyInCouple: "This account already belongs to a Couple World."
        case .coupleNotFound: "We couldn't find this Couple World."
        case .coupleAlreadyFull: "This Couple World is already shared."
        case .networkUnavailable: "You're offline. Reconnect and try again."
        case .permissionDenied: "You don't have access to this Couple World."
        case .invalidData: "This Couple World needs attention before it can open."
        case .unknown: "We couldn't prepare your world. Please try again."
        }
    },
    invite: { error in
        switch error {
        case .inviteInvalid: "This invite isn't valid. Ask your person for a new link."
        case .inviteExpired: "This invite has expired. Ask your person to share a new one."
        case .inviteAlreadyUsed: "This invite has already been used or replaced."
        case .cannotAcceptOwnInvite: "This invite is for your person—not for the account that created it."
        case .alreadyInCouple: "This account already belongs to a Couple World."
        case .coupleNotFound: "The Couple World behind this invite no longer exists."
        case .coupleAlreadyFull: "This Couple World is already shared by two people."
        case .configurationMissing: "Invite links aren't configured for this build."
        case .networkUnavailable: "You're offline. Reconnect and try again."
        case .permissionDenied: "We couldn't verify this invite for your account."
        case .unknown: "We couldn't accept this invite. Please try again."
        }
    },
    dailyExperience: { error in
        switch error {
        case .notFound: "Today is unavailable right now."
        case .alreadyAnswered: "Your answer is already part of this moment."
        case .notAMember, .permissionDenied: "This moment belongs to your Couple World."
        case .unavailable: "Today is temporarily unavailable."
        case .networkUnavailable: "You're offline. Your answer is safe—try again soon."
        case .invalidData, .unknown: "We couldn't open today's moment. Please try again."
        }
    },
    decision: { error in
        switch error {
        case .invalidInput: "Check the question and its choices."
        case .notFound: "This decision is no longer available."
        case .notResponder: "This decision is waiting for your person."
        case .alreadyResolved: "This decision has already been made."
        case .networkUnavailable: "You're offline. Try again when your connection returns."
        case .permissionDenied: "This decision belongs to another Couple World."
        case .unavailable: "Decisions are temporarily unavailable."
        case .invalidData, .unknown: "We couldn't open this decision. Please try again."
        }
    },
    market: { error in
        switch error {
        case .invalidInput: "Check what you're adding."
        case .itemNotFound: "This item is no longer on the list."
        case .runNotFound: "This market run has already ended."
        case .notShopper: "Only the person at the store can finish this run."
        case .runAlreadyFinished: "This market run is already done."
        case .listFull: "Your list is full. Clear a few things first."
        case .networkUnavailable: "You're offline. Your list is safe — try again when you're back."
        // Deliberately does not name a cause. A refusal here is almost never
        // the user being in the wrong Couple World — far more often it is a
        // stale sign-in or a rule that was never published — and an error that
        // guesses wrong sends people looking in the wrong place.
        case .permissionDenied: "We couldn't open your list. If this keeps happening, sign out and back in."
        case .unavailable: "Your list is temporarily unavailable."
        case .invalidData, .unknown: "We couldn't open your list. Please try again."
        }
    },
    chore: { error in
        switch error {
        case .invalidInput: "Check the chore and how often it comes around."
        case .notFound: "This chore is no longer on your list."
        case .notYourTurn: "This one is your person's turn."
        case .alreadyDone: "This one is already taken care of."
        case .listFull: "Your list is full. Finish or remove a few first."
        case .networkUnavailable: "You're offline. Try again when your connection returns."
        case .permissionDenied, .unavailable, .invalidData, .unknown:
            // Deliberately does not name a cause it cannot know.
            "We couldn't open your chores. If this keeps happening, sign out and back in."
        }
    }
)
