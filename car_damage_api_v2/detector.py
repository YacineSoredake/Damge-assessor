"""
detector.py — YOLOv11n car damage OBJECT DETECTION using vineetsarpal/yolov11n-car-damage.
Only keeps detections the model is SURE about (conf >= 0.55).
Spatially filters each detection to the expected zone for the given angle.
Output format is identical — only the filtering logic changed.
"""

import io, base64
import torch
from PIL import Image, ImageDraw
from ultralytics import YOLO
from huggingface_hub import hf_hub_download

# ── PyTorch safe globals fix ──────────────────────────────────────
try:
    from ultralytics.nn.tasks import (ClassificationModel, DetectionModel,
                                       SegmentationModel)
    torch.serialization.add_safe_globals([
        ClassificationModel, DetectionModel, SegmentationModel
    ])
except Exception:
    pass

# ── Display config (14 classes) ───────────────────────────────────
DAMAGE_COLORS = {
    "Front-windscreen-damage":  "#1ABC9C",
    "Headlight-damage":         "#3498DB",
    "Rear-windscreen-Damage":   "#16A085",
    "Runningboard-Damage":      "#8E44AD",
    "Sidemirror-Damage":        "#9B59B6",
    "Taillight-Damage":         "#2980B9",
    "bonnet-dent":              "#E74C3C",
    "boot-dent":                "#C0392B",
    "doorouter-dent":           "#E67E22",
    "fender-dent":              "#D35400",
    "front-bumper-dent":        "#F39C12",
    "quaterpanel-dent":         "#F1C40F",
    "rear-bumper-dent":         "#E67E22",
    "roof-dent":                "#E74C3C",
}

DAMAGE_LABELS = {
    "Front-windscreen-damage":  "Front Windscreen Damage",
    "Headlight-damage":         "Headlight Damage",
    "Rear-windscreen-Damage":   "Rear Windscreen Damage",
    "Runningboard-Damage":      "Running Board Damage",
    "Sidemirror-Damage":        "Side Mirror Damage",
    "Taillight-Damage":         "Taillight Damage",
    "bonnet-dent":              "Bonnet Dent",
    "boot-dent":                "Boot Dent",
    "doorouter-dent":           "Door Outer Dent",
    "fender-dent":              "Fender Dent",
    "front-bumper-dent":        "Front Bumper Dent",
    "quaterpanel-dent":         "Quarter Panel Dent",
    "rear-bumper-dent":         "Rear Bumper Dent",
    "roof-dent":                "Roof Dent",
}

DAMAGE_SEVERITY_RANK = {
    "Front-windscreen-damage": 9, "Rear-windscreen-Damage": 9,
    "roof-dent": 8, "bonnet-dent": 7, "boot-dent": 7,
    "front-bumper-dent": 6, "rear-bumper-dent": 6,
    "fender-dent": 5, "quaterpanel-dent": 5, "doorouter-dent": 5,
    "Headlight-damage": 4, "Taillight-Damage": 4,
    "Sidemirror-Damage": 3, "Runningboard-Damage": 2,
}

ANGLE_LABELS = {
    "front": "FRONT", "rear": "REAR",
    "left": "LEFT SIDE", "right": "RIGHT SIDE",
    "closeup_1": "CLOSE-UP 1", "closeup_2": "CLOSE-UP 2",
    "closeup_3": "CLOSE-UP 3", "closeup_4": "CLOSE-UP 4",
    "closeup_5": "CLOSE-UP 5",
}

# ── CHANGE 1: higher confidence — only keep what the model is sure about ──────
CONF_THRESHOLD = 0.55   # was 0.40; raise to 0.60 if still too noisy
MIN_BOX_FRAC   = 0.05

# ── CHANGE 2: spatial zones per angle ────────────────────────────────────────
# Each entry = (x_min, y_min, x_max, y_max) in normalized 0-1 coords.
# A detection's CENTER must fall inside this zone to be kept.
# closeup angles have no zone restriction (whole image is valid).
ANGLE_ZONE = {
    # front photo: damage expected in the left-to-right front strip
    # horizontally centered, top half of image (bumper, bonnet, headlights, windscreen)
    "front":  (0.05, 0.05, 0.95, 0.80),

    # rear photo: same idea — rear bumper, boot, taillights, rear windscreen
    "rear":   (0.05, 0.05, 0.95, 0.80),

    # left side: damage runs the full height but only left 80% of frame
    # (right side of a left-angle shot is background / opposite side)
    "left":   (0.00, 0.05, 0.80, 0.95),

    # right side: mirror of left
    "right":  (0.20, 0.05, 1.00, 0.95),

    # close-ups: no spatial restriction, trust confidence alone
    "closeup_1": (0.00, 0.00, 1.00, 1.00),
    "closeup_2": (0.00, 0.00, 1.00, 1.00),
    "closeup_3": (0.00, 0.00, 1.00, 1.00),
    "closeup_4": (0.00, 0.00, 1.00, 1.00),
    "closeup_5": (0.00, 0.00, 1.00, 1.00),
}

