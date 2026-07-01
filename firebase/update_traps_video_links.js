// Updates ONLY the VideoLink field of specific "exercises" documents whose
// old Vimeo link doesn't play in-app (the app only embeds YouTube).
// Nothing else in these documents is touched (uses a Firestore field mask).
//
// Usage:
//   node firebase/update_traps_video_links.js [projectId]
//
// Requires the Firebase CLI to already be logged in (`firebase login`).

const path = require("path");
const { execFileSync } = require("child_process");

const projectId = process.argv[2] || "nexus-90e55";
const collection = "exercises";

const UPDATES = {
  "barbell-upright-row-video-exercise-guide-0793": "https://www.youtube.com/embed/amCU-ziHITM?rel=0",
  "wide-grip-upright-row-video-exercise-guide-0795": "https://www.youtube.com/embed/Xpu0C50pD-U?rel=0",
  "seated-dumbbell-shrug-video-exercise-guide-0796": "https://www.youtube.com/embed/sgcOZ3wcWmI?rel=0",
  "one-arm-dumbbell-upright-row-video-exercise-guide-0797": "https://www.youtube.com/embed/KZUf1_JjTZo?rel=0",
  "tate-press-video-exercise-guide-0801": "https://www.youtube.com/embed/cZJ-4Ll3uAo?rel=0",
  "behind-the-back-barbell-shrug-video-exercise-guide-0803": "https://www.youtube.com/embed/ptBvX0z_in4?rel=0",
  "cable-row-to-neck-video-exercise-guide-0804": "https://www.youtube.com/embed/jeeH5rXXsBs?rel=0",
  "seated-cable-shrug-video-exercise-guide-0805": "https://www.youtube.com/embed/tUzLoRBPLDQ?rel=0",
  "smith-machine-shrug-video-exercise-guide-0806": "https://www.youtube.com/embed/8ppOGwvaFko?rel=0",
  "lying-cable-upright-row-video-exercise-guide-0816": "https://www.youtube.com/embed/6OB_YH6u42U?rel=0",
  "lying-cable-shrug-video-exercise-guide-0818": "https://www.youtube.com/embed/quh6n4ZmJjA?rel=0",
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
  console.log(`Done. Updated VideoLink on ${writes.length}/${entries.length} Traps exercises.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
