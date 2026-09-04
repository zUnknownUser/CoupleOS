import {
  DocumentReference,
  Firestore,
  Timestamp,
  Transaction,
} from "firebase-admin/firestore";
import {
  CoupleRecord,
  DomainError,
  generateInviteToken,
  hashInviteToken,
  INVITE_LIFETIME_MS,
  DAILY_OPTIONS,
  DAILY_PROMPT_ID,
  DailyExperienceRecord,
  decisionDraft,
  DecisionRecord,
  InviteRecord,
  advanceChore,
  choreDraft,
  ChoreRecord,
  CHORE_LIST_MAX,
  marketHistoryRecord,
  marketItemDraft,
  MarketItemRecord,
  MARKET_SWEEP_MAX_ITEMS,
  MarketItemStatus,
  MARKET_LIST_MAX_ITEMS,
  MarketRunRecord,
  normalizeTimeZone,
  NotificationRequest,
  requireChoreId,
  requireMarketId,
  requireMarketItemStatus,
  periodKeyFor,
  requireDocumentId,
  requireDecisionId,
  requireInviteToken,
} from "./domain.js";

const USERS = "users";
const COUPLES = "couples";
const INVITES = "invites";
const DAILY = "daily";
const DECISIONS = "decisions";
const MARKET_ITEMS = "marketItems";
const MARKET_RUNS = "marketRuns";
const MARKET_HISTORY = "marketHistory";
const CHORES = "chores";
const DAILY_PROMPT = "What would feel most like us today?";

export async function createCoupleForUser(
  database: Firestore,
  userId: string,
  untrustedTimeZone?: unknown,
): Promise<{ id: string; couple: CoupleRecord }> {
  const userRef = database.collection(USERS).doc(userId);
  const newCoupleRef = database.collection(COUPLES).doc();

  return database.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    if (!userSnapshot.exists) {
      throw new DomainError("profile-required", "failed-precondition", "Profile is required.");
    }

    const activeCoupleId = optionalString(userSnapshot.get("activeCoupleId"));
    if (activeCoupleId) {
      const existingRef = database.collection(COUPLES).doc(activeCoupleId);
      const existingSnapshot = await transaction.get(existingRef);
      if (!existingSnapshot.exists) {
        throw new DomainError("couple-not-found", "not-found", "Couple was not found.");
      }
      const existing = existingSnapshot.data() as CoupleRecord;
      if (!existing.memberIds.includes(userId)) {
        throw new DomainError("already-in-couple", "failed-precondition", "Account is already linked.");
      }
      return { id: existingSnapshot.id, couple: existing };
    }

    const now = Timestamp.now();
    const timeZone = normalizeTimeZone(untrustedTimeZone);
    const couple: CoupleRecord = {
      memberIds: [userId],
      status: "waitingForPartner",
      createdBy: userId,
      createdAt: now,
      ...(timeZone ? { timeZone } : {}),
    };
    transaction.create(newCoupleRef, couple);
    transaction.update(userRef, { activeCoupleId: newCoupleRef.id });
    return { id: newCoupleRef.id, couple };
  });
}

export async function createInviteForUser(
  database: Firestore,
  userId: string,
  expectedCoupleId?: string,
): Promise<{ token: string; coupleId: string; expiresAt: Timestamp }> {
  const token = generateInviteToken();
  const inviteId = hashInviteToken(token);
  const inviteRef = database.collection(INVITES).doc(inviteId);
  const userRef = database.collection(USERS).doc(userId);

  const result = await database.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    if (!userSnapshot.exists) {
      throw new DomainError("profile-required", "failed-precondition", "Profile is required.");
    }
    const coupleId = optionalString(userSnapshot.get("activeCoupleId"));
    if (!coupleId || (expectedCoupleId && expectedCoupleId !== coupleId)) {
      throw new DomainError("couple-not-found", "not-found", "Couple was not found.");
    }

    const coupleRef = database.collection(COUPLES).doc(coupleId);
    const coupleSnapshot = await transaction.get(coupleRef);
    if (!coupleSnapshot.exists) {
      throw new DomainError("couple-not-found", "not-found", "Couple was not found.");
    }
    const couple = coupleSnapshot.data() as CoupleRecord;
    if (!couple.memberIds.includes(userId)) {
      throw new DomainError("permission-denied", "permission-denied", "Membership is required.");
    }
    if (couple.status !== "waitingForPartner" || couple.memberIds.length !== 1) {
      throw new DomainError("couple-already-full", "failed-precondition", "Couple is already active.");
    }

    let previousInvite:
      | { ref: DocumentReference; record: InviteRecord }
      | undefined;
    if (couple.activeInviteId) {
      const previousRef = database.collection(INVITES).doc(couple.activeInviteId);
      const previousSnapshot = await transaction.get(previousRef);
      if (previousSnapshot.exists) {
        previousInvite = {
          ref: previousRef,
          record: previousSnapshot.data() as InviteRecord,
        };
      }
    }

    const now = Timestamp.now();
    const expiresAt = Timestamp.fromMillis(now.toMillis() + INVITE_LIFETIME_MS);
    if (previousInvite?.record.status === "pending") {
      transaction.update(previousInvite.ref, {
        status: "revoked",
        revokedAt: now,
      });
    }
    const invite: InviteRecord = {
      coupleId,
      createdBy: userId,
      status: "pending",
      createdAt: now,
      expiresAt,
    };
    transaction.create(inviteRef, invite);
    transaction.update(coupleRef, { activeInviteId: inviteId });
    return { coupleId, expiresAt };
  });

  return { token, ...result };
}

