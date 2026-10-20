# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Copy the backend directory
COPY backend/ ./backend/

# Install dependencies
RUN pip install --no-cache-dir -r backend/requirements.txt

# Expose port 7860 (Hugging Face Spaces default port)
EXPOSE 7860

# Run the application
CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "7860"]