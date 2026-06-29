// routes/assessmentRoutes.js

const express = require("express");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const router = express.Router();

const { requireAuth } = require("../middleware/requireAuth");
const {
  createAssessment,
  uploadPhoto,
  analyzeAssessment,
  getAssessmentStatus,
  getAssessment,
  listAssessments
} = require("../controllers/assessmentController");
const { generateReport } = require("../controllers/reportController");
// ...


// Local disk storage — TODO: swap for S3-compatible/MinIO storage before
// real photo volume arrives (see note in assessmentController.js).
const uploadsDir = path.join(__dirname, "..", "uploads");
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || ".jpg";
    cb(null, `${req.params.id}_${Date.now()}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB per photo, adjust if needed
});

router.post("/", requireAuth, createAssessment);
router.get("/", requireAuth, listAssessments);
router.post("/:id/report", requireAuth, generateReport);
router.post("/:id/photos", requireAuth, upload.single("photo"), uploadPhoto);
router.post("/:id/analyze", requireAuth, analyzeAssessment);
router.get("/:id/status", requireAuth, getAssessmentStatus);
router.get("/:id", requireAuth, getAssessment);

module.exports = router;
