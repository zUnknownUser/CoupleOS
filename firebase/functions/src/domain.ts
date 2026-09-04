import { createHash, randomBytes } from "node:crypto";
import { Timestamp } from "firebase-admin/firestore";
import type { FunctionsErrorCode } from "firebase-functions/https";

export const INVITE_LIFETIME_DAYS = 7;
export const INVITE_LIFETIME_MS = INVITE_LIFETIME_DAYS * 24 * 60 * 60 * 1000;
/**
 * The question the daily moment asks, as an identity rather than a sentence.
 *
 * One document is shared by both people, and they can be reading in different
 * languages, so the text cannot be the thing that is stored. The English copy
 * below still is — an older client that knows nothing about ids has to keep
 * working — but a current client renders from the id and ignores it.
 */
export const DAILY_PROMPT_ID = "everyday";

export const DAILY_OPTIONS = [
  "Stay in and make it cozy",
  "Go somewhere new",
  "Watch something together",
  "Just talk for a while",
  "Let the other person choose",
] as const;

export const DEFAULT_TIME_ZONE = "UTC";
export const DECISION_TITLE_MAX_LENGTH = 160;
export const DECISION_OPTION_MAX_LENGTH = 80;
export const DECISION_MIN_OPTIONS = 2;
export const DECISION_MAX_OPTIONS = 6;
export const MARKET_ITEM_NAME_MAX_LENGTH = 80;
export const MARKET_ITEM_NOTE_MAX_LENGTH = 200;
/** A list past this stopped being a list a long time ago. */
export const MARKET_LIST_MAX_ITEMS = 200;
/**
 * How many gathered items one sweep may archive.
 *
 * Each archived item costs two writes (a create and a delete) inside a single
 * transaction, and Firestore caps a transaction at 500. This leaves room for
 * the run document itself with a wide margin.
 */
export const MARKET_SWEEP_MAX_ITEMS = 200;
export const CHORE_TITLE_MAX_LENGTH = 80;
export const CHORE_MAX_CADENCE_DAYS = 365;
export const CHORE_LIST_MAX = 100;

export type CoupleStatus = "waitingForPartner" | "active";
export type InviteStatus = "pending" | "accepted" | "revoked";
export type DecisionStatus = "waitingForPartner" | "resolved";
export type MarketItemStatus = "pending" | "gathered";
export type MarketRunStatus = "active" | "finished";
export type ChoreRotation = "alternates" | "fixed" | "anyone";
export type ChoreStatus = "active" | "done";

export interface CoupleRecord {
  memberIds: string[];
  status: CoupleStatus;
  createdBy: string;
  createdAt: Timestamp;
  activatedAt?: Timestamp;
  activeInviteId?: string;
  timeZone?: string;
}

export interface InviteRecord {
  coupleId: string;
  createdBy: string;
  status: InviteStatus;
  createdAt: Timestamp;
  expiresAt: Timestamp;
  acceptedBy?: string;
  acceptedAt?: Timestamp;
  revokedAt?: Timestamp;
}

export interface DailyExperienceRecord {
  periodKey: string;
  /** Which question this is. Absent on documents written before ids existed. */
  promptId?: string;
  prompt: string;
  options: string[];
  answeredUserIds: string[];
  revealedAnswers?: Record<string, number>;
}

export interface DecisionRecord {
  title: string;
  options: string[];
  creatorId: string;
  responderId: string;
  status: DecisionStatus;
  createdAt: Timestamp;
  selectedOptionIndex?: number;
  resolvedAt?: Timestamp;
}

export interface MarketItemRecord {
  name: string;
  note?: string;
  isRequest: boolean;
  requestedBy: string;
  requestedAt: Timestamp;
  status: MarketItemStatus;
  gatheredBy?: string;
  gatheredAt?: Timestamp;
}

/**
 * A bought item, after the trip that bought it ended.
 *
 * History lives in its own collection rather than behind a flag so the live
 * listener never grows: a Couple can shop weekly for a decade and the list
 * query stays the same size. It is also the only reason a future "you buy
 * coffee every three weeks" can be derived from what actually happened rather
 * than guessed.
 */
export interface MarketHistoryRecord {
  name: string;
  note?: string;
  isRequest: boolean;
  requestedBy: string;
  requestedAt: Timestamp;
  gatheredBy: string;
  gatheredAt: Timestamp;
  archivedAt: Timestamp;
  runId?: string;
}

export interface MarketRunRecord {
  shopperId: string;
  status: MarketRunStatus;
  startedAt: Timestamp;
  endedAt?: Timestamp;
}

