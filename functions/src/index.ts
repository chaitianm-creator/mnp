import { initializeApp } from "firebase-admin/app";

initializeApp();

export { acceptQuest } from "./callable/acceptQuest.js";
export { submitForReview } from "./callable/submitForReview.js";
export { deliverQuest } from "./callable/deliverQuest.js";
export { redeliverReview } from "./callable/redeliverReview.js";
export { deleteAccount } from "./callable/deleteAccount.js";
export { initUser } from "./triggers/onUserCreated.js";
export { processReview } from "./review/pipeline.js";
export { dailyBatch } from "./scheduled/dailyBatch.js";
export { costGuard } from "./scheduled/costGuard.js";
