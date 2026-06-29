// middleware/requireAuth.js
//
// Protects every route after login (GET /me, POST /assessments, etc).
// Verifies OUR backend JWT — not the Firebase token, which is only
// used once during the /auth/firebase exchange.

const { verifyUserToken } = require("../utils/jwt");

function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization || "";
  const [scheme, token] = authHeader.split(" ");

  if (scheme !== "Bearer" || !token) {
    return res.status(401).json({ error: "Missing or malformed Authorization header." });
  }

  try {
    const payload = verifyUserToken(token);
    req.userId = payload.sub; // attach for downstream route handlers
    next();
  } catch (err) {
    // Covers expired and tampered tokens alike — Flutter app should
    // catch this 401 and route back to login (per the spec's
    // auth-interceptor design on the client side).
    return res.status(401).json({ error: "Invalid or expired session. Please log in again." });
  }
}

module.exports = { requireAuth };
