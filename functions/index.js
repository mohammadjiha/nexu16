const functions = require("firebase-functions");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const admin = require("firebase-admin");
const Stripe = require("stripe");

initializeApp();

// Lazy Stripe init — avoids crash during Firebase CLI local analysis
// when env vars aren't loaded yet.
let _stripe = null;
function getStripe() {
  if (!_stripe) {
    _stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
  }
  return _stripe;
}
const JOD_TO_USD = 1.41;

function getCommissionRate(months) {
  if (months >= 6) return 0.03;
  if (months >= 3) return 0.05;
  return 0.07;
}

function calcCommission(monthlyPrice, months) {
  const rate = getCommissionRate(months);
  const subscriptionTotal = monthlyPrice * months;
  const commissionJod = Math.round(subscriptionTotal * rate * 1000) / 1000;
  const commissionUsdCents = Math.round(commissionJod * JOD_TO_USD * 100);
  return { rate, subscriptionTotal, commissionJod, commissionUsdCents };
}

// ─── Commission / credit auth guard ───────────────────────────────────────────
// SECURITY: every commission/credit function below moves money or grants
// credit, so each one must (1) require a real signed-in caller, and
// (2) only ever act on the CALLER'S OWN uid — never an arbitrary userUid
// supplied in the request body. The Dart client already always sends its own
// uid (see commission_service.dart), so this is a pure tightening with zero
// effect on legitimate use.
function _assertOwnUid(context, userUid) {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }
  if (!userUid || userUid !== context.auth.uid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "You may only act on your own account."
    );
  }
}

// ─── createCommissionPayment ──────────────────────────────────────────────────
// Checks user credit first, charges only the remainder via Stripe.
exports.createCommissionPayment = functions
  .runWith({ timeoutSeconds: 30, secrets: ["STRIPE_SECRET_KEY"] })
  .https.onCall(async (data, context) => {
    const { monthlyPrice, months, gymId, playerName, operationType, userUid } = data;

    if (!monthlyPrice || !months || !gymId || !userUid) {
      throw new functions.https.HttpsError("invalid-argument", "Missing required fields");
    }

    _assertOwnUid(context, userUid);
    await _assertCanManageGym(getFirestore(), context.auth.uid, gymId);

    const { rate, subscriptionTotal, commissionJod, commissionUsdCents } =
      calcCommission(Number(monthlyPrice), Number(months));

    // Check user's credit balance
    const db = getFirestore();
    const userDoc = await db.collection("users").doc(userUid).get();
    const currentCredit = userDoc.exists
      ? (userDoc.data().commissionCredit || 0)
      : 0;

    const creditToUse = Math.min(currentCredit, commissionJod);
    const remainingJod = Math.max(0, commissionJod - creditToUse);
    const remainingUsdCents = Math.round(remainingJod * JOD_TO_USD * 100);

    // If credit covers full commission, deduct and return without Stripe
    if (remainingJod <= 0 || remainingUsdCents < 50) {
      if (creditToUse > 0) {
        await db.collection("users").doc(userUid).update({
          commissionCredit: FieldValue.increment(-creditToUse),
        });
      }
      return {
        fullyPaidByCredit: true,
        creditUsed: creditToUse,
        commissionJod,
        subscriptionTotal,
        rate,
        clientSecret: null,
        paymentIntentId: null,
      };
    }

    // Create Stripe PaymentIntent for remaining amount
    const chargeAmount = Math.max(remainingUsdCents, 50);
    const paymentIntent = await getStripe().paymentIntents.create({
      amount: chargeAmount,
      currency: "usd",
      metadata: {
        gymId,
        userUid,
        playerName: playerName || "",
        operationType: operationType || "add_player",
        months: String(months),
        monthlyPrice: String(monthlyPrice),
        commissionJod: String(commissionJod),
        creditUsed: String(creditToUse),
        rate: String(rate),
      },
      description: `NEXUS - ${operationType} - ${playerName || ""}`,
    });

    return {
      fullyPaidByCredit: false,
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
      commissionJod,
      remainingJod,
      creditUsed: creditToUse,
      commissionUsdCents: chargeAmount,
      subscriptionTotal,
      rate,
    };
  });

// ─── verifyCommissionPayment ──────────────────────────────────────────────────
// Verifies Stripe payment, deducts credit, and saves invoice to Firestore.
exports.verifyCommissionPayment = functions
  .runWith({ timeoutSeconds: 30, secrets: ["STRIPE_SECRET_KEY"] })
  .https.onCall(async (data, context) => {
    const {
      paymentIntentId, userUid, creditUsed,
      // Invoice fields (optional — auto-fetched from Firestore if missing)
      gymId, gymName: gymNameArg, playerName, operationType,
      months, monthlyPrice, rate, commissionJod,
    } = data;

    if (!paymentIntentId) {
      throw new functions.https.HttpsError("invalid-argument", "Missing paymentIntentId");
    }
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    if (userUid && userUid !== context.auth.uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "You may only act on your own account."
      );
    }

    const paymentIntent = await getStripe().paymentIntents.retrieve(paymentIntentId);

    if (paymentIntent.status !== "succeeded") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `Payment not completed. Status: ${paymentIntent.status}`
      );
    }

    const db = getFirestore();

    // Deduct credit that was used alongside this payment
    if (userUid && creditUsed && Number(creditUsed) > 0) {
      await db.collection("users").doc(userUid).update({
        commissionCredit: FieldValue.increment(-Number(creditUsed)),
      });
    }

    // Auto-fetch user info (role + name)
    let paidByRole = 'admin';
    let paidByName = '';
    if (userUid) {
      try {
        const userDoc = await db.collection("users").doc(userUid).get();
        if (userDoc.exists) {
          const ud = userDoc.data();
          paidByRole = ud.role || 'admin';
          paidByName = `${ud.firstName || ''} ${ud.lastName || ''}`.trim() || ud.email || '';
        }
      } catch (_) {}
    }

    // Auto-fetch gym name
    const resolvedGymId = gymId || (paymentIntent.metadata && paymentIntent.metadata.gymId) || '';
    if (resolvedGymId) {
      await _assertCanManageGym(db, context.auth.uid, resolvedGymId);
    }
    let gymName = gymNameArg || '';
    if (!gymName && resolvedGymId) {
      try {
        const gymDoc = await db.collection("gyms").doc(resolvedGymId).get();
        if (gymDoc.exists) {
          const gd = gymDoc.data();
          gymName = gd.gymName || gd.name || '';
        }
      } catch (_) {}
    }

    // Fallback invoice fields from PaymentIntent metadata if not provided
    const meta = paymentIntent.metadata || {};
    const resolvedPlayerName = playerName || meta.playerName || '';
    const resolvedOperation = operationType || meta.operationType || '';
    const resolvedMonths = Number(months) || Number(meta.months) || 0;
    const resolvedMonthlyPrice = Number(monthlyPrice) || Number(meta.monthlyPrice) || 0;
    const resolvedRate = Number(rate) || Number(meta.rate) || 0;
    const resolvedCommissionJod = Number(commissionJod) || Number(meta.commissionJod) || 0;
    const resolvedCreditUsed = Number(creditUsed) || Number(meta.creditUsed) || 0;

    // ── Save invoice to Firestore ──────────────────────────────────────────
    const now = new Date();
    const invoiceNum = `INV-${now.getFullYear()}${String(now.getMonth()+1).padStart(2,'0')}${String(now.getDate()).padStart(2,'0')}-${Math.floor(Math.random()*90000+10000)}`;

    const invoice = {
      invoiceNumber: invoiceNum,
      paymentIntentId: paymentIntentId,
      stripeAmount: paymentIntent.amount,
      currency: paymentIntent.currency,
      paidByUid: userUid || '',
      paidByRole,
      paidByName,
      gymId: resolvedGymId,
      gymName,
      playerName: resolvedPlayerName,
      operationType: resolvedOperation,
      months: resolvedMonths,
      monthlyPrice: resolvedMonthlyPrice,
      rate: resolvedRate,
      commissionJod: resolvedCommissionJod,
      creditUsed: resolvedCreditUsed,
      status: 'paid',
      createdAt: now,
    };

    if (userUid) {
      await db.collection("users").doc(userUid)
        .collection("commissionInvoices").add(invoice);
    }
    if (resolvedGymId) {
      await db.collection("gyms").doc(resolvedGymId)
        .collection("commissionInvoices").add(invoice);
    }
    await db.collection("commissionInvoices").add(invoice);

    return { verified: true, invoiceNumber: invoiceNum };
  });