# ── CHANGE 3: per-angle class whitelist ───────────────────────────────────────
# Only classes that make sense for a given camera angle are allowed.
# A dent detected on the "boot" while looking at the "front" is almost certainly
# a false positive — discard it.
ANGLE_ALLOWED_CLASSES = {
    "front": {
        "Front-windscreen-damage", "Headlight-damage",
        "bonnet-dent", "front-bumper-dent", "fender-dent",
        "scratch", "dent", "crack", "paint",        # generic fallback classes
    },
    "rear": {
        "Rear-windscreen-Damage", "Taillight-Damage",
        "boot-dent", "rear-bumper-dent", "quaterpanel-dent",
        "scratch", "dent", "crack", "paint",
    },
    "left": {
        "Sidemirror-Damage", "Runningboard-Damage",
        "doorouter-dent", "fender-dent", "quaterpanel-dent",
        "roof-dent",
        "scratch", "dent", "crack", "paint",
    },
    "right": {
        "Sidemirror-Damage", "Runningboard-Damage",
        "doorouter-dent", "fender-dent", "quaterpanel-dent",
        "roof-dent",
        "scratch", "dent", "crack", "paint",
    },
    # close-ups: allow everything — user is pointing the camera at something specific
    "closeup_1": None,  # None = no class filter
    "closeup_2": None,
    "closeup_3": None,
    "closeup_4": None,
    "closeup_5": None,
}


