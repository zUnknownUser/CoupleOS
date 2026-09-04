import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import {
  acceptInviteForUser,
  addMarketItemForUser,
  clearGatheredMarketItemsForUser,
  completeChoreForUser,
  createChoreForUser,
  createCoupleForUser,
  createDecisionForUser,
  createInviteForUser,
  finishMarketRunForUser,
  getTodayForUser,
  removeChoreForUser,
  removeMarketItemForUser,
  setMarketItemStatusForUser,
  startMarketRunForUser,
  submitTodayAnswerForUser,
  resolveDecisionForUser,
} from "./commands.js";
import {
  choreResponse,
  coupleResponse,
  dailyResponse,
  decisionResponse,
  DomainError,
  marketItemResponse,
  marketRunResponse,
} from "./domain.js";
import { deliver } from "./notifications.js";

initializeApp();

const database = getFirestore();
const messaging = getMessaging();

/**
 * App Check enforcement is opt-in so the backend can ship before every client
 * carries an attestation token. Register the app with App Attest in the
 * Firebase console, confirm the App Check dashboard shows verified traffic,
 * then set ENFORCE_APP_CHECK=true and redeploy. Turning it on while old builds
 * are still in the field would reject them.
 */
const callableOptions = {
  region: "us-central1",
  enforceAppCheck: process.env.ENFORCE_APP_CHECK === "true",
};

export const createCouple = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  try {
    const result = await createCoupleForUser(database, userId, request.data?.timeZone);
    return { couple: coupleResponse(result.id, result.couple) };
  } catch (error) {
    throw callableError(error);
  }
});

export const createInvite = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  const expectedCoupleId = optionalString(request.data?.coupleId);
  try {
    const result = await createInviteForUser(database, userId, expectedCoupleId);
    return {
      token: result.token,
      coupleId: result.coupleId,
      expiresAtMillis: result.expiresAt.toMillis(),
    };
  } catch (error) {
    throw callableError(error);
  }
});

export const acceptInvite = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  try {
    const result = await acceptInviteForUser(database, userId, request.data?.token);
    await deliver(database, messaging, result.notify);
    return { couple: coupleResponse(result.id, result.couple) };
  } catch (error) {
    throw callableError(error);
  }
});

export const getToday = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  try {
    const result = await getTodayForUser(database, userId);
    return { experience: dailyResponse(result.id, result.experience) };
  } catch (error) {
    throw callableError(error);
  }
});

export const submitTodayAnswer = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  try {
    const result = await submitTodayAnswerForUser(
      database,
      userId,
      request.data?.coupleId,
      request.data?.experienceId,
      request.data?.optionIndex,
    );
    await deliver(database, messaging, result.notify);
    return { experience: dailyResponse(result.id, result.experience) };
  } catch (error) {
    throw callableError(error);
  }
});

export const createDecision = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  try {
    const result = await createDecisionForUser(
      database,
      userId,
      request.data?.coupleId,
      request.data?.decisionId,
      request.data?.title,
      request.data?.options,
    );
    await deliver(database, messaging, result.notify);
    return { decision: decisionResponse(result.id, result.coupleId, result.decision) };
  } catch (error) {
    throw callableError(error);
  }
});

export const resolveDecision = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  try {
    const result = await resolveDecisionForUser(
      database,
      userId,
      request.data?.coupleId,
      request.data?.decisionId,
      request.data?.optionIndex,
    );
    await deliver(database, messaging, result.notify);
    return { decision: decisionResponse(result.id, result.coupleId, result.decision) };
  } catch (error) {
    throw callableError(error);
  }
});


export const addMarketItem = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  try {
    const result = await addMarketItemForUser(
      database,
      userId,
      request.data?.coupleId,
      request.data?.itemId,
      request.data?.name,
      request.data?.note,
      request.data?.isRequest,
    );
    await deliver(database, messaging, result.notify);
    return { item: marketItemResponse(result.id, result.coupleId, result.item) };
  } catch (error) {
    throw callableError(error);
  }
});

export const setMarketItemStatus = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  try {
    const result = await setMarketItemStatusForUser(
      database,
      userId,
      request.data?.coupleId,
      request.data?.itemId,
      request.data?.status,
    );
    return { item: marketItemResponse(result.id, result.coupleId, result.item) };
  } catch (error) {
    throw callableError(error);
  }
});

export const removeMarketItem = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  try {
    const result = await removeMarketItemForUser(
      database,
      userId,
      request.data?.coupleId,
      request.data?.itemId,
    );
    return { id: result.id, coupleId: result.coupleId };
  } catch (error) {
    throw callableError(error);
  }
});

export const startMarketRun = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  try {
    const result = await startMarketRunForUser(
      database,
      userId,
      request.data?.coupleId,
      request.data?.runId,
    );
    await deliver(database, messaging, result.notify);
    return { run: marketRunResponse(result.id, result.coupleId, result.run) };
  } catch (error) {
    throw callableError(error);
  }
});

export const finishMarketRun = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  try {
    const result = await finishMarketRunForUser(
      database,
      userId,
      request.data?.coupleId,
      request.data?.runId,
    );
    return {
      run: marketRunResponse(result.id, result.coupleId, result.run),
      swept: result.swept,
    };
  } catch (error) {
    throw callableError(error);
  }
});

export const clearGatheredMarketItems = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  try {
    const result = await clearGatheredMarketItemsForUser(
      database,
      userId,
      request.data?.coupleId,
    );
    return { coupleId: result.coupleId, swept: result.swept };
  } catch (error) {
    throw callableError(error);
  }
});

export const createChore = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  try {
    const result = await createChoreForUser(
      database,
      userId,
      request.data?.coupleId,
      request.data?.choreId,
      request.data?.title,
      request.data?.cadenceDays,
      request.data?.rotation,
      request.data?.firstOwnerId,
    );
    return { chore: choreResponse(result.id, result.coupleId, result.chore) };
  } catch (error) {
    throw callableError(error);
  }
});

export const completeChore = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  try {
    const result = await completeChoreForUser(
      database,
      userId,
      request.data?.coupleId,
      request.data?.choreId,
      request.data?.expectedDueAtMillis,
    );
    await deliver(database, messaging, result.notify);
    return { chore: choreResponse(result.id, result.coupleId, result.chore) };
  } catch (error) {
    throw callableError(error);
  }
});

export const removeChore = onCall(callableOptions, async (request) => {
  const userId = requireUserId(request.auth?.uid);
  try {
    const result = await removeChoreForUser(
      database,
      userId,
      request.data?.coupleId,
      request.data?.choreId,
    );
    return { id: result.id, coupleId: result.coupleId };
  } catch (error) {
    throw callableError(error);
  }
});

function requireUserId(userId: string | undefined): string {
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication is required.", {
      domainCode: "authentication-required",
    });
  }
  return userId;
}

function callableError(error: unknown): HttpsError {
  if (error instanceof DomainError) {
    return new HttpsError(error.httpsCode, error.message, {
      domainCode: error.domainCode,
    });
  }
  return new HttpsError("internal", "The operation could not be completed.", {
    domainCode: "unknown",
  });
}

function optionalString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}