// ─── saveCreditInvoice ────────────────────────────────────────────────────────
// Called when payment is fully covered by credit (no Stripe charge).
exports.saveCreditInvoice = functions
  .runWith({ timeoutSeconds: 30 })
  .https.onCall(async (data, context) => {
    const {
      userUid, gymId, gymName: gymNameArg, playerName, operationType,
      months, monthlyPrice, rate, commissionJod, creditUsed,
    } = data;

    _assertOwnUid(context, userUid);
    const db = getFirestore();
    if (gymId) {
      await _assertCanManageGym(db, context.auth.uid, gymId);
    }

    // Auto-fetch user info
    let paidByRole = 'admin';
    let paidByName = '';
    if (userUid) {
      try {
        const userDoc = await db.collection("users").doc(userUid).get();
        if (userDoc.exists) {
          const ud = userDoc.data();
          paidByRole = ud.role || 'admin';
          paidByName = `${ud.firstName || ''} ${ud.lastName || ''}`.trim() || ud.email || '';
        }
      } catch (_) {}
    }

    // Auto-fetch gym name
    let gymName = gymNameArg || '';
    if (!gymName && gymId) {
      try {
        const gymDoc = await db.collection("gyms").doc(gymId).get();
        if (gymDoc.exists) {
          const gd = gymDoc.data();
          gymName = gd.gymName || gd.name || '';
        }
      } catch (_) {}
    }

    const now = new Date();
    const invoiceNum = `INV-${now.getFullYear()}${String(now.getMonth()+1).padStart(2,'0')}${String(now.getDate()).padStart(2,'0')}-${Math.floor(Math.random()*90000+10000)}`;

    const invoice = {
      invoiceNumber: invoiceNum,
      paymentIntentId: 'CREDIT',
      stripeAmount: 0,
      currency: 'credit',
      paidByUid: userUid || '',
      paidByRole,
      paidByName,
      gymId: gymId || '',
      gymName,
      playerName: playerName || '',
      operationType: operationType || '',
      months: Number(months) || 0,
      monthlyPrice: Number(monthlyPrice) || 0,
      rate: Number(rate) || 0,
      commissionJod: Number(commissionJod) || 0,
      creditUsed: Number(creditUsed) || 0,
      status: 'paid_by_credit',
      createdAt: now,
    };

    if (userUid) {
      await db.collection("users").doc(userUid)
        .collection("commissionInvoices").add(invoice);
    }
    if (gymId) {
      await db.collection("gyms").doc(gymId)
        .collection("commissionInvoices").add(invoice);
    }
    await db.collection("commissionInvoices").add(invoice);

    return { invoiceNumber: invoiceNum };
  });

// ─── addCommissionCredit ──────────────────────────────────────────────────────
// Adds credit to a user's account (called when player is deleted).
exports.addCommissionCredit = functions
  .runWith({ timeoutSeconds: 30 })
  .https.onCall(async (data, context) => {
    const { userUid, creditAmount, reason } = data;

    if (!userUid || !creditAmount) {
      throw new functions.https.HttpsError("invalid-argument", "Missing required fields");
    }
    if (Number(creditAmount) <= 0) {
      throw new functions.https.HttpsError("invalid-argument", "creditAmount must be positive");
    }
    _assertOwnUid(context, userUid);

    const db = getFirestore();
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const callerRole = (callerDoc.exists ? (callerDoc.data().role || "") : "").toLowerCase();
    if (!callerRole || callerRole === "player") {
      throw new functions.https.HttpsError("permission-denied", "Not allowed");
    }

    await db.collection("users").doc(userUid).update({
      commissionCredit: FieldValue.increment(Number(creditAmount)),
    });

    // Log the credit transaction
    await db.collection("users").doc(userUid)
      .collection("creditHistory").add({
        amount: Number(creditAmount),
        reason: reason || "player_deleted",
        timestamp: new Date(),
      });

    return { success: true, creditAdded: creditAmount };
  });

// ─── createBulkCommissionPayment ─────────────────────────────────────────────
// For bulk player import — calculates total commission for all players.
exports.createBulkCommissionPayment = functions
  .runWith({ timeoutSeconds: 60, secrets: ["STRIPE_SECRET_KEY"] })
  .https.onCall(async (data, context) => {
    const { players, gymId, userUid } = data;
    // players: [{monthlyPrice, months, playerName}]

    if (!players || !players.length || !gymId || !userUid) {
      throw new functions.https.HttpsError("invalid-argument", "Missing required fields");
    }

    _assertOwnUid(context, userUid);
    await _assertCanManageGym(getFirestore(), context.auth.uid, gymId);

    // Calculate total commission
    let totalCommissionJod = 0;
    const breakdown = players.map((p) => {
      const { rate, commissionJod } = calcCommission(
        Number(p.monthlyPrice),
        Number(p.months)
      );
      totalCommissionJod += commissionJod;
      return { playerName: p.playerName, commissionJod, rate };
    });
    totalCommissionJod = Math.round(totalCommissionJod * 1000) / 1000;

    // Check user's credit
    const db = getFirestore();
    const userDoc = await db.collection("users").doc(userUid).get();
    const currentCredit = userDoc.exists
      ? (userDoc.data().commissionCredit || 0)
      : 0;

    const creditToUse = Math.min(currentCredit, totalCommissionJod);
    const remainingJod = Math.max(0, totalCommissionJod - creditToUse);
    const remainingUsdCents = Math.round(remainingJod * JOD_TO_USD * 100);

    if (remainingJod <= 0 || remainingUsdCents < 50) {
      if (creditToUse > 0) {
        await db.collection("users").doc(userUid).update({
          commissionCredit: FieldValue.increment(-creditToUse),
        });
      }
      return {
        fullyPaidByCredit: true,
        creditUsed: creditToUse,
        totalCommissionJod,
        breakdown,
        clientSecret: null,
        paymentIntentId: null,
      };
    }

    const chargeAmount = Math.max(remainingUsdCents, 50);
    const paymentIntent = await getStripe().paymentIntents.create({
      amount: chargeAmount,
      currency: "usd",
      metadata: {
        gymId,
        userUid,
        operationType: "bulk_import",
        playerCount: String(players.length),
        totalCommissionJod: String(totalCommissionJod),
        creditUsed: String(creditToUse),
      },
      description: `NEXUS - Bulk import ${players.length} players`,
    });

    return {
      fullyPaidByCredit: false,
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
      totalCommissionJod,
      remainingJod,
      creditUsed: creditToUse,
      breakdown,
    };
  });

