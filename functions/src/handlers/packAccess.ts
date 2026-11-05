import {logger} from "firebase-functions";
import {CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {checkAuthAndThrow, checkIfAdminAndThrow} from "../utils/utils";
import {hasCards} from "../utils/claimsUtils";
import {createHash} from "crypto";
import {gzipSync} from "zlib";

/*
 * A pack can be limited to some users:
 * - packs/{packId}.restricted = true marks it (readable by everyone, so it
 *   holds no emails),
 * - pack_access/{packId}.emails is the list (admins only),
 * - pack_access_by_email/{email}.packIds lets a user (and the security
 *   rules) check which limited packs that email may open.
 */

/** Most emails one pack can be limited to. */
const maxEmails = 2000;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

type Token = {email?: string; roles?: unknown};

/**
 * Cleans the email list sent by the admin: trimmed, lower case, no
 * duplicates, sorted.
 * @param {unknown} value The emails.
 * @return {string[]} The cleaned list.
 */
export function cleanEmails(value: unknown): string[] {
  if (!Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "emails must be a list.");
  }
  const emails = new Set<string>();
  for (const item of value) {
    if (typeof item !== "string") continue;
    const email = item.trim().toLowerCase();
    if (!email) continue;
    if (!emailPattern.test(email) || email.includes("/")) {
      throw new HttpsError("invalid-argument", `"${item}" is not an email.`);
    }
    emails.add(email);
  }
  if (emails.size > maxEmails) {
    throw new HttpsError(
      "invalid-argument",
      `A pack can be limited to at most ${maxEmails} emails.`,
    );
  }
  return [...emails].sort();
}

/**
 * Whether the caller may use a pack. Packs not limited are for everyone,
 * admins may use every pack.
 * @param {string} packId The pack id.
 * @param {FirebaseFirestore.DocumentData | undefined} pack The pack data.
 * @param {Token} token The caller's auth token.
 * @return {Promise<boolean>} True when allowed.
 */
export async function canUsePack(
  packId: string,
  pack: FirebaseFirestore.DocumentData | undefined,
  token: Token,
): Promise<boolean> {
  if (pack?.restricted !== true) return true;
  const roles = Array.isArray(token.roles) ? token.roles : [];
  if (roles.includes("admin")) return true;
  const email = (token.email ?? "").toLowerCase();
  if (!email) return false;
  const access = await getFirestore()
    .collection("pack_access").doc(packId).get();
  const emails = access.data()?.emails;
  return Array.isArray(emails) && emails.includes(email);
}

/**
 * Limits a pack to the given emails, or opens it to everyone when the list
 * is empty. Admins only.
 * @param {CallableRequest} request Has packId and emails.
 * @return {Promise<object>} The saved list.
 */
export async function setPackAccessHandler(request: CallableRequest) {
  try {
    checkIfAdminAndThrow(request.auth);
    const packId = request.data?.packId;
    if (typeof packId !== "string" || !packId || packId.includes("/")) {
      throw new HttpsError("invalid-argument", "Missing packId.");
    }
    const emails = cleanEmails(request.data?.emails);
    const db = getFirestore();
    const packRef = db.collection("packs").doc(packId);
    const accessRef = db.collection("pack_access").doc(packId);
    const byEmail = (email: string) =>
      db.collection("pack_access_by_email").doc(email);

    await db.runTransaction(async (tx) => {
      const [pack, access] = await Promise.all([tx.get(packRef), tx.get(accessRef)]);
      if (!pack.exists) {
        throw new HttpsError("not-found", "This pack no longer exists.");
      }
      const before: string[] = Array.isArray(access.data()?.emails) ?
        access.data()!.emails : [];
      const removed = before.filter((e) => !emails.includes(e));
      const added = emails.filter((e) => !before.includes(e));

      for (const email of removed) {
        tx.set(byEmail(email),
          {packIds: FieldValue.arrayRemove(packId)}, {merge: true});
      }
      for (const email of added) {
        tx.set(byEmail(email),
          {packIds: FieldValue.arrayUnion(packId)}, {merge: true});
      }
      if (emails.length) {
        tx.set(accessRef, {emails});
        tx.update(packRef, {restricted: true});
      } else {
        tx.delete(accessRef);
        tx.update(packRef, {restricted: FieldValue.delete()});
      }
    });
    logger.info("Pack access changed", {packId, count: emails.length});
    return {allowedEmails: emails};
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    logger.error("setPackAccess failed", {error});
    throw new HttpsError("internal", error.message || "Internal error");
  }
}

