import { Firestore } from "firebase-admin/firestore";
import { Messaging } from "firebase-admin/messaging";
import { NOTIFICATION_COPY, NotificationRequest } from "./domain.js";

const USERS = "users";
const DEVICES = "devices";

/** FCM codes that mean the token will never work again. */
const DEAD_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
]);

/**
 * Delivers a notification and prunes tokens FCM rejects as permanently dead.
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
    const copy = NOTIFICATION_COPY[request.event];
    const body =
      request.subject && copy.bodyWith ? copy.bodyWith(request.subject) : copy.body;
    const devices = await Promise.all(
      request.userIds.map((userId) =>
        database.collection(USERS).doc(userId).collection(DEVICES).get(),
      ),
    );
    const targets = devices
      .flatMap((snapshot) => snapshot.docs)
      .map((document) => ({ ref: document.ref, token: document.get("token") }))
      .filter((target): target is { ref: typeof target.ref; token: string } =>
        typeof target.token === "string" && target.token.length > 0,
      );
    if (targets.length === 0) return;

    const response = await messaging.sendEachForMulticast({
      tokens: targets.map((target) => target.token),
      notification: { title: copy.title, body },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
      data: { event: request.event },
    });

    const dead = response.responses.flatMap((result, index) =>
      !result.success && DEAD_TOKEN_CODES.has(result.error?.code ?? "")
        ? [targets[index].ref]
        : [],
    );
    await Promise.all(dead.map((ref) => ref.delete()));
  } catch (error) {
    console.error("NOTIFICATION_DELIVERY_FAILED", request.event, error);
  }
}
