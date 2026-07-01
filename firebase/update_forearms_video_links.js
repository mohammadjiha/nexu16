// Updates ONLY the VideoLink field of specific "exercises" documents whose
// old Vimeo link doesn't play in-app (the app only embeds YouTube).
// Nothing else in these documents is touched (uses a Firestore field mask).
//
// Usage:
//   node firebase/update_forearms_video_links.js [projectId]
//
// Requires the Firebase CLI to already be logged in (`firebase login`).

const path = require("path");
const { execFileSync } = require("child_process");

const projectId = process.argv[2] || "nexus-90e55";
const collection = "exercises";

const UPDATES = {
  "behind-the-back-barbell-wrist-curl-video-exercise-guide-1135": "https://www.youtube.com/embed/BhnIBEZxseo?rel=0",
  "reverse-grip-barbell-curl-video-exercise-guide-1136": "https://www.youtube.com/embed/YO98hq3vX7g?rel=0",
  "reverse-grip-cable-curl-video-exercise-guide-1138": "https://www.youtube.com/embed/BW6JwixlJYs?rel=0",
  "reverse-grip-dumbbell-wrist-curl-over-bench-video-exercise-guide-1139": "https://www.youtube.com/embed/jtQslxR3f0A?rel=0",
  "reverse-grip-barbell-curl-ez-bar-video-exercise-guide-1140": "https://www.youtube.com/embed/e0Mu2jC4nRk?rel=0",
  "seated-neutral-grip-dumbbell-wrist-curl-video-exercise-guide-1141": "https://www.youtube.com/embed/VGkF2NTtao0?rel=0",
  "one-arm-seated-dumbbell-wrist-curl-video-exercise-guide-1142": "https://www.youtube.com/embed/-Yg-A6Y4kEE?rel=0",
  "wrist-rollers-video-exercise-guide-1144": "https://www.youtube.com/embed/VPFQSgAiXco?rel=0",
  "behind-the-back-cable-wrist-curl-video-exercise-guide-1145": "https://www.youtube.com/embed/DXyWz-FQG_o?rel=0",
  "standing-reverse-grip-cable-curl-video-exercise-guide-1146": "https://www.youtube.com/embed/BW6JwixlJYs?rel=0",
  "seated-cable-wrist-curl-video-exercise-guide-1147": "https://www.youtube.com/embed/qMtmHwaCmYI?rel=0",
  "seated-dumbbell-wrist-curl-video-exercise-guide-1149": "https://www.youtube.com/embed/-Yg-A6Y4kEE?rel=0",
  "seated-reverse-grip-dumbbell-wrist-curl-video-exercise-guide-1153": "https://www.youtube.com/embed/jtQslxR3f0A?rel=0",
  "neutral-grip-dumbbell-wrist-curl-over-bench-video-exercise-guide-1155": "https://www.youtube.com/embed/VGkF2NTtao0?rel=0",
  "barbell-wrist-curl-over-bench-video-exercise-guide-1156": "https://www.youtube.com/embed/dQtMZ3ZEGwU?rel=0",
  "dumbbell-wrist-curl-over-bench-video-exercise-guide-1157": "https://www.youtube.com/embed/VqN3IEJJ33A?rel=0",
  "reverse-grip-barbell-wrist-curl-over-bench-video-exercise-guide-1158": "https://www.youtube.com/embed/s1MHtPsi8vY?rel=0",
  "weight-plate-pinches-video-exercise-guide-1159": "https://www.youtube.com/embed/jFTV3DQf3HE?rel=0",
  "reverse-grip-preacher-curl-ez-bar-video-exercise-guide-1160": "https://www.youtube.com/embed/cezjVm6x3x0?rel=0",
  "one-arm-dumbbell-reverse-grip-curl-video-exercise-guide-1161": "https://www.youtube.com/embed/YO98hq3vX7g?rel=0",
  "reverse-grip-barbell-wrist-curl-video-exercise-guide-1162": "https://www.youtube.com/embed/s1MHtPsi8vY?rel=0",
  "smith-machine-seated-wrist-curl-video-exercise-guide-1163": "https://www.youtube.com/embed/g09CAamwJKo?rel=0",
  "one-arm-reverse-dumbbell-wrist-curl-over-bench-video-exercise-guide-1164": "https://www.youtube.com/embed/jtQslxR3f0A?rel=0",
  "one-arm-seated-reverse-grip-dumbbell-wrist-curl-video-exercise-guide-1165": "https://www.youtube.com/embed/jtQslxR3f0A?rel=0",
  "reverse-grip-concentration-curl-video-exercise-guide-1167": "https://www.youtube.com/embed/YO98hq3vX7g?rel=0",
  "reverse-grip-cable-preacher-curl-video-exercise-guide-1170": "https://www.youtube.com/embed/cezjVm6x3x0?rel=0",
  "alternating-dumbbell-reverse-grip-curl-video-exercise-guide-1171": "https://www.youtube.com/embed/jtQslxR3f0A?rel=0",
  "reverse-grip-dumbbell-preacher-curl-video-exercise-guide-1174": "https://www.youtube.com/embed/cezjVm6x3x0?rel=0",
  "seated-reverse-grip-cable-wrist-curl-video-exercise-guide-1177": "https://www.youtube.com/embed/N-BdFkvrsek?rel=0",
  "reverse-one-arm-cable-curl-video-exercise-guide-1178": "https://www.youtube.com/embed/BW6JwixlJYs?rel=0",
  "one-arm-seated-neutral-grip-dumbbell-wrist-curl-video-exercise-guide-1179": "https://www.youtube.com/embed/VGkF2NTtao0?rel=0",
  "standing-smith-machine-wrist-curl-behind-back-video-exercise-guide-1180": "https://www.youtube.com/embed/g09CAamwJKo?rel=0",
  "one-arm-dumbbell-wrist-curl-over-bench-video-exercise-guide-1184": "https://www.youtube.com/embed/VqN3IEJJ33A?rel=0",
  "one-arm-neutral-grip-dumbbell-wrist-curl-over-bench-video-exercise-guide-1185": "https://www.youtube.com/embed/VGkF2NTtao0?rel=0",
  "reverse-grip-preacher-curl-video-exercise-guide-1186": "https://www.youtube.com/embed/cezjVm6x3x0?rel=0",
  "one-arm-reverse-grip-dumbbell-preacher-curl-video-exercise-guide-1187": "https://www.youtube.com/embed/cezjVm6x3x0?rel=0",
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
  console.log(`Done. Updated VideoLink on ${writes.length}/${entries.length} Forearms exercises.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
