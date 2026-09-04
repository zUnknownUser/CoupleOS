import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { after, before, describe, it } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "firebase/firestore";

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const integration = emulatorAvailable ? describe : describe.skip;

integration("Firestore rules", () => {
  let environment: RulesTestEnvironment;

  before(async () => {
    const [host, rawPort] = process.env.FIRESTORE_EMULATOR_HOST!.split(":");
    environment = await initializeTestEnvironment({
      projectId: "coupleos-rules-emulator",
      firestore: {
        host,
        port: Number(rawPort),
        rules: await readFile("../../firestore.rules", "utf8"),
      },
    });
  });

  after(async () => {
    await environment?.cleanup();
  });

  it("lets a user create and read only their own valid profile", async () => {
    const own = environment.authenticatedContext("user-a").firestore();
    const other = environment.authenticatedContext("user-b").firestore();
    const profile = doc(own, "users/user-a");

    await assertSucceeds(setDoc(profile, {
      firstName: "Alex",
      createdAt: serverTimestamp(),
      onboardingStatus: "readyForPartner",
    }));
    await assertSucceeds(getDoc(profile));
    await assertFails(getDoc(doc(other, "users/user-a")));
  });

  it("rejects extra fields and client-created activeCoupleId", async () => {
    const database = environment.authenticatedContext("user-a").firestore();
    await assertFails(setDoc(doc(database, "users/user-a"), {
      firstName: "Alex",
      createdAt: serverTimestamp(),
      onboardingStatus: "readyForPartner",
      activeCoupleId: "couple-a",
    }));
    await assertFails(setDoc(doc(database, "users/user-a"), {
      firstName: "Alex",
      createdAt: serverTimestamp(),
      onboardingStatus: "readyForPartner",
      unexpected: true,
    }));
  });

  it("prevents a client from completing onboarding or changing activeCoupleId", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users/user-a"), {
        firstName: "Alex",
        createdAt: new Date(),
        onboardingStatus: "readyForPartner",
        activeCoupleId: "couple-a",
      });
    });
    const database = environment.authenticatedContext("user-a").firestore();
    await assertFails(updateDoc(doc(database, "users/user-a"), {
      onboardingStatus: "completed",
    }));
    await assertFails(updateDoc(doc(database, "users/user-a"), {
      activeCoupleId: "couple-b",
    }));
  });

  it("lets active Couple members read each other's profile only", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const database = context.firestore();
      await setDoc(doc(database, "users/user-a"), {
        firstName: "Alex",
        createdAt: new Date(),
        onboardingStatus: "completed",
        activeCoupleId: "couple-a",
      });
      await setDoc(doc(database, "users/user-b"), {
        firstName: "Sam",
        createdAt: new Date(),
        onboardingStatus: "completed",
        activeCoupleId: "couple-a",
      });
      await setDoc(doc(database, "users/user-c"), {
        firstName: "Taylor",
        createdAt: new Date(),
        onboardingStatus: "completed",
        activeCoupleId: "couple-c",
      });
      await setDoc(doc(database, "couples/couple-a"), {
        memberIds: ["user-a", "user-b"],
        status: "active",
        createdBy: "user-a",
        createdAt: new Date(),
      });
    });

    const userA = environment.authenticatedContext("user-a").firestore();
    await assertSucceeds(getDoc(doc(userA, "users/user-b")));
    await assertFails(getDoc(doc(userA, "users/user-c")));
  });

  it("allows Couple reads only to members and denies every client write", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "couples/couple-a"), {
        memberIds: ["user-a"],
        status: "waitingForPartner",
        createdBy: "user-a",
        createdAt: new Date(),
      });
    });
    const member = environment.authenticatedContext("user-a").firestore();
    const stranger = environment.authenticatedContext("user-b").firestore();
    await assertSucceeds(getDoc(doc(member, "couples/couple-a")));
    await assertFails(getDoc(doc(stranger, "couples/couple-a")));
    await assertFails(updateDoc(doc(member, "couples/couple-a"), { memberIds: ["user-a", "user-b"] }));
  });

  it("never permits direct invite reads or writes", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "invites/hash"), { status: "pending" });
    });
    const database = environment.authenticatedContext("user-a").firestore();
    await assertFails(getDoc(doc(database, "invites/hash")));
    await assertFails(setDoc(doc(database, "invites/another"), { status: "pending" }));
  });

  it("lets only Couple members read Decisions and denies every client write", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const database = context.firestore();
      await setDoc(doc(database, "couples/couple-decisions"), {
        memberIds: ["user-a", "user-b"],
        status: "active",
        createdBy: "user-a",
        createdAt: new Date(),
      });
      await setDoc(doc(database, "couples/couple-decisions/decisions/decision-a"), {
        title: "Where should we eat?",
        options: ["Home", "Somewhere new"],
        creatorId: "user-a",
        responderId: "user-b",
        status: "waitingForPartner",
        createdAt: new Date(),
      });
    });

    const creator = environment.authenticatedContext("user-a").firestore();
    const responder = environment.authenticatedContext("user-b").firestore();
    const stranger = environment.authenticatedContext("user-c").firestore();
    const path = "couples/couple-decisions/decisions/decision-a";

    await assertSucceeds(getDoc(doc(creator, path)));
    await assertSucceeds(getDocs(collection(responder, "couples/couple-decisions/decisions")));
    await assertFails(getDoc(doc(stranger, path)));
    await assertFails(getDocs(collection(stranger, "couples/couple-decisions/decisions")));
    await assertFails(updateDoc(doc(responder, path), {
      status: "resolved",
      selectedOptionIndex: 0,
    }));
    await assertFails(setDoc(doc(creator, "couples/couple-decisions/decisions/decision-b"), {
      title: "Injected",
    }));
  });

  it("keeps the suite connected to the expected emulator", () => {
    assert.match(process.env.FIRESTORE_EMULATOR_HOST!, /:\d+$/);
  });
});