/**
 * A chore and whose turn it is.
 *
 * `cadenceDays` of `null` marks a one-off: doing it finishes it. Anything else
 * is how many days after a completion the home needs it again — measured from
 * when it was actually done, not from when it was last due, so falling behind
 * never stacks up a backlog nobody can clear.
 */
export interface ChoreRecord {
  title: string;
  cadenceDays: number | null;
  rotation: ChoreRotation;
  ownerId: string | null;
  status: ChoreStatus;
  dueAt: Timestamp;
  lastDoneBy?: string;
  lastDoneAt?: Timestamp;
  createdBy: string;
  createdAt: Timestamp;
}

export type DomainErrorCode =
  | "authentication-required"
  | "profile-required"
  | "already-in-couple"
  | "couple-not-found"
  | "couple-already-full"
  | "permission-denied"
  | "invite-invalid"
  | "invite-expired"
  | "invite-already-used"
  | "cannot-accept-own-invite"
  | "daily-not-found"
  | "already-answered"
  | "invalid-daily-answer"
  | "decision-not-found"
  | "invalid-decision"
  | "not-decision-responder"
  | "decision-already-resolved"
  | "invalid-market-item"
  | "market-item-not-found"
  | "market-run-not-found"
  | "not-market-shopper"
  | "market-run-finished"
  | "market-list-full"
  | "invalid-chore"
  | "chore-not-found"
  | "not-chore-owner"
  | "chore-already-done"
  | "chore-list-full";

export class DomainError extends Error {
  constructor(
    readonly domainCode: DomainErrorCode,
    readonly httpsCode: FunctionsErrorCode,
    message: string,
  ) {
    super(message);
    this.name = "DomainError";
  }
}

export function generateInviteToken(): string {
  return randomBytes(32).toString("base64url");
}

export function hashInviteToken(token: string): string {
  return createHash("sha256").update(token, "utf8").digest("hex");
}

/** What a completed command wants the recipients to be told about. */
export type NotificationEvent =
  | "partner-answered"
  | "daily-revealed"
  | "partner-joined"
  | "decision-asked"
  | "decision-resolved"
  | "market-run-started"
  | "market-item-requested"
  | "market-item-added"
  | "chore-done";

export interface NotificationRequest {
  userIds: string[];
  event: NotificationEvent;
  /**
   * What the event is about, when it is about a nameable thing.
   *
   * A notification that says "something" makes the reader open the app to find
   * out what. In a store aisle that round trip is the whole cost, so events
   * that can name their subject do.
   */
  subject?: string;
}

/**
 * The languages the app ships, as the client writes them onto a device record.
 * Kept in step with `AppLanguage` on iOS by hand: this is a short, closed list,
 * and the alternative — inferring copy at runtime — is how a notification ends
 * up in a language nobody chose.
 */
export const NOTIFICATION_LANGUAGES = ["en", "pt-BR"] as const;
export type NotificationLanguage = (typeof NOTIFICATION_LANGUAGES)[number];
export const DEFAULT_NOTIFICATION_LANGUAGE: NotificationLanguage = "en";

/**
 * The language a device asked for, if we speak it.
 *
 * Matched on the primary subtag, exactly as the client does, so an older
 * install that wrote a bare "pt" — or a device record from before language was
 * stored at all — still lands somewhere sensible instead of failing.
 */
export function notificationLanguage(value: unknown): NotificationLanguage {
  if (typeof value !== "string") return DEFAULT_NOTIFICATION_LANGUAGE;
  const primary = value.replace(/_/g, "-").split("-")[0]?.toLowerCase();
  if (primary === "pt") return "pt-BR";
  if (primary === "en") return "en";
  return DEFAULT_NOTIFICATION_LANGUAGE;
}

export interface NotificationCopy {
  title: string;
  body: string;
  /** Used instead of `body` when the request carries a subject. */
  bodyWith?: (subject: string) => string;
}

export const NOTIFICATION_COPY: Record<
  NotificationLanguage,
  Record<NotificationEvent, NotificationCopy>
