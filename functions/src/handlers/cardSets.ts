import {logger} from "firebase-functions";
import {CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {checkAuthAndThrow} from "../utils/utils";
import {hasCards} from "../utils/claimsUtils";

/** Most sets a student can have. */
export const maxCardSets = 5;
/** Most cards in one set. */
export const maxCardsInSet = 2000;
/** Longest set name. */
export const maxSetNameLength = 40;

/**
 * The caller's card sets ("My Sets"): named lists of cards they study like
 * a pack.
 * @param {string} uid The user's id.
 * @return {FirebaseFirestore.CollectionReference} The collection.
 */
function setsOf(uid: string) {
  return getFirestore().collection("users").doc(uid).collection("card_sets");
}

/**
 * Trims a set name and limits its length.
 * @param {unknown} name Name sent by the app.
 * @return {string} The clean name.
 */
export function cleanSetName(name: unknown): string {
  const clean = typeof name === "string" ?
    name.trim().replace(/\s+/g, " ").slice(0, maxSetNameLength) :
    "";
  if (!clean) throw new HttpsError("invalid-argument", "Give the set a name.");
  return clean;
}

/**
 * A string field of the request.
 * @param {unknown} data Request data.
 * @param {string} key The field.
 * @return {string} Its value.
 */
function requiredId(data: unknown, key: string): string {
  const value = (data as Record<string, unknown> | undefined)?.[key];
  if (typeof value !== "string" || !value || value.includes("/")) {
    throw new HttpsError("invalid-argument", `Missing ${key}.`);
  }
  return value;
}

/**
 * Wraps a handler: checks sign-in and turns unexpected errors into
 * "internal" errors.
 * @param {string} name For the log.
 * @param {Function} handler The work, given the user's id and the data.
 * @return {Function} The callable handler.
 */
function handler<T>(
  name: string,
  handler: (uid: string, data: unknown, request: CallableRequest) => Promise<T>,
) {
  return async (request: CallableRequest) => {
    try {
      checkAuthAndThrow(request.auth);
      return await handler(request.auth!.uid, request.data, request);
    } catch (error: any) {
      if (error instanceof HttpsError) throw error;
      logger.error(`${name} failed`, {error});
      throw new HttpsError("internal", error.message || "Internal error");
    }
  };
}

export const listCardSetsHandler = handler("listCardSets", async (uid) => {
  const snapshot = await setsOf(uid).orderBy("createdAt").get();
  return {
    sets: snapshot.docs.map((doc) => ({
      id: doc.id,
      name: doc.get("name") as string,
      flashcardIds: (doc.get("flashcardIds") as string[] | undefined) ?? [],
    })),
  };
});

/** Creates a set (with no id, optionally with cards) or renames one. */
export const saveCardSetHandler = handler("saveCardSet", async (uid, data) => {
  const name = cleanSetName((data as Record<string, unknown>)?.name);
  const id = (data as Record<string, unknown>)?.id;
  const sets = setsOf(uid);
  if (typeof id === "string" && id) {
    const ref = sets.doc(requiredId(data, "id"));
    if (!(await ref.get()).exists) {
      throw new HttpsError("not-found", "This set doesn't exist anymore.");
    }
    await ref.update({name});
    return {id: ref.id, name};
  }
  const db = getFirestore();
  return db.runTransaction(async (transaction) => {
    const existing = await transaction.get(sets.select());
    if (existing.size >= maxCardSets) {
      throw new HttpsError(
        "failed-precondition",
        `You can have up to ${maxCardSets} sets. Delete one to make another.`,
      );
    }
    const sent = (data as Record<string, unknown>)?.flashcardIds;
    const flashcardIds = Array.isArray(sent) ?
      [...new Set(sent.filter((v): v is string =>
        typeof v === "string" && v.length > 0 && !v.includes("/")))]
        .slice(0, maxCardsInSet) :
      [];
    const ref = sets.doc();
    transaction.set(ref, {name, flashcardIds, createdAt: Timestamp.now()});
    return {id: ref.id, name};
  });
});

export const deleteCardSetHandler = handler(
  "deleteCardSet",
  async (uid, data) => {
    const id = requiredId(data, "id");
    await setsOf(uid).doc(id).delete();
    // Its study session goes too.
    await getFirestore().recursiveDelete(
      getFirestore().collection("custom_sessions").doc(setSessionId(id)),
    );
    return {deleted: true};
  },
);

/** Adds a card to a set or takes it out. */
export const setCardInSetHandler = handler(
  "setCardInSet",
  async (uid, data) => {
    const id = requiredId(data, "setId");
    const flashcardId = requiredId(data, "flashcardId");
    const inSet = (data as Record<string, unknown>)?.inSet !== false;
    const ref = setsOf(uid).doc(id);
    const snapshot = await ref.get();
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "This set doesn't exist anymore.");
    }
    const ids = (snapshot.get("flashcardIds") as string[] | undefined) ?? [];
    if (inSet && !ids.includes(flashcardId) && ids.length >= maxCardsInSet) {
      throw new HttpsError(
        "failed-precondition",
        `A set can have up to ${maxCardsInSet} cards.`,
      );
    }
    await ref.update({
      flashcardIds: inSet ?
        FieldValue.arrayUnion(flashcardId) :
        FieldValue.arrayRemove(flashcardId),
    });
    return {inSet};
  },
);

