// app.js

const express = require("express");
const cors = require("cors");

const authRoutes = require("./routes/authRoutes");

const app = express();

app.use(cors());

// IMPORTANT: this raw-body parser for the webhook path MUST be
// registered before the global express.json() below. Chargily's
// signature is an HMAC over the exact raw bytes they sent — once
// express.json() parses and re-serializes the body, the original
// bytes are gone and signature verification will always fail.
app.use("/payments/webhook", express.raw({ type: "application/json" }));

app.use(express.json());

// Health check — useful for confirming the server is alive before
// debugging anything auth-related.
app.get("/health", (req, res) => {
  res.status(200).json({ status: "ok" });
});

app.use("/auth", authRoutes);
app.use("/payments", require("./routes/paymentRoutes"));
app.use("/assessments", require("./routes/assessmentRoutes"));

app.use("/uploads", express.static(require("path").join(__dirname, "uploads")));

// TODO: mount future route groups here as features are built:

// 404 fallback
app.use((req, res) => {
  res.status(404).json({ error: "Not found." });
});

// Centralized error handler
app.use((err, req, res, next) => {
  console.error("Unhandled error:", err);
  res.status(500).json({ error: "Something went wrong." });
});

module.exports = app;