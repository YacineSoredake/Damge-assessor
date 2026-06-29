// services/analysisService.js
//
// Calls the real FastAPI damage-assessment service (CarCheck) over HTTP.
// That service is stateless and synchronous (15-45s per the FastAPI
// developer's own docs) — we keep OUR async/polling architecture on
// top of it: this function runs in the background (fire-and-forget
// from the route handler), and the Flutter app polls
// GET /assessments/:id/status until status flips to 'complete'.

const fs = require("fs");
const path = require("path");
const axios = require("axios");
const FormData = require("form-data");

const pool = require("../config/db");
const assessmentModel = require("../models/assessmentModel");

const FASTAPI_BASE_URL =
  process.env.FASTAPI_BASE_URL || "http://localhost:8000";

// Maps our internal photo type enum to the FastAPI service's expected
// multipart field names (see its /angles endpoint for the exact list).
const ANGLE_FIELD_MAP = {
  angle_front: "front",
  angle_rear: "rear",
  angle_left: "left",
  angle_right: "right",
};
const MAX_CLOSEUPS = 5; // FastAPI service only accepts closeup_1..closeup_5

const progressMap = new Map();
function setProgress(assessmentId, step) {
  progressMap.set(assessmentId, step);
}
function getProgress(assessmentId) {
  return progressMap.get(assessmentId) || null;
}

async function runAnalysisAsync(assessmentId) {
  setProgress(assessmentId, "Uploading photos for analysis…");

  try {
    const photos = await assessmentModel.getPhotos(assessmentId);
    if (photos.length === 0) {
      throw new Error("No photos uploaded for this assessment.");
    }

    const formData = buildFormData(photos);

    setProgress(assessmentId, "Detecting damage and estimating cost…");
    const response = await axios.post(`${FASTAPI_BASE_URL}/analyze`, formData, {
      headers: formData.getHeaders(),
      timeout: 90_000,
      maxContentLength: Infinity,
      maxBodyLength: Infinity,
    });

    await persistResult(assessmentId, response.data, photos);

    setProgress(assessmentId, "Complete");
    await pool.query(
      `UPDATE assessments SET status = 'complete' WHERE id = ?`,
      [assessmentId],
    );

    // Consume the free trial only on a genuinely successful completion —
    // a failed analysis (Gemini/FastAPI error) should not cost the user
    // their one free report. Idempotent: harmless to set this again on
    // subsequent successful assessments once it's already 1.
    const assessment = await assessmentModel.findById(assessmentId);
    if (assessment) {
      await pool.query(`UPDATE users SET free_report_used = 1 WHERE id = ?`, [
        assessment.user_id,
      ]);
    }
  } catch (err) {
    const detail = err.response?.data || err.message;
    console.error(`Analysis failed for assessment ${assessmentId}:`, detail);
    setProgress(assessmentId, "Failed");
    await pool.query(`UPDATE assessments SET status = 'failed' WHERE id = ?`, [
      assessmentId,
    ]);
  }
}

/**
 * Builds the multipart form the FastAPI service expects: one file per
 * angle field (front/rear/left/right), plus up to 5 closeup_N fields.
 * Per the spec's edge case: an assessment may have zero close-ups
 * (clean car) — that's fine, the service accepts any subset as long
 * as at least one image is present overall.
 */
