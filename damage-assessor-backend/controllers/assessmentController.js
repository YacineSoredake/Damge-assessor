// controllers/assessmentController.js

const path = require("path");
const fs = require("fs");
const pool = require("../config/db");
const assessmentModel = require("../models/assessmentModel");
const damageRegionModel = require("../models/damageRegionModel");
const userModel = require("../models/userModel");
const analysisService = require("../services/analysisService");

const VALID_PHOTO_TYPES = ["angle_front", "angle_rear", "angle_left", "angle_right", "closeup"];
const REQUIRED_ANGLE_TYPES = ["angle_front", "angle_rear", "angle_left", "angle_right"];

/**
 * POST /assessments
 * body: { plate_number, vehicle_make_model?, client_reference?, notes? }
 *
 * IMPORTANT: re-checks trial/subscription server-side, even though the
 * Flutter dashboard already checked /me before navigating here. Per the
 * spec, the client-side check is just UX (avoid a wasted trip to the
 * camera screen) — this server check is the real enforcement, since a
 * client check alone could be bypassed by anyone calling the API directly.
 */
async function createAssessment(req, res) {
  const { plate_number, vehicle_make_model, client_reference, notes } = req.body;

  if (!plate_number || !plate_number.trim()) {
    return res.status(400).json({ error: "plate_number is required." });
  }

  try {
    const user = await userModel.findById(req.userId);
    if (!user) {
      return res.status(404).json({ error: "User not found." });
    }

    const canProceed =
      !user.free_report_used ||
      user.subscription_status === "active" ||
      user.subscription_status === "grace";

    if (!canProceed) {
      return res.status(403).json({ error: "Subscription required to start a new assessment." });
    }

    const assessment = await assessmentModel.create({
      userId: req.userId,
      plateNumber: plate_number.trim(),
      vehicleMakeModel: vehicle_make_model,
      clientReference: client_reference,
      notes,
    });

    return res.status(201).json({ assessment_id: assessment.id });
  } catch (err) {
    console.error("createAssessment error:", err);
    return res.status(500).json({ error: "Something went wrong. Please try again." });
  }
}

/**
 * POST /assessments/:id/photos
 * multipart/form-data: photo (file), type (one of VALID_PHOTO_TYPES)
 *
 * Storage decision: currently writes to local disk under /uploads.
 * Per the spec this is a placeholder — object storage (S3-compatible /
 * MinIO) should replace this before real photo volume arrives, since
 * local disk doesn't scale and complicates backups/server migration.
 */
async function uploadPhoto(req, res) {
  const assessmentId = req.params.id;
  const { type } = req.body;

  if (!VALID_PHOTO_TYPES.includes(type)) {
    return res.status(400).json({ error: `type must be one of: ${VALID_PHOTO_TYPES.join(", ")}` });
  }
  if (!req.file) {
    return res.status(400).json({ error: "photo file is required." });
  }

  try {
    const assessment = await assessmentModel.findByIdForUser(assessmentId, req.userId);
    if (!assessment) {
      // Don't leak whether the assessment exists for another user —
      // just a flat 404 either way.
      return res.status(404).json({ error: "Assessment not found." });
    }

    // req.file.path is set by multer's disk storage (see routes/assessmentRoutes.js)
    const storageUrl = `/uploads/${path.basename(req.file.path)}`;

    const photo = await assessmentModel.addPhoto({
      assessmentId,
      type,
      storageUrl,
    });

    return res.status(201).json({ photo_id: photo.id, storage_url: storageUrl });
  } catch (err) {
    console.error("uploadPhoto error:", err);
    return res.status(500).json({ error: "Could not upload photo. Please try again." });
  }
}

/**
 * POST /assessments/:id/analyze
 * Kicks off YOLO + Gemini analysis WITHOUT blocking the response —
 * per the spec's decision to use polling, not websockets, for v1.
 * Returns 202 immediately; the app then polls GET /assessments/:id/status.
 */