// ─── updatePlayerPassword ─────────────────────────────────────────────────────
// Called by Admin to change a player's Firebase Auth password.
// Only gym admins/coaches of that gym (or super admin) may call this.
exports.updatePlayerPassword = functions
  .runWith({ timeoutSeconds: 30 })
  .https.onCall(async (data, context) => {
    const { targetUid, newPassword, callerUid } = data;
    // Default true to preserve old behavior for existing callers that don't
    // pass this — the "quick random-generate" reset flow SHOULD still force
    // the player to pick their own password on next login. Only the "admin
    // types a specific final password" flow passes temporary:false.
    const isTemporary = data && data.temporary === false ? false : true;

    if (!targetUid || !newPassword || newPassword.length < 6) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "targetUid and newPassword (min 6 chars) are required"
      );
    }
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Must be signed in");
    }

    const db = getFirestore();

    // Verify caller has permission: must be admin/coach of same gym OR super admin
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    if (!callerDoc.exists) {
      throw new functions.https.HttpsError("permission-denied", "Caller not found");
    }
    const callerData = callerDoc.data();
    const callerRole = (callerData.role || '').toLowerCase();

    // Players cannot change other users' passwords
    if (callerRole === 'player') {
      throw new functions.https.HttpsError("permission-denied", "Players cannot change passwords");
    }

    // Non-super-admins can only change passwords of users in their own gym
    if (callerRole !== 'super_admin') {
      const targetDoc = await db.collection("users").doc(targetUid).get();
      if (!targetDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Target user not found");
      }
      if (targetDoc.data().gymId !== callerData.gymId) {
        throw new functions.https.HttpsError("permission-denied", "Different gym");
      }
    }

    // Update Firebase Auth password via Admin SDK
    console.log(`[updatePlayerPassword] Updating auth for uid=${targetUid}, pwLen=${newPassword.length}`);
    try {
      await admin.auth().updateUser(targetUid, { password: newPassword });

      // While resetting, also repair a bad login email (Arabic/@gym-/uXXXX@…)
      // so the login email matches the clean displayed one. No-op if good.
      try {
        const td = (await db.collection("users").doc(targetUid).get()).data() || {};
        await _repairOnePlayer(db, targetUid, td);
      } catch (e) {
        console.warn("[updatePlayerPassword] email repair skipped:", e.message);
      }

      const updatedUser = await admin.auth().getUser(targetUid);
      console.log(`[updatePlayerPassword] ✅ Auth updated for uid=${targetUid}, email=${updatedUser.email}`);

      // Save auth email + new password to Firestore so Flutter shows the correct login email.
      // temporaryPasswordSet controls whether the router forces the player into
      // /change_password on next login — only true for the "quick random
      // password" reset flow. When the admin deliberately types a specific
      // password (temporary:false), it should just work at login, no forced
      // follow-up change that would silently overwrite what the admin set.
      await db.collection("users").doc(targetUid).update({
        temporaryPassword: newPassword,
        temporaryPasswordSet: isTemporary,
        email: updatedUser.email,
        authEmail: updatedUser.email,   // the real Firebase Auth login email
        updatedAt: FieldValue.serverTimestamp(),
      });

      return { success: true, uid: targetUid, authEmail: updatedUser.email };
    } catch (authErr) {
      console.error(`[updatePlayerPassword] ❌ Auth update failed:`, authErr.code, authErr.message);
      throw new functions.https.HttpsError("internal", `Auth update failed: ${authErr.message}`);
    }
  });

// ─── Helper: send FCM push to a single user ──────────────────────────────────
async function sendFcmToUser(uid, title, body, data = {}) {
  const db = getFirestore();
  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) return;
  const token = userSnap.data().fcmToken;
  if (!token) return;
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data: { ...data },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });
  } catch (e) {
    console.warn(`[FCM] Failed to send to uid=${uid}: ${e.message}`);
  }
}

// ─── onNotificationCreated ────────────────────────────────────────────────────
// Fires whenever a coach/admin writes a notification doc to users/{uid}/notifications.
// Sends the FCM push to the recipient's device.
exports.onNotificationCreated = functions.firestore
  .document("users/{userId}/notifications/{notifId}")
  .onCreate(async (snap, context) => {
    const { userId } = context.params;
    const { title, body, type } = snap.data();
    if (!title || !body) return null;
    await sendFcmToUser(userId, title, body, { type: type || "general" });
    return null;
  });

// ─── onCommunityComment ───────────────────────────────────────────────────────
// Fires when a new comment is added to communityPosts/{postId}/comments/.
// Notifies the post owner (unless they commented on their own post).
exports.onCommunityComment = functions.firestore
  .document("communityPosts/{postId}/comments/{commentId}")
  .onCreate(async (snap, context) => {
    const { postId } = context.params;
    const db = getFirestore();
    const comment = snap.data();
    const commenterId = comment.userId;
    const commenterName = comment.userName || "Someone";

    // Fetch the parent post to get the owner's uid
    const postSnap = await db.collection("communityPosts").doc(postId).get();
    if (!postSnap.exists) return null;
    const post = postSnap.data();
    const postOwnerId = post.userId;

    // Don't notify if the post owner commented on their own post
    if (!postOwnerId || postOwnerId === commenterId) return null;

    const title = "💬 تعليق جديد";
    const body = `${commenterName} علّق على منشورك`;
    const postPreview = (post.content || "").substring(0, 60);

    // Write in-app notification doc (will also trigger this function's sibling)
    await db.collection("users").doc(postOwnerId).collection("notifications").add({
      type: "community_comment",
      title,
      body,
      postId,
      postPreview,
      commenterId,
      commenterName,
      route: "/community",
      read: false,
      senderId: commenterId,
      createdAt: FieldValue.serverTimestamp(),
    });

    // Send FCM directly as well (faster than waiting for onNotificationCreated)
    await sendFcmToUser(postOwnerId, title, body, {
      type: "community_comment",
      route: "/community",
      postId,
    });

    return null;
  });