function buildFormData(photos) {
  const formData = new FormData();
  let closeupIndex = 1;

  for (const photo of photos) {
    const absolutePath = path.join(
      __dirname,
      "..",
      photo.storage_url.replace(/^\/uploads\//, "uploads/"),
    );

    if (!fs.existsSync(absolutePath)) {
      console.warn(`Photo file missing on disk, skipping: ${absolutePath}`);
      continue;
    }

    if (photo.type === "closeup") {
      if (closeupIndex > MAX_CLOSEUPS) {
        console.warn(
          `More than ${MAX_CLOSEUPS} close-ups captured — the FastAPI service only ` +
            `accepts ${MAX_CLOSEUPS}, extra close-ups beyond this will be silently dropped.`,
        );
        continue;
      }
      formData.append(
        `closeup_${closeupIndex}`,
        fs.createReadStream(absolutePath),
      );
      closeupIndex++;
    } else {
      const fieldName = ANGLE_FIELD_MAP[photo.type];
      if (fieldName) {
        formData.append(fieldName, fs.createReadStream(absolutePath));
      }
    }
  }

  return formData;
}

/**
 * Persists the full MultiAngleResponse into MySQL:
 * - top-level fields → assessments table
 * - angles[] → annotated_image_base64 attached back onto the matching
 *   assessment_photos row (matched by angle name)
 * - all_damages[] → damage_regions rows
 */
async function persistResult(assessmentId, result, photos) {
  await pool.query(
    `UPDATE assessments SET
       job_id = ?, vehicle = ?, vin_visible = ?, mileage_visible = ?,
       overall_condition = ?, drivability = ?, structural_integrity = ?,
       total_cost_min_dzd = ?, total_cost_max_dzd = ?,
       labor_hours_total_min = ?, labor_hours_total_max = ?,
       total_loss_risk = ?, recommendation = ?, hidden_damage_risk = ?,
       summary = ?, assessor_notes = ?, primary_concerns_json = ?
     WHERE id = ?`,
    [
      result.job_id || null,
      result.vehicle || null,
      result.vin_visible ? 1 : 0,
      result.mileage_visible ? 1 : 0,
      result.overall_condition || null,
      result.drivability || null,
      result.structural_integrity || null,
      result.total_cost_min_dzd ?? null,
      result.total_cost_max_dzd ?? null,
      result.labor_hours_total_min ?? null,
      result.labor_hours_total_max ?? null,
      result.total_loss_risk || null,
      result.recommendation || null,
      result.hidden_damage_risk || null,
      result.summary || null,
      result.assessor_notes || null,
      JSON.stringify(result.primary_concerns || []),
      assessmentId,
    ],
  );

  const reverseAngleMap = {
    front: "angle_front",
    rear: "angle_rear",
    left: "angle_left",
    right: "angle_right",
  };
  for (const angleResult of result.angles || []) {
    const isCloseup = angleResult.angle.startsWith("closeup");
    const matchType = isCloseup
      ? "closeup"
      : reverseAngleMap[angleResult.angle];

    const candidates = photos.filter((p) => p.type === matchType);
    const target = candidates.find((p) => !p._claimed) || candidates[0];
    if (target) {
      target._claimed = true; // local-only flag, prevents reusing the same row twice in this loop
      await pool.query(
        `UPDATE assessment_photos SET angle = ?, annotated_image_base64 = ? WHERE id = ?`,
        [
          angleResult.angle,
          angleResult.annotated_image_base64 || null,
          target.id,
        ],
      );
    }
  }
  await pool.query(`DELETE FROM damage_regions WHERE assessment_id = ?`, [
    assessmentId,
  ]);

  for (const d of result.all_damages || []) {
    await pool.query(
      `INSERT INTO damage_regions
        (assessment_id, angle, detail_index, car_part, damage_type, description,
         severity_score, severity_label, affected_area_pct, repair_method, repair_complexity,
         labor_hours_min, labor_hours_max, cost_min_dzd, cost_max_dzd, safety_risk, priority,
         notes, bounding_box_json, confidence, yolo_class, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
      [
        assessmentId,
        d.angle || null,
        d.index ?? null,
        d.car_part || null,
        d.damage_type || null,
        d.description || null,
        d.severity_score ?? null,
        d.severity_label || null,
        d.affected_area_pct || null,
        d.repair_method || null,
        d.repair_complexity || null,
        d.labor_hours_min ?? null,
        d.labor_hours_max ?? null,
        d.cost_min_dzd ?? null,
        d.cost_max_dzd ?? null,
        d.safety_risk ? 1 : 0,
        d.priority || null,
        d.notes || null,
        d.bounding_box ? JSON.stringify(d.bounding_box) : null,
        d.confidence ?? null,
        d.yolo_class || null,
      ],
    );
  }
}

module.exports = { runAnalysisAsync, getProgress };
