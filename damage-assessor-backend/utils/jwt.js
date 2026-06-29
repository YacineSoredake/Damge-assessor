// utils/jwt.js
//
// Issues and verifies our OWN backend session JWT — separate from the
// Firebase ID token, which is only used once at login to prove phone
// ownership. All subsequent API calls authenticate with this JWT.

const jwt = require("jsonwebtoken");

const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "30d";

if (!JWT_SECRET) {
  throw new Error("JWT_SECRET is not set in environment variables.");
}

function signUserToken(user) {
  return jwt.sign(
    { sub: user.id, firebase_uid: user.firebase_uid },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
}

function verifyUserToken(token) {
  return jwt.verify(token, JWT_SECRET); // throws if invalid/expired
}

module.exports = { signUserToken, verifyUserToken };
