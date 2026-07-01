// Updates ONLY the VideoLink field of specific "exercises" documents whose
// old Vimeo link doesn't play in-app (the app only embeds YouTube).
// Nothing else in these documents is touched (uses a Firestore field mask),
// and every other exercise document is left completely untouched.
//
// Usage:
//   node firebase/update_chest_video_links.js [projectId]
//
// Requires the Firebase CLI to already be logged in (`firebase login`),
// same as upload_exercises_arabic.js — no service account file needed.

const path = require("path");
const { execFileSync } = require("child_process");

const projectId = process.argv[2] || "nexus-90e55";
const collection = "exercises";

// docId -> new YouTube embed link (verified working, copyright-safe YouTube videos)
const UPDATES = {
  "dumbbell-pullover-video-exercise-guide-0001": "https://www.youtube.com/embed/Ydpy886udzo?rel=0",
  "pec-deck-video-exercise-guide-0004": "https://www.youtube.com/embed/10hg4LAa7UQ?rel=0",
  "reverse-grip-dumbbell-bench-press-video-exercise-guide-0012": "https://www.youtube.com/embed/uBRFq6sBzlQ?rel=0",
  "cable-crossovers-upper-chest-video-exercise-guide-0016": "https://www.youtube.com/embed/ua6cX6lz9JI?rel=0",
  "smith-machine-incline-bench-press-video-exercise-guide-0022": "https://www.youtube.com/embed/4h08JEaphsg?rel=0",
  "weighted-chest-dip-video-exercise-guide-0024": "https://www.youtube.com/embed/h_qLxCGaeU8?rel=0",
  "smith-machine-bench-press-video-exercise-guide-0028": "https://www.youtube.com/embed/TxPLcd2deyY?rel=0",
  "floor-press-video-exercise-guide-0032": "https://www.youtube.com/embed/gacJl2rHwtg?rel=0",
  "barbell-pullover-video-exercise-guide-0033": "https://www.youtube.com/embed/E4NQ5DfqwbU?rel=0",
  "knee-push-up-video-exercise-guide-0034": "https://www.youtube.com/embed/z8nUnCdZXQI?rel=0",
  "barbell-pullover-and-press-video-exercise-guide-0046": "https://www.youtube.com/embed/sttAHDQt_mI?rel=0",
  "guillotine-press-video-exercise-guide-0057": "https://www.youtube.com/embed/y90T12sTukg?rel=0",
  "lying-cable-pullover-video-exercise-guide-0064": "https://www.youtube.com/embed/fbIyijUKdkA?rel=0",
  "one-arm-dumbbell-bench-press-video-exercise-guide-0067": "https://www.youtube.com/embed/td-4lC0tXKA?rel=0",
  "reverse-grip-incline-bench-press-video-exercise-guide-0077": "https://www.youtube.com/embed/CHU3WWlIf3o?rel=0",
  "push-up-on-bench-video-exercise-guide-0078": "https://www.youtube.com/embed/E--Ls5QtFqI?rel=0",
  "smith-machine-wide-grip-bench-press-video-exercise-guide-0090": "https://www.youtube.com/embed/19s0jzWQKHU?rel=0",
  "exercise-ball-cable-fly-video-exercise-guide-0091": "https://www.youtube.com/embed/sgS0riPfL-s?rel=0",
  "lying-cable-pullover-rope-extension-video-exercise-guide-0093": "https://www.youtube.com/embed/H8loMHtlnHY?rel=0",
  "alternating-incline-dumbbell-fly-video-exercise-guide-0104": "https://www.youtube.com/embed/BZhzMiOLiqg?rel=0",
  "alternating-decline-dumbbell-fly-video-exercise-guide-0108": "https://www.youtube.com/embed/uuxQYn-eZWg?rel=0",
  "cable-inner-chest-press-video-exercise-guide-0111": "https://www.youtube.com/embed/s_8o9WioQ4g?rel=0",
  "wide-reverse-grip-bench-press-video-exercise-guide-0114": "https://www.youtube.com/embed/_J-KyvKCrIg?rel=0",
  "alternating-dumbbell-fly-video-exercise-guide-0123": "https://www.youtube.com/embed/bf6xeXpilic?rel=0",
  "alternating-dumbbell-bench-press-low-start-video-exercise-guide-0126": "https://www.youtube.com/embed/xPR-LN2ppx0?rel=0",
  "reverse-grip-bench-press-video-exercise-guide-0129": "https://www.youtube.com/embed/izbtd_yZ4Pk?rel=0",
  "exercise-ball-dumbbell-fly-video-exercise-guide-0130": "https://www.youtube.com/embed/i2MXSnO4Xvg?rel=0",
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
    // Only touch these two fields — every other field on the document is left as-is.
    updateMask: { fieldPaths: ["VideoLink", "videoLinkUpdatedAt"] },
  }));

  await commitBatch(accessToken, writes);
  console.log(`Done. Updated VideoLink on ${writes.length}/${entries.length} Chest exercises.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
