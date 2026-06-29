"""
Car Damage Detection API v3 — Multi-Angle, DZD pricing, Algeria context
Detection model: abdullahg7/cardd-yolov8s (scratch|dent|crack|paint with bounding boxes)

Endpoints:
  POST /analyze   → full JSON assessment
  POST /report    → PDF download
  GET  /health    → service status
  GET  /angles    → supported angle names
"""

import os
from contextlib import asynccontextmanager
from functools import partial
import asyncio

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from dotenv import load_dotenv

from detector import DamageDetector
from analyzer import GroqAnalyzer
from reporter import build_pdf
from schemas import MultiAngleResponse, VALID_ANGLES

load_dotenv()

@asynccontextmanager
async def lifespan(app: FastAPI):
    global detector, analyzer
    print("⏳ Loading models...")
    detector = DamageDetector()
    analyzer = GroqAnalyzer()
    print("✅ Ready — using abdullahg7/cardd-yolov8s (detection with bounding boxes)")
    yield

app = FastAPI(
    title="Car Damage Detection API",
    description="Multi-angle vehicle damage assessment — Algeria / DZD — "
                "Object detection with real bounding boxes (scratch|dent|crack|paint)",
    version="3.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

async def collect_angles(**angle_files) -> dict:
    angle_bytes = {}
    for angle, upload in angle_files.items():
        if upload is not None:
            b = await upload.read()
            if b:
                angle_bytes[angle] = b
    if not angle_bytes:
        raise HTTPException(400, "No images received. Send at least one angle.")
    return angle_bytes

def run_pipeline(angle_bytes: dict):
    classifications = detector.classify_all(angle_bytes)
    overview, angle_objects, all_damages = analyzer.analyze_all(classifications)
    return overview, angle_objects, all_damages

@app.get("/health")
async def health():
    return {
        "status":   "ok",
        "detector": detector is not None,
        "analyzer": analyzer is not None,
        "model":    "abdullahg7/cardd-yolov8s",
        "llm":      "groq/meta-llama/llama-4-scout-17b-16e-instruct",
        "classes":  ["scratch","dent","crack","paint"],
    }

@app.get("/angles")
async def angles():
    return {
        "supported":   sorted(VALID_ANGLES),
        "recommended": ["front","rear","left","right"],
        "optional":    ["closeup_1","closeup_2","closeup_3","closeup_4","closeup_5"],
    }

@app.post("/analyze", response_model=MultiAngleResponse)
async def analyze(
    front:     UploadFile | None = File(default=None),
    rear:      UploadFile | None = File(default=None),
    left:      UploadFile | None = File(default=None),
    right:     UploadFile | None = File(default=None),
    closeup_1: UploadFile | None = File(default=None),
    closeup_2: UploadFile | None = File(default=None),
    closeup_3: UploadFile | None = File(default=None),
    closeup_4: UploadFile | None = File(default=None),
    closeup_5: UploadFile | None = File(default=None),
):
    angle_bytes = await collect_angles(
        front=front, rear=rear, left=left, right=right,
        closeup_1=closeup_1, closeup_2=closeup_2, closeup_3=closeup_3,
        closeup_4=closeup_4, closeup_5=closeup_5,
    )
    print(f"📸 /analyze — {len(angle_bytes)} angle(s): {list(angle_bytes.keys())}")
    try:
        loop = asyncio.get_event_loop()
        overview, angle_objects, all_damages = await loop.run_in_executor(
            None, partial(run_pipeline, angle_bytes)
        )
        return MultiAngleResponse(angles=angle_objects, all_damages=all_damages, **overview)
    except Exception as e:
        raise HTTPException(500, f"Analysis failed: {str(e)}")

@app.post("/report")
async def report(
    front:     UploadFile | None = File(default=None),
    rear:      UploadFile | None = File(default=None),
    left:      UploadFile | None = File(default=None),
    right:     UploadFile | None = File(default=None),
    closeup_1: UploadFile | None = File(default=None),
    closeup_2: UploadFile | None = File(default=None),
    closeup_3: UploadFile | None = File(default=None),
    closeup_4: UploadFile | None = File(default=None),
    closeup_5: UploadFile | None = File(default=None),
):
    angle_bytes = await collect_angles(
        front=front, rear=rear, left=left, right=right,
        closeup_1=closeup_1, closeup_2=closeup_2, closeup_3=closeup_3,
        closeup_4=closeup_4, closeup_5=closeup_5,
    )
    print(f"📸 /report — {len(angle_bytes)} angle(s)")
    try:
        loop = asyncio.get_event_loop()
        overview, angle_objects, all_damages = await loop.run_in_executor(
            None, partial(run_pipeline, angle_bytes)
        )
        pdf_bytes = await loop.run_in_executor(
            None, partial(build_pdf, overview, angle_objects, all_damages)
        )
        job_id = overview.get("job_id", "report")
        return StreamingResponse(
            iter([pdf_bytes]),
            media_type="application/pdf",
            headers={"Content-Disposition": f'attachment; filename="damage_{job_id}.pdf"'}
        )
    except Exception as e:
        raise HTTPException(500, f"Report failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)