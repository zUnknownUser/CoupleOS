import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  DEFAULT_TIME_ZONE,
  decisionDraft,
  marketItemDraft,
  normalizeTimeZone,
  periodKeyFor,
  requireDecisionId,
  requireInviteToken,
  requireMarketId,
  requireMarketItemStatus,
  NOTIFICATION_COPY,
  marketHistoryRecord,
  advanceChore,
  choreDraft,
  requireChoreId,
  type ChoreRecord,
} from "../domain.js";
import { Timestamp } from "firebase-admin/firestore";

describe("Daily period keys", () => {
  it("resolves the day in the Couple's own time zone, not UTC", () => {
    // 01:00 UTC is still the previous evening in São Paulo (UTC-3).
    const instant = new Date("2026-09-03T01:00:00.000Z");

    assert.equal(periodKeyFor(instant, "America/Sao_Paulo"), "2026-09-02");
    assert.equal(periodKeyFor(instant, DEFAULT_TIME_ZONE), "2026-09-03");
  });

  it("rolls the day forward for Couples ahead of UTC", () => {
    const instant = new Date("2026-09-02T23:00:00.000Z");

    assert.equal(periodKeyFor(instant, "Asia/Tokyo"), "2026-09-03");
    assert.equal(periodKeyFor(instant, "America/Sao_Paulo"), "2026-09-02");
  });

  it("keeps both partners on one key across a local midnight", () => {
    const zone = "America/Sao_Paulo";
    const beforeMidnight = new Date("2026-09-03T02:59:00.000Z");
    const afterMidnight = new Date("2026-09-03T03:01:00.000Z");

    assert.equal(periodKeyFor(beforeMidnight, zone), "2026-09-02");
    assert.equal(periodKeyFor(afterMidnight, zone), "2026-09-03");
  });

  it("pads months and days to a stable document id", () => {
    assert.equal(
      periodKeyFor(new Date("2026-01-05T12:00:00.000Z"), DEFAULT_TIME_ZONE),
      "2026-01-05",
    );
  });

  it("falls back to UTC for Couples created before time zones were stored", () => {
    const instant = new Date("2026-09-03T01:00:00.000Z");

    assert.equal(periodKeyFor(instant, undefined), "2026-09-03");
    assert.equal(periodKeyFor(instant, "Not/AZone"), "2026-09-03");
  });
});

describe("Time zone normalization", () => {
  it("accepts IANA identifiers", () => {
    assert.equal(normalizeTimeZone("America/Sao_Paulo"), "America/Sao_Paulo");
    assert.equal(normalizeTimeZone("UTC"), "UTC");
  });

  it("rejects anything the runtime cannot resolve", () => {
    assert.equal(normalizeTimeZone("Not/AZone"), undefined);
    assert.equal(normalizeTimeZone(""), undefined);
    assert.equal(normalizeTimeZone(42), undefined);
    assert.equal(normalizeTimeZone(undefined), undefined);
    assert.equal(normalizeTimeZone("A".repeat(65)), undefined);
  });
});

describe("Invite tokens", () => {
  it("accepts only 43-character base64url values", () => {
    assert.equal(requireInviteToken("A".repeat(43)), "A".repeat(43));
    assert.throws(() => requireInviteToken("A".repeat(42)));
    assert.throws(() => requireInviteToken(`${"A".repeat(42)}/`));
    assert.throws(() => requireInviteToken(undefined));
  });
});

describe("Decision input", () => {
  it("normalizes a small valid decision", () => {
    assert.deepEqual(
      decisionDraft("  Where should we eat? ", [" Home ", " Somewhere new "]),
      { title: "Where should we eat?", options: ["Home", "Somewhere new"] },
    );
  });

  it("rejects missing, duplicate and oversized choices", () => {
    assert.throws(() => decisionDraft("Question", ["Only one"]));
    assert.throws(() => decisionDraft("Question", ["Same", " same "]));
    assert.throws(() => decisionDraft("Question", ["", "Other"]));
    assert.throws(() => decisionDraft("Question", ["A", "B", "C", "D", "E", "F", "G"]));
  });

  it("accepts only UUID-shaped idempotency identifiers", () => {
    const id = "6dca159e-cc43-43fb-a884-8b9d55bf82f1";
    assert.equal(requireDecisionId(id), id);
    assert.throws(() => requireDecisionId("not-a-request-id"));
    assert.throws(() => requireDecisionId(`${id}/child`));
  });
});