// ─── Trophy level helper ─────────────────────────────────────────────────────
function getTrophyLevel(trophies) {
  if (trophies >= 1500) return 'diamond';
  if (trophies >= 700)  return 'gold';
  if (trophies >= 300)  return 'silver';
  if (trophies >= 100)  return 'bronze';
  return 'none';
}

const _levelNames = {
  bronze:  'البرونز 🥉',
  silver:  'الفضة 🥈',
  gold:    'الذهب 🥇',
  diamond: 'الألماس 💎',
};

// ─── onWorkoutSessionCreated ──────────────────────────────────────────────────
// Fires when the Flutter app saves a completed session to
// users/{uid}/workoutHistory/{sessionId}.
//
// Responsibilities
// ────────────────
// 1. Skip sessions where completedSets == 0 (player just pressed Finish).
// 2. Detect personal records (PRs) from exercisesLog — award +25 pts each.
// 3. Update current / longest streak and award streak bonuses.
// 4. Compute new trophyLevel; if it changed → FCM + in-app notification.
// 5. Increment totalSessionsCompleted.
//
// Note: the base workout points (10 + sets) are already awarded client-side
// via TrophyService.awardTrophiesOnce — this function adds only the BONUS
// points that require server-side historical data (PRs, streak).
exports.onWorkoutSessionCreated = functions.firestore
  .document("users/{uid}/workoutHistory/{sessionId}")
  .onCreate(async (snap, context) => {
    const { uid } = context.params;
    const session = snap.data();

    // Skip sessions with no completed sets — player just tapped Finish
    const completedSets = session.completedSets || 0;
    if (completedSets === 0) return null;

    const db = getFirestore();
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) return null;

    const userData = userSnap.data();
    const currentTrophies = userData.trophies || 0;
    const currentPRs = userData.personalRecords || {};

    // ── 1. PR detection ───────────────────────────────────────────────────────
    const exercisesLog = session.exercisesLog || [];
    const newPRExercises = [];
    const updatedPRs = { ...currentPRs };

    for (const exercise of exercisesLog) {
      if (!exercise.name) continue;
      const sets = exercise.sets || [];
      let maxKg = 0;
      for (const s of sets) {
        if (!s.skipped) {
          const kg = parseFloat(s.kg) || 0;
          if (kg > maxKg) maxKg = kg;
        }
      }
      if (maxKg > 0) {
        const prevMax = currentPRs[exercise.name] || 0;
        if (maxKg > prevMax) {
          newPRExercises.push({ name: exercise.name, kg: maxKg, prev: prevMax });
          updatedPRs[exercise.name] = maxKg;
        }
      }
    }

    // ── 2. Streak calculation ─────────────────────────────────────────────────
    const today = new Date().toISOString().split('T')[0];
    const lastWorkoutDate = userData.lastWorkoutDate || null;
    let currentStreak = userData.currentStreak || 0;
    let longestStreak = userData.longestStreak || 0;

    if (lastWorkoutDate === null) {
      currentStreak = 1;
    } else if (lastWorkoutDate === today) {
      // Second session on the same day — don't change streak
    } else {
      const prevDate = new Date(lastWorkoutDate);
      const todayDate = new Date(today);
      const diffDays = Math.round((todayDate - prevDate) / (1000 * 60 * 60 * 24));
      currentStreak = diffDays === 1 ? currentStreak + 1 : 1;
    }
    if (currentStreak > longestStreak) longestStreak = currentStreak;

    // ── 3. Bonus points ───────────────────────────────────────────────────────
    let bonusPoints = 0;

    // +25 per PR
    bonusPoints += newPRExercises.length * 25;

    // Streak milestones (fire only once — check previous streak value)
    const prevStreak = userData.currentStreak || 0;
    if (currentStreak === 7  && prevStreak < 7)  bonusPoints += 50;
    if (currentStreak === 14 && prevStreak < 14) bonusPoints += 100;
    if (currentStreak === 30 && prevStreak < 30) bonusPoints += 200;

    // ── 4. Trophy level check ─────────────────────────────────────────────────
    const newTotal   = currentTrophies + bonusPoints;
    const oldLevel   = getTrophyLevel(currentTrophies);
    const newLevel   = getTrophyLevel(newTotal);
    const leveledUp  = newLevel !== oldLevel && newLevel !== 'none';

    // ── 5. Write to Firestore ─────────────────────────────────────────────────
    const updates = {
      personalRecords: updatedPRs,
      currentStreak,
      longestStreak,
      lastWorkoutDate: today,
      trophyLevel: getTrophyLevel(newTotal),
      totalSessionsCompleted: FieldValue.increment(1),
    };
    if (bonusPoints > 0) {
      updates.trophies = FieldValue.increment(bonusPoints);
      updates.cups     = FieldValue.increment(bonusPoints);
    }
    // Strength points: only from PRs (independent of overall trophies)
    if (newPRExercises.length > 0) {
      updates.strengthPoints = FieldValue.increment(newPRExercises.length * 25);
    }
    await userRef.update(updates);

    // ── 6. PR push notification ───────────────────────────────────────────────
    if (newPRExercises.length > 0) {
      const pr = newPRExercises[0];
      const prTitle = "🏋️ رقم شخصي جديد!";
      const prBody  = `${pr.name}: ${pr.kg} كيلو — أنت تقوى كل يوم 💪`;
      await sendFcmToUser(uid, prTitle, prBody, {
        type: "pr_achievement",
        route: "/dashboard",
      });
    }

    // ── 7. Streak milestone push notification ─────────────────────────────────
    const streakMilestones = { 7: "🔥 أسبوع كامل!", 14: "🔥🔥 أسبوعان!", 30: "🔥🔥🔥 شهر كامل!" };
    if (streakMilestones[currentStreak] && currentStreak !== prevStreak) {
      await sendFcmToUser(uid,
        streakMilestones[currentStreak],
        `${currentStreak} يوم متتالي بدون انقطاع — استمر أنت على الطريق الصح!`,
        { type: "streak_milestone", route: "/dashboard" }
      );
    }

    // ── 8. Level-up push + in-app notification ────────────────────────────────
    if (leveledUp) {
      const levelName = _levelNames[newLevel] || newLevel;
      const lvTitle = `🏆 ترقية في الرانك!`;
      const lvBody  = `وصلت لمستوى ${levelName} — تحقق من الرانك في صفحة المجتمع!`;

      await sendFcmToUser(uid, lvTitle, lvBody, {
        type:  "level_up",
        route: "/community",
      });

      const notifDb = getFirestore();
      await notifDb.collection("users").doc(uid).collection("notifications").add({
        type:      "level_up",
        title:     lvTitle,
        body:      lvBody,
        route:     "/community",
        read:      false,
        senderId:  uid,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    return null;
  });

// ─── onCommunityLike ──────────────────────────────────────────────────────────
// Fires when a communityPost document is updated.
// If a new uid appeared in likedBy → notify the post owner.
exports.onCommunityLike = functions.firestore
  .document("communityPosts/{postId}")
  .onUpdate(async (change, context) => {
    const db = getFirestore();
    const before = change.before.data();
    const after  = change.after.data();

    const likedBefore = new Set(before.likedBy || []);
    const likedAfter  = after.likedBy || [];

    // Find the uid(s) that newly liked (not unliked)
    const newLikers = likedAfter.filter(uid => !likedBefore.has(uid));
    if (newLikers.length === 0) return null;   // it was an unlike → skip

    const postOwnerId = after.userId;
    if (!postOwnerId) return null;

    // Only process the first new liker (usually one at a time)
    const likerId = newLikers[0];

    // Don't notify if owner liked their own post
    if (likerId === postOwnerId) return null;

    // Get liker's name
    const likerSnap = await db.collection("users").doc(likerId).get();
    const likerName = likerSnap.exists
      ? ((likerSnap.data().firstName || "") + " " + (likerSnap.data().lastName || "")).trim() || "Someone"
      : "Someone";

    const title = "❤️ إعجاب جديد";
    const body  = `${likerName} أعجبه منشورك`;
    const postPreview = (after.content || "").substring(0, 60);

    // Write in-app notification
    await db.collection("users").doc(postOwnerId).collection("notifications").add({
      type: "community_like",
      title,
      body,
      postId: context.params.postId,
      postPreview,
      likerId,
      likerName,
      route: "/community",
      read: false,
      senderId: likerId,
      createdAt: FieldValue.serverTimestamp(),
    });

    // Send FCM
    await sendFcmToUser(postOwnerId, title, body, {
      type: "community_like",
      route: "/community",
      postId: context.params.postId,
    });

    return null;
  });

// ════════════════════════════════════════════════════════════════════════════
// Gemini AI proxy — keeps the API key server-side. Clients NEVER receive it.
// The key is read from the GEMINI_API_KEY environment variable (functions/.env
// locally, or Secret Manager / `firebase functions:config`/env in production).
// ════════════════════════════════════════════════════════════════════════════

const GEMINI_DEFAULT_MODEL = "gemini-2.5-flash";

function _geminiKey() {
  const key = process.env.GEMINI_API_KEY;
  if (!key || !key.trim()) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "AI is not configured on the server (missing GEMINI_API_KEY)."
    );
  }
  return key.trim();
}

