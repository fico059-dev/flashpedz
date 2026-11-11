import {logger} from "firebase-functions";
import {CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {FieldPath, getFirestore} from "firebase-admin/firestore";
import {checkIfAdminAndThrow} from "../utils/utils";

/** Most cards changed by one request. */
export const maxBulkCards = 400;

/**
 * A card's tags after adding and removing some (order kept, no repeats).
 * @param {string[]} tags The card's tags now.
 * @param {string[]} add Tags to add.
 * @param {string[]} remove Tags to remove.
 * @return {string[]} The new tags.
 */
export function changedTags(
  tags: string[],
  add: string[],
  remove: string[],
): string[] {
  const removed = new Set(remove);
  const result: string[] = [];
  for (const tag of [...tags, ...add]) {
    if (!removed.has(tag) && !result.includes(tag)) result.push(tag);
  }
  return result;
}

/**
 * A pack's tag counts after cards' tags changed. Counts never go below
 * zero, and a tag with no cards is left out.
 * @param {Record<string, number>} counts The pack's counts now.
 * @param {{before: string[], after: string[]}[]} changes The cards' tags.
 * @return {Record<string, number>} The new counts.
 */
export function countsAfter(
  counts: Record<string, number>,
  changes: {before: string[]; after: string[]}[],
): Record<string, number> {
  const result: Record<string, number> = {...counts};
  for (const {before, after} of changes) {
    const was = new Set(before);
    const now = new Set(after);
    for (const tag of now) {
      if (!was.has(tag)) result[tag] = (result[tag] ?? 0) + 1;
    }
    for (const tag of was) {
      if (!now.has(tag)) {
        const left = (result[tag] ?? 0) - 1;
        if (left > 0) result[tag] = left;
        else delete result[tag];
      }
    }
  }
  return result;
}

/**
 * Adds and removes tags on many cards at once (pack editor): each pack's
 * tag counts are updated once, the cards in one go, then the students'
 * copies of the cards and the reports. Much faster than one request per
 * card, which all had to take turns updating the same pack.
 * @param {CallableRequest} request {flashcardIds, addTags, removeTags}.
 * @return {Promise<object>} {updated, unchanged, missing}.
 */
export async function bulkUpdateCardTagsHandler(request: CallableRequest) {
  try {
    checkIfAdminAndThrow(request.auth);
    const list = (value: unknown) => Array.isArray(value) ?
      [...new Set(value.filter((v): v is string =>
        typeof v === "string" && v.length > 0))] :
      [];
    const ids = list(request.data?.flashcardIds);
    const add = list(request.data?.addTags);
    const remove = list(request.data?.removeTags);
    if (ids.length === 0 || (add.length === 0 && remove.length === 0)) {
      throw new HttpsError("invalid-argument", "Nothing to change.");
    }
    if (ids.length > maxBulkCards) {
      throw new HttpsError(
        "invalid-argument",
        `At most ${maxBulkCards} cards at a time.`,
      );
    }

    const db = getFirestore();
    const cardRefs = ids.map((id) => db.collection("flashcards").doc(id));
    const snapshots = await db.getAll(...cardRefs);
    const missing = snapshots.filter((s) => !s.exists).map((s) => s.id);

    // The cards of each pack whose tags change.
    const byPack = new Map<string, string[]>();
    for (const snap of snapshots) {
      if (!snap.exists) continue;
      const tags: string[] = snap.get("tags") ?? [];
      const after = changedTags(tags, add, remove);
      if (after.length === tags.length && after.every((t, i) => t === tags[i])) {
        continue;
      }
      const packId = snap.get("packId") as string;
      byPack.set(packId, [...(byPack.get(packId) ?? []), snap.id]);
    }

    // Per pack, in a transaction: the cards (read again, so no change is
    // lost) and the pack's counts, written together.
    const newTags = new Map<string, string[]>();
    await Promise.all([...byPack].map(([packId, cardIds]) =>
      db.runTransaction(async (tx) => {
        const packRef = db.collection("packs").doc(packId);
        const refs = cardIds.map((id) => db.collection("flashcards").doc(id));
        const [pack, ...cards] = await tx.getAll(packRef, ...refs);
        const changes: {before: string[]; after: string[]}[] = [];
        const written = new Map<string, string[]>();
        for (const card of cards) {
          if (!card.exists) continue;
          const before: string[] = card.get("tags") ?? [];
          const after = changedTags(before, add, remove);
          changes.push({before, after});
          written.set(card.id, after);
          tx.update(card.ref, {tags: after});
        }
        if (pack.exists) {
          const counts = countsAfter(pack.get("tagCounts") ?? {}, changes);
          tx.update(packRef, {tagCounts: counts, tags: Object.keys(counts)});
        }
        // Only kept once the transaction succeeded.
        return written;
      }).then((written) => {
        for (const [id, tags] of written) newTags.set(id, tags);
      })
    ));

    // The students' copies of the cards and the reports.
    const writer = db.bulkWriter();
    const changedIds = [...newTags.keys()];
    const chunks: string[][] = [];
    for (let i = 0; i < changedIds.length; i += 30) {
      chunks.push(changedIds.slice(i, i + 30));
    }
    await Promise.all(chunks.map(async (chunk) => {
      const [progress, reports] = await Promise.all([
        db.collection("fcp_data")
          .where("flashcardId", "in", chunk)
          .select("flashcardId")
          .get(),
        db.collection("flashcard_reports")
          .where(FieldPath.documentId(), "in", chunk)
          .select()
          .get(),
      ]);
      for (const doc of progress.docs) {
        const tags = newTags.get(doc.get("flashcardId") as string);
        if (tags) writer.update(doc.ref, {"flashcardSnapshot.tags": tags});
      }
      for (const doc of reports.docs) {
        const tags = newTags.get(doc.id);
        if (tags) writer.update(doc.ref, {"flashcardSnapshot.tags": tags});
      }
    }));
    await writer.close();

    logger.info("Bulk tag change", {
      cards: ids.length,
      updated: changedIds.length,
      add,
      remove,
    });
    return {
      updated: changedIds,
      unchanged: ids.length - changedIds.length - missing.length,
      missing,
    };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    logger.error("bulkUpdateCardTags failed", {error});
    throw new HttpsError("internal", error.message || "Internal error");
  }
}
