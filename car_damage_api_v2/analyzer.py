"""
analyzer.py — Groq vision analysis per crop, Algeria context, DZD pricing.

Uses Groq's OpenAI-compatible API with a vision-capable model
(meta-llama/llama-4-scout-17b-16e-instruct) for image understanding.
Structured output is achieved by prompting for JSON and parsing the response.

Three layers:
  1. Per-detection crop analysis (cropped box image → part, type, cost DZD)
  2. Per-angle overview (condition, notes) — uses full annotated image
  3. Holistic assessment (all angles together, text-only — no image)
"""

import os
import json
import uuid
import time
import base64
import io as _io
from PIL import Image
from groq import Groq
from schemas import DamageDetail, AngleResult

# ── Model config ──────────────────────────────────────────────────
# Best Groq vision model as of mid-2025; swap if you have access to a newer one
VISION_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"
TEXT_MODEL   = "llama-3.3-70b-versatile"   # holistic: no image, just big text context
MAX_TOKENS   = 2048

# ── Prompts ───────────────────────────────────────────────────────
REGION_PROMPT = """\
You are a senior automotive insurance damage assessor working in Algeria.
Analyze this CROPPED car damage image. The crop was detected by a YOLO model as: {yolo_damage_class} ({yolo_class}).
Cost estimates must reflect realistic Algerian repair market pricing (expressed in DZD).
Consider local costs for bodywork, painting, and part sourcing in Algeria (Algiers, Oran, Constantine markets).

Respond ONLY with a valid JSON object — no markdown, no preamble — matching this exact schema:
{{
  "car_part":          "<exact part name e.g. front left door, hood, rear bumper>",
  "damage_type":       "<scratch|dent|crack|rust|paint_damage|structural|glass|missing_part>",
  "description":       "<clear technical description for an insurance report>",
  "severity_score":    <integer 1-10>,
  "severity_label":    "<minor|moderate|severe|critical>",
  "affected_area_pct": "<estimated % of part surface affected e.g. 15%>",
  "repair_method":     "<paint touch-up|PDR|panel replacement|glass replacement|etc.>",
  "repair_complexity": "<simple|moderate|complex|replacement_required>",
  "labor_hours_min":   <number>,
  "labor_hours_max":   <number>,
  "cost_min_dzd":      <number>,
  "cost_max_dzd":      <number>,
  "safety_risk":       <true|false>,
  "priority":          "<urgent|high|medium|low>",
  "notes":             "<additional notes>"
}}"""

ANGLE_PROMPT = """\
You are a senior automotive insurance damage assessor working in Algeria.
Review the overall structural and aesthetic condition of this vehicle angle.
The annotated image shows all detected damage regions with bounding boxes.
Detected damages on this angle: {damage_summary}

Respond ONLY with a valid JSON object — no markdown, no preamble:
{{
  "angle_condition": "<excellent|good|fair|poor|wrecked>",
  "angle_notes":     "<technical summary observations for an insurance dossier>"
}}"""

HOLISTIC_PROMPT = """\
You are the Chief Claims Adjuster reviewing a compiled multi-angle vehicle survey in Algeria.
Review all gathered angle metrics, aggregate total parts damaged, cross-reference overlaps
(to prevent double-billing same-side structural damage), and calculate total repair parameters.
Provide a final recommendation (repair vs total loss) in the Algerian automobile market context.

Vehicle damage data:
{payload}

Respond ONLY with a valid JSON object — no markdown, no preamble:
{{
  "vehicle":                "<make/model/color if identifiable, else 'Unknown Vehicle'>",
  "vin_visible":            <true|false>,
  "mileage_visible":        <true|false>,
  "overall_condition":      "<excellent|good|fair|poor|wrecked>",
  "drivability":            "<fully drivable|conditional|not drivable>",
  "structural_integrity":   "<intact|compromised|severely compromised>",
  "primary_concerns":       ["<concern 1>", "<concern 2>"],
  "total_cost_min_dzd":     <number>,
  "total_cost_max_dzd":     <number>,
  "labor_hours_total_min":  <number>,
  "labor_hours_total_max":  <number>,
  "total_loss_risk":        "<low|medium|high>",
  "recommendation":         "<repair|total loss|further inspection required>",
  "hidden_damage_risk":     "<low|medium|high>",
  "summary":                "<executive summary paragraph>",
  "assessor_notes":         "<notes for the file>"
}}"""


def _pil_to_b64_url(img: Image.Image, max_size: int = 768) -> str:
    """Resize PIL image and encode as a base64 data URL for Groq vision."""
    img = img.copy()
    img.thumbnail((max_size, max_size))
    buf = _io.BytesIO()
    img.save(buf, format="JPEG", quality=85)
    b64 = base64.b64encode(buf.getvalue()).decode()
    return f"data:image/jpeg;base64,{b64}"


