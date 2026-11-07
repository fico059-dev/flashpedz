// functions/src/index.ts
import {initializeApp} from "firebase-admin/app";

// RUN THIS IF YOU GET TYPESRIPT ERRORS WHEN DEPLOYING!!!!!
// ----------------------------------- npm i typescript@latest -------------------------------------------------------

initializeApp();

// IAP
export {verifyPurchase} from "./iap/router";
export {playRtdn} from "./iap/rtdn";

import {onCall} from "firebase-functions/v2/https";
import {addAdminRoleHandler} from "./handlers/addAdminRole";
import {deletePackProgressHandler} from "./handlers/deletePackProgress";
import {renamePackEverywhereHandler} from "./handlers/renamePackEverywhere";
import {deleteFlashcardEverywhereHandler} from "./handlers/deleteFlashcardEverywhere";
import {updateFlashcardEverywhereHandler} from "./handlers/updateFlashcardEverywhere";
import {
  countCustomSessionCardsHandler,
  createCustomSessionHandler,
} from "./handlers/createCustomSession";
import {renameCustomSessionHandler} from "./handlers/renameCustomSession";
import {
  deleteHighlightHandler,
  listHighlightsHandler,
  saveHighlightHandler,
} from "./handlers/highlights";
import {
  deleteCardSetHandler,
  listCardSetsHandler,
  saveCardSetHandler,
  setCardInSetHandler,
  studyCardSetHandler,
} from "./handlers/cardSets";
import {
  getStudyLogHandler,
  saveStudyLogHandler,
} from "./handlers/studyLog";
import {uploadCardImageHandler} from "./handlers/cardImages";
import {setProfilePhotoHandler} from "./handlers/profilePhoto";
import {
  getPackAccessHandler,
  listSearchableFlashcardsHandler,
  setPackAccessHandler,
} from "./handlers/packAccess";
import {
  deleteOsceFolderHandler,
  listOsceFoldersHandler,
  saveOsceFolderHandler,
  setOsceFolderHandler,
  setOscePremiumHandler,
  setOsceScenarioImageHandler,
} from "./handlers/osceFolders";
import {getAppAnalyticsHandler} from "./handlers/analytics";
import {devGrantHandler} from "./handlers/devGrant";
import {deletePackEverywhereHandler} from "./handlers/deletePackEverywhere";
import {deletePackWithCardsHandler} from "./handlers/deletePackWithCards";
import {deleteUserAndUserDataHandler} from "./handlers/deleteUserAndData";

export const deleteUserAndUserData = onCall(deleteUserAndUserDataHandler);

// admins
export const addAdminRole = onCall(addAdminRoleHandler);
export const getAppAnalytics = onCall(
  {memory: "1GiB", timeoutSeconds: 300},
  getAppAnalyticsHandler,
);

// pack and pp_data operations
export const deletePackProgress = onCall(deletePackProgressHandler);
export const renamePackEverywhere = onCall(renamePackEverywhereHandler);
export const deletePackEverywhereIfEmpty = onCall(deletePackEverywhereHandler);
export const deletePackWithCards = onCall(
  {timeoutSeconds: 540, memory: "512MiB"},
  deletePackWithCardsHandler,
);

// flashcards operations
export const deleteFlashcardEverywhere = onCall(
  deleteFlashcardEverywhereHandler,
);
export const updateFlashcardEverywhere = onCall(
  updateFlashcardEverywhereHandler,
);

// fcp_data operations
// Exams read the tags of every card of the chosen packs: memory (and the
// faster processor that comes with it) like the card search.
export const createCustomSession = onCall(
  {memory: "1GiB", timeoutSeconds: 120},
  createCustomSessionHandler,
);
export const countCustomSessionCards = onCall(
  {memory: "1GiB", timeoutSeconds: 120},
  countCustomSessionCardsHandler,
);
export const renameCustomSession = onCall(renameCustomSessionHandler);
export const saveHighlight = onCall(saveHighlightHandler);
export const deleteHighlight = onCall(deleteHighlightHandler);
export const listHighlights = onCall(listHighlightsHandler);
export const listCardSets = onCall(listCardSetsHandler);
export const saveCardSet = onCall(saveCardSetHandler);
export const deleteCardSet = onCall(deleteCardSetHandler);
export const setCardInSet = onCall(setCardInSetHandler);
export const studyCardSet = onCall(studyCardSetHandler);
export const saveStudyLog = onCall(saveStudyLogHandler);
export const getStudyLog = onCall(getStudyLogHandler);
export const setPackAccess = onCall(setPackAccessHandler);
export const uploadCardImage = onCall(uploadCardImageHandler);
export const setProfilePhoto = onCall(setProfilePhotoHandler);
export const getPackAccess = onCall(getPackAccessHandler);
export const listSearchableFlashcards = onCall(
  {memory: "1GiB", timeoutSeconds: 120},
  listSearchableFlashcardsHandler,
);
export const listOsceFolders = onCall(listOsceFoldersHandler);
export const saveOsceFolder = onCall(saveOsceFolderHandler);
export const deleteOsceFolder = onCall(deleteOsceFolderHandler);
export const setOsceFolder = onCall(setOsceFolderHandler);
export const setOscePremium = onCall(setOscePremiumHandler);
export const setOsceScenarioImage = onCall(setOsceScenarioImageHandler);

// subscription operations
export const devGrant = onCall(devGrantHandler);
