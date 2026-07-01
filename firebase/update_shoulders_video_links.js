// Updates ONLY the VideoLink field of specific "exercises" documents whose
// old Vimeo link doesn't play in-app (the app only embeds YouTube).
// Nothing else in these documents is touched (uses a Firestore field mask).
//
// Usage:
//   node firebase/update_shoulders_video_links.js [projectId]
//
// Requires the Firebase CLI to already be logged in (`firebase login`).

const path = require("path");
const { execFileSync } = require("child_process");

const projectId = process.argv[2] || "nexus-90e55";
const collection = "exercises";

const UPDATES = {
  "dumbbell-lateral-raise-video-exercise-guide-0252": "https://www.youtube.com/embed/-hyAJdSFzT4?rel=0",
  "standing-dumbbell-shoulder-press-video-exercise-guide-0256": "https://www.youtube.com/embed/e_f5oodNEcI?rel=0",
  "smith-machine-shoulder-press-video-exercise-guide-0259": "https://www.youtube.com/embed/kYZ0aUEzgEQ?rel=0",
  "seated-dumbbell-lateral-raise-video-exercise-guide-0260": "https://www.youtube.com/embed/djTVHrWCvw8?rel=0",
  "standing-dumbbell-front-raise-video-exercise-guide-0263": "https://www.youtube.com/embed/h-0BU7fQl68?rel=0",
  "cable-lateral-raise-video-exercise-guide-0267": "https://www.youtube.com/embed/zpbm-xRHB6k?rel=0",
  "incline-rear-delt-fly-video-exercise-guide-0269": "https://www.youtube.com/embed/SCnaJkL3BDY?rel=0",
  "one-arm-dumbbell-lateral-raise-video-exercise-guide-0272": "https://www.youtube.com/embed/jZYA0-uwbwI?rel=0",
  "lateral-raise-machine-video-exercise-guide-0273": "https://www.youtube.com/embed/IropE3iOk2c?rel=0",
  "standing-arnold-press-video-exercise-guide-0280": "https://www.youtube.com/embed/ZsVxV2dV5YU?rel=0",
  "weight-plate-front-raise-video-exercise-guide-0283": "https://www.youtube.com/embed/v7tac1hXOfU?rel=0",
  "barbell-clean-and-press-video-exercise-guide-0286": "https://www.youtube.com/embed/xeq_So7YpMg?rel=0",
  "one-arm-cable-front-raise-video-exercise-guide-0295": "https://www.youtube.com/embed/viQrUpV_nVw?rel=0",
  "standing-neutral-grip-dumbbell-shoulder-press-video-exercise-guide-0297": "https://www.youtube.com/embed/5qCLfziROZI?rel=0",
  "one-arm-seated-dumbbell-shoulder-press-video-exercise-guide-0301": "https://www.youtube.com/embed/KV1rny2aQeM?rel=0",
  "alternating-dumbbell-lateral-raise-video-exercise-guide-0308": "https://www.youtube.com/embed/Pw2JhhF-DuE?rel=0",
  "standing-dublin-press-video-exercise-guide-0317": "https://www.youtube.com/embed/-dWSzGqG-CU?rel=0",
  "dublin-press-video-exercise-guide-0319": "https://www.youtube.com/embed/c28638rjwRg?rel=0",
  "overhead-front-raise-with-weight-plate-video-exercise-guide-0320": "https://www.youtube.com/embed/e8my9OOCXVo?rel=0",
  "one-arm-dumbbell-rear-delt-fly-video-exercise-guide-0321": "https://www.youtube.com/embed/o9YUiQk5bV0?rel=0",
  "smith-machine-behind-the-neck-shoulder-press-video-exercise-guide-0322": "https://www.youtube.com/embed/DHxCa0btKEo?rel=0",
  "alternating-seated-bent-over-rear-delt-fly-video-exercise-guide-0326": "https://www.youtube.com/embed/8QtjzwP4e0A?rel=0",
  "lying-rear-delt-fly-video-exercise-guide-0327": "https://www.youtube.com/embed/1pzq02DD5Fo?rel=0",
  "one-arm-bent-over-cable-reverse-fly-video-exercise-guide-0329": "https://www.youtube.com/embed/OMZp3VLUvM4?rel=0",
  "seated-dumbbell-front-raise-video-exercise-guide-0331": "https://www.youtube.com/embed/5D1cueqZM-M?rel=0",
  "one-arm-seated-dumbbell-lateral-raise-video-exercise-guide-0336": "https://www.youtube.com/embed/n25Em2K0iIE?rel=0",
  "alternating-dumbbell-front-raise-video-exercise-guide-0338": "https://www.youtube.com/embed/fKMIHZD9S98?rel=0",
  "one-arm-standing-dumbbell-shoulder-press-video-exercise-guide-0341": "https://www.youtube.com/embed/JyJJLEnCcUo?rel=0",
  "barbell-rear-delt-row-to-neck-video-exercise-guide-0349": "https://www.youtube.com/embed/f8tF8KGz5xI?rel=0",
  "seated-barbell-overhead-front-raise-video-exercise-guide-0351": "https://www.youtube.com/embed/Ytffw4cHBh0?rel=0",
  "one-arm-dumbbell-front-raise-video-exercise-guide-0355": "https://www.youtube.com/embed/B6e5b8SY64g?rel=0",
  "exercise-ball-dumbbell-shoulder-press-video-exercise-guide-0358": "https://www.youtube.com/embed/UkmJZrk_hmE?rel=0",
  "alternating-incline-rear-delt-fly-video-exercise-guide-0360": "https://www.youtube.com/embed/-7kvipzTVR4?rel=0",
  "exercise-ball-barbell-shoulder-press-video-exercise-guide-0365": "https://www.youtube.com/embed/DsibXnWakEk?rel=0",
  "one-arm-neutral-grip-dumbbell-shoulder-press-video-exercise-guide-0369": "https://www.youtube.com/embed/GHVfxRFhoII?rel=0",
  "alternating-rear-delt-fly-video-exercise-guide-0372": "https://www.youtube.com/embed/zqWVolge-Tk?rel=0",
  "seated-alternating-arnold-press-video-exercise-guide-0374": "https://www.youtube.com/embed/JhfBSa7rQyg?rel=0",
  "lying-cable-front-raise-video-exercise-guide-0380": "https://www.youtube.com/embed/v8tvw75ZFGA?rel=0",
  "exercise-ball-lateral-raise-video-exercise-guide-0382": "https://www.youtube.com/embed/2kPVbAOB46A?rel=0",
  "seated-alternating-neutral-grip-dumbbell-shoulder-press-video-exercise-guide-0386": "https://www.youtube.com/embed/DpwyONGs3eI?rel=0",
  "one-arm-standing-arnold-press-video-exercise-guide-0389": "https://www.youtube.com/embed/V7qZEEenaaU?rel=0",
  "one-arm-seated-rear-delt-fly-video-exercise-guide-0396": "https://www.youtube.com/embed/JVPa2wHKAuI?rel=0",
  "one-arm-lying-rear-delt-fly-video-exercise-guide-0398": "https://www.youtube.com/embed/hsglKkHnGDs?rel=0",
  "one-arm-seated-arnold-press-video-exercise-guide-0400": "https://www.youtube.com/embed/2zzkQH3kzME?rel=0",
  "seated-alternating-dumbbell-lateral-raise-video-exercise-guide-0403": "https://www.youtube.com/embed/n7rcM_jU_-Q?rel=0",
  "alternating-lying-rear-delt-fly-video-exercise-guide-0405": "https://www.youtube.com/embed/1pzq02DD5Fo?rel=0",
  "one-arm-seated-dumbbell-front-raise-video-exercise-guide-0407": "https://www.youtube.com/embed/5D1cueqZM-M?rel=0",
  "one-arm-seated-neutral-grip-dumbbell-shoulder-press-video-exercise-guide-0410": "https://www.youtube.com/embed/zQIvIRi66RM?rel=0",
  "seated-alternating-dumbbell-front-raise-video-exercise-guide-0411": "https://www.youtube.com/embed/5D1cueqZM-M?rel=0",
  "alternating-standing-arnold-press-video-exercise-guide-0412": "https://www.youtube.com/embed/3N7qz1kE_yA?rel=0",
  "one-arm-incline-dumbbell-front-raise-video-exercise-guide-0415": "https://www.youtube.com/embed/pJklk7UR69s?rel=0",
  "seated-barbell-front-raise-video-exercise-guide-0417": "https://www.youtube.com/embed/kvFlGwryWVI?rel=0",
  "lying-rear-delt-barbell-raise-video-exercise-guide-0420": "https://www.youtube.com/embed/rf7iXSMj9dY?rel=0",
  "alternating-standing-dumbbell-shoulder-press-video-exercise-guide-0422": "https://www.youtube.com/embed/uMr1qYcrcfY?rel=0",
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
  console.log(`Done. Updated VideoLink on ${writes.length}/${entries.length} Shoulders exercises.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
