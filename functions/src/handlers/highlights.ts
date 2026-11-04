import {logger} from "firebase-functions";
import {CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {checkAuthAndThrow} from "../utils/utils";

/** Longest highlighted text that is kept. */
const maxTextLength = 1000;
/** Most highlights returned to the app. */
const maxHighlights = 3000;

type HighlightData = {
  flashcardId: string;
  packId: string;
  side: "question" | "answer";
  text: string;
  start: number;
  question: string;
  /** "underline" marks only show on the card, not in the notebook. */
  kind: "highlight" | "underline";
};

/**
 * The caller's highlights collection.
 * @param {string} uid The user's id.
 * @return {FirebaseFirestore.CollectionReference} The collection.
 */
function highlightsOf(uid: string) {
  return getFirestore().collection("users").doc(uid).collection("highlights");
}

/**
 * Checks and cleans a highlight sent by the app.
 * @param {unknown} data Request data.
 * @return {HighlightData} The highlight to save.
 */
export function parseHighlight(data: unknown): HighlightData {
  const d = (data ?? {}) as Record<string, unknown>;
  const str = (key: string, max: number) => {
    const value = d[key];
    if (typeof value !== "string" || !value.trim()) {
      throw new HttpsError("invalid-argument", `Missing ${key}.`);
    }
    return value.slice(0, max);
  };
  const side = d.side === "answer" ? "answer" : "question";
  const start = Number.isInteger(d.start) && (d.start as number) >= 0 ?
    d.start as number : 0;
  return {
    flashcardId: str("flashcardId", 200),
    packId: str("packId", 200),
    side,
    text: str("text", maxTextLength),
    start,
    question: str("question", 300),
    kind: d.kind === "underline" ? "underline" : "highlight",
  };
}

/**
 * Saves a highlighted passage of a flashcard for the caller.
 * @param {CallableRequest} request Has the highlight fields.
 * @return {Promise<{id: string}>} The new highlight id.
 */
export async function saveHighlightHandler(request: CallableRequest) {
  try {
    checkAuthAndThrow(request.auth);
    const highlight = parseHighlight(request.data);
    const ref = await highlightsOf(request.auth!.uid).add({
      ...highlight,
      createdAt: Timestamp.now(),
    });
    return {id: ref.id};
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    logger.error("saveHighlight failed", {error});
    throw new HttpsError("internal", error.message || "Internal error");
  }
}

/**
 * Deletes one of the caller's highlights.
 * @param {CallableRequest} request Has the highlight id.
 * @return {Promise<{deleted: boolean}>} Done.
 */
export async function deleteHighlightHandler(request: CallableRequest) {
  try {
    checkAuthAndThrow(request.auth);
    const id = request.data?.id;
    if (typeof id !== "string" || !id) {
      throw new HttpsError("invalid-argument", "Missing id.");
    }
    await highlightsOf(request.auth!.uid).doc(id).delete();
    return {deleted: true};
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    logger.error("deleteHighlight failed", {error});
    throw new HttpsError("internal", error.message || "Internal error");
  }
}

/**
 * Lists the caller's highlights, newest first.
 * @param {CallableRequest} request No data needed.
 * @return {Promise<{highlights: object[]}>} The highlights.
 */
export async function listHighlightsHandler(request: CallableRequest) {
  try {
    checkAuthAndThrow(request.auth);
    const snapshot = await highlightsOf(request.auth!.uid)
      .orderBy("createdAt", "desc")
      .limit(maxHighlights)
      .get();
    return {
      highlights: snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          flashcardId: data.flashcardId,
          packId: data.packId,
          side: data.side,
          text: data.text,
          start: data.start ?? 0,
          question: data.question ?? "",
          kind: data.kind === "underline" ? "underline" : "highlight",
          createdAt: (data.createdAt as Timestamp | undefined)?.toMillis() ?? 0,
        };
      }),
    };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    logger.error("listHighlights failed", {error});
    throw new HttpsError("internal", error.message || "Internal error");
  }
}
