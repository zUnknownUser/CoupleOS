import Foundation
@testable import CoupleOS

nonisolated enum TestFixtures {
    static let authenticatedUser = AuthenticatedUser(
        id: "user-1",
        email: "alex@example.com",
        displayName: "Alex"
    )

    static func user(status: OnboardingStatus = .readyForPartner) -> User {
        User(
            id: authenticatedUser.id,
            firstName: "Alex",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            onboardingStatus: status
        )
    }

    static let inviteToken = InviteToken(rawValue: String(repeating: "A", count: 43))!

    static func couple(status: Couple.Status = .waitingForPartner) -> Couple {
        Couple(
            id: "couple-1",
            memberIDs: status == .active ? ["user-1", "user-2"] : ["user-1"],
            status: status,
            createdBy: "user-1",
            createdAt: Date(timeIntervalSince1970: 1_700_000_010),
            activatedAt: status == .active ? Date(timeIntervalSince1970: 1_700_000_020) : nil
        )
    }

    static var invite: CoupleInvite {
        CoupleInvite(
            token: inviteToken,
            url: URL(string: "https://coupleos.test/invite/\(inviteToken.rawValue)")!,
            expiresAt: Date(timeIntervalSince1970: 1_700_604_810)
        )
    }

    static func marketItem(
        id: String,
        name: String = "Coffee",
        isRequest: Bool = false,
        requestedBy: String = "user-2",
        status: MarketItem.Status = .pending,
        requestedAt: Date = Date(timeIntervalSince1970: 1_700_000_100)
    ) -> MarketItem {
        MarketItem(
            id: id,
            coupleID: "couple-1",
            name: name,
            note: nil,
            isRequest: isRequest,
            requestedBy: requestedBy,
            requestedAt: requestedAt,
            status: status,
            gatheredBy: status == .gathered ? "user-1" : nil,
            gatheredAt: status == .gathered ? Date(timeIntervalSince1970: 1_700_000_200) : nil
        )
    }

    static func marketRun(
        id: String = "run-1",
        shopperID: String = "user-2",
        endedAt: Date? = nil
    ) -> MarketRun {
        MarketRun(
            id: id,
            coupleID: "couple-1",
            shopperID: shopperID,
            startedAt: Date(timeIntervalSince1970: 1_700_000_300),
            endedAt: endedAt
        )
    }

    static let choreDue = Date(timeIntervalSince1970: 1_700_000_000)

    static func chore(
        id: String,
        title: String = "Dishes",
        cadence: Chore.Cadence = .everyDays(2),
        rotation: Chore.Rotation = .alternates,
        ownerID: String? = "user-1",
        status: Chore.Status = .active,
        dueAt: Date = choreDue,
        lastDoneBy: String? = nil,
        lastDoneAt: Date? = nil
    ) -> Chore {
        Chore(
            id: id,
            coupleID: "couple-1",
            title: title,
            cadence: cadence,
            rotation: rotation,
            ownerID: rotation == .anyone ? nil : ownerID,
            status: status,
            dueAt: dueAt,
            lastDoneBy: lastDoneBy,
            lastDoneAt: lastDoneAt,
            createdBy: "user-1",
            createdAt: Date(timeIntervalSince1970: 1_699_000_000)
        )
    }

    static var session: Session {
        Session(authenticatedUser: authenticatedUser, user: user())
    }
}
