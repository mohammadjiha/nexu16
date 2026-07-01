// Updates ONLY the VideoLink field of specific "exercises" documents whose
// old Vimeo link doesn't play in-app (the app only embeds YouTube).
// Nothing else in these documents is touched (uses a Firestore field mask).
//
// Usage:
//   node firebase/update_legs_video_links.js [projectId]
//
// Requires the Firebase CLI to already be logged in (`firebase login`).

const path = require("path");
const { execFileSync } = require("child_process");

const projectId = process.argv[2] || "nexus-90e55";
const collection = "exercises";

const UPDATES = {
  "seated-dumbbell-calf-raise-video-exercise-guide-0427": "https://www.youtube.com/embed/fFWpWJy8ybU?rel=0",
  "bodyweight-standing-calf-raise-video-exercise-guide-0428": "https://www.youtube.com/embed/Uyg2QR1WAq8?rel=0",
  "standing-one-leg-calf-raise-with-dumbbell-video-exercise-guide-0430": "https://www.youtube.com/embed/lYfI9gd3A8o?rel=0",
  "one-leg-seated-dumbbell-calf-raise-video-exercise-guide-0432": "https://www.youtube.com/embed/Ih4bGiKq4Ac?rel=0",
  "standing-barbell-calf-raise-video-exercise-guide-0433": "https://www.youtube.com/embed/3UWi44yN-wM?rel=0",
  "donkey-calf-raise-video-exercise-guide-0434": "https://www.youtube.com/embed/Ko_kZoahbAw?rel=0",
  "smith-machine-calf-raise-video-exercise-guide-0436": "https://www.youtube.com/embed/1lKjFPrYqf0?rel=0",
  "one-leg-standing-bodyweight-calf-raise-video-exercise-guide-0437": "https://www.youtube.com/embed/IphGZ8OlfYg?rel=0",
  "hack-squat-calf-raise-video-exercise-guide-0438": "https://www.youtube.com/embed/Jw33qwHb5jA?rel=0",
  "standing-barbell-calf-raise-on-floor-video-exercise-guide-0440": "https://www.youtube.com/embed/BXV0YV1z8a8?rel=0",
  "one-leg-smith-machine-toe-raise-video-exercise-guide-0442": "https://www.youtube.com/embed/FNdI5TynYxs?rel=0",
  "exercise-ball-on-the-wall-calf-raise-video-exercise-guide-0444": "https://www.youtube.com/embed/E6vR0_E3QAw?rel=0",
  "smith-machine-seated-calf-raise-video-exercise-guide-0448": "https://www.youtube.com/embed/kxzr_bPqgoU?rel=0",
  "45-degree-calf-raise-toes-out-video-exercise-guide-0449": "https://www.youtube.com/embed/85qZUrk5l1M?rel=0",
  "rocking-standing-calf-raise-video-exercise-guide-0452": "https://www.youtube.com/embed/Uyg2QR1WAq8?rel=0",
  "smith-machine-calf-raise-toes-out-video-exercise-guide-0454": "https://www.youtube.com/embed/1lKjFPrYqf0?rel=0",
  "one-leg-smith-machine-calf-raise-video-exercise-guide-0456": "https://www.youtube.com/embed/FNdI5TynYxs?rel=0",
  "one-leg-donkey-calf-raise-video-exercise-guide-0457": "https://www.youtube.com/embed/POfdVjaIT3E?rel=0",
  "smith-machine-toe-raise-video-exercise-guide-0458": "https://www.youtube.com/embed/1lKjFPrYqf0?rel=0",
  "one-leg-floor-calf-raise-video-exercise-guide-0460": "https://www.youtube.com/embed/IphGZ8OlfYg?rel=0",
  "cable-calf-raise-video-exercise-guide-0462": "https://www.youtube.com/embed/xQO7HYZcqfM?rel=0",
  "one-leg-seated-calf-raise-video-exercise-guide-0464": "https://www.youtube.com/embed/3ZRe_QpvRPg?rel=0",
  "smith-machine-seated-toe-raise-video-exercise-guide-0467": "https://www.youtube.com/embed/kxzr_bPqgoU?rel=0",
  "one-leg-smith-machine-seated-calf-raise-video-exercise-guide-0468": "https://www.youtube.com/embed/Nd25-BniuGQ?rel=0",
  "seated-barbell-calf-raise-video-exercise-guide-0471": "https://www.youtube.com/embed/PMYBu2wyczo?rel=0",
  "one-leg-cable-calf-raise-video-exercise-guide-0473": "https://www.youtube.com/embed/GN6oO3vBqM8?rel=0",
  "one-leg-hack-squat-calf-raise-video-exercise-guide-0476": "https://www.youtube.com/embed/v8C2Dvzb70Q?rel=0",
  "smith-machine-calf-raise-toes-in-video-exercise-guide-0477": "https://www.youtube.com/embed/1lKjFPrYqf0?rel=0",
  "one-leg-45-degree-calf-raise-video-exercise-guide-0478": "https://www.youtube.com/embed/85qZUrk5l1M?rel=0",
  "bodyweight-floor-calf-raise-video-exercise-guide-0482": "https://www.youtube.com/embed/Uyg2QR1WAq8?rel=0",
  "45-degree-calf-raise-toes-in-video-exercise-guide-0484": "https://www.youtube.com/embed/85qZUrk5l1M?rel=0",
  "45-degree-toe-raise-video-exercise-guide-0487": "https://www.youtube.com/embed/85qZUrk5l1M?rel=0",
  "standing-glute-kickback-machine-video-exercise-guide-0491": "https://www.youtube.com/embed/24pvhNOoK80?rel=0",
  "wide-stance-smith-machine-squat-video-exercise-guide-0493": "https://www.youtube.com/embed/YlMSM_Gjrxc?rel=0",
  "hip-flexion-machine-video-exercise-guide-0530": "https://www.youtube.com/embed/YPh3oRYZofI?rel=0",
  "dumbbell-stiff-leg-deadlift-video-exercise-guide-0531": "https://www.youtube.com/embed/uMlKNyFFOLI?rel=0",
  "leg-curl-video-exercise-guide-0533": "https://www.youtube.com/embed/hqI59xXChFk?rel=0",
  "dumbbell-hamstring-curl-video-exercise-guide-0536": "https://www.youtube.com/embed/dY7BmNR7RJk?rel=0",
  "single-leg-curl-video-exercise-guide-0542": "https://www.youtube.com/embed/Qsc45sDpvbM?rel=0",
  "standing-cable-hamstring-curl-video-exercise-guide-0545": "https://www.youtube.com/embed/OA7c_8HfdOw?rel=0",
  "reverse-hack-squat-video-exercise-guide-0553": "https://www.youtube.com/embed/3Kopway1dyg?rel=0",
  "lying-cable-leg-curl-video-exercise-guide-0565": "https://www.youtube.com/embed/Atl5qhOfJpQ?rel=0",
  "smith-machine-stiff-leg-deadlift-video-exercise-guide-0566": "https://www.youtube.com/embed/F-UZBW_lUOY?rel=0",
  "barbell-split-squat-with-jump-video-exercise-guide-0576": "https://www.youtube.com/embed/fiFvoKrHxng?rel=0",
  "one-leg-lying-cable-hamstring-curl-video-exercise-guide-0582": "https://www.youtube.com/embed/Y1dQUd6OKHk?rel=0",
  "stiff-leg-deadlift-on-bench-video-exercise-guide-0587": "https://www.youtube.com/embed/9RtHb3sOU2E?rel=0",
  "dumbbell-stiff-leg-deadlift-on-bench-video-exercise-guide-0594": "https://www.youtube.com/embed/RKMJgOyVJcM?rel=0",
  "dumbbell-squat-video-exercise-guide-0606": "https://www.youtube.com/embed/ZXwvmRSRRxY?rel=0",
  "dumbbell-lunge-video-exercise-guide-0609": "https://www.youtube.com/embed/G4gAK8Bhyro?rel=0",
  "dumbbell-step-up-video-exercise-guide-0611": "https://www.youtube.com/embed/DxUNi119Qzs?rel=0",
  "frog-squat-video-exercise-guide-0613": "https://www.youtube.com/embed/RfjYil2AgiY?rel=0",
  "bodyweight-walking-lunge-video-exercise-guide-0619": "https://www.youtube.com/embed/LPmjFqNlDIw?rel=0",
  "bodyweight-squat-jump-video-exercise-guide-0623": "https://www.youtube.com/embed/JwCaCql7VpQ?rel=0",
  "bodyweight-lateral-lunge-video-exercise-guide-0624": "https://www.youtube.com/embed/sGZn1_WK6gc?rel=0",
  "dumbbell-lateral-lunge-video-exercise-guide-0627": "https://www.youtube.com/embed/lrhTa-GqCPY?rel=0",
  "barbell-lunge-video-exercise-guide-0628": "https://www.youtube.com/embed/RpcdWs9bOrs?rel=0",
  "sissy-squat-video-exercise-guide-0647": "https://www.youtube.com/embed/cHpDhoud8oo?rel=0",
  "barbell-deep-squat-video-exercise-guide-0652": "https://www.youtube.com/embed/SW_C1A-rejs?rel=0",
  "leg-extension-toes-in-video-exercise-guide-0656": "https://www.youtube.com/embed/F1JfmctnmTE?rel=0",
  "smith-machine-box-squat-video-exercise-guide-0659": "https://www.youtube.com/embed/mr27gcM7Slo?rel=0",
  "barbell-box-squat-video-exercise-guide-0668": "https://www.youtube.com/embed/mr27gcM7Slo?rel=0",
  "dumbbell-squat-jump-video-exercise-guide-0673": "https://www.youtube.com/embed/JwCaCql7VpQ?rel=0",
  "bodyweight-bulgarian-split-squat-video-exercise-guide-0678": "https://www.youtube.com/embed/VPhhE6bBzZE?rel=0",
  "barbell-narrow-stance-squat-video-exercise-guide-0680": "https://www.youtube.com/embed/9Ulb6gOqhA4?rel=0",
  "one-leg-hack-squat-video-exercise-guide-0686": "https://www.youtube.com/embed/2Y-fymtHVDc?rel=0",
  "barbell-lateral-split-squat-video-exercise-guide-0691": "https://www.youtube.com/embed/ImBoRJAzZRY?rel=0",
  "barbell-wide-stance-squat-video-exercise-guide-0694": "https://www.youtube.com/embed/JXdGBp_YYz0?rel=0",
  "narrow-stance-smith-machine-squat-video-exercise-guide-0696": "https://www.youtube.com/embed/9Ulb6gOqhA4?rel=0",
  "exercise-ball-wall-squat-video-exercise-guide-0697": "https://www.youtube.com/embed/0iJ70YF-g1A?rel=0",
  "barbell-sumo-squat-video-exercise-guide-0698": "https://www.youtube.com/embed/RKyiGw8Vyg0?rel=0",
  "dumbbell-box-squat-video-exercise-guide-0701": "https://www.youtube.com/embed/wL9FSf7ZENU?rel=0",
  "smith-machine-zercher-squat-video-exercise-guide-0703": "https://www.youtube.com/embed/Qq3yteWfVGE?rel=0",
  "decline-bench-barbell-lunge-video-exercise-guide-0704": "https://www.youtube.com/embed/RpcdWs9bOrs?rel=0",
  "smith-machine-bulgarian-split-squat-video-exercise-guide-0710": "https://www.youtube.com/embed/VPhhE6bBzZE?rel=0",
  "barbell-quarter-squat-video-exercise-guide-0711": "https://www.youtube.com/embed/BiSrbzClUPI?rel=0",
  "decline-bench-bodyweight-lunge-video-exercise-guide-0714": "https://www.youtube.com/embed/LPmjFqNlDIw?rel=0",
  "bodyweight-wall-squat-video-exercise-guide-0719": "https://www.youtube.com/embed/aKBxiKs9n8A?rel=0",
  "barbell-jumping-squats-video-exercise-guide-0722": "https://www.youtube.com/embed/jFlwvc4uz2A?rel=0",
  "barbell-speed-squats-video-exercise-guide-0743": "https://www.youtube.com/embed/1Kn38Pl8MR0?rel=0",
  "barbell-half-squat-video-exercise-guide-0746": "https://www.youtube.com/embed/BiSrbzClUPI?rel=0",
  "dumbbell-pistol-squat-on-bench-video-exercise-guide-0752": "https://www.youtube.com/embed/qMzKGNYlTa4?rel=0",
  "barbell-front-box-squat-video-exercise-guide-0754": "https://www.youtube.com/embed/0ect9ETE6t0?rel=0",
  "exercise-ball-dumbbell-wall-squat-video-exercise-guide-0763": "https://www.youtube.com/embed/0iJ70YF-g1A?rel=0",
  "leg-extension-toes-out-video-exercise-guide-0764": "https://www.youtube.com/embed/F1JfmctnmTE?rel=0",
  "weighted-sissy-squat-video-exercise-guide-0769": "https://www.youtube.com/embed/W6osqAEKHJs?rel=0",
  "decline-bench-dumbbell-lunge-video-exercise-guide-0772": "https://www.youtube.com/embed/G4gAK8Bhyro?rel=0",
  "barbell-bulgarian-split-squat-video-exercise-guide-0775": "https://www.youtube.com/embed/VPhhE6bBzZE?rel=0",
  "dumbbell-wall-squat-video-exercise-guide-0779": "https://www.youtube.com/embed/aKBxiKs9n8A?rel=0",
  "smith-machine-squat-feet-forward-video-exercise-guide-0786": "https://www.youtube.com/embed/eMYjBnIVb_A?rel=0",
  "dumbbell-split-squat-with-jump-video-exercise-guide-0788": "https://www.youtube.com/embed/wSBKfMxompA?rel=0",
  "single-leg-wall-squat-video-exercise-guide-0790": "https://www.youtube.com/embed/0iJ70YF-g1A?rel=0",
};