// Calls the Gemini generateContent REST endpoint and returns the plain text.
async function _callGemini(model, body) {
  const url =
    "https://generativelanguage.googleapis.com/v1beta/models/" +
    encodeURIComponent(model || GEMINI_DEFAULT_MODEL) +
    ":generateContent?key=" +
    _geminiKey();

  let resp;
  try {
    resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  } catch (e) {
    throw new functions.https.HttpsError("unavailable", "AI request failed: " + e.message);
  }

  if (!resp.ok) {
    const errText = await resp.text().catch(() => "");
    // 400/403 here usually means the API key value itself is invalid.
    throw new functions.https.HttpsError(
      "internal",
      "AI error " + resp.status + ": " + errText.slice(0, 400)
    );
  }

  const json = await resp.json();
  const parts = json &&
    json.candidates &&
    json.candidates[0] &&
    json.candidates[0].content &&
    json.candidates[0].content.parts;
  const text = Array.isArray(parts)
    ? parts.map((p) => (p && p.text ? p.text : "")).join("")
    : "";
  return text;
}

// ─── geminiGenerate ───────────────────────────────────────────────────────────
// One-shot generation. Input: { model?, prompt, fileBase64?, mimeType?, jsonOnly? }
exports.geminiGenerate = functions
  .runWith({
    timeoutSeconds: 120,
    memory: "1GB",
    secrets: ["GEMINI_API_KEY"],
    // App Check: kept false because the app intentionally skips App Check in
    // debug builds. Set to true for production once you register an App Check
    // debug token in the Firebase console (otherwise debug calls are rejected).
    enforceAppCheck: false,
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }

    const model = (data && data.model ? String(data.model) : "") || GEMINI_DEFAULT_MODEL;
    const prompt = data && data.prompt ? String(data.prompt) : "";
    const fileBase64 = data && data.fileBase64 ? String(data.fileBase64) : "";
    const mimeType = data && data.mimeType ? String(data.mimeType) : "";

    const parts = [];
    if (prompt) parts.push({ text: prompt });
    if (fileBase64 && mimeType) {
      parts.push({ inline_data: { mime_type: mimeType, data: fileBase64 } });
    }
    if (parts.length === 0) {
      throw new functions.https.HttpsError("invalid-argument", "Nothing to generate.");
    }

    const body = { contents: [{ role: "user", parts }] };
    if (data && data.jsonOnly) {
      body.generationConfig = { responseMimeType: "application/json" };
    }

    const text = await _callGemini(model, body);
    return { text };
  });

// ─── geminiChat ───────────────────────────────────────────────────────────────
// Multi-turn chat. Input: { model?, systemInstruction?, history?: [{role,text}], message }
// role must be "user" or "model".
exports.geminiChat = functions
  .runWith({
    timeoutSeconds: 60,
    memory: "512MB",
    secrets: ["GEMINI_API_KEY"],
    // See note above — enable in production after registering a debug token.
    enforceAppCheck: false,
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }

    const model = (data && data.model ? String(data.model) : "") || GEMINI_DEFAULT_MODEL;
    const message = data && data.message ? String(data.message) : "";
    if (!message) {
      throw new functions.https.HttpsError("invalid-argument", "Empty message.");
    }

    const history = Array.isArray(data && data.history) ? data.history : [];
    const contents = [];
    for (const h of history) {
      if (!h) continue;
      const role = h.role === "model" ? "model" : "user";
      const text = h.text ? String(h.text) : "";
      if (text) contents.push({ role, parts: [{ text }] });
    }
    contents.push({ role: "user", parts: [{ text: message }] });

    const body = { contents };
    const sys = data && data.systemInstruction ? String(data.systemInstruction) : "";
    if (sys) body.systemInstruction = { parts: [{ text: sys }] };

    const text = await _callGemini(model, body);
    return { text };
  });

// ════════════════════════════════════════════════════════════════════════════
// Player email repair — fixes old/bad auto-generated emails (Arabic, .nexus,
// uXXXX@, @gym-…) by changing the real Firebase Auth login email to a clean
// transliterated firstname.lastname.xxxx@gmail.com, and syncing Firestore.
// Only the Admin SDK can change an Auth email, so this lives server-side.
// ════════════════════════════════════════════════════════════════════════════

const _ARABIC_MAP = {
  "ا": "a", "أ": "a", "إ": "a", "آ": "a", "ب": "b", "ت": "t", "ث": "th",
  "ج": "j", "ح": "h", "خ": "kh", "د": "d", "ذ": "dh", "ر": "r", "ز": "z",
  "س": "s", "ش": "sh", "ص": "s", "ض": "d", "ط": "t", "ظ": "z", "ع": "a",
  "غ": "gh", "ف": "f", "ق": "q", "ك": "k", "ل": "l", "م": "m", "ن": "n",
  "ه": "h", "و": "w", "ي": "y", "ى": "a", "ة": "h", "ئ": "y", "ء": "", "ؤ": "w",
};

