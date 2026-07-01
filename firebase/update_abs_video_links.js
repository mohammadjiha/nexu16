// Updates ONLY the VideoLink field of specific "exercises" documents whose
// old Vimeo link doesn't play in-app (the app only embeds YouTube).
// Nothing else in these documents is touched (uses a Firestore field mask).
//
// Usage:
//   node firebase/update_abs_video_links.js [projectId]
//
// Requires the Firebase CLI to already be logged in (`firebase login`).

const path = require("path");
const { execFileSync } = require("child_process");

const projectId = process.argv[2] || "nexus-90e55";
const collection = "exercises";

const UPDATES = {
  "cable-crunch-video-exercise-guide-1005": "https://www.youtube.com/embed/wJxxROdW9CA?rel=0",
  "hanging-leg-raise-video-exercise-guide-1006": "https://www.youtube.com/embed/rbOJSK07AGA?rel=0",
  "plank-video-exercise-guide-1007": "https://www.youtube.com/embed/A2b2EmIg0dA?rel=0",
  "side-plank-video-exercise-guide-1008": "https://www.youtube.com/embed/iNbH7_edNI8?rel=0",
  "exercise-ball-crunch-video-exercise-guide-1011": "https://www.youtube.com/embed/tCzN9iJfAWE?rel=0",
  "hanging-knee-raise-video-exercise-guide-1013": "https://www.youtube.com/embed/p9hhX_Sx5v0?rel=0",
  "russian-twist-video-exercise-guide-1014": "https://www.youtube.com/embed/H4tMFJoyAd8?rel=0",
  "barbell-abdominal-rollouts-video-exercise-guide-1015": "https://www.youtube.com/embed/O-d6HC9gLcw?rel=0",
  "decline-bench-sit-up-video-exercise-guide-1018": "https://www.youtube.com/embed/YSQ6w0YynpI?rel=0",
  "floor-crunch-legs-on-bench-video-exercise-guide-1019": "https://www.youtube.com/embed/Xyd_fa5zoEU?rel=0",
  "hanging-knee-raise-with-twist-video-exercise-guide-1021": "https://www.youtube.com/embed/p9hhX_Sx5v0?rel=0",
  "standing-cable-crunch-video-exercise-guide-1022": "https://www.youtube.com/embed/wJxxROdW9CA?rel=0",
  "seated-knee-tucks-video-exercise-guide-1029": "https://www.youtube.com/embed/54q250IUEAc?rel=0",
  "lying-leg-raise-with-hip-thrust-video-exercise-guide-1032": "https://www.youtube.com/embed/SuIxXbKnwx4?rel=0",
  "oblique-cable-crunch-video-exercise-guide-1033": "https://www.youtube.com/embed/wJxxROdW9CA?rel=0",
  "lying-leg-raise-on-bench-video-exercise-guide-1034": "https://www.youtube.com/embed/SuIxXbKnwx4?rel=0",
  "alternating-lying-leg-raise-video-exercise-guide-1038": "https://www.youtube.com/embed/SuIxXbKnwx4?rel=0",
  "seated-cable-crunch-video-exercise-guide-1040": "https://www.youtube.com/embed/mkE_gNDQN8o?rel=0",
  "jackknife-on-bench-video-exercise-guide-1042": "https://www.youtube.com/embed/GEZ8NLbtc8Q?rel=0",
  "roman-chair-leg-raise-video-exercise-guide-1043": "https://www.youtube.com/embed/fMaUOQpniLE?rel=0",
  "decline-bench-knee-raise-video-exercise-guide-1044": "https://www.youtube.com/embed/RUu5LImgFws?rel=0",
  "side-crunch-with-leg-lift-video-exercise-guide-1049": "https://www.youtube.com/embed/iNbH7_edNI8?rel=0",
  "reach-and-catch-video-exercise-guide-1050": "https://www.youtube.com/embed/NtK3Z1sHW6Y?rel=0",
  "feet-elevated-plank-video-exercise-guide-1051": "https://www.youtube.com/embed/A2b2EmIg0dA?rel=0",
  "decline-bench-leg-raise-video-exercise-guide-1053": "https://www.youtube.com/embed/SuIxXbKnwx4?rel=0",
  "decline-weighted-twist-video-exercise-guide-1055": "https://www.youtube.com/embed/6yHm0Y8Pn6U?rel=0",
  "abominal-hip-thrust-video-exercise-guide-1057": "https://www.youtube.com/embed/wl2Y2UJqUFg?rel=0",
  "rotating-crunch-legs-on-bench-video-exercise-guide-1058": "https://www.youtube.com/embed/Xyd_fa5zoEU?rel=0",
  "decline-bench-abdominal-reach-video-exercise-guide-1059": "https://www.youtube.com/embed/NtK3Z1sHW6Y?rel=0",
  "weighted-hanging-knee-raise-video-exercise-guide-1061": "https://www.youtube.com/embed/p9hhX_Sx5v0?rel=0",
  "lying-alternating-knee-raise-video-exercise-guide-1062": "https://www.youtube.com/embed/SuIxXbKnwx4?rel=0",
  "standing-barbell-twist-video-exercise-guide-1064": "https://www.youtube.com/embed/ulvTqepr2is?rel=0",
  "decline-weighted-sit-up-with-twist-video-exercise-guide-1065": "https://www.youtube.com/embed/G0nAMO90HAA?rel=0",
  "decline-bench-alternating-leg-raise-video-exercise-guide-1067": "https://www.youtube.com/embed/SuIxXbKnwx4?rel=0",
  "exercise-ball-weighted-sit-up-video-exercise-guide-1069": "https://www.youtube.com/embed/tCzN9iJfAWE?rel=0",
  "lying-cable-crunch-video-exercise-guide-1073": "https://www.youtube.com/embed/wJxxROdW9CA?rel=0",
  "lower-abdominal-hip-roll-video-exercise-guide-1080": "https://www.youtube.com/embed/wl2Y2UJqUFg?rel=0",
  "abdominal-pendulum-video-exercise-guide-1083": "https://www.youtube.com/embed/bwV3-gTy4Aw?rel=0",
  "twisting-lying-cable-crunch-video-exercise-guide-1085": "https://www.youtube.com/embed/wJxxROdW9CA?rel=0",
  "twisting-crunch-video-exercise-guide-1087": "https://www.youtube.com/embed/Xyd_fa5zoEU?rel=0",
  "decline-bench-alternating-knee-raise-video-exercise-guide-1088": "https://www.youtube.com/embed/RUu5LImgFws?rel=0",
  "lying-cable-knee-raise-video-exercise-guide-1089": "https://www.youtube.com/embed/p9hhX_Sx5v0?rel=0",
  "decline-bench-cable-knee-raise-video-exercise-guide-1090": "https://www.youtube.com/embed/RUu5LImgFws?rel=0",
  "weighted-russian-twist-video-exercise-guide-1095": "https://www.youtube.com/embed/H4tMFJoyAd8?rel=0",
  "exercise-ball-hip-roll-video-exercise-guide-1096": "https://www.youtube.com/embed/vxvTAU0f5qo?rel=0",
  "exercise-ball-knee-tuck-video-exercise-guide-1097": "https://www.youtube.com/embed/UOQkUyxESfk?rel=0",
  "exercise-ball-plank-video-exercise-guide-1099": "https://www.youtube.com/embed/A2b2EmIg0dA?rel=0",
  "roman-chair-knee-raise-video-exercise-guide-1101": "https://www.youtube.com/embed/RUu5LImgFws?rel=0",
  "twisting-cable-crunch-video-exercise-guide-1102": "https://www.youtube.com/embed/wJxxROdW9CA?rel=0",
  "decline-leg-raise-with-hip-thrust-video-exercise-guide-1103": "https://www.youtube.com/embed/SuIxXbKnwx4?rel=0",
  "decline-bench-cable-crunch-video-exercise-guide-1104": "https://www.youtube.com/embed/wJxxROdW9CA?rel=0",
  "roman-chair-twisting-knee-raise-video-exercise-guide-1106": "https://www.youtube.com/embed/RUu5LImgFws?rel=0",
  "barbell-side-bends-video-exercise-guide-1107": "https://www.youtube.com/embed/dL9ZzqtQI5c?rel=0",
  "roman-chair-weighted-knee-raise-video-exercise-guide-1110": "https://www.youtube.com/embed/RUu5LImgFws?rel=0",
  "one-leg-lying-cable-knee-raise-video-exercise-guide-1111": "https://www.youtube.com/embed/p9hhX_Sx5v0?rel=0",
  "decline-bench-sit-up-with-twist-video-exercise-guide-1113": "https://www.youtube.com/embed/G0nAMO90HAA?rel=0",
  "alternating-reach-and-catch-video-exercise-guide-1117": "https://www.youtube.com/embed/NtK3Z1sHW6Y?rel=0",
  "dumbbell-side-bends-video-exercise-guide-1118": "https://www.youtube.com/embed/dL9ZzqtQI5c?rel=0",
  "seated-barbell-twist-video-exercise-guide-1122": "https://www.youtube.com/embed/ulvTqepr2is?rel=0",
  "alternating-seated-dumbbell-side-bends-video-exercise-guide-1127": "https://www.youtube.com/embed/dL9ZzqtQI5c?rel=0",
  "seated-barbell-twist-on-floor-video-exercise-guide-1132": "https://www.youtube.com/embed/ulvTqepr2is?rel=0",
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

  const writes = entries.map(([docId, videoLink]) => ({
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
  console.log(`Done. Updated VideoLink on ${writes.length}/${entries.length} Abs exercises.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
