FROM python:3.10-slim

WORKDIR /app

# Copy backend contents to /app so "main:app" resolves
COPY backend/ .

RUN pip install --no-cache-dir -r requirements.txt

# Hugging Face Spaces default port
EXPOSE 7860

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]
