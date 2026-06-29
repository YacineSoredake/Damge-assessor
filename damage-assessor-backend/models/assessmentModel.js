// models/assessmentModel.js

const pool = require("../config/db");

async function create({ userId, plateNumber, vehicleMakeModel, clientReference, notes }) {
  const [result] = await pool.query(
    `INSERT INTO assessments (user_id, plate_number, vehicle_make_model, client_reference, notes, status, created_at)
     VALUES (?, ?, ?, ?, ?, 'capturing', NOW())`,
    [userId, plateNumber, vehicleMakeModel || null, clientReference || null, notes || null]
  );
  return findById(result.insertId);
}

async function findById(id) {
  const [rows] = await pool.query(`SELECT * FROM assessments WHERE id = ? LIMIT 1`, [id]);
  return rows[0] || null;
}

async function listForUser(userId, { search, limit, offset }) {
  const params = [userId];
  let whereClause = "WHERE user_id = ?";
  if (search) {
    whereClause += " AND plate_number LIKE ?";
    params.push(`%${search}%`);
  }
  params.push(limit, offset);

  const [rows] = await pool.query(
    `SELECT id, plate_number, vehicle, overall_condition, status, created_at
     FROM assessments
     ${whereClause}
     ORDER BY created_at DESC
     LIMIT ? OFFSET ?`,
    params
  );
  return rows;
}

/** Confirms the assessment belongs to this user — prevents one user from uploading
 * photos to or reading another user's assessment by guessing an id. */
async function findByIdForUser(id, userId) {
  const [rows] = await pool.query(
    `SELECT * FROM assessments WHERE id = ? AND user_id = ? LIMIT 1`,
    [id, userId]
  );
  return rows[0] || null;
}

async function addPhoto({ assessmentId, type, storageUrl }) {
  const [result] = await pool.query(
    `INSERT INTO assessment_photos (assessment_id, type, storage_url, created_at)
     VALUES (?, ?, ?, NOW())`,
    [assessmentId, type, storageUrl]
  );
  return { id: result.insertId, assessmentId, type, storageUrl };
}

async function getPhotos(assessmentId) {
  const [rows] = await pool.query(
    `SELECT id, type, storage_url, angle, annotated_image_base64, created_at
     FROM assessment_photos WHERE assessment_id = ?`,
    [assessmentId]
  );
  return rows;
}
async function countForUser(userId) {
  const [rows] = await pool.query(`SELECT COUNT(*) AS total FROM assessments WHERE user_id = ?`, [userId]);
  return rows[0].total;
}

module.exports = {countForUser,listForUser , create, findById, findByIdForUser, addPhoto, getPhotos };
