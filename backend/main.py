from fastapi import FastAPI, File, UploadFile, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import cv2
import numpy as np
import base64
import tempfile
import os
import analyzer

app = FastAPI(title="RiceGrade Analyzer API")

# CORS middleware - adjust origins as needed
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB

@app.post("/analyze")
async def analyze_rice(file: UploadFile = File(...)):
    # Validate file type
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    # Read file contents
    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File size exceeds 5 MB limit")

    # Decode image
    nparr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=400, detail="Unable to decode image")

    # Save to temporary file for analyzer
    with tempfile.NamedTemporaryFile(delete=False, suffix=".png") as tmp:
        tmp.write(contents)
        tmp_path = tmp.name

    try:
        # Run analysis
        metrics, annotated_img = analyzer.analyze_grains(tmp_path)
    finally:
        # Clean up temp file
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)

    # Encode annotated image to base64 (PNG)
    _, buffer = cv2.imencode('.png', annotated_img)
    annotated_base64 = base64.b64encode(buffer).decode('utf-8')

    # Prepare response
    response = {
        "whole_count": metrics["whole_count"],
        "broken_count": metrics["broken_count"],
        "broken_percent": metrics["broken_percent"],
        "avg_length_breadth_ratio": metrics["avg_length_breadth_ratio"],
        "grade": metrics["grade"],
        "annotated_image_base64": annotated_base64
    }
    return response

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)