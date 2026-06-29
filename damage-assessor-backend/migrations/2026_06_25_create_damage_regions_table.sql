CREATE TABLE IF NOT EXISTS damage_regions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  assessment_id INT NOT NULL,
  photo_id INT NULL,
  car_part VARCHAR(100) NULL,
  damage_type VARCHAR(50) NULL,
  severity_score INT NULL,
  severity_label VARCHAR(20) NULL,
  cost_min_dzd INT NULL,
  cost_max_dzd INT NULL,
  repair_method VARCHAR(100) NULL,
  safety_risk TINYINT(1) NULL,
  confidence DECIMAL(4,3) NULL,
  notes TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (assessment_id) REFERENCES assessments(id),
  FOREIGN KEY (photo_id) REFERENCES assessment_photos(id)
);

CREATE INDEX idx_damage_regions_assessment_id ON damage_regions (assessment_id);