/**
 * The custom session a set is studied in. One per set, so studying it
 * again starts over instead of making more sessions.
 * @param {string} setId The set's id.
 * @return {string} The session's id.
 */
export function setSessionId(setId: string): string {
  return `set-${setId}`;
}

/**
 * Starts studying a set: (re)makes its session with the set's cards in a
 * random order. Cards that were deleted, or are paid without access, are
 * left out.
 */
export const studyCardSetHandler = handler(
  "studyCardSet",
  async (uid, data, request) => {
    const id = requiredId(data, "setId");
    const db = getFirestore();
    const setSnapshot = await setsOf(uid).doc(id).get();
    if (!setSnapshot.exists) {
      throw new HttpsError("not-found", "This set doesn't exist anymore.");
    }
    const name = setSnapshot.get("name") as string;
    const ids = (setSnapshot.get("flashcardIds") as string[] | undefined) ?? [];
    const access = hasCards(request.auth!.token as any);

    const kept: string[] = [];
    let isPaid = false;
    for (let i = 0; i < ids.length; i += 100) {
      const refs = ids.slice(i, i + 100)
        .map((cardId) => db.collection("flashcards").doc(cardId));
      const cards = refs.length ? await db.getAll(...refs) : [];
      for (const card of cards) {
        if (!card.exists) continue;
        const paid = card.get("isPaid") === true;
        if (paid && !access) continue;
        isPaid = isPaid || paid;
        kept.push(card.id);
      }
    }
    if (kept.length === 0) {
      throw new HttpsError(
        "failed-precondition",
        ids.length === 0 ?
          "This set has no cards yet. Add cards while studying or browsing." :
          "None of the cards in this set are available to you.",
      );
    }

    const shuffled = [...kept];
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    const sessionRef = db.collection("custom_sessions").doc(setSessionId(id));
    const createdAt = Timestamp.now();
    const batch = db.batch();
    batch.set(sessionRef, {
      profileId: uid,
      cardCount: shuffled.length,
      isPaid,
      currentIndex: 0,
      correctCount: 0,
      createdAt,
      name,
      fromSet: id,
    });
    batch.set(sessionRef.collection("flashcard_ids").doc("all_ids"), {
      flashcardIds: shuffled,
    });
    await batch.commit();
    return {
      id: sessionRef.id,
      name,
      cardCount: shuffled.length,
      isPaid,
      createdAtMs: createdAt.toMillis(),
    };
  },
);
