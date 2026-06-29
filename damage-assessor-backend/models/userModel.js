// models/userModel.js
//
// Raw SQL via mysql2/promise pool, matching the pattern used elsewhere
// in your the backend. Adjust the `require` path below to match
// wherever your existing DB pool is exported from.

const pool = require("../config/db");

/**
 * Looks up a user by their Firebase UID.
 * Returns null if no user exists yet (first-time login).
 */
async function findByFirebaseUid(firebaseUid) {
  const [rows] = await pool.query(
    `SELECT id, firebase_uid, phone, name, email, company,
            free_report_used, subscription_status, subscription_expires_at, created_at
     FROM users
     WHERE firebase_uid = ?
     LIMIT 1`,
    [firebaseUid]
  );
  return rows[0] || null;
}

/**
 * Creates a new user row on first-ever login for this Firebase account.
 * `phone` comes from the verified Firebase token (phone_number claim) —
 * never trust a phone number passed directly from the client body.
 */
async function createUser({ firebaseUid, phone }) {
  const [result] = await pool.query(
    `INSERT INTO users (firebase_uid, phone, free_report_used, subscription_status, created_at)
     VALUES (?, ?, 0, 'none', NOW())`,
    [firebaseUid, phone]
  );
  return findById(result.insertId);
}

async function findById(id) {
  const [rows] = await pool.query(
    `SELECT id, firebase_uid, phone, name, email, company,
            free_report_used, subscription_status, subscription_expires_at, created_at
     FROM users
     WHERE id = ?
     LIMIT 1`,
    [id]
  );
  return rows[0] || null;
}

module.exports = { findByFirebaseUid, createUser, findById };