export async function acceptInviteForUser(
  database: Firestore,
  userId: string,
  untrustedToken: unknown,
): Promise<{ id: string; couple: CoupleRecord; notify: NotificationRequest }> {
  const token = requireInviteToken(untrustedToken);
  const inviteId = hashInviteToken(token);
  const inviteRef = database.collection(INVITES).doc(inviteId);

  return database.runTransaction(async (transaction) => {
    const inviteSnapshot = await transaction.get(inviteRef);
    if (!inviteSnapshot.exists) {
      throw new DomainError("invite-invalid", "not-found", "Invite is invalid.");
    }
    const invite = inviteSnapshot.data() as InviteRecord;
    if (invite.status !== "pending") {
      throw new DomainError("invite-already-used", "failed-precondition", "Invite is no longer available.");
    }
    const now = Timestamp.now();
    if (invite.expiresAt.toMillis() <= now.toMillis()) {
      throw new DomainError("invite-expired", "failed-precondition", "Invite has expired.");
    }
    if (invite.createdBy === userId) {
      throw new DomainError(
        "cannot-accept-own-invite",
        "failed-precondition",
        "Creator cannot accept their own invite.",
      );
    }

    const coupleRef = database.collection(COUPLES).doc(invite.coupleId);
    const inviteeRef = database.collection(USERS).doc(userId);
    const creatorRef = database.collection(USERS).doc(invite.createdBy);
    const [coupleSnapshot, inviteeSnapshot, creatorSnapshot] = await Promise.all([
      transaction.get(coupleRef),
      transaction.get(inviteeRef),
      transaction.get(creatorRef),
    ]);

    if (!coupleSnapshot.exists) {
      throw new DomainError("couple-not-found", "not-found", "Couple was not found.");
    }
    if (!inviteeSnapshot.exists || !creatorSnapshot.exists) {
      throw new DomainError("profile-required", "failed-precondition", "Profile is required.");
    }

    const couple = coupleSnapshot.data() as CoupleRecord;
    if (
      couple.status !== "waitingForPartner" ||
      couple.memberIds.length !== 1 ||
      couple.memberIds[0] !== invite.createdBy ||
      couple.activeInviteId !== inviteId
    ) {
      throw new DomainError("invite-already-used", "failed-precondition", "Invite is no longer available.");
    }
    if (optionalString(inviteeSnapshot.get("activeCoupleId"))) {
      throw new DomainError("already-in-couple", "failed-precondition", "Account is already linked.");
    }
    if (optionalString(creatorSnapshot.get("activeCoupleId")) !== invite.coupleId) {
      throw new DomainError("couple-not-found", "failed-precondition", "Couple is inconsistent.");
    }

    const activeCouple: CoupleRecord = {
      memberIds: [invite.createdBy, userId],
      status: "active",
      createdBy: couple.createdBy,
      createdAt: couple.createdAt,
      activatedAt: now,
      ...(couple.timeZone ? { timeZone: couple.timeZone } : {}),
    };
    transaction.set(coupleRef, activeCouple, { merge: false });
    transaction.update(inviteeRef, {
      activeCoupleId: invite.coupleId,
      onboardingStatus: "completed",
    });
    transaction.update(creatorRef, { onboardingStatus: "completed" });
    transaction.update(inviteRef, {
      status: "accepted",
      acceptedBy: userId,
      acceptedAt: now,
    });
    return {
      id: invite.coupleId,
      couple: activeCouple,
      notify: {
        userIds: [invite.createdBy],
        event: "partner-joined",
      } satisfies NotificationRequest,
    };
  });
}

