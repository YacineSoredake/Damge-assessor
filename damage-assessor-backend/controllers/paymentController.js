// controllers/paymentController.js
//
// Real Chargily Pay V2 integration, verified against their actual docs
// (dev.chargily.com/pay-v2) — not guessed against general patterns.
//
// Still an open item from the spec: Chargily has no native recurring
// billing. This charges once per period and extends
// subscription_expires_at via the webhook — no automatic re-charge on
// expiry. The user simply hits the paywall again once expired.

const crypto = require("crypto");
const axios = require("axios");
const paymentModel = require("../models/paymentModel");

const CHARGILY_MODE = process.env.CHARGILY_MODE || "test"; // 'test' or 'live'
const CHARGILY_API_BASE =
  CHARGILY_MODE === "live"
    ? "https://pay.chargily.net/api/v2"
    : "https://pay.chargily.net/test/api/v2";
const CHARGILY_SECRET_KEY = process.env.CHARGILY_SECRET_KEY;

/**
 * POST /payments/checkout
 * body: { plan: 'monthly' | 'yearly' }
 * Auth required (requireAuth middleware).
 */
async function createCheckout(req, res) {
  const { plan } = req.body;

  if (!["monthly", "yearly"].includes(plan)) {
    return res.status(400).json({ error: "plan must be 'monthly' or 'yearly'." });
  }

  try {
    const { id: paymentId, amount } = await paymentModel.createPendingPayment({
      userId: req.userId,
      plan,
    });

    const chargilyResponse = await axios.post(
      `${CHARGILY_API_BASE}/checkouts`,
      {
        amount,
        currency: "dzd",
        success_url: process.env.PAYMENT_SUCCESS_URL || "https://example.com/payments/success",
        failure_url: process.env.PAYMENT_FAILURE_URL || "https://example.com/payments/failure",
        webhook_endpoint: process.env.PAYMENT_WEBHOOK_URL,
        description: `Damage Assessor — ${plan} subscription`,
        locale: "fr",
        metadata: [{ payment_id: paymentId, user_id: req.userId, plan }],
      },
      { headers: { Authorization: `Bearer ${CHARGILY_SECRET_KEY}` } }
    );

    const checkoutUrl = chargilyResponse.data.checkout_url;
    const providerRef = chargilyResponse.data.id;

    await paymentModel.attachProviderRef(paymentId, providerRef);

    return res.status(200).json({ checkout_url: checkoutUrl });
  } catch (err) {
    console.error("createCheckout error:", err.response?.data || err.message);
    return res.status(500).json({ error: "Could not start checkout. Please try again." });
  }
}

/**
 * POST /payments/webhook
 * Called server-to-server by Chargily. Requires the raw request body
 * (see app.js — this route must NOT go through express.json() first,
 * or the signature check below will always fail since HMAC is computed
 * over the exact raw bytes Chargily sent, not a re-serialized object).
 */
async function handleWebhook(req, res) {
  const signature = req.get("signature") || "";
  const rawBody = req.body; // Buffer — see the express.raw() middleware in app.js

  if (!signature) {
    console.warn("Webhook rejected: missing signature header.");
    return res.status(400).json({ error: "Missing signature." });
  }

  const expectedSignature = crypto
    .createHmac("sha256", CHARGILY_SECRET_KEY)
    .update(rawBody)
    .digest("hex");

  // timingSafeEqual requires equal-length buffers — guard against a
  // length mismatch throwing instead of just failing the check.
  const signatureBuffer = Buffer.from(signature);
  const expectedBuffer = Buffer.from(expectedSignature);
  const isValid =
    signatureBuffer.length === expectedBuffer.length &&
    crypto.timingSafeEqual(signatureBuffer, expectedBuffer);

  if (!isValid) {
    console.warn("Webhook rejected: invalid signature.");
    return res.status(403).json({ error: "Invalid signature." });
  }

  let event;
  try {
    event = JSON.parse(rawBody.toString("utf8"));
  } catch {
    return res.status(400).json({ error: "Malformed payload." });
  }

  try {
    if (event.type === "checkout.paid") {
      const providerRef = event.data?.id;
      const payment = await paymentModel.markPaidByProviderRef(providerRef);
      if (!payment) {
        console.warn("Webhook: no matching payment for provider_ref", providerRef);
      }
    }
    // Other event types (checkout.failed, checkout.expired) can be
    // handled here as needed — not required for v1.

    return res.status(200).json({ received: true });
  } catch (err) {
    console.error("handleWebhook error:", err);
    return res.status(500).json({ error: "Webhook processing failed." });
  }
}

module.exports = { createCheckout, handleWebhook };