async function analyzeAssessment(req, res) {
  try {
    const assessment = await assessmentModel.findByIdForUser(req.params.id, req.userId);
    if (!assessment) {
      return res.status(404).json({ error: "Assessment not found." });
    }

    const photos = await assessmentModel.getPhotos(assessment.id);
    const photoTypes = photos.map((p) => p.type);
    const missingAngles = REQUIRED_ANGLE_TYPES.filter((t) => !photoTypes.includes(t));
    if (missingAngles.length > 0) {
      return res.status(400).json({
        error: `Missing required photos: ${missingAngles.join(", ")}`,
      });
    }

    await pool.query(`UPDATE assessments SET status = 'analyzing' WHERE id = ?`, [assessment.id]);

    // Deliberately not awaited — fire-and-forget background job.
    // Errors inside it are caught and recorded via analysisService's
    // own try/catch (sets status to 'failed'), so this won't crash
    // the request or leave an unhandled promise rejection.
    analysisService.runAnalysisAsync(assessment.id);

    return res.status(202).json({ status: "analyzing" });
  } catch (err) {
    console.error("analyzeAssessment error:", err);
    return res.status(500).json({ error: "Could not start analysis." });
  }
}

/**
 * GET /assessments/:id/status
 * Polled every ~2s by the Flutter app while on the "Analyzing" screen.
 */
async function getAssessmentStatus(req, res) {
  try {
    const assessment = await assessmentModel.findByIdForUser(req.params.id, req.userId);
    if (!assessment) {
      return res.status(404).json({ error: "Assessment not found." });
    }
    return res.status(200).json({
      status: assessment.status,
      progress_step: analysisService.getProgress(assessment.id),
    });
  } catch (err) {
    console.error("getAssessmentStatus error:", err);
    return res.status(500).json({ error: "Something went wrong." });
  }
}

/**
 * GET /assessments?search=plate&page=1&limit=20
 * Paginated history list for the logged-in user, optionally filtered
 * by plate number (partial match).
 */
async function listAssessments(req, res) {
  const page = Math.max(parseInt(req.query.page) || 1, 1);
  const limit = Math.min(parseInt(req.query.limit) || 20, 50);
  const offset = (page - 1) * limit;
  const search = (req.query.search || "").trim();

  try {
    const rows = await assessmentModel.listForUser(req.userId, { search, limit, offset });
    const total = await assessmentModel.countForUser(req.userId);
    return res.status(200).json({ assessments: rows, page, limit, total });
  } catch (err) {
    console.error("listAssessments error:", err);
    return res.status(500).json({ error: "Something went wrong." });
  }
}

/**
 * GET /assessments/:id
 * Returns the assessment + photos + damage regions (once analysis
 * has completed — empty array otherwise).
 */
async function getAssessment(req, res) {
  try {
    const assessment = await assessmentModel.findByIdForUser(req.params.id, req.userId);
    if (!assessment) {
      return res.status(404).json({ error: "Assessment not found." });
    }
    const photos = await assessmentModel.getPhotos(assessment.id);
    const damageRegions = await damageRegionModel.getByAssessmentId(assessment.id);

    let primaryConcerns = [];
    try {
      primaryConcerns = assessment.primary_concerns_json
        ? JSON.parse(assessment.primary_concerns_json)
        : [];
    } catch {
      primaryConcerns = [];
    }

    return res.status(200).json({
      ...assessment,
      vin_visible: !!assessment.vin_visible,
      mileage_visible: !!assessment.mileage_visible,
      primary_concerns: primaryConcerns,
      photos,
      damage_regions: damageRegions.map((d) => ({
        ...d,
        safety_risk: !!d.safety_risk,
        bounding_box: d.bounding_box_json ? JSON.parse(d.bounding_box_json) : null,
      })),
    });
  } catch (err) {
    console.error("getAssessment error:", err);
    return res.status(500).json({ error: "Something went wrong." });
  }
}

module.exports = { listAssessments, createAssessment, uploadPhoto, analyzeAssessment, getAssessmentStatus, getAssessment };
