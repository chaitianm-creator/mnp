import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onCall } from "firebase-functions/v2/https";

import { REGION, appError, paths } from "../shared/core.js";

/**
 * Phase 6 §1.8 / US-E10-02(ストア審査必須): アカウントと全データの完全削除。
 * users/{uid} ツリー(recursiveDelete) + Storage users/{uid}/** + Auth ユーザー。
 */
export const deleteAccount = onCall(
  { region: REGION, enforceAppCheck: true, timeoutSeconds: 300 },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw appError("auth/unauthenticated", "permission-denied");

    const db = getFirestore();
    // 1. Firestore: サブコレクション込みで再帰削除
    await db.recursiveDelete(db.doc(paths.user(uid)));
    // 2. Storage: 提出画像
    await getStorage().bucket().deleteFiles({ prefix: `users/${uid}/` });
    // 3. Auth
    await getAuth().deleteUser(uid);

    return { ok: true, data: { deleted: true } };
  },
);
