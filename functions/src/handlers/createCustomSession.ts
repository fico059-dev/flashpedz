import {logger} from "firebase-functions";
import {CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {checkAuthAndThrow, getMissingParams} from "../utils/utils";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {hasCards} from "../utils/claimsUtils";
import {canUsePack} from "./packAccess";

enum PackSelectedFilter {
  all = "all",
  unseen = "unseen",
  seen = "seen",
  bookmarked = "bookmarked",
  ignored = "ignored",
}

type RequstDataDto = {
  profileId: string | undefined;
  filter: PackSelectedFilter | undefined;
  tags: string[] | undefined;
  packIds: string[] | undefined;
  sessionSize: number | undefined;
  name?: string | null;
  /** Sent by app 1.1.0+; older versions expect any-tag matching. */
  matchAllTags?: boolean;
  /** Cards must have one of these topic tags. */
  topics?: string[];
  /** Cards with any of these tags are left out. */
  excludeTags?: string[];
  /** Which studied cards: "forgotten", "hard" or "due" (all when unset). */
  studied?: string;
};

type FsrsCardData = {
  lapses?: number;
  difficulty?: number;
  state?: string;
  due?: {toDate: () => Date} | Date;
};

/** FSRS difficulty (1 to 10) from which a card counts as hard for the student. */
export const hardDifficulty = 7;

/**
 * Whether a studied card is one the student asked to review: forgotten
 * (answered Again at least once), hard for them, or due now.
 * @param {FsrsCardData | undefined} card The card's FSRS progress.
 * @param {string | undefined} studied The choice; anything else keeps all.
 * @param {Date} now The current time.
 * @return {boolean} Whether to keep the card.
 */
export function matchesStudied(
  card: FsrsCardData | undefined,
  studied: string | undefined,
  now: Date,
): boolean {
  switch (studied) {
  case "forgotten":
    return (card?.lapses ?? 0) > 0 || card?.state === "relearning";
  case "hard":
    return (card?.difficulty ?? 0) >= hardDifficulty;
  case "due": {
    const due = card?.due;
    if (!due) return false;
    const date = due instanceof Date ? due : due.toDate();
    return date.getTime() <= now.getTime();
  }
  default:
    return true;
  }
}

/**
 * Keeps the cards that have one of the topics and none of the excluded
 * tags. Empty lists don't filter.
 * @param {T[]} flashcards Cards to filter.
 * @param {string[]} topics Topic tags, a card needs one of them.
 * @param {string[]} excludeTags Tags whose cards are left out.
 * @return {T[]} The matching cards.
 */
export function filterByTopicsAndExclusions<T extends {tags?: string[]}>(
  flashcards: T[],
  topics: string[],
  excludeTags: string[],
): T[] {
  if (topics.length === 0 && excludeTags.length === 0) return flashcards;
  const excluded = new Set(excludeTags);
  return flashcards.filter((flashcard) => {
    const cardTags = flashcard.tags ?? [];
    if (cardTags.some((tag) => excluded.has(tag))) return false;
    return topics.length === 0 || cardTags.some((tag) => topics.includes(tag));
  });
}

/**
 * The strings of a list sent by the app, or none.
 * @param {unknown} value The value sent.
 * @return {string[]} Its strings.
 */
function stringList(value: unknown): string[] {
  return Array.isArray(value) ?
    value.filter((v): v is string => typeof v === "string") :
    [];
}

/** Longest custom session name, also enforced by renameCustomSession. */
export const maxSessionNameLength = 60;

/**
 * Trims a session name and limits its length.
 * @param {unknown} name Name sent by the app.
 * @return {string | null} The clean name, or null when there is none.
 */
export function cleanSessionName(name: unknown): string | null {
  if (typeof name !== "string") return null;
  const trimmed = name.trim().replace(/\s+/g, " ");
  if (!trimmed) return null;
  return trimmed.slice(0, maxSessionNameLength);
}

/**
 * Keeps the cards that have at least one of the tags (old app versions,
 * which select every tag by default). Untagged cards are kept too.
 * @param {T[]} flashcards Cards to filter.
 * @param {string[]} tags Tags to look for.
 * @return {T[]} The matching cards.
 */
export function filterByAnyTag<T extends {tags?: string[]}>(
  flashcards: T[],
  tags: string[],
): T[] {
  if (tags.length === 0) return flashcards;
  return flashcards.filter((flashcard) => {
    if (!flashcard.tags || flashcard.tags.length === 0) return true;
    return flashcard.tags.some((tag) => tags.includes(tag));
  });
}

/**
 * Keeps the cards that have every one of the tags (e.g. "neoreview" AND
 * "2025"). With no tags selected every card is kept.
 * @param {T[]} flashcards Cards to filter.
 * @param {string[]} tags Tags every kept card must have.
 * @return {T[]} The matching cards.
 */
export function filterByAllTags<T extends {tags?: string[]}>(
  flashcards: T[],
  tags: string[],
): T[] {
  if (tags.length === 0) return flashcards;
  return flashcards.filter((flashcard) => {
    const cardTags = new Set(flashcard.tags ?? []);
    return tags.every((tag) => cardTags.has(tag));
  });
}

type FlashcardSnapshot = {
  id: string;
  packId: string;
  question: string;
  answer: string;
  tags: string[];
  /** The student's progress, for cards they studied. */
  fsrs?: FsrsCardData;
};

export async function createCustomSessionHandler(request: CallableRequest) {
  try {
    const {auth, data} = request;
    checkAuthAndThrow(auth);
    const claims = auth.token as any;

    const {profileId, filter, packIds, tags, sessionSize} =
      data as RequstDataDto;
    const name = cleanSessionName((data as RequstDataDto).name);
    const matchAllTags = (data as RequstDataDto).matchAllTags === true;
    const topics = stringList((data as RequstDataDto).topics);
    const excludeTags = stringList((data as RequstDataDto).excludeTags);
    const studied = (data as RequstDataDto).studied;

    if (!profileId || !filter || !packIds || !tags || !sessionSize) {
      const missingParams = getMissingParams({
        profileId,
        filter,
        packIds,
        tags,
        sessionSize,
      });
      logger.error(`Missing required argument: ${missingParams}`);
      throw new HttpsError(
        "invalid-argument",
        `Missing required argument/s: ${missingParams}`,
      );
    }

    if (profileId !== auth!.uid) {
      throw new HttpsError(
        "permission-denied",
        "You can only create sessions for your own profile.",
      );
    }

    if (packIds.length === 0) {
      logger.error("packIds array is empty");
      throw new HttpsError(
        "invalid-argument",
        "packIds array must contain at least one pack ID.",
      );
    }

    if (packIds.length > 30) {
      logger.error("packIds array exceeds limit of 30");
      throw new HttpsError(
        "invalid-argument",
        "packIds array must not contain more than 30 pack IDs.",
      );
    }

    const packSnapshots = await Promise.all(
      packIds.map((id) => getFirestore().collection("packs").doc(id).get()),
    );
    const allowed = await Promise.all(
      packSnapshots.map((doc) => canUsePack(doc.id, doc.data(), claims)),
    );
    if (allowed.includes(false)) {
      throw new HttpsError(
        "permission-denied",
        "One of the selected packs isn't available for your account.",
      );
    }

    const hasPaidPack = await isPaidPackSelected(packIds);
    const userHasCards = hasCards(claims);

    if (hasPaidPack && !userHasCards) {
      logger.error(
        "User does not have access to paid packs but selected a paid pack",
      );
      throw new HttpsError(
        "permission-denied",
        "You do not have access to the selected paid pack(s). Please purchase access to use paid packs.",
      );
    }

    const now = new Date();
    const flashcardSnapshots = (await getFlashcardsByFilter(
      filter,
      packIds,
      profileId,
    )).filter((card) => !card.fsrs || matchesStudied(card.fsrs, studied, now));
    const filteredFlashcards = filterByTagsAndSlice(
      filterByTopicsAndExclusions(flashcardSnapshots, topics, excludeTags),
      tags,
      sessionSize,
      matchAllTags,
    );
    if (filteredFlashcards.length === 0) {
      logger.info("No flashcards found after filtering");
      throw new HttpsError(
        "not-found",
        "No flashcards match the selected tags and filter. Select fewer tags or another filter.",
      );
    }

    await writeToCustomSession(
      profileId,
      filteredFlashcards,
      hasPaidPack,
      name,
    );

    // return filteredFlashcards;
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;

    logger.error("createCustomSessionHandler failed", {error});
    throw new HttpsError("internal", error.message || "Internal error");
  }

  function filterByTagsAndSlice(
    flashcards: FlashcardSnapshot[],
    tags: string[],
    sessionSize: number,
    matchAllTags: boolean,
  ): FlashcardSnapshot[] {
    const filtered = matchAllTags ?
      filterByAllTags(flashcards, tags) :
      filterByAnyTag(flashcards, tags);

    logger.info(
      `Filtered flashcards by tags. Original count: ${flashcards.length}, Filtered count: ${filtered.length}`,
      {tags},
    );

    // Random selection, so each session isn't the same first cards.
    const sliced = shuffle(filtered).slice(0, sessionSize);
    logger.info(
      `Sliced flashcards to session size: ${sessionSize}. Result count: ${sliced.length}`,
      {sessionSize},
    );
    return sliced;
  }

  async function isPaidPackSelected(packIds: string[]): Promise<boolean> {
    // posto nemam field 'packId' unutar pack-a, moramo da saljemo 30 request-a bazi da bi dobili sve pekove
    // radi se sa Primise.all() koji paralelno izvrsava zahteve, jeste sporije neko 'in' query ali za max 30 pekova
    // je skoro pa zanemarljivo, valjda :)
    const packRefs = packIds.map((id) =>
      getFirestore().collection("packs").doc(id),
    );
    const packSnapshots = await Promise.all(packRefs.map((ref) => ref.get()));

    const hasPaidPack = packSnapshots.some(
      (doc) => doc.exists && doc.data()?.isPaid === true,
    );
    return hasPaidPack;
  }

  async function getFlashcardsByFilter(
    filter: PackSelectedFilter,
    packIds: string[],
    profileId: string,
  ): Promise<FlashcardSnapshot[]> {
    const db = getFirestore();

    // Unseen: cards of the packs without a progress record (never studied,
    // in regular study or a custom session, bookmarked or ignored).
    if (filter === PackSelectedFilter.unseen) {
      const [cards, progress] = await Promise.all([
        db.collection("flashcards").where("packId", "in", packIds).get(),
        db
          .collection("fcp_data")
          .where("profileId", "==", profileId)
          .where("flashcardSnapshot.packId", "in", packIds)
          .select("flashcardId")
          .get(),
      ]);
      const seenIds = new Set(
        progress.docs.map((doc) => doc.get("flashcardId") as string),
      );
      const unseen: FlashcardSnapshot[] = cards.docs
        .filter((doc) => !seenIds.has(doc.id))
        .map((doc) => {
          const data = doc.data();
          return {
            id: doc.id,
            packId: data.packId,
            question: data.question,
            answer: data.answer,
            tags: data.tags ?? [],
          };
        });

      logger.info(
        `Found ${unseen.length} unseen of ${cards.size} flashcards in packs`,
        {packIds},
      );
      return unseen;
    }

    // prvo da vidimo za "all" slucaj
    if (filter === PackSelectedFilter.all) {
      const query = db.collection("flashcards").where("packId", "in", packIds);
      const snapshot = await query.limit(1000).get();

      const flashcardSnapshots: FlashcardSnapshot[] = snapshot.docs.map(
        (doc) => {
          const data = doc.data()!;
          return {
            id: doc.id,
            packId: data.packId,
            question: data.question,
            answer: data.answer,
            tags: data.tags,
          } as FlashcardSnapshot;
        },
      );

      logger.info(`Found ${flashcardSnapshots.length} flashcards in packs`, {
        packIds,
      });
      return flashcardSnapshots;
    }

    let query = db
      .collection("fcp_data")
      .where("profileId", "==", profileId)
      .where("flashcardSnapshot.packId", "in", packIds);
    switch (filter) {
    case PackSelectedFilter.seen:
      // kartica je seen ako je u fcp_data kolekciji
      break;
    case PackSelectedFilter.bookmarked:
      query = query.where("hasBookmark", "==", true);
      break;
    case PackSelectedFilter.ignored:
      query = query.where("ignored", "==", true);
      break;
    default:
      logger.error(`Unknown filter type: ${filter}`);
      throw new HttpsError(
        "invalid-argument",
        `Unknown filter type: ${filter}`,
      );
    }

    const snapshot = await query.limit(1000).get();
    const flashcardSnapshots: FlashcardSnapshot[] = snapshot.docs.map((doc) => {
      const fcSnapshot = doc.data().flashcardSnapshot;
      return {
        id: doc.data().flashcardId,
        packId: fcSnapshot.packId,
        question: fcSnapshot.question,
        answer: fcSnapshot.answer,
        tags: fcSnapshot.tags,
        fsrs: doc.data().fsrs_card ?? {},
      } as FlashcardSnapshot;
    });

    logger.info(`Found ${flashcardSnapshots.length} flashcards in fcp_data`, {
      packIds,
    });
    return flashcardSnapshots;
  }

  async function writeToCustomSession(
    profileId: string,
    flashcards: FlashcardSnapshot[],
    hasPaidPack: boolean,
    name: string | null,
  ) {
    const db = getFirestore();
    const batch = db.batch();
    const sessionRef = db.collection("custom_sessions").doc();
    const flashcardIds = flashcards.map((fc) => fc.id);

    // Kolekcija pamti broj kartica, id-evi se pamte u subkolekciji
    batch.set(sessionRef, {
      profileId,
      cardCount: flashcards.length,
      isPaid: hasPaidPack,
      currentIndex: 0,
      correctCount: 0,
      createdAt: Timestamp.now(),
      ...(name ? {name} : {}),
    });

    batch.set(sessionRef.collection("flashcard_ids").doc("all_ids"), {
      flashcardIds,
    });

    await batch.commit();

    logger.info(
      `Custom session created for profile ${profileId} with ${flashcards.length} flashcards`,
    );
  }
}

/**
 * Returns a shuffled copy of the items (Fisher-Yates).
 * @param {T[]} items The items.
 * @return {T[]} A shuffled copy.
 */
function shuffle<T>(items: T[]): T[] {
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}
