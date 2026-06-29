// routes/authRoutes.js

const express = require("express");
const router = express.Router();

const { loginWithFirebase } = require("../controllers/authController");
const { requireAuth } = require("../middleware/requireAuth");
const userModel = require("../models/userModel");

// POST /auth/firebase — exchange a verified Firebase ID token for a backend session.
router.post("/firebase", loginWithFirebase);
 
// GET /me — returns the current user's profile + trial/subscription status.
// Protected by requireAuth so the Flutter app's dashboard/middleware checks
// always hit live backend data, never a cached client-side value.
router.get("/me", requireAuth, async (req, res) => {
  try {
    const user = await userModel.findById(req.userId);
    if (!user) {
      return res.status(404).json({ error: "User not found." });
    }
    return res.status(200).json({
      id: String(user.id),
      phone: user.phone,
      name: user.name,
      email: user.email,
      company: user.company,
      free_report_used: !!user.free_report_used,
      subscription_status: user.subscription_status,
      subscription_expires_at: user.subscription_expires_at,
    });
  } catch (err) {
    console.error("GET /me error:", err);
    return res.status(500).json({ error: "Something went wrong." });
  }
});

module.exports = router;
