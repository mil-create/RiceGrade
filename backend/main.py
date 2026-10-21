import base64
import os
import tempfile

import cv2
import numpy as np
import uvicorn
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

import analyzer

app = FastAPI(title="RiceGrade Analyzer API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB
# Some clients (e.g. Dart's Dio) send images as application/octet-stream.
# Real validation happens when decoding the bytes below.
ALLOWED_TYPES_PREFIX = ("image/", "application/octet-stream")


@app.get("/")
def health():
    return {"status": "ok"}


@app.post("/analyze")
async def analyze_rice(file: UploadFile = File(...)):
    if not file.content_type or not file.content_type.startswith(ALLOWED_TYPES_PREFIX):
        raise HTTPException(status_code=400, detail="File must be an image")

    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File size exceeds 5 MB limit")

    img = cv2.imdecode(np.frombuffer(contents, np.uint8), cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=400, detail="Unable to decode image")

    with tempfile.NamedTemporaryFile(delete=False, suffix=".png") as tmp:
        tmp.write(contents)
        tmp_path = tmp.name
    try:
        metrics, annotated_img = analyzer.analyze_grains(tmp_path)
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)

    _, buffer = cv2.imencode(".png", annotated_img)
    return {
        "whole_count": metrics["whole_count"],
        "broken_count": metrics["broken_count"],
        "broken_percent": metrics["broken_percent"],
        "avg_length_breadth_ratio": metrics["avg_length_breadth_ratio"],
        "grade": metrics["grade"],
        "annotated_image_base64": base64.b64encode(buffer).decode("utf-8"),
    }


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