> = {
  en: {
    "partner-answered": {
      title: "Today",
      body: "Your person left something here for you.",
    },
    "daily-revealed": {
      title: "Today",
      body: "You both left a mark. See what it means.",
    },
    "partner-joined": {
      title: "Your world is shared",
      body: "Your person just joined you.",
    },
    "decision-asked": {
      title: "A decision",
      body: "Your person is waiting on your pick.",
    },
    "decision-resolved": {
      title: "Decided",
      body: "Your person made the call. See what it is.",
    },
    /**
     * The one notification the Market module exists for. It is deliberately
     * urgent-sounding: unlike everything else here, it stops being actionable
     * the moment your person walks out of the store.
     */
    "market-run-started": {
      title: "At the market",
      body: "Your person is at the store. Anything you need?",
    },
    "market-item-requested": {
      title: "One thing",
      body: "Your person asked you to bring something home.",
      bodyWith: (subject) => `Your person asked you to bring ${subject}.`,
    },
    /**
     * Someone added to the list while the other is standing in the store. A
     * different moment from an ask, and it reads differently: nobody is being
     * asked for a favour, the basket simply grew.
     */
    "market-item-added": {
      title: "At the market",
      body: "Something was just added to your list.",
      bodyWith: (subject) => `Added to your list: ${subject}`,
    },
    /**
     * Sent on completion, never on lateness. A chore that nags is a chore that
     * gets the whole app muted, and being told what your person did for the
     * home is the half of this worth delivering.
     */
    "chore-done": {
      title: "Taken care of",
      body: "Your person took care of something at home.",
      bodyWith: (subject) => `Your person took care of ${subject}.`,
    },
  },
  /**
   * Portuguese keeps "sua pessoa" for the same reason English keeps "your
   * person": it names someone warmly without gendering them, which matters
   * here because the backend never learns who the other person is.
   */
  "pt-BR": {
    "partner-answered": {
      title: "Hoje",
      body: "Sua pessoa deixou algo aqui para você.",
    },
    "daily-revealed": {
      title: "Hoje",
      body: "Vocês dois deixaram uma marca. Veja o que significa.",
    },
    "partner-joined": {
      title: "O mundo agora é dos dois",
      body: "Sua pessoa acabou de entrar.",
    },
    "decision-asked": {
      title: "Uma decisão",
      body: "Sua pessoa está esperando sua escolha.",
    },
    "decision-resolved": {
      title: "Decidido",
      body: "Sua pessoa escolheu. Veja o que ficou.",
    },
    "market-run-started": {
      title: "No mercado",
      body: "Sua pessoa está no mercado. Precisa de alguma coisa?",
    },
    "market-item-requested": {
      title: "Uma coisa",
      body: "Sua pessoa pediu para você trazer algo.",
      bodyWith: (subject) => `Sua pessoa pediu para você trazer ${subject}.`,
    },
    "market-item-added": {
      title: "No mercado",
      body: "Algo acabou de entrar na sua lista.",
      bodyWith: (subject) => `Adicionado à sua lista: ${subject}`,
    },
    "chore-done": {
      title: "Resolvido",
      body: "Sua pessoa cuidou de algo em casa.",
      bodyWith: (subject) => `Sua pessoa cuidou de ${subject}.`,
    },
  },
};

/** The words for one event, in one language. */
export function notificationCopy(
  event: NotificationEvent,
  language: NotificationLanguage,
): NotificationCopy {
  return NOTIFICATION_COPY[language][event];
}

/** Callable payloads arrive untyped; ids are used to build document paths. */
export function requireDocumentId(
  value: unknown,
  errorCode: DomainErrorCode = "invalid-daily-answer",
): string {
  if (
    typeof value !== "string" ||
    value.length === 0 ||
    value.length > 200 ||
    value.includes("/") ||
    value === "." ||
    value === ".."
  ) {
    throw new DomainError(errorCode, "invalid-argument", "Request is invalid.");
  }
  return value;
}

export function requireInviteToken(value: unknown): string {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{43}$/.test(value)) {
    throw new DomainError("invite-invalid", "invalid-argument", "Invite is invalid.");
  }
  return value;
}

export function requireDecisionId(value: unknown): string {
  if (
    typeof value !== "string" ||
    !/^[0-9a-fA-F-]{36}$/.test(value) ||
    value.includes("/")
  ) {
    throw new DomainError("invalid-decision", "invalid-argument", "Decision is invalid.");
  }
  return value;
}

export function decisionDraft(
  untrustedTitle: unknown,
  untrustedOptions: unknown,
): { title: string; options: string[] } {
  if (typeof untrustedTitle !== "string" || !Array.isArray(untrustedOptions)) {
    throw new DomainError("invalid-decision", "invalid-argument", "Decision is invalid.");
  }

  const title = untrustedTitle.trim();
  const options = untrustedOptions.map((option) =>
    typeof option === "string" ? option.trim() : "",
  );
  const normalized = options.map((option) => option.toLocaleLowerCase("en-US"));
  const hasInvalidOption = options.some(
    (option) => option.length === 0 || option.length > DECISION_OPTION_MAX_LENGTH,
  );

  if (
    title.length === 0 ||
    title.length > DECISION_TITLE_MAX_LENGTH ||
    options.length < DECISION_MIN_OPTIONS ||
    options.length > DECISION_MAX_OPTIONS ||
    hasInvalidOption ||
    new Set(normalized).size !== normalized.length
  ) {
    throw new DomainError("invalid-decision", "invalid-argument", "Decision is invalid.");
  }

  return { title, options };
}