function optionalString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

export async function getTodayForUser(database: Firestore, userId: string) {
  const userSnapshot = await database.collection(USERS).doc(userId).get();
  const coupleId = optionalString(userSnapshot.get("activeCoupleId"));
  if (!coupleId) throw new DomainError("couple-not-found", "not-found", "Couple was not found.");
  const coupleSnapshot = await database.collection(COUPLES).doc(coupleId).get();
  const couple = coupleSnapshot.data() as CoupleRecord | undefined;
  if (!couple?.memberIds.includes(userId)) {
    throw new DomainError("permission-denied", "permission-denied", "Membership is required.");
  }
  const periodKey = periodKeyFor(new Date(), couple.timeZone);
  const ref = database.collection(COUPLES).doc(coupleId).collection(DAILY).doc(periodKey);
  const experience = await database.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (snapshot.exists) return snapshot.data() as DailyExperienceRecord;
    const record: DailyExperienceRecord = {
      periodKey,
      promptId: DAILY_PROMPT_ID,
      prompt: DAILY_PROMPT,
      options: [...DAILY_OPTIONS],
      answeredUserIds: [],
    };
    transaction.create(ref, record);
    return record;
  });
  return { id: periodKey, experience };
}

export async function submitTodayAnswerForUser(
  database: Firestore,
  userId: string,
  untrustedCoupleId: unknown,
  untrustedExperienceId: unknown,
  untrustedOptionIndex: unknown,
): Promise<{
  id: string;
  experience: DailyExperienceRecord;
  notify?: NotificationRequest;
}> {
  const coupleId = requireDocumentId(untrustedCoupleId);
  const experienceId = requireDocumentId(untrustedExperienceId);
  if (!Number.isInteger(untrustedOptionIndex) || (untrustedOptionIndex as number) < 0) {
    throw new DomainError("invalid-daily-answer", "invalid-argument", "Answer is invalid.");
  }
  const optionIndex = untrustedOptionIndex as number;

  const coupleRef = database.collection(COUPLES).doc(coupleId);
  const ref = database.collection(COUPLES).doc(coupleId).collection(DAILY).doc(experienceId);
  const answerRef = ref.collection("answers").doc(userId);
  return database.runTransaction(async (transaction) => {
    const coupleSnapshot = await transaction.get(coupleRef);
    const dailySnapshot = await transaction.get(ref);
    const answerSnapshot = await transaction.get(answerRef);
    const couple = coupleSnapshot.data() as CoupleRecord | undefined;
    if (!couple?.memberIds.includes(userId)) {
      throw new DomainError("permission-denied", "permission-denied", "Membership is required.");
    }
    // Only the Couple's current day is answerable; a stale id from a client that
    // sat open across midnight belongs to a moment that has already closed.
    if (experienceId !== periodKeyFor(new Date(), couple.timeZone)) {
      throw new DomainError("daily-not-found", "failed-precondition", "That moment has closed.");
    }
    if (!dailySnapshot.exists) throw new DomainError("daily-not-found", "not-found", "Daily moment was not found.");
    if (answerSnapshot.exists) throw new DomainError("already-answered", "already-exists", "Answer already submitted.");
    const record = dailySnapshot.data() as DailyExperienceRecord;
    if (optionIndex >= record.options.length) {
      throw new DomainError("invalid-daily-answer", "invalid-argument", "Answer is invalid.");
    }
    const answeredUserIds = [...new Set([...record.answeredUserIds, userId])];
    const update: Partial<DailyExperienceRecord> = { answeredUserIds };
    if (answeredUserIds.length === 2) {
      const revealedAnswers: Record<string, number> = {};
      for (const memberID of couple.memberIds) {
        if (memberID === userId) {
          revealedAnswers[memberID] = optionIndex;
          continue;
        }
        const snapshot = await transaction.get(ref.collection("answers").doc(memberID));
        const storedAnswer = snapshot.data()?.optionIndex;
        if (typeof storedAnswer !== "number") {
          throw new DomainError("daily-not-found", "failed-precondition", "Answers are incomplete.");
        }
        revealedAnswers[memberID] = storedAnswer;
      }
      update.revealedAnswers = revealedAnswers;
    }
    transaction.create(answerRef, { optionIndex });
    transaction.update(ref, update);

    // The submitter is looking at the result already; only the partner needs telling.
    const partnerIds = couple.memberIds.filter((memberId) => memberId !== userId);
    return {
      id: experienceId,
      experience: { ...record, ...update },
      notify: partnerIds.length > 0
        ? {
            userIds: partnerIds,
            event: update.revealedAnswers ? "daily-revealed" : "partner-answered",
          } satisfies NotificationRequest
        : undefined,
    };
  });
}