function requireFirebaseTools(modulePath) {
  const npmRoot =
    process.platform === "win32"
      ? execFileSync("cmd.exe", ["/c", "npm", "root", "-g"], { encoding: "utf8" }).trim()
      : execFileSync("npm", ["root", "-g"], { encoding: "utf8" }).trim();
  return require(path.join(npmRoot, "firebase-tools", "lib", modulePath));
}

async function getCliAccessToken() {
  const auth = requireFirebaseTools("auth.js");
  const { requireAuth } = requireFirebaseTools("requireAuth.js");
  const apiv2 = requireFirebaseTools("apiv2.js");
  const account = auth.getGlobalDefaultAccount();
  if (!account?.user || !account?.tokens) {
    throw new Error("Firebase CLI is not logged in. Run `firebase login` first.");
  }
  await requireAuth({ user: account.user, tokens: account.tokens, project: projectId });
  return apiv2.getAccessToken();
}

async function commitBatch(accessToken, writes) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  const response = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({ writes }),
  });
  if (!response.ok) throw new Error(`Commit failed: ${response.status} ${await response.text()}`);
}

async function main() {
  const entries = Object.entries(UPDATES);
  const accessToken = await getCliAccessToken();

  // Firestore commit has a 500-write limit per request; batch in chunks of 400 to be safe.
  const chunkSize = 400;
  let done = 0;
  for (let i = 0; i < entries.length; i += chunkSize) {
    const chunk = entries.slice(i, i + chunkSize);
    const writes = chunk.map(([docId, videoLink]) => ({
      update: {
        name: `projects/${projectId}/databases/(default)/documents/${collection}/${docId}`,
        fields: {
          VideoLink: { stringValue: videoLink },
          videoLinkUpdatedAt: { stringValue: new Date().toISOString() },
        },
      },
      updateMask: { fieldPaths: ["VideoLink", "videoLinkUpdatedAt"] },
    }));
    await commitBatch(accessToken, writes);
    done += writes.length;
    console.log(`Updated ${done}/${entries.length}`);
  }
  console.log(`Done. Updated VideoLink on ${done}/${entries.length} Legs exercises.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
