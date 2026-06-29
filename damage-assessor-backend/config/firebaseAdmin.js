// config/firebaseAdmin.js
//
// Initializes the Firebase Admin SDK once at server startup.
// Requires a service account JSON key — generate it from
// Firebase Console > Project Settings > Service Accounts > Generate new private key.
//
// NEVER commit the service account JSON to git. Load it via env var
// (recommended for most hosts) or a path to a gitignored file.

const admin = require("firebase-admin");

function initFirebaseAdmin() {
  if (admin.apps.length > 0) {
    return admin; // already initialized — avoid double-init on hot reload
  }

  let credential;

  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    // Recommended for most hosting providers (Railway, Render, etc.):
    // paste the entire service account JSON as a single env var.
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    credential = admin.credential.cert(serviceAccount);
  } else if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
    // Alternative: path to a local JSON file (keep it gitignored).
    credential = admin.credential.cert(require(process.env.FIREBASE_SERVICE_ACCOUNT_PATH));
  } else {
    throw new Error(
      "Firebase Admin SDK not configured. Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_SERVICE_ACCOUNT_PATH in your environment."
    );
  }

  admin.initializeApp({ credential });
  return admin;
}

module.exports = { admin: initFirebaseAdmin() };
