// Updates ONLY the VideoLink field of specific "exercises" documents whose
// old Vimeo link doesn't play in-app (the app only embeds YouTube).
// Nothing else in these documents is touched (uses a Firestore field mask).
//
// Usage:
//   node firebase/update_biceps_video_links.js [projectId]
//
// Requires the Firebase CLI to already be logged in (`firebase login`).

const path = require("path");
const { execFileSync } = require("child_process");

const projectId = process.argv[2] || "nexus-90e55";
const collection = "exercises";

const UPDATES = {
  "standing-dumbbell-curl-video-exercise-guide-0926": "https://www.youtube.com/embed/av7-8igSXTs?rel=0",
  "standing-hammer-curl-video-exercise-guide-0927": "https://www.youtube.com/embed/9Mpl_rio1Hk?rel=0",
  "standing-barbell-curl-video-exercise-guide-0929": "https://www.youtube.com/embed/ajXnfC6FaU0?rel=0",
  "cable-curl-video-exercise-guide-0930": "https://www.youtube.com/embed/rfRdD5PKrko?rel=0",
  "ez-bar-preacher-curl-video-exercise-guide-0933": "https://www.youtube.com/embed/e7X6G07KnPI?rel=0",
  "cross-body-hammer-curl-pinwheel-curls-video-exercise-guide-0934": "https://www.youtube.com/embed/7MrzVaPM0Uw?rel=0",
  "barbell-preacher-curl-video-exercise-guide-0935": "https://www.youtube.com/embed/e7X6G07KnPI?rel=0",
  "ez-bar-curl-video-exercise-guide-0936": "https://www.youtube.com/embed/5NsFLGUf0Fo?rel=0",
  "cable-curl-rope-extension-video-exercise-guide-0937": "https://www.youtube.com/embed/rfRdD5PKrko?rel=0",
  "alternating-standing-dumbbell-curl-video-exercise-guide-0938": "https://www.youtube.com/embed/JLIb64XUPYA?rel=0",
  "alternating-seated-dumbbell-curl-video-exercise-guide-0939": "https://www.youtube.com/embed/av7-8igSXTs?rel=0",
  "spider-curl-video-exercise-guide-0942": "https://www.youtube.com/embed/CITtSuda0Fg?rel=0",
  "seated-dumbbell-curl-video-exercise-guide-0943": "https://www.youtube.com/embed/av7-8igSXTs?rel=0",
  "machine-bicep-curl-video-exercise-guide-0944": "https://www.youtube.com/embed/rUP8PxCIiNQ?rel=0",
  "wide-grip-standing-barbell-curl-video-exercise-guide-0945": "https://www.youtube.com/embed/x0s-hL3CuKg?rel=0",
  "standing-high-pulley-cable-curl-video-exercise-guide-0947": "https://www.youtube.com/embed/grFE5bhFmiQ?rel=0",
  "one-arm-seated-dumbbell-curl-video-exercise-guide-0948": "https://www.youtube.com/embed/av7-8igSXTs?rel=0",
  "one-arm-standing-hammer-curl-video-exercise-guide-0949": "https://www.youtube.com/embed/9Mpl_rio1Hk?rel=0",
  "seated-hammer-curl-video-exercise-guide-0950": "https://www.youtube.com/embed/obovFxPjXSM?rel=0",
  "barbell-drag-curl-video-exercise-guide-0951": "https://www.youtube.com/embed/LMdNTHH6G8I?rel=0",
  "one-arm-cable-curl-video-exercise-guide-0953": "https://www.youtube.com/embed/njLoCel5lUI?rel=0",
  "cable-preacher-curl-video-exercise-guide-0954": "https://www.youtube.com/embed/vruRZKgRzv0?rel=0",
  "incline-hammer-curl-video-exercise-guide-0955": "https://www.youtube.com/embed/DCe8f6vMe9A?rel=0",
  "lateral-pulldown-bicep-curl-video-exercise-guide-0956": "https://www.youtube.com/embed/p5GH60WI7Os?rel=0",
  "alternating-standing-hammer-curl-video-exercise-guide-0957": "https://www.youtube.com/embed/9Mpl_rio1Hk?rel=0",
  "cable-drag-curl-video-exercise-guide-0958": "https://www.youtube.com/embed/LMdNTHH6G8I?rel=0",
  "one-arm-standing-dumbbell-curl-video-exercise-guide-0959": "https://www.youtube.com/embed/av7-8igSXTs?rel=0",
  "close-grip-ez-bar-curl-video-exercise-guide-0961": "https://www.youtube.com/embed/5NsFLGUf0Fo?rel=0",
  "lying-dumbbell-curl-video-exercise-guide-0962": "https://www.youtube.com/embed/okwUqL1kbEA?rel=0",
  "hammer-bar-curl-video-exercise-guide-0963": "https://www.youtube.com/embed/Sf7VsXb71d4?rel=0",
  "lying-incline-bench-barbell-curl-video-exercise-guide-0964": "https://www.youtube.com/embed/CHK-ISOT0zo?rel=0",
  "seated-cable-curl-video-exercise-guide-0965": "https://www.youtube.com/embed/rfRdD5PKrko?rel=0",
  "smith-machine-bicep-curl-video-exercise-guide-0966": "https://www.youtube.com/embed/zlCPcmPlhX4?rel=0",
  "incline-bench-hammer-curl-video-exercise-guide-0967": "https://www.youtube.com/embed/DCe8f6vMe9A?rel=0",
  "seated-barbell-curl-video-exercise-guide-0968": "https://www.youtube.com/embed/ajXnfC6FaU0?rel=0",
  "alternating-seated-hammer-curl-video-exercise-guide-0969": "https://www.youtube.com/embed/obovFxPjXSM?rel=0",
  "alternating-incline-dumbbell-curl-video-exercise-guide-0970": "https://www.youtube.com/embed/DCe8f6vMe9A?rel=0",
  "one-arm-dumbbell-preacher-curl-video-exercise-guide-0971": "https://www.youtube.com/embed/rqfcNmxJQ7k?rel=0",
  "alternating-dumbbell-preacher-curl-video-exercise-guide-0972": "https://www.youtube.com/embed/rqfcNmxJQ7k?rel=0",
  "lying-cable-curl-on-floor-video-exercise-guide-0973": "https://www.youtube.com/embed/n9wrBT05k6Y?rel=0",
  "alternating-standing-dumbbell-twisting-curls-video-exercise-guide-0974": "https://www.youtube.com/embed/av7-8igSXTs?rel=0",
  "wide-grip-ez-bar-curl-video-exercise-guide-0975": "https://www.youtube.com/embed/5NsFLGUf0Fo?rel=0",
  "incline-bench-dumbbell-curl-video-exercise-guide-0976": "https://www.youtube.com/embed/DCe8f6vMe9A?rel=0",
  "squatting-cable-curl-video-exercise-guide-0979": "https://www.youtube.com/embed/4DFEs8jKyH0?rel=0",
  "one-arm-prone-incline-dumbbell-curl-video-exercise-guide-0981": "https://www.youtube.com/embed/GHlyeXyJrbU?rel=0",
  "one-arm-dumbbell-hammer-preacher-curl-video-exercise-guide-0982": "https://www.youtube.com/embed/rqfcNmxJQ7k?rel=0",
  "incline-cable-bicep-curl-video-exercise-guide-0983": "https://www.youtube.com/embed/rfRdD5PKrko?rel=0",
  "alternating-dumbbell-hammer-preacher-curl-video-exercise-guide-0985": "https://www.youtube.com/embed/rqfcNmxJQ7k?rel=0",
  "lying-wide-dumbbell-curl-video-exercise-guide-0986": "https://www.youtube.com/embed/okwUqL1kbEA?rel=0",
  "cable-concentration-curl-video-exercise-guide-0987": "https://www.youtube.com/embed/gd5Q7hNu7KM?rel=0",
  "one-arm-seated-hammer-curl-video-exercise-guide-0988": "https://www.youtube.com/embed/obovFxPjXSM?rel=0",
  "hammer-bar-preacher-curl-video-exercise-guide-0989": "https://www.youtube.com/embed/e7X6G07KnPI?rel=0",
  "exercise-ball-dumbbell-curl-video-exercise-guide-0990": "https://www.youtube.com/embed/av7-8igSXTs?rel=0",
  "two-arm-low-pulley-cable-curl-video-exercise-guide-0991": "https://www.youtube.com/embed/OsQupgowb00?rel=0",
  "prone-incline-hammer-curl-video-exercise-guide-0992": "https://www.youtube.com/embed/GHlyeXyJrbU?rel=0",
  "barbell-concentration-curl-video-exercise-guide-0993": "https://www.youtube.com/embed/gd5Q7hNu7KM?rel=0",
  "one-arm-prone-hammer-curl-video-exercise-guide-0994": "https://www.youtube.com/embed/GHlyeXyJrbU?rel=0",
  "exercise-ball-preacher-curl-video-exercise-guide-0995": "https://www.youtube.com/embed/rafnTaCOxM0?rel=0",
  "lying-high-pulley-cable-curl-video-exercise-guide-0996": "https://www.youtube.com/embed/n9wrBT05k6Y?rel=0",
  "cable-preacher-curl-rope-extension-video-exercise-guide-0997": "https://www.youtube.com/embed/EyW4D6qcs_M?rel=0",
  "lying-high-pulley-close-grip-cable-curl-video-exercise-guide-0998": "https://www.youtube.com/embed/n9wrBT05k6Y?rel=0",
  "wide-grip-cable-curl-video-exercise-guide-0999": "https://www.youtube.com/embed/rfRdD5PKrko?rel=0",
  "close-grip-cable-curl-video-exercise-guide-1000": "https://www.youtube.com/embed/rfRdD5PKrko?rel=0",
  "alternating-incline-hammer-curl-video-exercise-guide-1001": "https://www.youtube.com/embed/DCe8f6vMe9A?rel=0",
  "prone-incline-dumbbell-curl-video-exercise-guide-1002": "https://www.youtube.com/embed/GHlyeXyJrbU?rel=0",
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
  console.log(`Done. Updated VideoLink on ${writes.length}/${entries.length} Biceps exercises.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
