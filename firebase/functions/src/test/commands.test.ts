import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { before, describe, it } from "node:test";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import {
  acceptInviteForUser,
  createCoupleForUser,
  createDecisionForUser,
  createInviteForUser,
  getTodayForUser,
  submitTodayAnswerForUser,
  resolveDecisionForUser,
} from "../commands.js";
import { DomainError, hashInviteToken } from "../domain.js";

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const integration = emulatorAvailable ? describe : describe.skip;

integration("Couple commands", () => {
  const database = getFirestore(initializeApp({ projectId: "coupleos-emulator" }, "commands-tests"));

  before(() => {
    assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
  });

  it("creates one idempotent Couple per user", async () => {
    const creator = await seedUser();
    const first = await createCoupleForUser(database, creator);
    const second = await createCoupleForUser(database, creator);

    assert.equal(first.id, second.id);
    assert.deepEqual(first.couple.memberIds, [creator]);
    assert.equal(first.couple.status, "waitingForPartner");
    const profile = await database.collection("users").doc(creator).get();
    assert.equal(profile.get("activeCoupleId"), first.id);
  });

  it("stores only a SHA-256 invite identifier and revokes the previous invite", async () => {
    const creator = await seedUser();
    const couple = await createCoupleForUser(database, creator);
    const first = await createInviteForUser(database, creator, couple.id);
    const second = await createInviteForUser(database, creator, couple.id);

    assert.notEqual(first.token, second.token);
    const firstDocument = await database.collection("invites").doc(hashInviteToken(first.token)).get();
    const secondDocument = await database.collection("invites").doc(hashInviteToken(second.token)).get();
    assert.equal(firstDocument.get("status"), "revoked");
    assert.equal(secondDocument.get("status"), "pending");
    assert.equal(secondDocument.data()?.token, undefined);
  });

  it("rejects accepting your own invite", async () => {
    const creator = await seedUser();
    const couple = await createCoupleForUser(database, creator);
    const invite = await createInviteForUser(database, creator, couple.id);

    await assertDomainError(
      () => acceptInviteForUser(database, creator, invite.token),
      "cannot-accept-own-invite",
    );
  });

  it("rejects an expired invite", async () => {
    const creator = await seedUser();
    const invitee = await seedUser();
    const couple = await createCoupleForUser(database, creator);
    const invite = await createInviteForUser(database, creator, couple.id);
    await database.collection("invites").doc(hashInviteToken(invite.token)).update({
      expiresAt: Timestamp.fromMillis(Date.now() - 1),
    });

    await assertDomainError(
      () => acceptInviteForUser(database, invitee, invite.token),
      "invite-expired",
    );
  });

  it("rejects a reused invite", async () => {
    const creator = await seedUser();
    const firstInvitee = await seedUser();
    const secondInvitee = await seedUser();
    const couple = await createCoupleForUser(database, creator);
    const invite = await createInviteForUser(database, creator, couple.id);
    await acceptInviteForUser(database, firstInvitee, invite.token);

    await assertDomainError(
      () => acceptInviteForUser(database, secondInvitee, invite.token),
      "invite-already-used",
    );
  });

  it("rejects an invitee who already belongs to a Couple", async () => {
    const creator = await seedUser();
    const invitee = await seedUser();
    await createCoupleForUser(database, invitee);
    const couple = await createCoupleForUser(database, creator);
    const invite = await createInviteForUser(database, creator, couple.id);

    await assertDomainError(
      () => acceptInviteForUser(database, invitee, invite.token),
      "already-in-couple",
    );
  });

  it("allows only one of two concurrent acceptances", async () => {
    const creator = await seedUser();
    const firstInvitee = await seedUser();
    const secondInvitee = await seedUser();
    const couple = await createCoupleForUser(database, creator);
    const invite = await createInviteForUser(database, creator, couple.id);

    const results = await Promise.allSettled([
      acceptInviteForUser(database, firstInvitee, invite.token),
      acceptInviteForUser(database, secondInvitee, invite.token),
    ]);
    assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
    assert.equal(results.filter((result) => result.status === "rejected").length, 1);

    const storedCouple = await database.collection("couples").doc(couple.id).get();
    assert.equal(storedCouple.get("status"), "active");
    assert.equal((storedCouple.get("memberIds") as string[]).length, 2);
  });

  it("atomically activates the Couple, both profiles and the invite", async () => {
    const creator = await seedUser();
    const invitee = await seedUser();
    const couple = await createCoupleForUser(database, creator);
    const invite = await createInviteForUser(database, creator, couple.id);
    const result = await acceptInviteForUser(database, invitee, invite.token);

    assert.deepEqual(result.couple.memberIds, [creator, invitee]);
    assert.equal(result.couple.status, "active");
    assert.ok(result.couple.activatedAt);

    const [creatorProfile, inviteeProfile, inviteDocument] = await Promise.all([
      database.collection("users").doc(creator).get(),
      database.collection("users").doc(invitee).get(),
      database.collection("invites").doc(hashInviteToken(invite.token)).get(),
    ]);
    assert.equal(creatorProfile.get("activeCoupleId"), couple.id);
    assert.equal(creatorProfile.get("onboardingStatus"), "completed");
    assert.equal(inviteeProfile.get("activeCoupleId"), couple.id);
    assert.equal(inviteeProfile.get("onboardingStatus"), "completed");
    assert.equal(inviteDocument.get("status"), "accepted");
    assert.equal(inviteDocument.get("acceptedBy"), invitee);
  });

  it("stores the Couple's time zone and ignores an unusable one", async () => {
    const creator = await seedUser();
    const couple = await createCoupleForUser(database, creator, "America/Sao_Paulo");
    assert.equal(couple.couple.timeZone, "America/Sao_Paulo");

    const other = await seedUser();
    const fallback = await createCoupleForUser(database, other, "Not/AZone");
    assert.equal(fallback.couple.timeZone, undefined);
  });

  it("keeps the Couple's time zone when the partner accepts", async () => {
    const creator = await seedUser();
    const invitee = await seedUser();
    const couple = await createCoupleForUser(database, creator, "America/Sao_Paulo");
    const invite = await createInviteForUser(database, creator, couple.id);
    const result = await acceptInviteForUser(database, invitee, invite.token);

    assert.equal(result.couple.timeZone, "America/Sao_Paulo");
    const stored = await database.collection("couples").doc(couple.id).get();
    assert.equal(stored.get("timeZone"), "America/Sao_Paulo");
  });

  it("rejects an answer for a day that has already closed", async () => {
    const couple = await seedActiveCouple();
    const today = await getTodayForUser(database, couple.creator);

    assert.notEqual(today.id, "2020-01-01");
    await assertDomainError(
      () => submitTodayAnswerForUser(database, couple.creator, couple.id, "2020-01-01", 0),
      "daily-not-found",
    );
  });

  it("rejects an option that is not on the moment", async () => {
    const couple = await seedActiveCouple();
    const today = await getTodayForUser(database, couple.creator);

    for (const option of [today.experience.options.length, -1, 1.5, "0", null]) {
      await assertDomainError(
        () => submitTodayAnswerForUser(database, couple.creator, couple.id, today.id, option),
        "invalid-daily-answer",
      );
    }
  });

  it("rejects a malformed couple or experience id", async () => {
    const couple = await seedActiveCouple();
    await assertDomainError(
      () => submitTodayAnswerForUser(database, couple.creator, couple.id, "a/b", 0),
      "invalid-daily-answer",
    );
    await assertDomainError(
      () => submitTodayAnswerForUser(database, couple.creator, undefined, "2026-01-01", 0),
      "invalid-daily-answer",
    );
  });

  it("lets the second partner answer and reveals both sides", async () => {
    const couple = await seedActiveCouple();
    const today = await getTodayForUser(database, couple.creator);

    const first = await submitTodayAnswerForUser(database, couple.creator, couple.id, today.id, 0);
    assert.equal(first.experience.revealedAnswers, undefined);
    assert.deepEqual(first.notify, { userIds: [couple.invitee], event: "partner-answered" });

    const second = await submitTodayAnswerForUser(database, couple.invitee, couple.id, today.id, 1);
    assert.deepEqual(second.experience.revealedAnswers, {
      [couple.creator]: 0,
      [couple.invitee]: 1,
    });
    assert.deepEqual(second.notify, { userIds: [couple.creator], event: "daily-revealed" });
  });

  it("refuses a second answer from the same partner", async () => {
    const couple = await seedActiveCouple();
    const today = await getTodayForUser(database, couple.creator);
    await submitTodayAnswerForUser(database, couple.creator, couple.id, today.id, 0);

    await assertDomainError(
      () => submitTodayAnswerForUser(database, couple.creator, couple.id, today.id, 1),
      "already-answered",
    );
  });

  it("creates an idempotent Decision for the authenticated Couple member", async () => {
    const couple = await seedActiveCouple();
    const decisionId = randomUUID();
    const first = await createDecisionForUser(
      database,
      couple.creator,
      couple.id,
      decisionId,
      "Where should we eat?",
      ["At home", "Somewhere new"],
    );
    const repeated = await createDecisionForUser(
      database,
      couple.creator,
      couple.id,
      decisionId,
      "Where should we eat?",
      ["At home", "Somewhere new"],
    );

    assert.deepEqual(repeated, first);
    assert.equal(first.decision.creatorId, couple.creator);
    assert.equal(first.decision.responderId, couple.invitee);
    assert.equal(first.decision.status, "waitingForPartner");
  });

  it("rejects creating a Decision for another Couple", async () => {
    const couple = await seedActiveCouple();
    const stranger = await seedUser();

    await assertDomainError(
      () => createDecisionForUser(
        database,
        stranger,
        couple.id,
        randomUUID(),
        "Question",
        ["A", "B"],
      ),
      "permission-denied",
    );
  });

  it("allows only the requested partner to resolve and persists one result", async () => {
    const couple = await seedActiveCouple();
    const created = await createDecisionForUser(
      database,
      couple.creator,
      couple.id,
      randomUUID(),
      "What should we watch?",
      ["Dune", "Arrival", "Blade Runner"],
    );

    await assertDomainError(
      () => resolveDecisionForUser(database, couple.creator, couple.id, created.id, 0),
      "not-decision-responder",
    );

    const resolved = await resolveDecisionForUser(
      database,
      couple.invitee,
      couple.id,
      created.id,
      1,
    );
    assert.equal(resolved.decision.status, "resolved");
    assert.equal(resolved.decision.selectedOptionIndex, 1);
    assert.ok(resolved.decision.resolvedAt);

    const stored = await database.collection("couples").doc(couple.id)
      .collection("decisions").doc(created.id).get();
    assert.equal(stored.get("selectedOptionIndex"), 1);
    assert.equal(stored.get("status"), "resolved");
  });

  it("makes repeated resolution idempotent only for the committed choice", async () => {
    const couple = await seedActiveCouple();
    const created = await createDecisionForUser(
      database,
      couple.creator,
      couple.id,
      randomUUID(),
      "Choose one",
      ["A", "B"],
    );
    const first = await resolveDecisionForUser(
      database,
      couple.invitee,
      couple.id,
      created.id,
      0,
    );
    const repeated = await resolveDecisionForUser(
      database,
      couple.invitee,
      couple.id,
      created.id,
      0,
    );
    assert.deepEqual(repeated, first);
    await assertDomainError(
      () => resolveDecisionForUser(database, couple.invitee, couple.id, created.id, 1),
      "decision-already-resolved",
    );
  });

  it("commits only one result under concurrent resolution", async () => {
    const couple = await seedActiveCouple();
    const created = await createDecisionForUser(
      database,
      couple.creator,
      couple.id,
      randomUUID(),
      "Choose one",
      ["A", "B"],
    );
    const results = await Promise.allSettled([
      resolveDecisionForUser(database, couple.invitee, couple.id, created.id, 0),
      resolveDecisionForUser(database, couple.invitee, couple.id, created.id, 1),
    ]);

    assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
    assert.equal(results.filter((result) => result.status === "rejected").length, 1);
    const stored = await database.collection("couples").doc(couple.id)
      .collection("decisions").doc(created.id).get();
    assert.equal(stored.get("status"), "resolved");
    assert.ok([0, 1].includes(stored.get("selectedOptionIndex") as number));
  });

  async function seedActiveCouple(): Promise<{
    id: string;
    creator: string;
    invitee: string;
  }> {
    const creator = await seedUser();
    const invitee = await seedUser();
    const couple = await createCoupleForUser(database, creator);
    const invite = await createInviteForUser(database, creator, couple.id);
    await acceptInviteForUser(database, invitee, invite.token);
    return { id: couple.id, creator, invitee };
  }

  async function seedUser(): Promise<string> {
    const userId = `user-${randomUUID()}`;
    await database.collection("users").doc(userId).set({
      firstName: "Person",
      createdAt: Timestamp.now(),
      onboardingStatus: "readyForPartner",
    });
    return userId;
  }
});

async function assertDomainError(
  operation: () => Promise<unknown>,
  expectedCode: DomainError["domainCode"],
): Promise<void> {
  await assert.rejects(operation, (error: unknown) => {
    assert.ok(error instanceof DomainError);
    assert.equal(error.domainCode, expectedCode);
    return true;
  });
}
