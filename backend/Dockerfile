# ---------------------------------------------------------
# Clipping Creator — Backend Processing Service
# ---------------------------------------------------------
# Multi-stage build: slim Python image with FFmpeg
# ---------------------------------------------------------

FROM python:3.12-slim AS base

# Install system dependencies including FFmpeg and fonts
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    fonts-dejavu-core \
    fonts-liberation \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code into a backend subdirectory
COPY . ./backend

# Create temp directory for processing
RUN mkdir -p /tmp/clipping

# Environment defaults
ENV PORT=8080 \
    HOST=0.0.0.0 \
    TEMP_DIR=/tmp/clipping \
    FFMPEG_PATH=ffmpeg \
    PYTHONPATH=/app \
    PYTHONUNBUFFERED=1

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"

# Run the FastAPI server (using shell form to expand $PORT dynamically injected by hosting platforms like Render)
CMD uvicorn backend.main:app --host 0.0.0.0 --port $PORT --workers 2
