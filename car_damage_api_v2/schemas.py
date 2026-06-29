"""
schemas.py — Multi-angle car damage assessment models (DZD currency).
"""

from pydantic import BaseModel
from typing import Optional

VALID_ANGLES = {"front","rear","left","right",
                "closeup_1","closeup_2","closeup_3","closeup_4","closeup_5"}

class DamageDetail(BaseModel):
    index:             int
    angle:             str
    car_part:          str
    damage_type:       str
    description:       str
    severity_score:    int
    severity_label:    str
    affected_area_pct: str
    repair_method:     str
    repair_complexity: str
    labor_hours_min:   float
    labor_hours_max:   float
    cost_min_dzd:      float        # Algerian Dinar
    cost_max_dzd:      float
    safety_risk:       bool
    priority:          str
    notes:             str
    bounding_box:      list[float]  # [x1, y1, x2, y2] normalized 0-1; empty [] if unavailable
    confidence:        float
    yolo_class:        str          # scratch | dent | crack | paint (from detection model)
    yolo_damage_class: str          # human-readable damage category label

class AngleResult(BaseModel):
    angle:                  str
    annotated_image_base64: str     # full image with all boxes drawn
    damage_count:           int
    damages:                list[DamageDetail]
    angle_condition:        str
    angle_notes:            str
    yolo_severity:          str     # worst YOLO class found in this angle
    yolo_confidence:        float   # highest confidence detection
    all_probs:              dict    # {damage_class: count} tally for this angle

class MultiAngleResponse(BaseModel):
    job_id:                 str
    vehicle:                str
    vin_visible:            bool
    mileage_visible:        bool
    overall_condition:      str
    drivability:            str
    structural_integrity:   str
    total_damage_areas:     int
    primary_concerns:       list[str]
    total_cost_min_dzd:     float
    total_cost_max_dzd:     float
    labor_hours_total_min:  float
    labor_hours_total_max:  float
    total_loss_risk:        str
    recommendation:         str
    hidden_damage_risk:     str
    summary:                str
    assessor_notes:         str
    angles:                 list[AngleResult]
    all_damages:            list[DamageDetail]