export async function createDecisionForUser(
  database: Firestore,
  userId: string,
  untrustedCoupleId: unknown,
  untrustedDecisionId: unknown,
  untrustedTitle: unknown,
  untrustedOptions: unknown,
): Promise<{
  id: string;
  coupleId: string;
  decision: DecisionRecord;
  notify?: NotificationRequest;
}> {
  const coupleId = requireDocumentId(untrustedCoupleId, "invalid-decision");
  const decisionId = requireDecisionId(untrustedDecisionId);
  const draft = decisionDraft(untrustedTitle, untrustedOptions);
  const coupleRef = database.collection(COUPLES).doc(coupleId);
  const decisionRef = coupleRef.collection(DECISIONS).doc(decisionId);

  return database.runTransaction(async (transaction) => {
    const { partnerId: responderId } = await requireActiveMembership(
      transaction,
      database,
      userId,
      coupleId,
    );
    const decisionSnapshot = await transaction.get(decisionRef);

    if (decisionSnapshot.exists) {
      const existing = decisionSnapshot.data() as DecisionRecord;
      if (
        existing.creatorId !== userId ||
        existing.responderId !== responderId ||
        existing.title !== draft.title ||
        JSON.stringify(existing.options) !== JSON.stringify(draft.options)
      ) {
        throw new DomainError("invalid-decision", "already-exists", "Decision is invalid.");
      }
      return { id: decisionId, coupleId, decision: existing };
    }

    const decision: DecisionRecord = {
      ...draft,
      creatorId: userId,
      responderId,
      status: "waitingForPartner",
      createdAt: Timestamp.now(),
    };
    transaction.create(decisionRef, decision);
    return {
      id: decisionId,
      coupleId,
      decision,
      notify: { userIds: [responderId], event: "decision-asked" } satisfies NotificationRequest,
    };
  });
}

export async function resolveDecisionForUser(
  database: Firestore,
  userId: string,
  untrustedCoupleId: unknown,
  untrustedDecisionId: unknown,
  untrustedOptionIndex: unknown,
): Promise<{
  id: string;
  coupleId: string;
  decision: DecisionRecord;
  notify?: NotificationRequest;
}> {
  const coupleId = requireDocumentId(untrustedCoupleId, "invalid-decision");
  const decisionId = requireDecisionId(untrustedDecisionId);
  if (!Number.isInteger(untrustedOptionIndex) || (untrustedOptionIndex as number) < 0) {
    throw new DomainError("invalid-decision", "invalid-argument", "Decision is invalid.");
  }
  const optionIndex = untrustedOptionIndex as number;
  const userRef = database.collection(USERS).doc(userId);
  const coupleRef = database.collection(COUPLES).doc(coupleId);
  const decisionRef = coupleRef.collection(DECISIONS).doc(decisionId);

  return database.runTransaction(async (transaction) => {
    const [userSnapshot, coupleSnapshot, decisionSnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(coupleRef),
      transaction.get(decisionRef),
    ]);
    if (!userSnapshot.exists || optionalString(userSnapshot.get("activeCoupleId")) !== coupleId) {
      throw new DomainError("permission-denied", "permission-denied", "Membership is required.");
    }
    const couple = coupleSnapshot.data() as CoupleRecord | undefined;
    if (!couple?.memberIds.includes(userId)) {
      throw new DomainError("permission-denied", "permission-denied", "Membership is required.");
    }
    if (!decisionSnapshot.exists) {
      throw new DomainError("decision-not-found", "not-found", "Decision was not found.");
    }

    const decision = decisionSnapshot.data() as DecisionRecord;
    if (decision.responderId !== userId || decision.creatorId === userId) {
      throw new DomainError(
        "not-decision-responder",
        "permission-denied",
        "Only the requested partner can resolve this decision.",
      );
    }
    if (optionIndex >= decision.options.length) {
      throw new DomainError("invalid-decision", "invalid-argument", "Decision is invalid.");
    }
    if (decision.status === "resolved") {
      if (decision.selectedOptionIndex === optionIndex) {
        return { id: decisionId, coupleId, decision };
      }
      throw new DomainError(
        "decision-already-resolved",
        "failed-precondition",
        "Decision is already resolved.",
      );
    }
    if (decision.status !== "waitingForPartner") {
      throw new DomainError("invalid-decision", "failed-precondition", "Decision is invalid.");
    }

    const resolved: DecisionRecord = {
      ...decision,
      status: "resolved",
      selectedOptionIndex: optionIndex,
      resolvedAt: Timestamp.now(),
    };
    transaction.set(decisionRef, resolved, { merge: false });
    return {
      id: decisionId,
      coupleId,
      decision: resolved,
      notify: {
        userIds: [decision.creatorId],
        event: "decision-resolved",
      } satisfies NotificationRequest,
    };
  });
}