function _transliterate(input) {
  const stripped = (input || "").replace(
    /[ؐ-ًؚ-ْٰـ]/g, "");
  let out = "";
  for (let i = 0; i < stripped.length; i++) {
    const two = stripped.substr(i, 2);
    if (two === "لا") { out += "la"; i++; continue; }
    if (two === "ال") { out += "al"; i++; continue; }
    const ch = stripped[i];
    if (Object.prototype.hasOwnProperty.call(_ARABIC_MAP, ch)) {
      out += _ARABIC_MAP[ch];
    } else if (/[a-zA-Z]/.test(ch)) {
      out += ch.toLowerCase();
    }
  }
  out = out.replace(/[^a-z]/g, "");
  return out || "player";
}

function _genEmail(first, last) {
  const f = _transliterate(first);
  const l = _transliterate(last);
  const chars = "abcdefghjkmnpqrstuvwxyz23456789";
  let rand = "";
  for (let i = 0; i < 6; i++) {
    rand += chars[Math.floor(Math.random() * chars.length)];
  }
  const local = [f, l, rand].filter((s) => s).join(".");
  return `${local}@gmail.com`;
}

function _isBadEmail(email) {
  const e = (email || "").trim().toLowerCase();
  if (!e) return true;
  if (/[؀-ۿ]/.test(e)) return true;   // Arabic characters
  if (e.includes(".nexus")) return true;
  if (/^u\d{10,}@/.test(e)) return true;
  if (/^p09\d+@/.test(e)) return true;
  if (/@gym-/.test(e)) return true;
  return false;
}

// Returns an email guaranteed not to collide with an existing Auth user.
async function _uniqueEmail(seedEmail) {
  let candidate = seedEmail;
  for (let i = 0; i < 6; i++) {
    try {
      await admin.auth().getUserByEmail(candidate);
      // Exists → add a numeric suffix and retry.
      const at = candidate.indexOf("@");
      const local = candidate.slice(0, at);
      const domain = candidate.slice(at + 1);
      candidate = `${local}.${Math.floor(1000 + Math.random() * 9000)}@${domain}`;
    } catch (e) {
      return candidate; // not found → available
    }
  }
  return candidate;
}

// Repairs ONE player's email (Auth + Firestore + memberEmails). Returns the
// final email, or null if nothing changed.
async function _repairOnePlayer(db, uid, data) {
  let authUser;
  try {
    authUser = await admin.auth().getUser(uid);
  } catch (e) {
    return null; // no auth account
  }
  const currentEmail = authUser.email || "";
  if (!_isBadEmail(currentEmail)) return null; // already good

  const newEmail = await _uniqueEmail(
    _genEmail(data.firstName || "", data.lastName || ""));

  await admin.auth().updateUser(uid, { email: newEmail });

  const gymId = data.gymId;
  const userUpdate = {
    email: newEmail,
    authEmail: newEmail,
    updatedAt: FieldValue.serverTimestamp(),
  };
  await db.collection("users").doc(uid).update(userUpdate);

  if (gymId) {
    const gymRef = db.collection("gyms").doc(gymId);
    try {
      if (currentEmail) {
        await gymRef.collection("memberEmails")
          .doc(currentEmail.toLowerCase()).delete();
      }
      await gymRef.collection("memberEmails")
        .doc(newEmail.toLowerCase()).set({
          role: "player",
          status: "active",
          firstName: data.firstName || "",
          lastName: data.lastName || "",
          phone: data.phone || "",
          addedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      await gymRef.collection("members").doc(uid)
        .set({ email: newEmail }, { merge: true });
    } catch (e) { /* best-effort */ }
  }
  return newEmail;
}

async function _assertCanManageGym(db, callerUid, gymId) {
  const callerDoc = await db.collection("users").doc(callerUid).get();
  if (!callerDoc.exists) {
    throw new functions.https.HttpsError("permission-denied", "Caller not found");
  }
  const c = callerDoc.data();
  const role = (c.role || "").toLowerCase();
  if (role === "player") {
    throw new functions.https.HttpsError("permission-denied", "Not allowed");
  }
  if (role !== "super_admin" && c.gymId !== gymId) {
    throw new functions.https.HttpsError("permission-denied", "Different gym");
  }
}

// ─── fixGymPlayerEmails ───────────────────────────────────────────────────────
// Bulk-repairs every player in a gym whose Auth email is bad. Owner-triggered.
exports.fixGymPlayerEmails = functions
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const gymId = data && data.gymId ? String(data.gymId) : "";
    if (!gymId) {
      throw new functions.https.HttpsError("invalid-argument", "gymId required");
    }

    const db = getFirestore();
    await _assertCanManageGym(db, context.auth.uid, gymId);

    const snap = await db.collection("users")
      .where("gymId", "==", gymId)
      .where("role", "==", "player")
      .get();

    let fixed = 0, skipped = 0, failed = 0;
    for (const doc of snap.docs) {
      try {
        const res = await _repairOnePlayer(db, doc.id, doc.data() || {});
        if (res) fixed++; else skipped++;
      } catch (e) {
        failed++;
      }
    }
    return { fixed, skipped, failed, total: snap.size };
  });

// ─── auditPlayerAccounts ──────────────────────────────────────────────────────
// Classifies every Firebase Auth account and (optionally) deletes ONLY the
// confirmed-junk ones. An account is deleted only when ALL of these hold:
//   1. its email matches a junk pattern (Arabic / .nexus / uXXXX@ / @gym-…),
//   2. there is NO users/{uid} Firestore doc (zero player data),
//   3. NO user doc references that email (so it isn't a mis-linked login).
// Accounts that hold player data are never touched. Run with deleteOrphans=false
// first to preview, then deleteOrphans=true to clean.
exports.auditPlayerAccounts = functions
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const db = getFirestore();
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const role = (callerDoc.exists ? (callerDoc.data().role || "") : "").toLowerCase();
    if (!role || role === "player") {
      throw new functions.https.HttpsError("permission-denied", "Not allowed");
    }

    const doDelete = !!(data && data.deleteOrphans === true);

    let linked = 0, mislinked = 0, orphans = 0, deleted = 0, deleteFailed = 0;
    const mislinkedSample = [];
    const orphanSample = [];

    let pageToken = undefined;
    do {
      const res = await admin.auth().listUsers(1000, pageToken);
      for (const u of res.users) {
        const email = (u.email || "").toLowerCase();
        if (!email) continue;          // phone-only / no-email accounts: skip
        if (!_isBadEmail(email)) continue; // clean emails: never touch

        // 1) Does this uid have a player document?
        const docSnap = await db.collection("users").doc(u.uid).get();
        if (docSnap.exists) { linked++; continue; }

        // 2) Is this email referenced by any user doc (mis-linked login)?
        let referenced = false;
        const q1 = await db.collection("users")
          .where("email", "==", email).limit(1).get();
        if (!q1.empty) {
          referenced = true;
        } else {
          const q2 = await db.collection("users")
            .where("authEmail", "==", email).limit(1).get();
          referenced = !q2.empty;
        }
        if (referenced) {
          mislinked++;
          if (mislinkedSample.length < 50) mislinkedSample.push(email);
          continue;
        }

        // 3) Confirmed orphan (junk email, no doc, no reference).
        orphans++;
        if (orphanSample.length < 100) orphanSample.push(email);
        if (doDelete) {
          try {
            await admin.auth().deleteUser(u.uid);
            deleted++;
          } catch (e) {
            deleteFailed++;
          }
        }
      }
      pageToken = res.pageToken;
    } while (pageToken);

    return {
      linked,
      mislinked,
      orphans,
      deleted,
      deleteFailed,
      didDelete: doDelete,
      mislinkedSample,
      orphanSample,
    };
  });

