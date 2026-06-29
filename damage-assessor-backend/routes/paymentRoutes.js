// routes/paymentRoutes.js

const express = require("express");
const router = express.Router();

const { createCheckout, handleWebhook } = require("../controllers/paymentController");
const { requireAuth } = require("../middleware/requireAuth");

router.post("/checkout", requireAuth, createCheckout);

// No requireAuth — this is called by Chargily's servers, not the app.
// Relies on webhook signature verification instead (see TODO in controller).
router.post("/webhook", handleWebhook);

module.exports = router;
