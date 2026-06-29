CREATE TABLE IF NOT EXISTS assessments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  plate_number VARCHAR(20) NOT NULL,
  vehicle_make_model VARCHAR(255) NULL,
  client_reference VARCHAR(255) NULL,
  notes TEXT NULL,
  status ENUM('capturing', 'analyzing', 'complete', 'failed') NOT NULL DEFAULT 'capturing',
  overall_condition VARCHAR(20) NULL,
  drivability VARCHAR(30) NULL,
  total_cost_min_dzd INT NULL,
  total_cost_max_dzd INT NULL,
  total_loss_risk VARCHAR(10) NULL,
  recommendation VARCHAR(30) NULL,
  summary TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS assessment_photos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  assessment_id INT NOT NULL,
  type ENUM('angle_front', 'angle_rear', 'angle_left', 'angle_right', 'closeup') NOT NULL,
  storage_url VARCHAR(500) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (assessment_id) REFERENCES assessments(id)
);

CREATE INDEX idx_assessments_user_id ON assessments (user_id);
CREATE INDEX idx_assessment_photos_assessment_id ON assessment_photos (assessment_id);