export function requireMarketId(value: unknown): string {
  if (typeof value !== "string" || !/^[0-9a-fA-F-]{36}$/.test(value)) {
    throw new DomainError("invalid-market-item", "invalid-argument", "Item is invalid.");
  }
  return value;
}

export function marketItemDraft(
  untrustedName: unknown,
  untrustedNote: unknown,
  untrustedIsRequest: unknown,
): { name: string; note?: string; isRequest: boolean } {
  if (typeof untrustedName !== "string") {
    throw new DomainError("invalid-market-item", "invalid-argument", "Item is invalid.");
  }
  const name = untrustedName.trim();
  if (name.length === 0 || name.length > MARKET_ITEM_NAME_MAX_LENGTH) {
    throw new DomainError("invalid-market-item", "invalid-argument", "Item is invalid.");
  }

  const note =
    typeof untrustedNote === "string" && untrustedNote.trim().length > 0
      ? untrustedNote.trim()
      : undefined;
  if (note !== undefined && note.length > MARKET_ITEM_NOTE_MAX_LENGTH) {
    throw new DomainError("invalid-market-item", "invalid-argument", "Item is invalid.");
  }

  // The key is omitted rather than set to `undefined`: Firestore rejects an
  // undefined value outright, and this draft is spread straight into the
  // document, so an absent note would fail every note-less item.
  return {
    name,
    isRequest: untrustedIsRequest === true,
    ...(note === undefined ? {} : { note }),
  };
}

export function requireMarketItemStatus(value: unknown): MarketItemStatus {
  if (value !== "pending" && value !== "gathered") {
    throw new DomainError("invalid-market-item", "invalid-argument", "Item is invalid.");
  }
  return value;
}

/**
 * A Couple shares one calendar, so the period a daily moment belongs to is
 * resolved in the Couple's own time zone rather than the caller's. Anything the
 * runtime cannot resolve falls back to UTC, which is what pre-time-zone Couples
 * were already keyed on.
 */
export function normalizeTimeZone(value: unknown): string | undefined {
  if (typeof value !== "string" || value.length === 0 || value.length > 64) {
    return undefined;
  }
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: value });
    return value;
  } catch {
    return undefined;
  }
}

export function periodKeyFor(date: Date, timeZone: string | undefined): string {
  const zone = normalizeTimeZone(timeZone) ?? DEFAULT_TIME_ZONE;
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: zone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const part = (type: string) =>
    parts.find((candidate) => candidate.type === type)?.value ?? "";
  return `${part("year")}-${part("month")}-${part("day")}`;
}

export function coupleResponse(id: string, couple: CoupleRecord) {
  return {
    id,
    memberIds: couple.memberIds,
    status: couple.status,
    createdBy: couple.createdBy,
    createdAtMillis: couple.createdAt.toMillis(),
    activatedAtMillis: couple.activatedAt?.toMillis() ?? null,
  };
}

export function dailyResponse(id: string, record: DailyExperienceRecord) {
  return {
    id,
    periodKey: record.periodKey,
    promptId: record.promptId ?? null,
    prompt: record.prompt,
    options: record.options,
    answeredUserIds: record.answeredUserIds,
    revealedAnswers: record.revealedAnswers ?? null,
  };
}

export function marketItemResponse(
  id: string,
  coupleId: string,
  record: MarketItemRecord,
) {
  return {
    id,
    coupleId,
    name: record.name,
    note: record.note ?? null,
    isRequest: record.isRequest,
    requestedBy: record.requestedBy,
    requestedAtMillis: record.requestedAt.toMillis(),
    status: record.status,
    gatheredBy: record.gatheredBy ?? null,
    gatheredAtMillis: record.gatheredAt?.toMillis() ?? null,
  };
}

/**
 * Turns a gathered item into its archive form, dropping keys with no value.
 *
 * Firestore rejects `undefined`, and this record is written straight to the
 * document, so an absent note has to be an absent key.
 */
export function requireChoreId(value: unknown): string {
  if (typeof value !== "string" || !/^[0-9a-fA-F-]{36}$/.test(value)) {
    throw new DomainError("invalid-chore", "invalid-argument", "Chore is invalid.");
  }
  return value;
}

