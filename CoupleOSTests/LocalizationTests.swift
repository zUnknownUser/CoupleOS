import ComposableArchitecture
import XCTest

@testable import CoupleOS

/// What the language layer promises, in the order the app depends on it:
/// resolve the region, remember an override, and never leave a screen with a
/// hole in it.
final class AppLanguageTests: XCTestCase {
    func testRegionVariantsLandOnTheLanguageWeSpeak() {
        // Nobody's phone says "pt-BR" and nothing else. A person in Portugal,
        // Angola or Brazil is better served by Portuguese than by English.
        XCTAssertEqual(AppLanguage.matching("pt-BR"), .portugueseBrazil)
        XCTAssertEqual(AppLanguage.matching("pt-PT"), .portugueseBrazil)
        XCTAssertEqual(AppLanguage.matching("pt"), .portugueseBrazil)
        XCTAssertEqual(AppLanguage.matching("pt_BR"), .portugueseBrazil)
        XCTAssertEqual(AppLanguage.matching("en-GB"), .english)
        XCTAssertEqual(AppLanguage.matching("fr-FR"), nil)
    }

    func testThePhonesOrderDecidesWhichLanguageWins() {
        XCTAssertEqual(
            AppLanguage.resolved(fromPreferred: ["fr-FR", "pt-BR", "en-US"]),
            .portugueseBrazil,
            "A bilingual phone should land on the language listed first"
        )
        XCTAssertEqual(
            AppLanguage.resolved(fromPreferred: ["fr-FR", "de-DE"]),
            .english,
            "A language we do not speak falls back rather than showing nothing"
        )
        XCTAssertEqual(AppLanguage.resolved(fromPreferred: []), .english)
    }

    func testAutomaticFollowsThePhoneWhileAChoiceOverridesIt() {
        XCTAssertEqual(LanguagePreference.automatic.resolve(system: .portugueseBrazil), .portugueseBrazil)
        XCTAssertEqual(LanguagePreference.automatic.resolve(system: .english), .english)
        XCTAssertEqual(
            LanguagePreference.fixed(.english).resolve(system: .portugueseBrazil),
            .english,
            "A manual choice outranks the phone"
        )
    }

    func testThePreferenceSurvivesStorageAndGarbage() {
        for preference in [LanguagePreference.automatic, .fixed(.english), .fixed(.portugueseBrazil)] {
            XCTAssertEqual(LanguagePreference(storedValue: preference.storedValue), preference)
        }
        XCTAssertEqual(
            LanguagePreference(storedValue: "klingon"),
            .automatic,
            "An unreadable stored value must not strand someone in no language at all"
        )
    }
}

@MainActor
final class LocalizationFeatureTests: XCTestCase {
    func testOpeningTheAppReadsThePhoneAndTheStoredChoice() async {
        let store = TestStore(initialState: LocalizationFeature.State()) {
            LocalizationFeature()
        } withDependencies: {
            $0.localizationClient.systemLanguage = { .portugueseBrazil }
            $0.localizationClient.loadPreference = { .automatic }
        }

        await store.send(.task) {
            $0.systemLanguage = .portugueseBrazil
        }
        // The resolved language moved, so anything downstream of it hears.
        await store.receive(\.delegate.languageChanged, .portugueseBrazil)
        XCTAssertEqual(store.state.language, .portugueseBrazil)
    }

    func testChoosingALanguageStoresItAndAnnouncesTheChange() async {
        let saved = LockIsolated<[LanguagePreference]>([])
        let store = TestStore(initialState: LocalizationFeature.State()) {
            LocalizationFeature()
        } withDependencies: {
            $0.localizationClient.systemLanguage = { .english }
            $0.localizationClient.savePreference = { preference in
                saved.withValue { $0.append(preference) }
            }
        }

        await store.send(.preferenceSelected(.fixed(.portugueseBrazil))) {
            $0.preference = .fixed(.portugueseBrazil)
        }
        await store.receive(\.delegate.languageChanged, .portugueseBrazil)
        XCTAssertEqual(saved.value, [.fixed(.portugueseBrazil)])
    }

