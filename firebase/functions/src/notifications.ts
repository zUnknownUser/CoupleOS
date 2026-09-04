import { Firestore } from "firebase-admin/firestore";
import { Messaging } from "firebase-admin/messaging";
import {
  NotificationLanguage,
  NotificationRequest,
  notificationCopy,
  notificationLanguage,
} from "./domain.js";

const USERS = "users";
const DEVICES = "devices";

/** FCM codes that mean the token will never work again. */
const DEAD_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
]);

interface Target {
  ref: FirebaseFirestore.DocumentReference;
  token: string;
  language: NotificationLanguage;
}

/**
 * Delivers a notification and prunes tokens FCM rejects as permanently dead.
 *
 * Language is a property of the *device*, not of the person: each install
 * writes the language it reads in onto its own record, so one person's phone
 * and tablet can differ, and a couple reading in two languages each get their
 * own. Targets are therefore grouped by language and sent one multicast per
 * group rather than one for everybody.
 *
 * Never throws: a Couple's action has already been committed by the time this
 * runs, so a delivery problem must not turn a successful command into an error.
 */
export async function deliver(
  database: Firestore,
  messaging: Messaging,
  request: NotificationRequest | undefined,
): Promise<void> {
  if (!request || request.userIds.length === 0) return;
  try {
    const devices = await Promise.all(
      request.userIds.map((userId) =>
        database.collection(USERS).doc(userId).collection(DEVICES).get(),
      ),
    );
    const targets = devices
      .flatMap((snapshot) => snapshot.docs)
      .map((document) => ({
        ref: document.ref,
        token: document.get("token"),
        // A record written before the app stored a language still has to be
        // deliverable, so an absent field falls back rather than dropping.
        language: notificationLanguage(document.get("language")),
      }))
      .filter(
        (target): target is Target =>
          typeof target.token === "string" && target.token.length > 0,
      );
    if (targets.length === 0) return;

    const dead: FirebaseFirestore.DocumentReference[] = [];

    for (const [language, group] of groupByLanguage(targets)) {
      const copy = notificationCopy(request.event, language);
      const body =
        request.subject && copy.bodyWith ? copy.bodyWith(request.subject) : copy.body;

      const response = await messaging.sendEachForMulticast({
        tokens: group.map((target) => target.token),
        notification: { title: copy.title, body },
        apns: {
          payload: { aps: { sound: "default", badge: 1 } },
        },
        data: { event: request.event },
      });

      dead.push(
        ...response.responses.flatMap((result, index) =>
          !result.success && DEAD_TOKEN_CODES.has(result.error?.code ?? "")
            ? [group[index].ref]
            : [],
        ),
      );
    }

    await Promise.all(dead.map((ref) => ref.delete()));
  } catch (error) {
    console.error("NOTIFICATION_DELIVERY_FAILED", request.event, error);
  }
}

function groupByLanguage(targets: Target[]): Map<NotificationLanguage, Target[]> {
  const groups = new Map<NotificationLanguage, Target[]>();
  for (const target of targets) {
    const group = groups.get(target.language);
    if (group) {
      group.push(target);
    } else {
      groups.set(target.language, [target]);
    }
  }
  return groups;
}
