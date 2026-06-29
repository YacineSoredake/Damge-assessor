-- Extends the assessments/damage_regions tables to match the real
-- FastAPI service's MultiAngleResponse / DamageDetail / AngleResult shape.
-- Run after 2026_06_24_create_assessments_tables.sql and
-- 2026_06_25_create_damage_regions_table.sql.
ALTER TABLE assessments
ADD COLUMN job_id VARCHAR(20) NULL,
ADD COLUMN vehicle VARCHAR(255) NULL,
ADD COLUMN vin_visible TINYINT (1) NULL,
ADD COLUMN mileage_visible TINYINT (1) NULL,
ADD COLUMN structural_integrity VARCHAR(30) NULL,
ADD COLUMN hidden_damage_risk VARCHAR(10) NULL,
ADD COLUMN assessor_notes TEXT NULL,
ADD COLUMN labor_hours_total_min DECIMAL(6, 1) NULL,
ADD COLUMN labor_hours_total_max DECIMAL(6, 1) NULL,
ADD COLUMN primary_concerns_json TEXT NULL;

-- JSON array, stored as text (no native JSON ops needed yet)
ALTER TABLE damage_regions
ADD COLUMN angle VARCHAR(20) NULL,
ADD COLUMN detail_index INT NULL, -- the API's "index" field (1-based across all angles)
ADD COLUMN description TEXT NULL,
ADD COLUMN affected_area_pct VARCHAR(10) NULL,
ADD COLUMN repair_complexity VARCHAR(30) NULL,
ADD COLUMN labor_hours_min DECIMAL(5, 1) NULL,
ADD COLUMN labor_hours_max DECIMAL(5, 1) NULL,
ADD COLUMN priority VARCHAR(10) NULL,
ADD COLUMN bounding_box_json VARCHAR(100) NULL, -- "[x1,y1,x2,y2]" normalized 0-1, stored as text
ADD COLUMN yolo_class VARCHAR(50) NULL;

ALTER TABLE assessment_photos
ADD COLUMN angle VARCHAR(20) NULL, -- front|rear|left|right|closeup_1..5 (FastAPI's naming)
ADD COLUMN annotated_image_base64 MEDIUMTEXT NULL;

-- full image with YOLO boxes drawn, returned per angle
ALTER TABLE assessments
ADD COLUMN report_pdf_path VARCHAR(255) NULL;