    func testPinningTheLanguageThePhoneAlreadyUsesChangesNothingDownstream() async {
        let store = TestStore(initialState: LocalizationFeature.State()) {
            LocalizationFeature()
        } withDependencies: {
            $0.localizationClient.systemLanguage = { .english }
            $0.localizationClient.savePreference = { _ in }
        }

        // The stored preference changes — the language does not — so no
        // delegate fires and the device record is left alone.
        await store.send(.preferenceSelected(.fixed(.english))) {
            $0.preference = .fixed(.english)
        }
    }

    func testTheDiscreetControlAlwaysOffersAWayBackToAutomatic() {
        let options = LocalizationFeature.State().options
        XCTAssertEqual(options.first, .automatic)
        XCTAssertEqual(
            options.count,
            AppLanguage.allCases.count + 1,
            "Every language we speak has to be reachable, plus automatic"
        )
    }
}

/// The catalogue's own guarantee. Missing copy does not fail to compile when it
/// is merely *empty*, so this is the one hole the type system leaves open.
final class StringsCatalogueTests: XCTestCase {
    func testNoLanguageHasAnEmptyString() {
        for language in AppLanguage.allCases {
            for (path, value) in strings(in: Strings.of(language)) {
                XCTAssertFalse(
                    value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "\(language.rawValue) has nothing to say for \(path)"
                )
            }
        }
    }

    func testEveryFailureCanBeSaidInEveryLanguage() {
        for language in AppLanguage.allCases {
            let errors = Strings.of(language).errors
            assertAllCasesSpeak(AuthenticationError.allCases, errors.authentication, language)
            assertAllCasesSpeak(UserClientError.allCases, errors.user, language)
            assertAllCasesSpeak(CoupleClientError.allCases, errors.couple, language)
            assertAllCasesSpeak(InviteClientError.allCases, errors.invite, language)
            assertAllCasesSpeak(DailyExperienceError.allCases, errors.dailyExperience, language)
            assertAllCasesSpeak(DecisionClientError.allCases, errors.decision, language)
            assertAllCasesSpeak(MarketClientError.allCases, errors.market, language)
            assertAllCasesSpeak(ChoreClientError.allCases, errors.chore, language)
        }
    }

    func testThePartnerStandInIsUsedWheneverThereIsNoName() {
        // The whole reason parameterised copy takes `String?` rather than a
        // pre-resolved name: the stand-in is a different word per language, and
        // in Portuguese a different word again mid-sentence.
        let pt = Strings.portugueseBrazil
        XCTAssertEqual(pt.common.person(nil), "Sua pessoa")
        XCTAssertEqual(pt.common.personInline(nil), "sua pessoa")
        XCTAssertEqual(pt.common.person("Sam"), "Sam")
        XCTAssertEqual(pt.market.statusPartnerThere(nil), "Sua pessoa está lá agora")
        XCTAssertEqual(pt.market.statusPartnerThere("Sam"), "Sam está lá agora")
        XCTAssertEqual(pt.chores.turnPartner(nil), "Vez de sua pessoa")
    }

    func testCountedCopyAgreesWithItselfInBothLanguages() {
        XCTAssertEqual(Strings.english.chores.standingLate(1), "1 day late")
        XCTAssertEqual(Strings.english.chores.standingLate(3), "3 days late")
        XCTAssertEqual(Strings.portugueseBrazil.chores.standingLate(1), "1 dia de atraso")
        XCTAssertEqual(Strings.portugueseBrazil.chores.standingLate(3), "3 dias de atraso")
        XCTAssertEqual(Strings.portugueseBrazil.market.runHeadlineRemaining(1), "Falta 1 item.")
        XCTAssertEqual(Strings.portugueseBrazil.market.runHeadlineRemaining(4), "Faltam 4 itens.")
    }

