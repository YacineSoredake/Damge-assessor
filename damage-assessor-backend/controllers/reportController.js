// controllers/reportController.js
//
// Re-sends the same photos already on disk to the FastAPI service's
// /report endpoint, which returns a ready-made PDF. We save it once
// and reuse it on subsequent requests — per the FastAPI docs' own
// known limitation #6, re-calling /report re-runs the full pipeline
// and re-pays the Groq cost, so we avoid doing that twice.

const fs = require("fs");
const path = require("path");
const axios = require("axios");
const FormData = require("form-data");

const assessmentModel = require("../models/assessmentModel");
const pool = require("../config/db");

const FASTAPI_BASE_URL = process.env.FASTAPI_BASE_URL || "http://localhost:8000";
const ANGLE_FIELD_MAP = {
  angle_front: "front",
  angle_rear: "rear",
  angle_left: "left",
  angle_right: "right",
};
const MAX_CLOSEUPS = 5;

const reportsDir = path.join(__dirname, "..", "uploads", "reports");
if (!fs.existsSync(reportsDir)) {
  fs.mkdirSync(reportsDir, { recursive: true });
}

function buildFormData(photos) {
  const formData = new FormData();
  let closeupIndex = 1;
  for (const photo of photos) {
    const absolutePath = path.join(
      __dirname,
      "..",
      photo.storage_url.replace(/^\/uploads\//, "uploads/")
    );
    if (!fs.existsSync(absolutePath)) continue;

    if (photo.type === "closeup") {
      if (closeupIndex > MAX_CLOSEUPS) continue;
      formData.append(`closeup_${closeupIndex}`, fs.createReadStream(absolutePath));
      closeupIndex++;
    } else {
      const fieldName = ANGLE_FIELD_MAP[photo.type];
      if (fieldName) formData.append(fieldName, fs.createReadStream(absolutePath));
    }
  }
  return formData;
}

/**
 * POST /assessments/:id/report
 * Generates (or returns the already-generated) PDF for this assessment.
 */
async function generateReport(req, res) {
  try {
    const assessment = await assessmentModel.findByIdForUser(req.params.id, req.userId);
    if (!assessment) {
      return res.status(404).json({ error: "Assessment not found." });
    }
    if (assessment.status !== "complete") {
      return res.status(400).json({ error: "Analysis must complete before generating a report." });
    }

    // Reuse the existing PDF if we already generated one — avoids
    // re-paying the full Groq pipeline cost on every "Generate report" tap.
    if (assessment.report_pdf_path && fs.existsSync(path.join(__dirname, "..", assessment.report_pdf_path))) {
      return res.status(200).json({ pdf_url: `/${assessment.report_pdf_path}` });
    }

    const photos = await assessmentModel.getPhotos(assessment.id);
    const formData = buildFormData(photos);

    const response = await axios.post(`${FASTAPI_BASE_URL}/report`, formData, {
      headers: formData.getHeaders(),
      responseType: "arraybuffer",
      timeout: 90_000,
      maxContentLength: Infinity,
      maxBodyLength: Infinity,
    });

    const filename = `damage_${assessment.job_id || assessment.id}.pdf`;
    const filePath = path.join(reportsDir, filename);
    fs.writeFileSync(filePath, response.data);

    const relativePath = `uploads/reports/${filename}`;
    await pool.query(`UPDATE assessments SET report_pdf_path = ? WHERE id = ?`, [
      relativePath,
      assessment.id,
    ]);

    return res.status(200).json({ pdf_url: `/${relativePath}` });
  } catch (err) {
    console.error("generateReport error:", err.response?.data || err.message);
    return res.status(500).json({ error: "Could not generate report. Please try again." });
  }
}

module.exports = { generateReport };