/**
 * Establishes that the caller is one of two people in an active Couple, and
 * says who the other one is.
 *
 * Every shared-surface command needs exactly this, and each one used to spell
 * it out again. Divergence between those copies would be a permission bug, so
 * there is now one copy.
 */
async function requireActiveMembership(
  transaction: Transaction,
  database: Firestore,
  userId: string,
  coupleId: string,
): Promise<{ couple: CoupleRecord; partnerId: string }> {
  const [userSnapshot, coupleSnapshot] = await Promise.all([
    transaction.get(database.collection(USERS).doc(userId)),
    transaction.get(database.collection(COUPLES).doc(coupleId)),
  ]);
  if (!userSnapshot.exists) {
    throw new DomainError("profile-required", "failed-precondition", "Profile is required.");
  }
  if (optionalString(userSnapshot.get("activeCoupleId")) !== coupleId) {
    throw new DomainError("permission-denied", "permission-denied", "Membership is required.");
  }

  const couple = coupleSnapshot.data() as CoupleRecord | undefined;
  const members = new Set(couple?.memberIds ?? []);
  const partnerId = couple?.memberIds.find((memberId) => memberId !== userId);
  if (
    !couple ||
    couple.status !== "active" ||
    couple.memberIds.length !== 2 ||
    members.size !== 2 ||
    !members.has(userId) ||
    !partnerId
  ) {
    throw new DomainError("permission-denied", "permission-denied", "Membership is required.");
  }
  return { couple, partnerId };
}

/** The Couple's open run, if one of them is standing in a store right now. */
async function activeRun(
  transaction: Transaction,
  database: Firestore,
  coupleId: string,
): Promise<{ id: string; run: MarketRunRecord } | undefined> {
  const snapshot = await transaction.get(
    database
      .collection(COUPLES)
      .doc(coupleId)
      .collection(MARKET_RUNS)
      .where("status", "==", "active")
      .limit(1),
  );
  const document = snapshot.docs[0];
  return document ? { id: document.id, run: document.data() as MarketRunRecord } : undefined;
}

/**
 * Moves everything already gathered out of the live list and into history.
 *
 * Reads must precede writes inside a transaction, so the caller passes the
 * snapshot it already read. Sweeping *all* gathered items rather than only the
 * ones this run touched is deliberate: items ticked off at home, with no run
 * open, would otherwise sit in the basket forever.
 */
function sweepGathered(
  transaction: Transaction,
  coupleRef: DocumentReference,
  gathered: FirebaseFirestore.QuerySnapshot,
  runId: string | undefined,
): number {
  const archivedAt = Timestamp.now();
  let swept = 0;

  for (const document of gathered.docs) {
    const record = marketHistoryRecord(
      document.data() as MarketItemRecord,
      archivedAt,
      runId,
    );
    if (!record) continue;
    transaction.create(coupleRef.collection(MARKET_HISTORY).doc(document.id), record);
    transaction.delete(document.ref);
    swept += 1;
  }
  return swept;
}

function gatheredQuery(coupleRef: DocumentReference) {
  return coupleRef
    .collection(MARKET_ITEMS)
    .where("status", "==", "gathered")
    .limit(MARKET_SWEEP_MAX_ITEMS);
}