// ─── Login brute-force lockout ────────────────────────────────────────────────
// Tracks failed email/password sign-in attempts per email in
// /loginAttempts/{email} (Firestore rules deny ALL client access to this
// collection — only these Cloud Functions, via the Admin SDK, ever touch it).
//
// Both functions are intentionally callable WITHOUT context.auth: the whole
// point is to gate an attempt BEFORE the user has successfully signed in, so
// there is no auth token to check yet. This is safe because the functions
// only ever read/increment a per-email counter — they never expose or modify
// any other user data.
const MAX_LOGIN_ATTEMPTS = 5;
const LOGIN_LOCKOUT_MS = 15 * 60 * 1000; // 15 minutes

function normalizeEmailKey(email) {
  return String(email || "").trim().toLowerCase();
}

// Called by the client right before attempting sign-in.
exports.checkLoginLock = functions
  .runWith({ timeoutSeconds: 10 })
  .https.onCall(async (data) => {
    const email = normalizeEmailKey(data && data.email);
    if (!email) {
      throw new functions.https.HttpsError("invalid-argument", "Missing email");
    }

    const db = getFirestore();
    const doc = await db.collection("loginAttempts").doc(email).get();
    if (!doc.exists) {
      return { locked: false, attemptsRemaining: MAX_LOGIN_ATTEMPTS, lockedUntilMs: null };
    }

    const d = doc.data();
    const lockedUntilMs = d.lockedUntil ? d.lockedUntil.toMillis() : 0;
    if (lockedUntilMs > Date.now()) {
      return { locked: true, attemptsRemaining: 0, lockedUntilMs };
    }

    const count = d.count || 0;
    return {
      locked: false,
      attemptsRemaining: Math.max(0, MAX_LOGIN_ATTEMPTS - count),
      lockedUntilMs: null,
    };
  });

// Called by the client right after every sign-in attempt (success or failure).
exports.recordLoginResult = functions
  .runWith({ timeoutSeconds: 10 })
  .https.onCall(async (data) => {
    const email = normalizeEmailKey(data && data.email);
    const success = data && data.success === true;
    if (!email) {
      throw new functions.https.HttpsError("invalid-argument", "Missing email");
    }

    const db = getFirestore();
    const ref = db.collection("loginAttempts").doc(email);

    if (success) {
      await ref.set(
        { count: 0, lockedUntil: null, updatedAt: FieldValue.serverTimestamp() },
        { merge: true }
      );
      return { locked: false, attemptsRemaining: MAX_LOGIN_ATTEMPTS, lockedUntilMs: null };
    }

    return db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const d = snap.exists ? snap.data() : {};
      const existingLockedUntilMs = d.lockedUntil ? d.lockedUntil.toMillis() : 0;

      // Already locked — don't extend the lock further, just report it.
      if (existingLockedUntilMs > Date.now()) {
        return { locked: true, attemptsRemaining: 0, lockedUntilMs: existingLockedUntilMs };
      }

      const newCount = (d.count || 0) + 1;
      if (newCount >= MAX_LOGIN_ATTEMPTS) {
        const lockedUntilMs = Date.now() + LOGIN_LOCKOUT_MS;
        tx.set(
          ref,
          {
            count: 0, // fresh window once the lock expires
            lockedUntil: new Date(lockedUntilMs),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        return { locked: true, attemptsRemaining: 0, lockedUntilMs };
      }

      tx.set(
        ref,
        { count: newCount, lockedUntil: null, updatedAt: FieldValue.serverTimestamp() },
        { merge: true }
      );
      return { locked: false, attemptsRemaining: MAX_LOGIN_ATTEMPTS - newCount, lockedUntilMs: null };
    });
  });

// ─── resetPasswordViaPhone ────────────────────────────────────────────────────
// Called by ForgotPhoneScreen after the user has already completed real
// Firebase Phone Auth (signInWithCredential with a verified SMS code). We
// NEVER trust a client-supplied phone number — we only trust
// context.auth.token.phone_number, which Firebase Auth itself stamps onto the
// caller's ID token, so this cannot be spoofed by sending an arbitrary phone
// string in the request body.
//
// accountRecovery/{phoneKey} (phoneKey = digits-only phone) is maintained by
// admin/coach flows whenever a player's phone is set (see
// admin_repository.dart / coach_repository.dart) and maps a phone number to
// the Firebase Auth uid + email it belongs to.
exports.resetPasswordViaPhone = functions
  .runWith({ timeoutSeconds: 30 })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Phone OTP required.");
    }

    const verifiedPhone = context.auth.token.phone_number;
    if (!verifiedPhone) {
      throw new functions.https.HttpsError("failed-precondition", "No verified phone number.");
    }

    const newPassword = String((data && data.newPassword) || "").trim();
    if (newPassword.length < 6) {
      throw new functions.https.HttpsError("invalid-argument", "Password must be at least 6 characters.");
    }

    const db = getFirestore();
    const phoneKey = verifiedPhone.replace(/\D/g, "");
    const recoverySnap = await db.collection("accountRecovery").doc(phoneKey).get();

    if (!recoverySnap.exists) {
      throw new functions.https.HttpsError("not-found", "No account linked to this phone number.");
    }

    const recoveryData = recoverySnap.data();
    const uid = recoveryData.uid;
    if (!uid) {
      throw new functions.https.HttpsError("internal", "Incomplete account data.");
    }

    await admin.auth().updateUser(uid, { password: newPassword });
    console.log(`[resetPasswordViaPhone] Password reset: uid=${uid} phone=${verifiedPhone}`);

    // The player just set their own password — any admin-visible
    // temporaryPassword on file is now stale (wrong) and must never be shown
    // again. Clear it so the admin panel correctly falls back to "no
    // password on file" instead of silently displaying an outdated value.
    try {
      await db.collection("users").doc(uid).update({
        temporaryPassword: FieldValue.delete(),
        temporaryPasswordSet: false,
        updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      console.warn("[resetPasswordViaPhone] stale temp-password cleanup skipped:", e.message);
    }

    const email = recoveryData.email || "";
    return { success: true, email };
  });

