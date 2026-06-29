// models/paymentModel.js

const pool = require("../config/db");

const PLAN_PRICES_DZD = {
  monthly: 1500, // TODO: confirm real pricing before launch
  yearly: 14400,
};

const PLAN_DURATION_DAYS = {
  monthly: 30,
  yearly: 365,
};

async function createPendingPayment({ userId, plan }) {
  const amount = PLAN_PRICES_DZD[plan];
  const [result] = await pool.query(
    `INSERT INTO payments (user_id, plan, amount_dzd, status, created_at)
     VALUES (?, ?, ?, 'pending', NOW())`,
    [userId, plan, amount]
  );
  return { id: result.insertId, amount };
}

async function markPaidByProviderRef(providerRef) {
  const [rows] = await pool.query(
    `SELECT id, user_id, plan FROM payments WHERE provider_ref = ? LIMIT 1`,
    [providerRef]
  );
  const payment = rows[0];
  if (!payment) return null;

  await pool.query(`UPDATE payments SET status = 'paid' WHERE id = ?`, [payment.id]);

  const durationDays = PLAN_DURATION_DAYS[payment.plan];
  await pool.query(
    `UPDATE users
     SET subscription_status = 'active',
         subscription_expires_at = DATE_ADD(NOW(), INTERVAL ? DAY)
     WHERE id = ?`,
    [durationDays, payment.user_id]
  );

  return payment;
}

async function attachProviderRef(paymentId, providerRef) {
  await pool.query(`UPDATE payments SET provider_ref = ? WHERE id = ?`, [providerRef, paymentId]);
}

module.exports = { createPendingPayment, markPaidByProviderRef, attachProviderRef, PLAN_PRICES_DZD };