export async function addMarketItemForUser(
  database: Firestore,
  userId: string,
  untrustedCoupleId: unknown,
  untrustedItemId: unknown,
  untrustedName: unknown,
  untrustedNote: unknown,
  untrustedIsRequest: unknown,
): Promise<{
  id: string;
  coupleId: string;
  item: MarketItemRecord;
  notify?: NotificationRequest;
}> {
  const coupleId = requireDocumentId(untrustedCoupleId, "invalid-market-item");
  const itemId = requireMarketId(untrustedItemId);
  const draft = marketItemDraft(untrustedName, untrustedNote, untrustedIsRequest);
  const coupleRef = database.collection(COUPLES).doc(coupleId);
  const itemRef = coupleRef.collection(MARKET_ITEMS).doc(itemId);

  return database.runTransaction(async (transaction) => {
    const { partnerId } = await requireActiveMembership(transaction, database, userId, coupleId);
    const [itemSnapshot, run, pending] = await Promise.all([
      transaction.get(itemRef),
      activeRun(transaction, database, coupleId),
      transaction.get(
        coupleRef
          .collection(MARKET_ITEMS)
          .where("status", "==", "pending")
          .limit(MARKET_LIST_MAX_ITEMS),
      ),
    ]);

    // The client retries with the same id, so a replay is a read, not a second
    // item — and must not fire the notification again.
    if (itemSnapshot.exists) {
      return { id: itemId, coupleId, item: itemSnapshot.data() as MarketItemRecord };
    }
    if (pending.size >= MARKET_LIST_MAX_ITEMS) {
      throw new DomainError("market-list-full", "resource-exhausted", "List is full.");
    }

    const item: MarketItemRecord = {
      ...draft,
      requestedBy: userId,
      requestedAt: Timestamp.now(),
      status: "pending",
    };
    transaction.create(itemRef, item);

    /**
     * Someone standing in a store is the only person this can still reach in
     * time, so they outrank the ordinary "bring this" ask. Adding to your own
     * list while you are the one shopping tells nobody anything.
     */
    const notify: NotificationRequest | undefined =
      run && run.run.shopperId !== userId
        ? { userIds: [run.run.shopperId], event: "market-item-added", subject: draft.name }
        : !run && draft.isRequest
          ? { userIds: [partnerId], event: "market-item-requested", subject: draft.name }
          : undefined;

    return { id: itemId, coupleId, item, notify };
  });
}

export async function setMarketItemStatusForUser(
  database: Firestore,
  userId: string,
  untrustedCoupleId: unknown,
  untrustedItemId: unknown,
  untrustedStatus: unknown,
): Promise<{ id: string; coupleId: string; item: MarketItemRecord }> {
  const coupleId = requireDocumentId(untrustedCoupleId, "invalid-market-item");
  const itemId = requireMarketId(untrustedItemId);
  const status: MarketItemStatus = requireMarketItemStatus(untrustedStatus);
  const itemRef = database
    .collection(COUPLES)
    .doc(coupleId)
    .collection(MARKET_ITEMS)
    .doc(itemId);

  return database.runTransaction(async (transaction) => {
    await requireActiveMembership(transaction, database, userId, coupleId);
    const snapshot = await transaction.get(itemRef);
    if (!snapshot.exists) {
      throw new DomainError("market-item-not-found", "not-found", "Item was not found.");
    }

    const existing = snapshot.data() as MarketItemRecord;
    if (existing.status === status) {
      return { id: itemId, coupleId, item: existing };
    }

    const item: MarketItemRecord =
      status === "gathered"
        ? { ...existing, status, gatheredBy: userId, gatheredAt: Timestamp.now() }
        : {
            name: existing.name,
            ...(existing.note === undefined ? {} : { note: existing.note }),
            isRequest: existing.isRequest,
            requestedBy: existing.requestedBy,
            requestedAt: existing.requestedAt,
            status,
          };
    transaction.set(itemRef, item, { merge: false });
    return { id: itemId, coupleId, item };
  });
}

export async function removeMarketItemForUser(
  database: Firestore,
  userId: string,
  untrustedCoupleId: unknown,
  untrustedItemId: unknown,
): Promise<{ id: string; coupleId: string }> {
  const coupleId = requireDocumentId(untrustedCoupleId, "invalid-market-item");
  const itemId = requireMarketId(untrustedItemId);
  const itemRef = database
    .collection(COUPLES)
    .doc(coupleId)
    .collection(MARKET_ITEMS)
    .doc(itemId);

  return database.runTransaction(async (transaction) => {
    await requireActiveMembership(transaction, database, userId, coupleId);
    // Removing what is already gone is what the caller wanted; a retry of a
    // delete that succeeded must not read as a failure.
    transaction.delete(itemRef);
    return { id: itemId, coupleId };
  });
}