/**
 * The emails a pack is limited to (empty when it is for everyone).
 * Admins only.
 * @param {CallableRequest} request Has packId.
 * @return {Promise<object>} The list.
 */
export async function getPackAccessHandler(request: CallableRequest) {
  try {
    checkIfAdminAndThrow(request.auth);
    const packId = request.data?.packId;
    if (typeof packId !== "string" || !packId || packId.includes("/")) {
      throw new HttpsError("invalid-argument", "Missing packId.");
    }
    const access = await getFirestore()
      .collection("pack_access").doc(packId).get();
    const emails = access.data()?.emails;
    return {allowedEmails: Array.isArray(emails) ? emails : []};
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    logger.error("getPackAccess failed", {error});
    throw new HttpsError("internal", error.message || "Internal error");
  }
}

type SearchCard = {
  id: string;
  question: string;
  answer: string;
  isPaid: boolean;
  tags: string[];
  packId: string;
  /** Only when the card has one, to keep the list small. */
  questionImageUrl?: string;
  answerImageUrl?: string;
};

/** Cards and packs are read again after this long (ms). */
const searchCacheMs = 3 * 60 * 1000;
let searchCache: {
  at: number;
  packs: {id: string; data: FirebaseFirestore.DocumentData}[];
  cards: SearchCard[];
} | undefined;

/**
 * Every pack and card, kept for a few minutes so searches by many users
 * (and repeated searches) don't read all the cards each time.
 * @return {Promise<object>} Packs and cards.
 */
async function searchData() {
  if (searchCache && Date.now() - searchCache.at < searchCacheMs) {
    return searchCache;
  }
  const db = getFirestore();
  const [packs, cards] = await Promise.all([
    db.collection("packs").get(),
    db.collection("flashcards")
      .select(
        "question",
        "answer",
        "isPaid",
        "tags",
        "packId",
        "questionImageUrl",
        "answerImageUrl",
      )
      .get(),
  ]);
  searchCache = {
    at: Date.now(),
    packs: packs.docs.map((d) => ({id: d.id, data: d.data()})),
    cards: cards.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        question: data.question ?? "",
        answer: data.answer ?? "",
        isPaid: data.isPaid === true,
        tags: Array.isArray(data.tags) ? data.tags : [],
        packId: data.packId ?? "",
        ...(data.questionImageUrl ?
          {questionImageUrl: data.questionImageUrl} : {}),
        ...(data.answerImageUrl ? {answerImageUrl: data.answerImageUrl} : {}),
      };
    }),
  };
  return searchCache;
}

/**
 * The flashcards the caller may search: premium cards only with a
 * subscription, limited packs only for their users.
 *
 * With `compressed: true` the list comes gzipped (base64) with a `version`;
 * when the caller sends the `version` it already has and nothing changed,
 * only `{unchanged: true}` is sent back.
 * @param {CallableRequest} request Optional compressed and version.
 * @return {Promise<object>} The cards.
 */
export async function listSearchableFlashcardsHandler(
  request: CallableRequest,
) {
  try {
    checkAuthAndThrow(request.auth);
    const token = request.auth!.token as Token;
    const roles = Array.isArray(token.roles) ? token.roles : [];
    const isAdmin = roles.includes("admin");
    const paidAllowed = isAdmin || hasCards(token as any);

    const data = await searchData();
    const hidden = new Set<string>();
    for (const pack of data.packs) {
      if (!(await canUsePack(pack.id, pack.data, token))) {
        hidden.add(pack.id);
      }
    }
    const result = data.cards.filter((card) =>
      !hidden.has(card.packId) && (paidAllowed || !card.isPaid));

    if (request.data?.compressed !== true) return {flashcards: result};

    const json = JSON.stringify(result);
    // "img-": the list has the cards' pictures, so the app can show cards
    // from it without reading each one.
    const version = "img-" + createHash("sha1").update(json).digest("hex");
    if (request.data?.version === version) return {unchanged: true, version};
    return {
      version,
      gzip: gzipSync(Buffer.from(json, "utf8"), {level: 9}).toString("base64"),
    };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    logger.error("listSearchableFlashcards failed", {error});
    throw new HttpsError("internal", error.message || "Internal error");
  }
}