describe("Market input", () => {
  it("omits the note key entirely when there is none", () => {
    const draft = marketItemDraft("  Coffee  ", undefined, false);

    assert.deepEqual(draft, { name: "Coffee", isRequest: false });
    // Firestore rejects an undefined value, and this draft is spread straight
    // into the document. The key must be absent, not present-and-undefined.
    assert.equal("note" in draft, false);
  });

  it("keeps a real note and trims it", () => {
    const draft = marketItemDraft("Yogurt", "  the greek one  ", true);

    assert.deepEqual(draft, { name: "Yogurt", isRequest: true, note: "the greek one" });
  });

  it("treats a blank note as no note at all", () => {
    assert.equal("note" in marketItemDraft("Bread", "   ", false), false);
  });

  it("rejects an empty or oversized name", () => {
    assert.throws(() => marketItemDraft("   ", undefined, false));
    assert.throws(() => marketItemDraft("x".repeat(81), undefined, false));
    assert.throws(() => marketItemDraft(42, undefined, false));
  });

  it("rejects an oversized note", () => {
    assert.throws(() => marketItemDraft("Milk", "x".repeat(201), false));
  });

  it("accepts only the two statuses an item can hold", () => {
    assert.equal(requireMarketItemStatus("pending"), "pending");
    assert.equal(requireMarketItemStatus("gathered"), "gathered");
    assert.throws(() => requireMarketItemStatus("bought"));
    assert.throws(() => requireMarketItemStatus(undefined));
  });

  it("accepts only UUID-shaped idempotency identifiers", () => {
    assert.equal(
      requireMarketId("3e286e48-c764-4f62-b48b-ad216d619300"),
      "3e286e48-c764-4f62-b48b-ad216d619300",
    );
    assert.throws(() => requireMarketId("../escape"));
    assert.throws(() => requireMarketId(""));
  });
});

describe("Notification copy", () => {
  it("names the item when the request carries one", () => {
    const asked = NOTIFICATION_COPY["market-item-requested"];
    const added = NOTIFICATION_COPY["market-item-added"];

    assert.equal(asked.bodyWith?.("AA batteries"), "Your person asked you to bring AA batteries.");
    assert.equal(added.bodyWith?.("AA batteries"), "Added to your list: AA batteries");
  });

  it("still reads as a sentence with no subject to name", () => {
    for (const event of ["market-item-requested", "market-item-added"] as const) {
      const copy = NOTIFICATION_COPY[event];
      assert.ok(copy.body.length > 0);
      assert.ok(copy.title.length > 0);
    }
  });

  it("leaves every event with copy, named or not", () => {
    for (const [event, copy] of Object.entries(NOTIFICATION_COPY)) {
      assert.ok(copy.title.length > 0, `${event} has no title`);
      assert.ok(copy.body.length > 0, `${event} has no body`);
    }
  });
});

describe("Market history", () => {
  const requestedAt = Timestamp.fromMillis(1_700_000_000_000);
  const gatheredAt = Timestamp.fromMillis(1_700_000_900_000);
  const archivedAt = Timestamp.fromMillis(1_700_001_000_000);

  const gathered = {
    name: "Coffee",
    isRequest: false,
    requestedBy: "user-1",
    requestedAt,
    status: "gathered" as const,
    gatheredBy: "user-2",
    gatheredAt,
  };

  it("carries the trip that bought it", () => {
    const record = marketHistoryRecord(gathered, archivedAt, "run-1");

    assert.equal(record?.runId, "run-1");
    assert.equal(record?.archivedAt, archivedAt);
    assert.equal(record?.gatheredBy, "user-2");
  });

  it("omits keys with nothing in them", () => {
    const record = marketHistoryRecord(gathered, archivedAt, undefined);

    // Same Firestore constraint as the draft: an absent value must be an
    // absent key, or the archive write throws.
    assert.equal("runId" in (record ?? {}), false);
    assert.equal("note" in (record ?? {}), false);
  });

  it("keeps a note when the item had one", () => {
    const record = marketHistoryRecord({ ...gathered, note: "the dark roast" }, archivedAt, "r");

    assert.equal(record?.note, "the dark roast");
  });

  it("refuses to archive anything that was not actually gathered", () => {
    assert.equal(
      marketHistoryRecord({ ...gathered, status: "pending" }, archivedAt, "r"),
      undefined,
    );
    // A gathered item with no gatherer is a malformed document; half-copying it
    // into history would launder the corruption.
    assert.equal(
      marketHistoryRecord({ ...gathered, gatheredBy: undefined }, archivedAt, "r"),
      undefined,
    );
  });
});