export async function startMarketRunForUser(
  database: Firestore,
  userId: string,
  untrustedCoupleId: unknown,
  untrustedRunId: unknown,
): Promise<{
  id: string;
  coupleId: string;
  run: MarketRunRecord;
  notify?: NotificationRequest;
}> {
  const coupleId = requireDocumentId(untrustedCoupleId, "invalid-market-item");
  const runId = requireMarketId(untrustedRunId);
  const runRef = database.collection(COUPLES).doc(coupleId).collection(MARKET_RUNS).doc(runId);

  return database.runTransaction(async (transaction) => {
    const { partnerId } = await requireActiveMembership(transaction, database, userId, coupleId);
    const existing = await activeRun(transaction, database, coupleId);

    // One run at a time per Couple. A second caller — a retry, or the partner
    // arriving at the same store — joins the run that is already open rather
    // than opening a rival one.
    if (existing) {
      return { id: existing.id, coupleId, run: existing.run };
    }

    const run: MarketRunRecord = {
      shopperId: userId,
      status: "active",
      startedAt: Timestamp.now(),
    };
    transaction.create(runRef, run);

    return {
      id: runId,
      coupleId,
      run,
      notify: { userIds: [partnerId], event: "market-run-started" } satisfies NotificationRequest,
    };
  });
}

export async function finishMarketRunForUser(
  database: Firestore,
  userId: string,
  untrustedCoupleId: unknown,
  untrustedRunId: unknown,
): Promise<{ id: string; coupleId: string; run: MarketRunRecord; swept: number }> {
  const coupleId = requireDocumentId(untrustedCoupleId, "invalid-market-item");
  const runId = requireMarketId(untrustedRunId);
  const coupleRef = database.collection(COUPLES).doc(coupleId);
  const runRef = coupleRef.collection(MARKET_RUNS).doc(runId);

  return database.runTransaction(async (transaction) => {
    await requireActiveMembership(transaction, database, userId, coupleId);
    // Every read first: a transaction cannot read after it has written.
    const [snapshot, gathered] = await Promise.all([
      transaction.get(runRef),
      transaction.get(gatheredQuery(coupleRef)),
    ]);
    if (!snapshot.exists) {
      throw new DomainError("market-run-not-found", "not-found", "Run was not found.");
    }

    const existing = snapshot.data() as MarketRunRecord;
    if (existing.shopperId !== userId) {
      throw new DomainError(
        "not-market-shopper",
        "permission-denied",
        "Only the person at the store can end this run.",
      );
    }
    if (existing.status === "finished") {
      return { id: runId, coupleId, run: existing, swept: 0 };
    }

    const run: MarketRunRecord = { ...existing, status: "finished", endedAt: Timestamp.now() };
    transaction.set(runRef, run, { merge: false });
    const swept = sweepGathered(transaction, coupleRef, gathered, runId);
    return { id: runId, coupleId, run, swept };
  });
}

/**
 * Empties the basket without a run having happened — the case where things were
 * ticked off at home. Same sweep, reachable on its own.
 */
export async function clearGatheredMarketItemsForUser(
  database: Firestore,
  userId: string,
  untrustedCoupleId: unknown,
): Promise<{ coupleId: string; swept: number }> {
  const coupleId = requireDocumentId(untrustedCoupleId, "invalid-market-item");
  const coupleRef = database.collection(COUPLES).doc(coupleId);

  return database.runTransaction(async (transaction) => {
    await requireActiveMembership(transaction, database, userId, coupleId);
    const gathered = await transaction.get(gatheredQuery(coupleRef));
    return { coupleId, swept: sweepGathered(transaction, coupleRef, gathered, undefined) };
  });
}