    func testTheDailyQuestionIsSaidByThePhoneNotByTheServer() {
        // One document, two people, possibly two languages: the server stores
        // which question it is, each phone says it in its own words.
        let experience = DailyExperience(
            id: "2026-09-04",
            periodKey: "2026-09-04",
            prompt: "What would feel most like us today?",
            options: Strings.english.today.optionsEveryday,
            answeredUserIDs: [],
            revealedAnswers: nil,
            promptID: .everyday
        )

        XCTAssertEqual(
            Strings.english.today.prompt(experience),
            "What would feel most like us today?"
        )
        XCTAssertEqual(
            Strings.portugueseBrazil.today.prompt(experience),
            "O que hoje teria mais a cara de vocês?"
        )
        XCTAssertEqual(
            Strings.portugueseBrazil.today.options(experience).first,
            "Ficar em casa e deixar aconchegante"
        )
        XCTAssertEqual(
            Strings.portugueseBrazil.today.options(experience).count,
            experience.options.count,
            "An answer is an index into the server's list, so the lengths must match"
        )
    }

    func testAnUnknownQuestionFallsBackToWhatTheServerWrote() {
        // A prompt shipped by the backend that this build has no words for has
        // to read as itself. Silence would be worse than English.
        let experience = DailyExperience(
            id: "2026-09-04",
            periodKey: "2026-09-04",
            prompt: "Something the server invented",
            options: ["A", "B"],
            answeredUserIDs: [],
            revealedAnswers: nil,
            promptID: nil
        )

        XCTAssertEqual(
            Strings.portugueseBrazil.today.prompt(experience),
            "Something the server invented"
        )
        XCTAssertEqual(Strings.portugueseBrazil.today.options(experience), ["A", "B"])
    }

    func testATranslationOfTheWrongLengthIsRefused() {
        // The server changed its answers and this build has not caught up.
        // Substituting would let one person choose a different thing from the
        // one their partner is looking at.
        let experience = DailyExperience(
            id: "2026-09-04",
            periodKey: "2026-09-04",
            prompt: "What would feel most like us today?",
            options: ["Only one option now"],
            answeredUserIDs: [],
            revealedAnswers: nil,
            promptID: .everyday
        )

        XCTAssertEqual(
            Strings.portugueseBrazil.today.options(experience),
            ["Only one option now"]
        )
    }

    func testTheSameHomeReadsDifferentlyInEachLanguage() {
        var state = MarketFeature.State()
        state.phase = .ready
        state.coupleID = "couple-1"
        state.currentUserID = "user-1"
        state.partnerID = "user-2"
        state.board = MarketBoard(
            items: [TestFixtures.marketItem(id: "a", name: "Milk")],
            run: TestFixtures.marketRun(shopperID: "user-2")
        )

        let english = state.homeContribution(strings: .english, partnerName: "Sam")
        let portuguese = state.homeContribution(strings: .portugueseBrazil, partnerName: "Sam")

        XCTAssertEqual(english.signals.first?.title, "Sam is at the market")
        XCTAssertEqual(portuguese.signals.first?.title, "Sam está no mercado")
        XCTAssertEqual(english.summary.status, "Sam is there now")
        XCTAssertEqual(portuguese.summary.status, "Sam está lá agora")
        XCTAssertEqual(
            english.signals.first?.urgency,
            portuguese.signals.first?.urgency,
            "Language changes the words, never the behaviour"
        )
    }

    // MARK: - Helpers

    private func assertAllCasesSpeak<E>(
        _ cases: [E],
        _ say: (E) -> String,
        _ language: AppLanguage,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for error in cases {
            XCTAssertFalse(
                say(error).isEmpty,
                "\(language.rawValue) has nothing to say for \(error)",
                file: file,
                line: line
            )
        }
    }

    /// Every stored `String` in the catalogue, with a path to name it. Closures
    /// are skipped — there is no generic way to call one — which is why the
    /// counted and partner-dependent cases are asserted by hand above.
    private func strings(in value: Any, path: String = "") -> [(String, String)] {
        if let text = value as? String { return [(path, text)] }
        return Mirror(reflecting: value).children.flatMap { child -> [(String, String)] in
            let name = child.label ?? "?"
            return strings(in: child.value, path: path.isEmpty ? name : "\(path).\(name)")
        }
    }
}
