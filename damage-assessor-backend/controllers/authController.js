// controllers/authController.js

const { admin } = require("../config/firebaseAdmin");
const userModel = require("../models/userModel");
const { signUserToken } = require("../utils/jwt");

/**
 * POST /auth/firebase
 * body: { firebase_id_token }
 *
 * Flow:
 * 1. Verify the Firebase ID token server-side (never trust the client's
 *    claim that it's "already verified" — this is the one mandatory check).
 * 2. Extract the Firebase UID + phone number from the *verified* token,
 *    not from anything the client sent in the request body.
 * 3. Look up the user by firebase_uid; create one if this is their first login.
 * 4. Issue our own backend JWT and return it + the user profile.
 */
async function loginWithFirebase(req, res) {
  const { firebase_id_token } = req.body;

  if (!firebase_id_token) {
    return res.status(400).json({ error: "firebase_id_token is required." });
  }

  let decodedToken;
  try {
    decodedToken = await admin.auth().verifyIdToken(firebase_id_token);
  } catch (err) {
    // Covers expired tokens, malformed tokens, revoked tokens, etc.
    // Distinct from a 500 — this is a client auth problem, not a server bug.
    return res.status(401).json({ error: "Invalid or expired Firebase token." });
  }

  const firebaseUid = decodedToken.uid;
  const phone = decodedToken.phone_number || null;

  if (!phone) {
    // Shouldn't happen with Phone Auth, but guards against a misconfigured
    // client sending a token from a different sign-in method (e.g. email link)
    // that this app doesn't support yet.
    return res.status(400).json({ error: "Token does not contain a verified phone number." });
  }

  try {
    let user = await userModel.findByFirebaseUid(firebaseUid);

    if (!user) {
      user = await userModel.createUser({ firebaseUid, phone });
    }

    const backendToken = signUserToken(user);

    return res.status(200).json({
      token: backendToken,
      user: {
        id: String(user.id),
        firebase_uid: user.firebase_uid,
        phone: user.phone,
        name: user.name,
        email: user.email,
        company: user.company,
        free_report_used: !!user.free_report_used,
        subscription_status: user.subscription_status,
        subscription_expires_at: user.subscription_expires_at,
      },
    });
  } catch (err) {
    console.error("loginWithFirebase error:", err);
    return res.status(500).json({ error: "Something went wrong. Please try again." });
  }
}

module.exports = { loginWithFirebase };
