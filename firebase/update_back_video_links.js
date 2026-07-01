// Updates ONLY the VideoLink field of specific "exercises" documents whose
// old Vimeo link doesn't play in-app (the app only embeds YouTube).
// Nothing else in these documents is touched (uses a Firestore field mask).
//
// Usage:
//   node firebase/update_back_video_links.js [projectId]
//
// Requires the Firebase CLI to already be logged in (`firebase login`).

const path = require("path");
const { execFileSync } = require("child_process");

const projectId = process.argv[2] || "nexus-90e55";
const collection = "exercises";

const UPDATES = {
  "v-bar-pull-up-video-exercise-guide-0142": "https://www.youtube.com/embed/kAAuh1-SxXw?rel=0",
  "underhand-close-grip-lateral-pulldown-video-exercise-guide-0150": "https://www.youtube.com/embed/agVJpGoTiOs?rel=0",
  "lateral-pulldown-rope-extension-video-exercise-guide-0154": "https://www.youtube.com/embed/VqSsnPSpHOU?rel=0",
  "overhand-close-grip-lateral-pulldown-video-exercise-guide-0162": "https://www.youtube.com/embed/hkZWmvkbNNQ?rel=0",
  "rope-pull-up-video-exercise-guide-0170": "https://www.youtube.com/embed/O570XmxD2vY?rel=0",
  "wide-grip-chin-up-video-exercise-guide-0174": "https://www.youtube.com/embed/fewqxNeGQ8I?rel=0",
  "dumbbell-deadlift-video-exercise-guide-0187": "https://www.youtube.com/embed/gLogcYIvgRA?rel=0",
  "smith-machine-deadlift-video-exercise-guide-0189": "https://www.youtube.com/embed/ONRRAgNLVac?rel=0",
  "seated-cable-row-video-exercise-guide-0195": "https://www.youtube.com/embed/xQNrFHEMhI4?rel=0",
  "machine-row-video-exercise-guide-0197": "https://www.youtube.com/embed/TeFo51Q_Nsc?rel=0",
  "feet-elevated-inverted-row-video-exercise-guide-0199": "https://www.youtube.com/embed/44W1JgF0lyQ?rel=0",
  "reverse-grip-bent-over-dumbbell-row-video-exercise-guide-0202": "https://www.youtube.com/embed/SzPxYvZqL6k?rel=0",
  "smith-machine-bent-over-row-video-exercise-guide-0204": "https://www.youtube.com/embed/ZFNLCpj8e-o?rel=0",
  "reverse-grip-bent-over-row-video-exercise-guide-0205": "https://www.youtube.com/embed/HCp3BU289LA?rel=0",
  "inverted-row-video-exercise-guide-0206": "https://www.youtube.com/embed/ytFnYaoIkSg?rel=0",
  "seated-row-rope-extension-video-exercise-guide-0207": "https://www.youtube.com/embed/8bHMXyRjQKk?rel=0",
  "one-arm-seated-cable-row-video-exercise-guide-0209": "https://www.youtube.com/embed/oDKu4Y-hQtA?rel=0",
  "incline-bench-cable-row-rope-extension-video-exercise-guide-0213": "https://www.youtube.com/embed/DUuyaffIjdE?rel=0",
  "seated-high-cable-row-video-exercise-guide-0215": "https://www.youtube.com/embed/gMuj8JEuBrQ?rel=0",
  "reverse-grip-bent-over-row-ez-bar-video-exercise-guide-0216": "https://www.youtube.com/embed/9cU2k2qeULM?rel=0",
  "incline-bench-barbell-row-video-exercise-guide-0218": "https://www.youtube.com/embed/2cGfXlLaJT0?rel=0",
  "reverse-grip-incline-bench-cable-row-video-exercise-guide-0219": "https://www.youtube.com/embed/SoFp55fk8rU?rel=0",
  "one-arm-landmine-row-video-exercise-guide-0220": "https://www.youtube.com/embed/tiETx7VNDf0?rel=0",
  "incline-bench-cable-row-video-exercise-guide-0221": "https://www.youtube.com/embed/LfALM2ZKWhs?rel=0",
  "one-arm-machine-row-video-exercise-guide-0222": "https://www.youtube.com/embed/z11jNvj5hH0?rel=0",
  "palms-in-bent-over-dumbbell-row-video-exercise-guide-0223": "https://www.youtube.com/embed/KIdzT7ZJT0o?rel=0",
  "reverse-grip-smith-machine-bent-over-row-video-exercise-guide-0224": "https://www.youtube.com/embed/EZPdp0lNEpk?rel=0",
  "rope-crossover-seated-row-video-exercise-guide-0226": "https://www.youtube.com/embed/7KhA_TDJuyQ?rel=0",
  "reverse-grip-incline-bench-barbell-row-video-exercise-guide-0228": "https://www.youtube.com/embed/w-a346cMYlo?rel=0",
  "reverse-grip-incline-bench-two-arm-dumbbell-row-video-exercise-guide-0229": "https://www.youtube.com/embed/nzB9Ly-IaOY?rel=0",
  "cable-palm-rotational-row-video-exercise-guide-0230": "https://www.youtube.com/embed/FZ-ERsNegtQ?rel=0",
  "palm-rotational-row-video-exercise-guide-0238": "https://www.youtube.com/embed/dSaRLdsk7N8?rel=0",
  "smith-machine-one-arm-row-video-exercise-guide-0248": "https://www.youtube.com/embed/w6ua5fqNws0?rel=0",
  "reverse-grip-machine-t-bar-row-video-exercise-guide-0251": "https://www.youtube.com/embed/C-CxG522l1Q?rel=0",
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
  console.log(`Done. Updated VideoLink on ${writes.length}/${entries.length} Back exercises.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
