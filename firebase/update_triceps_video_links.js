// Updates ONLY the VideoLink field of specific "exercises" documents whose
// old Vimeo link doesn't play in-app (the app only embeds YouTube).
// Nothing else in these documents is touched (uses a Firestore field mask).
//
// Usage:
//   node firebase/update_triceps_video_links.js [projectId]
//
// Requires the Firebase CLI to already be logged in (`firebase login`).

const path = require("path");
const { execFileSync } = require("child_process");

const projectId = process.argv[2] || "nexus-90e55";
const collection = "exercises";

const UPDATES = {
  "lying-dumbbell-extension-video-exercise-guide-0824": "https://www.youtube.com/embed/R6SdxvZGK5s?rel=0",
  "tricep-dip-video-exercise-guide-0828": "https://www.youtube.com/embed/JhX1nBnirNw?rel=0",
  "lying-barbell-tricep-extension-skull-crusher-video-exercise-guide-0831": "https://www.youtube.com/embed/LRmjMu9NOnY?rel=0",
  "french-press-video-exercise-guide-0832": "https://www.youtube.com/embed/ItLKDvhO8RU?rel=0",
  "bench-dip-video-exercise-guide-0834": "https://www.youtube.com/embed/WVeZDBhZwLA?rel=0",
  "one-arm-seated-dumbbell-extension-video-exercise-guide-0836": "https://www.youtube.com/embed/cDs7-IlDxko?rel=0",
  "one-arm-standing-dumbbell-extension-video-exercise-guide-0837": "https://www.youtube.com/embed/oAaAFOKIojs?rel=0",
  "dumbbell-tricep-kickback-video-exercise-guide-0838": "https://www.youtube.com/embed/Z25HaB_qrYY?rel=0",
  "standing-low-pulley-overhead-tricep-extension-rope-extension-video-exercise-guide-0840": "https://www.youtube.com/embed/l4i7iDLiMXs?rel=0",
  "45-degree-lying-tricep-extension-video-exercise-guide-0841": "https://www.youtube.com/embed/LRmjMu9NOnY?rel=0",
  "close-grip-push-up-video-exercise-guide-0842": "https://www.youtube.com/embed/NPmRYbIneTE?rel=0",
  "one-arm-cable-tricep-extension-video-exercise-guide-0844": "https://www.youtube.com/embed/juNUDw4hVHU?rel=0",
  "seated-french-press-video-exercise-guide-0845": "https://www.youtube.com/embed/ItLKDvhO8RU?rel=0",
  "incline-skull-crusher-video-exercise-guide-0846": "https://www.youtube.com/embed/KUYbWo1D6g0?rel=0",
  "reverse-one-arm-cable-tricep-extension-video-exercise-guide-0850": "https://www.youtube.com/embed/juNUDw4hVHU?rel=0",
  "one-arm-cable-overhead-tricep-extension-video-exercise-guide-0853": "https://www.youtube.com/embed/w3iAESGWK6M?rel=0",
  "high-pulley-overhead-tricep-extension-video-exercise-guide-0855": "https://www.youtube.com/embed/l4i7iDLiMXs?rel=0",
  "one-arm-seated-overhead-tricep-extension-video-exercise-guide-0856": "https://www.youtube.com/embed/cDs7-IlDxko?rel=0",
  "smith-machine-incline-tricep-extension-video-exercise-guide-0862": "https://www.youtube.com/embed/z8UWdGwtzRM?rel=0",
  "smith-machine-close-grip-bench-press-video-exercise-guide-0868": "https://www.youtube.com/embed/z8UWdGwtzRM?rel=0",
  "cable-tricep-kickback-video-exercise-guide-0869": "https://www.youtube.com/embed/ZvF4Oi_6Vtg?rel=0",
  "reverse-grip-skull-crusher-video-exercise-guide-0871": "https://www.youtube.com/embed/LRmjMu9NOnY?rel=0",
  "seated-low-pulley-overhead-tricep-extension-rope-extension-video-exercise-guide-0872": "https://www.youtube.com/embed/l4i7iDLiMXs?rel=0",
  "close-grip-chest-press-video-exercise-guide-0874": "https://www.youtube.com/embed/a2G3IdaTcPU?rel=0",
  "two-arm-tricep-cable-extension-video-exercise-guide-0875": "https://www.youtube.com/embed/ZF7hru0b9Z0?rel=0",
  "inline-bench-french-press-video-exercise-guide-0876": "https://www.youtube.com/embed/KUYbWo1D6g0?rel=0",
  "reverse-grip-one-arm-overhead-cable-tricep-extension-video-exercise-guide-0877": "https://www.youtube.com/embed/w3iAESGWK6M?rel=0",
  "kneeling-overhead-tricep-extension-over-flat-bench-video-exercise-guide-0878": "https://www.youtube.com/embed/1LSys7HZBQE?rel=0",
  "lying-cable-tricep-extension-rope-extension-video-exercise-guide-0879": "https://www.youtube.com/embed/l4i7iDLiMXs?rel=0",
  "lying-dumbbell-extension-single-dumbbell-video-exercise-guide-0880": "https://www.youtube.com/embed/R6SdxvZGK5s?rel=0",
  "lying-cable-tricep-extension-video-exercise-guide-0881": "https://www.youtube.com/embed/l4i7iDLiMXs?rel=0",
  "incline-cable-tricep-extension-video-exercise-guide-0882": "https://www.youtube.com/embed/GxDegBiychk?rel=0",
  "single-bench-dip-video-exercise-guide-0883": "https://www.youtube.com/embed/WVeZDBhZwLA?rel=0",
  "one-arm-seated-dumbbell-kickback-video-exercise-guide-0884": "https://www.youtube.com/embed/AbOUz070DC4?rel=0",
  "seated-reverse-grip-one-arm-overhead-tricep-extension-video-exercise-guide-0886": "https://www.youtube.com/embed/w3iAESGWK6M?rel=0",
  "twisting-dumbbell-bench-press-video-exercise-guide-0887": "https://www.youtube.com/embed/fHv3_kU4cdg?rel=0",
  "seated-alternating-bent-over-dumbbell-kickback-video-exercise-guide-0888": "https://www.youtube.com/embed/Z25HaB_qrYY?rel=0",
  "reverse-grip-cable-tricep-kickback-video-exercise-guide-0889": "https://www.youtube.com/embed/ZvF4Oi_6Vtg?rel=0",
  "exercise-ball-one-arm-dumbbell-extension-video-exercise-guide-0892": "https://www.youtube.com/embed/R6SdxvZGK5s?rel=0",
  "smith-machine-reverse-close-grip-bench-press-video-exercise-guide-0893": "https://www.youtube.com/embed/z8UWdGwtzRM?rel=0",
  "standing-low-pulley-overhead-tricep-extension-video-exercise-guide-0894": "https://www.youtube.com/embed/l4i7iDLiMXs?rel=0",
  "cable-concentration-tricep-extension-video-exercise-guide-0895": "https://www.youtube.com/embed/juNUDw4hVHU?rel=0",
  "close-grip-press-behind-the-neck-video-exercise-guide-0896": "https://www.youtube.com/embed/a2G3IdaTcPU?rel=0",
  "alternating-bent-over-dumbbell-kickback-video-exercise-guide-0897": "https://www.youtube.com/embed/Z25HaB_qrYY?rel=0",
  "weighted-bench-dip-video-exercise-guide-0898": "https://www.youtube.com/embed/w72qXc85sRU?rel=0",
  "seated-low-pulley-overhead-tricep-extension-video-exercise-guide-0899": "https://www.youtube.com/embed/l4i7iDLiMXs?rel=0",
  "one-arm-seated-bent-over-dumbbell-kickback-video-exercise-guide-0900": "https://www.youtube.com/embed/AbOUz070DC4?rel=0",
  "alternating-lying-dumbbell-extension-video-exercise-guide-0902": "https://www.youtube.com/embed/R6SdxvZGK5s?rel=0",
  "one-arm-lying-dumbbell-extension-video-exercise-guide-0903": "https://www.youtube.com/embed/R6SdxvZGK5s?rel=0",
  "two-arm-cable-tricep-kickback-video-exercise-guide-0906": "https://www.youtube.com/embed/ZvF4Oi_6Vtg?rel=0",
  "lying-barbell-reverse-extension-video-exercise-guide-0908": "https://www.youtube.com/embed/LRmjMu9NOnY?rel=0",
  "reverse-grip-french-press-video-exercise-guide-0911": "https://www.youtube.com/embed/ItLKDvhO8RU?rel=0",
  "three-bench-dip-video-exercise-guide-0912": "https://www.youtube.com/embed/WVeZDBhZwLA?rel=0",
  "incline-cable-tricep-extension-rope-extension-video-exercise-guide-0913": "https://www.youtube.com/embed/GxDegBiychk?rel=0",
  "weighted-three-bench-dip-video-exercise-guide-0915": "https://www.youtube.com/embed/w72qXc85sRU?rel=0",
  "reverse-grip-seated-french-press-video-exercise-guide-0916": "https://www.youtube.com/embed/ItLKDvhO8RU?rel=0",
  "exercise-ball-dumbbell-kickbacks-video-exercise-guide-0917": "https://www.youtube.com/embed/Z25HaB_qrYY?rel=0",
  "45-degree-lying-tricep-extension-ez-bar-video-exercise-guide-0918": "https://www.youtube.com/embed/LRmjMu9NOnY?rel=0",
  "exercise-ball-dip-video-exercise-guide-0920": "https://www.youtube.com/embed/xAjzkYXqTjc?rel=0",
  "reverse-grip-close-grip-bench-press-video-exercise-guide-0921": "https://www.youtube.com/embed/a2G3IdaTcPU?rel=0",
  "exercise-ball-french-press-video-exercise-guide-0923": "https://www.youtube.com/embed/ItLKDvhO8RU?rel=0",
  "exercise-ball-two-arm-dumbbell-extension-video-exercise-guide-0925": "https://www.youtube.com/embed/R6SdxvZGK5s?rel=0",
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
  console.log(`Done. Updated VideoLink on ${done}/${entries.length} Triceps exercises.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