def _safe_parse(text: str) -> dict:
    """Strip markdown fences and parse JSON robustly."""
    text = text.strip()
    # Remove ```json ... ``` or ``` ... ``` wrappers
    if text.startswith("```"):
        lines = text.splitlines()
        # drop first and last fence lines
        text = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])
    # Find the first { and last } to be safe
    start = text.find("{")
    end   = text.rfind("}")
    if start != -1 and end != -1:
        text = text[start:end+1]
    return json.loads(text)


class GroqAnalyzer:
    def __init__(self):
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            raise RuntimeError("GROQ_API_KEY not set in .env")
        self.client = Groq(api_key=api_key)

    def new_id(self) -> str:
        return str(uuid.uuid4())[:8]

    # ── Core call helpers ─────────────────────────────────────────

    def _call_vision(self, prompt: str, images: list[Image.Image]) -> dict:
        """
        Send a vision request to Groq.
        Builds a user message with alternating image_url + text content blocks.
        Retries on rate-limit (429).
        """
        content = []
        for img in images:
            content.append({
                "type": "image_url",
                "image_url": {"url": _pil_to_b64_url(img)},
            })
        content.append({"type": "text", "text": prompt})

        max_retries     = 3
        backoff_seconds = 30

        for attempt in range(max_retries):
            try:
                resp = self.client.chat.completions.create(
                    model=VISION_MODEL,
                    messages=[{"role": "user", "content": content}],
                    max_tokens=MAX_TOKENS,
                    temperature=0.2,
                )
                raw = resp.choices[0].message.content
                return _safe_parse(raw)
            except Exception as e:
                err = str(e)
                if "429" in err or "rate" in err.lower():
                    if attempt < max_retries - 1:
                        print(f"⚠️  Groq rate limit — sleeping {backoff_seconds}s "
                              f"(attempt {attempt+1}/{max_retries})...")
                        time.sleep(backoff_seconds)
                        continue
                raise

    def _call_text(self, prompt: str) -> dict:
        """
        Text-only call for holistic synthesis (no images — large context).
        Uses a bigger text model for best reasoning quality.
        """
        max_retries     = 3
        backoff_seconds = 30

        for attempt in range(max_retries):
            try:
                resp = self.client.chat.completions.create(
                    model=TEXT_MODEL,
                    messages=[{"role": "user", "content": prompt}],
                    max_tokens=MAX_TOKENS,
                    temperature=0.2,
                )
                raw = resp.choices[0].message.content
                return _safe_parse(raw)
            except Exception as e:
                err = str(e)
                if "429" in err or "rate" in err.lower():
                    if attempt < max_retries - 1:
                        print(f"⚠️  Groq rate limit — sleeping {backoff_seconds}s "
                              f"(attempt {attempt+1}/{max_retries})...")
                        time.sleep(backoff_seconds)
                        continue
                raise

    # ── Layer 1: per-detection crop ───────────────────────────────

    def analyze_region(self, detection: dict, angle: str, global_index: int) -> DamageDetail:
        """Analyze one YOLO-detected crop with Groq vision."""
        prompt = REGION_PROMPT.format(
            yolo_damage_class=detection["yolo_damage_class"],
            yolo_class=detection["yolo_class"],
        )
        try:
            data = self._call_vision(prompt, [detection["crop_pil"]])

            data["index"]             = global_index
            data["angle"]             = angle
            data["confidence"]        = detection["confidence"]
            data["yolo_class"]        = detection["yolo_class"]
            data["yolo_damage_class"] = detection["yolo_damage_class"]
            data["bounding_box"]      = detection["bbox_norm"]

            return DamageDetail(**data)

        except Exception as e:
            print(f"  ⚠️  Region {global_index} ({angle}) Groq failed: {e}")
            return DamageDetail(
                index=global_index,
                angle=angle,
                car_part="unknown",
                damage_type=detection["yolo_class"],
                description=f"Analysis failed: {str(e)}",
                severity_score=5,
                severity_label=detection["severity_label"],
                affected_area_pct="unknown",
                repair_method="inspect",
                repair_complexity="moderate",
                labor_hours_min=1.0,
                labor_hours_max=3.0,
                cost_min_dzd=5000.0,
                cost_max_dzd=15000.0,
                safety_risk=False,
                priority="medium",
                notes="Fallback record — manual review required.",
                bounding_box=detection["bbox_norm"],
                confidence=detection["confidence"],
                yolo_class=detection["yolo_class"],
                yolo_damage_class=detection["yolo_damage_class"],
            )

    # ── Layer 2: per-angle overview ───────────────────────────────

    def analyze_angle(self, classification: dict, damages: list[DamageDetail]) -> AngleResult:
        """Summarize the overall condition of one angle using the annotated full image."""
        damage_summary = "; ".join(
            f"{d.car_part} ({d.damage_type}, severity {d.severity_score}/10)"
            for d in damages
        ) or "no detections"

        prompt = ANGLE_PROMPT.format(damage_summary=damage_summary)

        # Build all_probs tally
        all_probs = {}
        for det in classification["detections"]:
            k = det["yolo_class"]
            all_probs[k] = all_probs.get(k, 0) + 1

        # Worst detection by severity
        from detector import DAMAGE_SEVERITY_RANK
        worst_det = max(
            classification["detections"],
            key=lambda d: (DAMAGE_SEVERITY_RANK.get(d["yolo_class"], 0), d["confidence"])
        )

        try:
            # Decode annotated image (b64 → PIL)
            ann_img = Image.open(
                _io.BytesIO(base64.b64decode(classification["annotated_b64"]))
            ).convert("RGB")

            data = self._call_vision(prompt, [ann_img])

            return AngleResult(
                angle=classification["angle"],
                annotated_image_base64=classification["annotated_b64"],
                damage_count=len(damages),
                damages=damages,
                angle_condition=data["angle_condition"],
                angle_notes=data["angle_notes"],
                yolo_severity=worst_det["yolo_class"],
                yolo_confidence=worst_det["confidence"],
                all_probs=all_probs,
            )
        except Exception as e:
            print(f"  ⚠️  Angle synthesis failed for {classification['angle']}: {e}")
            return AngleResult(
                angle=classification["angle"],
                annotated_image_base64=classification["annotated_b64"],
                damage_count=len(damages),
                damages=damages,
                angle_condition="fair",
                angle_notes="Angle evaluation could not be completed.",
                yolo_severity=worst_det["yolo_class"],
                yolo_confidence=worst_det["confidence"],
                all_probs=all_probs,
            )

    # ── Layer 3: holistic (text only) ─────────────────────────────

    def analyze_holistic(self, classifications: list, all_damages: list[DamageDetail]) -> dict:
        """
        Global synthesis across all angles.
        Groq vision models cap at 5 images per request, and holistic context
        is already rich from the serialized damage log — so we use the text model here.
        """
        serialized = [d.model_dump() for d in all_damages]
        payload_str = json.dumps({
            "total_angles":         len(classifications),
            "total_detections":     len(all_damages),
            "detected_damages_log": serialized,
        }, indent=2)

        prompt = HOLISTIC_PROMPT.format(payload=payload_str)

        try:
            overview = self._call_text(prompt)
            overview["job_id"]             = self.new_id()
            overview["total_damage_areas"] = len(all_damages)
            return overview
        except Exception as e:
            print(f"  ⚠️  Holistic analysis failed: {e}")
            tmin = sum(d.cost_min_dzd for d in all_damages)
            tmax = sum(d.cost_max_dzd for d in all_damages)
            return {
                "job_id":                 self.new_id(),
                "vehicle":                "Detected Vehicle",
                "vin_visible":            False,
                "mileage_visible":        False,
                "overall_condition":      "fair",
                "drivability":            "conditional",
                "structural_integrity":   "unknown",
                "total_damage_areas":     len(all_damages),
                "primary_concerns":       ["Manual structural verification required"],
                "total_cost_min_dzd":     float(tmin),
                "total_cost_max_dzd":     float(tmax),
                "labor_hours_total_min":  float(sum(d.labor_hours_min for d in all_damages)),
                "labor_hours_total_max":  float(sum(d.labor_hours_max for d in all_damages)),
                "total_loss_risk":        "medium",
                "recommendation":         "repair",
                "hidden_damage_risk":     "medium",
                "summary":                "Automated holistic processing failed. Review individual entries.",
                "assessor_notes":         "Verify aggregate costs manually.",
            }

    # ── Full pipeline ─────────────────────────────────────────────

    def analyze_all(self, classifications: list) -> tuple:
        """
        Full pipeline: detections → per-crop Groq vision → per-angle → holistic.
        classifications: output of detector.classify_all()
        Returns: (holistic_overview, angle_result_objects, all_damages)
        """
        all_damages   = []
        angle_objects = []
        global_index  = 1

        for cls in classifications:
            n = len(cls["detections"])
            print(f"  Angle [{cls['angle']}]: {n} detection(s) → Groq per crop...")
            angle_damages = []

            for det in cls["detections"]:
                print(f"    → crop {global_index}: {det['yolo_damage_class']} "
                      f"({det['confidence']:.0%}) bbox={det['bbox_norm']}")
                damage = self.analyze_region(det, cls["angle"], global_index)
                angle_damages.append(damage)
                all_damages.append(damage)
                global_index += 1

            angle_obj = self.analyze_angle(cls, angle_damages)
            angle_objects.append(angle_obj)

        print(f"  Running holistic analysis across {len(classifications)} angle(s), "
              f"{len(all_damages)} detection(s)...")
        overview = self.analyze_holistic(classifications, all_damages)

        return overview, angle_objects, all_damages