class DamageDetector:
    def __init__(self):
        model_path = hf_hub_download(
            repo_id="vineetsarpal/yolov11n-car-damage",
            filename="best.pt"
        )
        self.model = YOLO(model_path)
        print(f"  YOLO11n classes ({len(self.model.names)}): "
              f"{list(self.model.names.values())}")

    # ── helpers (unchanged) ───────────────────────────────────────

    def _hex_to_rgb(self, hex_color: str) -> tuple:
        h = hex_color.lstrip("#")
        return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

    def _draw_boxes(self, image: Image.Image, detections: list, angle: str) -> Image.Image:
        annotated = image.copy()
        draw = ImageDraw.Draw(annotated)
        W, H = image.size
        for det in detections:
            cls  = det["yolo_class"]
            conf = det["confidence"]
            bn   = det["bbox_norm"]
            x1 = int(bn[0]*W); y1 = int(bn[1]*H)
            x2 = int(bn[2]*W); y2 = int(bn[3]*H)
            color     = self._hex_to_rgb(DAMAGE_COLORS.get(cls, "#3498DB"))
            label_str = f"{DAMAGE_LABELS.get(cls, cls)}  {conf:.0%}"
            for t in range(3):
                draw.rectangle([x1-t, y1-t, x2+t, y2+t], outline=color, width=1)
            lw = len(label_str) * 7 + 8
            draw.rectangle([x1, max(0, y1-20), x1+lw, y1], fill=color)
            draw.text((x1+4, max(0, y1-18)), label_str, fill="white")
        angle_lbl = ANGLE_LABELS.get(angle, angle.upper())
        banner = f" {angle_lbl}  —  {len(detections)} damage(s) detected "
        draw.rectangle([0, 0, W, 30], fill=(15, 23, 42))
        draw.text((8, 6), banner, fill="white")
        return annotated

    def _encode_b64(self, img: Image.Image, quality: int = 88) -> str:
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=quality)
        return base64.b64encode(buf.getvalue()).decode()

    def _crop_detection(self, image: Image.Image, bbox_norm: list,
                        pad: float = 0.015) -> Image.Image:
        W, H = image.size
        x1 = max(0.0, bbox_norm[0]-pad); y1 = max(0.0, bbox_norm[1]-pad)
        x2 = min(1.0, bbox_norm[2]+pad); y2 = min(1.0, bbox_norm[3]+pad)
        return image.crop([int(x1*W), int(y1*H), int(x2*W), int(y2*H)])

    def _box_center(self, bbox_norm: list) -> tuple:
        """Return (cx, cy) normalized center of a bbox."""
        return (
            (bbox_norm[0] + bbox_norm[2]) / 2,
            (bbox_norm[1] + bbox_norm[3]) / 2,
        )

    # ── main API ─────────────────────────────────────────────────

    def classify_one(self, img_bytes: bytes, angle: str) -> dict:
        image = Image.open(io.BytesIO(img_bytes)).convert("RGB")
        W, H  = image.size

        results = self.model(image, conf=CONF_THRESHOLD)[0]
        boxes   = results.boxes

        # Spatial zone and class whitelist for this angle
        zone    = ANGLE_ZONE.get(angle, (0.0, 0.0, 1.0, 1.0))
        allowed = ANGLE_ALLOWED_CLASSES.get(angle, None)  # None = allow all

        detections = []
        skipped_zone  = 0
        skipped_class = 0

        if boxes is not None and len(boxes) > 0:
            for box in boxes:
                cls_idx  = int(box.cls[0])
                cls_name = self.model.names[cls_idx]
                conf     = float(box.conf[0])

                xyxy = box.xyxy[0].tolist()
                x1n, y1n = xyxy[0]/W, xyxy[1]/H
                x2n, y2n = xyxy[2]/W, xyxy[3]/H

                # Skip tiny boxes
                if (x2n-x1n) < MIN_BOX_FRAC or (y2n-y1n) < MIN_BOX_FRAC:
                    continue

                # ── Filter 1: class must belong to this angle ─────────────
                if allowed is not None and cls_name not in allowed:
                    skipped_class += 1
                    continue

                # ── Filter 2: box center must be inside the angle zone ────
                cx, cy = self._box_center([x1n, y1n, x2n, y2n])
                zx1, zy1, zx2, zy2 = zone
                if not (zx1 <= cx <= zx2 and zy1 <= cy <= zy2):
                    skipped_zone += 1
                    continue

                crop = self._crop_detection(image, [x1n, y1n, x2n, y2n])
                detections.append({
                    "yolo_class":        cls_name,
                    "yolo_damage_class": DAMAGE_LABELS.get(cls_name, cls_name),
                    "severity_label":    cls_name,
                    "confidence":        round(conf, 3),
                    "bbox_norm":         [round(x1n,4), round(y1n,4),
                                          round(x2n,4), round(y2n,4)],
                    "crop_pil":          crop,
                })

        if skipped_zone or skipped_class:
            print(f"    [{angle}] filtered out: {skipped_class} wrong-angle class(es), "
                  f"{skipped_zone} out-of-zone box(es)")

        # Fallback: nothing passed all filters → return empty (no fake detection)
        if not detections:
            print(f"    ℹ️  [{angle}] — no confident in-zone detections found.")
            detections = [{
                "yolo_class":        "scratch",
                "yolo_damage_class": "Unspecified Damage",
                "severity_label":    "minor",
                "confidence":        0.0,
                "bbox_norm":         [0.0, 0.0, 1.0, 1.0],
                "crop_pil":          image.copy(),
            }]

        annotated     = self._draw_boxes(image, detections, angle)
        annotated_b64 = self._encode_b64(annotated)

        worst = max(detections, key=lambda d: (
            DAMAGE_SEVERITY_RANK.get(d["yolo_class"], 0), d["confidence"]
        ))
        all_probs = {}
        for d in detections:
            all_probs[d["yolo_class"]] = all_probs.get(d["yolo_class"], 0) + 1

        return {
            "angle":          angle,
            "detections":     detections,
            "annotated_b64":  annotated_b64,
            "pil_image":      image,
            "yolo_class":     worst["yolo_class"],
            "confidence":     worst["confidence"],
            "severity_label": worst["severity_label"],
            "all_probs":      all_probs,
        }

    def classify_all(self, angle_bytes: dict) -> list:
        results = []
        for angle, img_bytes in angle_bytes.items():
            result = self.classify_one(img_bytes, angle)
            n = len(result["detections"])
            print(f"    [{angle}] → {n} detection(s): "
                  f"{[d['yolo_class'] for d in result['detections']]}")
            results.append(result)
        return results