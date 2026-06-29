// models/damageRegionModel.js

const pool = require("../config/db");

async function getByAssessmentId(assessmentId) {
  const [rows] = await pool.query(
    `SELECT id, photo_id, angle, detail_index, car_part, damage_type, description,
            severity_score, severity_label, affected_area_pct, repair_method, repair_complexity,
            labor_hours_min, labor_hours_max, cost_min_dzd, cost_max_dzd, safety_risk, priority,
            confidence, yolo_class, bounding_box_json, notes, created_at
     FROM damage_regions
     WHERE assessment_id = ?
     ORDER BY detail_index ASC`,
    [assessmentId]
  );
  return rows;
}

module.exports = { getByAssessmentId };