describe("Chore turns", () => {
  const members = ["user-1", "user-2"];
  const createdAt = Timestamp.fromMillis(1_700_000_000_000);
  const doneAt = Timestamp.fromMillis(1_700_086_400_000);

  const base: ChoreRecord = {
    title: "Dishes",
    cadenceDays: 2,
    rotation: "alternates",
    ownerId: "user-1",
    status: "active",
    dueAt: createdAt,
    createdBy: "user-1",
    createdAt,
  };

  it("hands the turn to the other person when it alternates", () => {
    const next = advanceChore(base, members, "user-1", doneAt);

    assert.equal(next.ownerId, "user-2");
    assert.equal(next.status, "active");
    assert.equal(next.lastDoneBy, "user-1");
    // Counted from the completion, not from the old due date, so falling
    // behind never builds a backlog.
    assert.equal(next.dueAt.toMillis(), doneAt.toMillis() + 2 * 24 * 60 * 60 * 1000);
  });

  it("keeps the owner when the chore is genuinely someone's", () => {
    const next = advanceChore({ ...base, rotation: "fixed" }, members, "user-1", doneAt);

    assert.equal(next.ownerId, "user-1");
  });

  it("leaves an unowned chore unowned", () => {
    const next = advanceChore(
      { ...base, rotation: "anyone", ownerId: null },
      members,
      "user-2",
      doneAt,
    );

    assert.equal(next.ownerId, null);
    assert.equal(next.status, "active");
  });

  it("finishes a one-off instead of scheduling it again", () => {
    const next = advanceChore({ ...base, cadenceDays: null }, members, "user-1", doneAt);

    assert.equal(next.status, "done");
    assert.equal(next.lastDoneAt, doneAt);
    // The due date is left where it was: a finished chore has no next time.
    assert.equal(next.dueAt.toMillis(), createdAt.toMillis());
  });

  it("does not strand the turn when a partner cannot be found", () => {
    const next = advanceChore(base, ["user-1"], "user-1", doneAt);

    assert.equal(next.ownerId, "user-1");
  });
});

describe("Chore input", () => {
  it("normalizes a recurring chore", () => {
    assert.deepEqual(choreDraft("  Dishes  ", 2, "alternates"), {
      title: "Dishes",
      cadenceDays: 2,
      rotation: "alternates",
    });
  });

  it("treats a missing cadence as a one-off", () => {
    assert.equal(choreDraft("Fix the shelf", null, "fixed").cadenceDays, null);
    assert.equal(choreDraft("Fix the shelf", undefined, "fixed").cadenceDays, null);
  });

  it("rejects nonsense", () => {
    assert.throws(() => choreDraft("", 1, "fixed"));
    assert.throws(() => choreDraft("x".repeat(81), 1, "fixed"));
    assert.throws(() => choreDraft("Dishes", 0, "fixed"));
    assert.throws(() => choreDraft("Dishes", 366, "fixed"));
    assert.throws(() => choreDraft("Dishes", 1.5, "fixed"));
    assert.throws(() => choreDraft("Dishes", 1, "whoever"));
  });

  it("accepts only UUID-shaped identifiers", () => {
    assert.throws(() => requireChoreId("../escape"));
    assert.equal(
      requireChoreId("3e286e48-c764-4f62-b48b-ad216d619300"),
      "3e286e48-c764-4f62-b48b-ad216d619300",
    );
  });
});