export function choreDraft(
  untrustedTitle: unknown,
  untrustedCadenceDays: unknown,
  untrustedRotation: unknown,
): { title: string; cadenceDays: number | null; rotation: ChoreRotation } {
  if (typeof untrustedTitle !== "string") {
    throw new DomainError("invalid-chore", "invalid-argument", "Chore is invalid.");
  }
  const title = untrustedTitle.trim();
  if (title.length === 0 || title.length > CHORE_TITLE_MAX_LENGTH) {
    throw new DomainError("invalid-chore", "invalid-argument", "Chore is invalid.");
  }

  const rotation = untrustedRotation;
  if (rotation !== "alternates" && rotation !== "fixed" && rotation !== "anyone") {
    throw new DomainError("invalid-chore", "invalid-argument", "Chore is invalid.");
  }

  // `null` is a one-off, which is a different thing from a missing value.
  let cadenceDays: number | null = null;
  if (untrustedCadenceDays !== null && untrustedCadenceDays !== undefined) {
    if (
      !Number.isInteger(untrustedCadenceDays) ||
      (untrustedCadenceDays as number) < 1 ||
      (untrustedCadenceDays as number) > CHORE_MAX_CADENCE_DAYS
    ) {
      throw new DomainError("invalid-chore", "invalid-argument", "Chore is invalid.");
    }
    cadenceDays = untrustedCadenceDays as number;
  }

  return { title, cadenceDays, rotation };
}

/**
 * Where a chore stands after someone does it.
 *
 * A one-off is finished. Anything recurring gets a fresh due date counted from
 * the completion, and — when the rotation alternates — hands the turn to the
 * other person. Computing this on the server rather than the client is what
 * stops two devices from disagreeing about whose turn it is.
 */
export function advanceChore(
  chore: ChoreRecord,
  memberIds: string[],
  doneBy: string,
  doneAt: Timestamp,
): ChoreRecord {
  if (chore.cadenceDays === null) {
    return { ...chore, status: "done", lastDoneBy: doneBy, lastDoneAt: doneAt };
  }

  const nextOwnerId =
    chore.rotation === "alternates"
      ? (memberIds.find((memberId) => memberId !== doneBy) ?? chore.ownerId)
      : chore.ownerId;

  return {
    ...chore,
    ownerId: nextOwnerId,
    status: "active",
    dueAt: Timestamp.fromMillis(doneAt.toMillis() + chore.cadenceDays * 24 * 60 * 60 * 1000),
    lastDoneBy: doneBy,
    lastDoneAt: doneAt,
  };
}

export function choreResponse(id: string, coupleId: string, record: ChoreRecord) {
  return {
    id,
    coupleId,
    title: record.title,
    cadenceDays: record.cadenceDays,
    rotation: record.rotation,
    ownerId: record.ownerId,
    status: record.status,
    dueAtMillis: record.dueAt.toMillis(),
    lastDoneBy: record.lastDoneBy ?? null,
    lastDoneAtMillis: record.lastDoneAt?.toMillis() ?? null,
    createdBy: record.createdBy,
    createdAtMillis: record.createdAt.toMillis(),
  };
}

export function marketHistoryRecord(
  item: MarketItemRecord,
  archivedAt: Timestamp,
  runId: string | undefined,
): MarketHistoryRecord | undefined {
  // Only a genuinely gathered item can be archived; anything else is a
  // malformed document and is left alone rather than half-copied.
  if (item.status !== "gathered" || !item.gatheredBy || !item.gatheredAt) {
    return undefined;
  }
  return {
    name: item.name,
    isRequest: item.isRequest,
    requestedBy: item.requestedBy,
    requestedAt: item.requestedAt,
    gatheredBy: item.gatheredBy,
    gatheredAt: item.gatheredAt,
    archivedAt,
    ...(item.note === undefined ? {} : { note: item.note }),
    ...(runId === undefined ? {} : { runId }),
  };
}

export function marketRunResponse(id: string, coupleId: string, record: MarketRunRecord) {
  return {
    id,
    coupleId,
    shopperId: record.shopperId,
    status: record.status,
    startedAtMillis: record.startedAt.toMillis(),
    endedAtMillis: record.endedAt?.toMillis() ?? null,
  };
}

export function decisionResponse(id: string, coupleId: string, record: DecisionRecord) {
  return {
    id,
    coupleId,
    title: record.title,
    options: record.options,
    creatorId: record.creatorId,
    responderId: record.responderId,
    status: record.status,
    createdAtMillis: record.createdAt.toMillis(),
    selectedOptionIndex: record.selectedOptionIndex ?? null,
    resolvedAtMillis: record.resolvedAt?.toMillis() ?? null,
  };
}