export async function createChoreForUser(
  database: Firestore,
  userId: string,
  untrustedCoupleId: unknown,
  untrustedChoreId: unknown,
  untrustedTitle: unknown,
  untrustedCadenceDays: unknown,
  untrustedRotation: unknown,
  untrustedFirstOwnerId: unknown,
): Promise<{ id: string; coupleId: string; chore: ChoreRecord }> {
  const coupleId = requireDocumentId(untrustedCoupleId, "invalid-chore");
  const choreId = requireChoreId(untrustedChoreId);
  const draft = choreDraft(untrustedTitle, untrustedCadenceDays, untrustedRotation);
  const coupleRef = database.collection(COUPLES).doc(coupleId);
  const choreRef = coupleRef.collection(CHORES).doc(choreId);

  return database.runTransaction(async (transaction) => {
    const { couple } = await requireActiveMembership(transaction, database, userId, coupleId);
    const [snapshot, active] = await Promise.all([
      transaction.get(choreRef),
      transaction.get(coupleRef.collection(CHORES).where("status", "==", "active").limit(CHORE_LIST_MAX)),
    ]);

    // A retry of a create that already landed reads it back rather than
    // rejecting, so a flaky connection never costs the user their entry.
    if (snapshot.exists) {
      return { id: choreId, coupleId, chore: snapshot.data() as ChoreRecord };
    }
    if (active.size >= CHORE_LIST_MAX) {
      throw new DomainError("chore-list-full", "resource-exhausted", "Chore list is full.");
    }

    // An owner is only meaningful when someone in particular has the turn, and
    // it has to be a real member — a client cannot hand a chore to a stranger.
    const requestedOwner = optionalString(untrustedFirstOwnerId);
    const ownerId =
      draft.rotation === "anyone"
        ? null
        : requestedOwner && couple.memberIds.includes(requestedOwner)
          ? requestedOwner
          : userId;

    const now = Timestamp.now();
    const chore: ChoreRecord = {
      ...draft,
      ownerId,
      status: "active",
      // Due immediately: a chore added today is a chore somebody is thinking
      // about today. Waiting a full cadence to first ask would be strange.
      dueAt: now,
      createdBy: userId,
      createdAt: now,
    };
    transaction.create(choreRef, chore);
    return { id: choreId, coupleId, chore };
  });
}

export async function completeChoreForUser(
  database: Firestore,
  userId: string,
  untrustedCoupleId: unknown,
  untrustedChoreId: unknown,
  untrustedExpectedDueAtMillis: unknown,
): Promise<{
  id: string;
  coupleId: string;
  chore: ChoreRecord;
  notify?: NotificationRequest;
}> {
  const coupleId = requireDocumentId(untrustedCoupleId, "invalid-chore");
  const choreId = requireChoreId(untrustedChoreId);
  if (!Number.isInteger(untrustedExpectedDueAtMillis)) {
    throw new DomainError("invalid-chore", "invalid-argument", "Chore is invalid.");
  }
  const expectedDueAtMillis = untrustedExpectedDueAtMillis as number;
  const choreRef = database.collection(COUPLES).doc(coupleId).collection(CHORES).doc(choreId);

  return database.runTransaction(async (transaction) => {
    const { couple, partnerId } = await requireActiveMembership(
      transaction,
      database,
      userId,
      coupleId,
    );
    const snapshot = await transaction.get(choreRef);
    if (!snapshot.exists) {
      throw new DomainError("chore-not-found", "not-found", "Chore was not found.");
    }

    const chore = snapshot.data() as ChoreRecord;

    /**
     * Optimistic concurrency, and the reason both people can hold this screen
     * at once. The caller says which cycle it meant to finish; if the chore has
     * already moved past it — the other person got there first, or this is a
     * retry of a call that landed — the cycle is simply already done. Returning
     * the current chore is the honest answer, and it advances nothing twice.
     */
    if (chore.dueAt.toMillis() !== expectedDueAtMillis) {
      return { id: choreId, coupleId, chore };
    }
    if (chore.status === "done") {
      throw new DomainError("chore-already-done", "failed-precondition", "Chore is done.");
    }
    if (chore.rotation !== "anyone" && chore.ownerId !== null && chore.ownerId !== userId) {
      throw new DomainError(
        "not-chore-owner",
        "permission-denied",
        "This chore belongs to the other person's turn.",
      );
    }

    const advanced = advanceChore(chore, couple.memberIds, userId, Timestamp.now());
    transaction.set(choreRef, advanced, { merge: false });

    return {
      id: choreId,
      coupleId,
      chore: advanced,
      notify: {
        userIds: [partnerId],
        event: "chore-done",
        subject: chore.title,
      } satisfies NotificationRequest,
    };
  });
}

export async function removeChoreForUser(
  database: Firestore,
  userId: string,
  untrustedCoupleId: unknown,
  untrustedChoreId: unknown,
): Promise<{ id: string; coupleId: string }> {
  const coupleId = requireDocumentId(untrustedCoupleId, "invalid-chore");
  const choreId = requireChoreId(untrustedChoreId);
  const choreRef = database.collection(COUPLES).doc(coupleId).collection(CHORES).doc(choreId);

  return database.runTransaction(async (transaction) => {
    await requireActiveMembership(transaction, database, userId, coupleId);
    transaction.delete(choreRef);
    return { id: choreId, coupleId };
  });
}