// ─── broadcastToAllUsers ──────────────────────────────────────────────────────
// Called from the Super Admin dashboard's broadcast dialog. Fans a
// notification out to every non-deleted user and logs it to sa_broadcasts.
// Ported over from the old functions/src/index.ts codebase — that file was
// never actually wired into the deployed functions/index.js, so this callable
// did not exist in production until now (found while cleaning up the orphaned
// TypeScript source).
exports.broadcastToAllUsers = functions
  .runWith({ timeoutSeconds: 300, memory: "512MB" })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
    }

    const db = getFirestore();
    const callerSnap = await db.collection("users").doc(context.auth.uid).get();
    const callerRole = (callerSnap.exists ? (callerSnap.data().role || "") : "").toLowerCase();
    if (callerRole !== "super_admin" && callerRole !== "superadmin" && callerRole !== "dev") {
      throw new functions.https.HttpsError("permission-denied", "Super admin only.");
    }

    const title = String((data && data.title) || "").trim();
    const body = String((data && data.body) || "").trim();
    const type = String((data && data.type) || "broadcast").trim();
    const route = String((data && data.route) || "/dashboard").trim();

    if (!title || !body) {
      throw new functions.https.HttpsError("invalid-argument", "title and body required.");
    }

    const usersSnap = await db.collection("users").where("isDeleted", "!=", true).get();

    const BATCH_LIMIT = 400;
    let batch = db.batch();
    let opCount = 0;
    let sentTo = 0;

    const flushBroadcast = async () => {
      if (opCount > 0) {
        await batch.commit();
        batch = db.batch();
        opCount = 0;
      }
    };

    for (const doc of usersSnap.docs) {
      const uid = doc.id;
      const notifRef = db.collection("users").doc(uid).collection("notifications").doc();

      batch.set(notifRef, {
        title,
        body,
        type,
        route,
        read: false,
        senderId: context.auth.uid,
        sentBy: context.auth.uid,
        createdAt: FieldValue.serverTimestamp(),
      });
      opCount++;
      sentTo++;

      if (opCount >= BATCH_LIMIT) await flushBroadcast();
    }

    await flushBroadcast();

    await db.collection("sa_broadcasts").add({
      title,
      body,
      type,
      route,
      sentBy: context.auth.uid,
      sentCount: sentTo,
      sentAt: FieldValue.serverTimestamp(),
    });

    console.log(`[broadcastToAllUsers] sent by ${context.auth.uid}, recipients=${sentTo}`);

    return { success: true, sentCount: sentTo };
  });

// ─── sendSubscriptionReminders ────────────────────────────────────────────────
// Scheduled daily at 08:00 Asia/Amman. Sends expiry warnings at 3d / 2d / 1d /
// 0d before subscriptionEnd, plus a payment-due reminder when a balance is
// outstanding. Also ported over from the orphaned functions/src/index.ts —
// this scheduled job was never actually running in production before now.
function _buildExpiryMessage(daysLeft, name) {
  switch (daysLeft) {
    case 3:
      return {
        title: "⚠️ اشتراكك ينتهي بعد 3 أيام",
        body: `${name}، اشتراكك ينتهي بعد 3 أيام. تواصل مع المدرب لتجديده قبل فوات الأوان.`,
      };
    case 2:
      return {
        title: "⚠️ اشتراكك ينتهي بعد يومين",
        body: `${name}، تبقّى يومان فقط على انتهاء اشتراكك. جدّد الآن!`,
      };
    case 1:
      return {
        title: "🔔 اشتراكك ينتهي غداً!",
        body: `${name}، اشتراكك ينتهي غداً. تواصل مع المدرب فوراً لتجديده.`,
      };
    case 0:
      return {
        title: "❌ انتهى اشتراكك اليوم",
        body: `${name}، انتهى اشتراكك اليوم. تواصل مع المدرب لتجديده والاستمرار في تدريبك.`,
      };
    default:
      return { title: "تذكير الاشتراك", body: "" };
  }
}

exports.sendSubscriptionReminders = functions
  .runWith({ timeoutSeconds: 300, memory: "512MB" })
  .pubsub.schedule("0 8 * * *")
  .timeZone("Asia/Amman")
  .onRun(async (_context) => {
    const db = getFirestore();
    const now = new Date();
    const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));

    const snap = await db.collection("users").where("role", "==", "player").get();

    const REMINDER_DAYS = [3, 2, 1, 0];
    const MS_PER_DAY = 24 * 60 * 60 * 1000;

    const BATCH_LIMIT = 400;
    let batch = db.batch();
    let opCount = 0;

    const flush = async () => {
      if (opCount > 0) {
        await batch.commit();
        batch = db.batch();
        opCount = 0;
      }
    };

    const enqueue = async (ref, data) => {
      batch.set(ref, data);
      opCount++;
      if (opCount >= BATCH_LIMIT) await flush();
    };

    for (const doc of snap.docs) {
      const data = doc.data();
      if (data.isDeleted === true) continue;

      const subEndTs = data.subscriptionEnd;
      if (!subEndTs || typeof subEndTs.toDate !== "function") continue;

      const subEnd = subEndTs.toDate();
      const subEndDay = new Date(Date.UTC(subEnd.getUTCFullYear(), subEnd.getUTCMonth(), subEnd.getUTCDate()));
      const daysLeft = Math.round((subEndDay.getTime() - today.getTime()) / MS_PER_DAY);

      if (!REMINDER_DAYS.includes(daysLeft)) continue;

      const uid = doc.id;
      const endDateStr = subEnd.toISOString().split("T")[0];
      const notifCol = db.collection("users").doc(uid).collection("notifications");

      const firstName = data.firstName || "";
      const lastName = data.lastName || "";
      const name = [firstName, lastName].filter(Boolean).join(" ") || "عزيزي اللاعب";

      const { title: exTitle, body: exBody } = _buildExpiryMessage(daysLeft, name);

      await enqueue(notifCol.doc(`expiry_${daysLeft}d_${endDateStr}`), {
        title: exTitle,
        body: exBody,
        type: "subscription_reminder",
        route: "/dashboard",
        createdAt: FieldValue.serverTimestamp(),
      });

      const amountRemaining = Number(data.amountRemaining || 0);
      if (amountRemaining > 0) {
        await enqueue(notifCol.doc(`payment_reminder_${daysLeft}d_${endDateStr}`), {
          title: "💰 تذكير بالمدفوعات",
          body: `${name}، لديك مبلغ ${amountRemaining} JD غير مدفوع. يرجى التواصل مع المدرب لإتمام الدفع.`,
          type: "payment_reminder",
          route: "/dashboard",
          createdAt: FieldValue.serverTimestamp(),
        });
      }
    }

    await flush();
    console.log(`[sendSubscriptionReminders] processed ${snap.size} players, today=${today.toISOString()}`);
  });
