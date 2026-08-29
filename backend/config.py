"""
Application configuration — reads all settings from environment variables.
"""

from __future__ import annotations

import os
from functools import lru_cache
from typing import Optional

# Auto-load .env file if present
def _load_env_file() -> None:
    try:
        from dotenv import load_dotenv
        # Check backend/.env or root .env
        for path in [".env", "backend/.env", os.path.join(os.path.dirname(__file__), ".env")]:
            if os.path.exists(path):
                load_dotenv(path)
                break
    except ImportError:
        # Fallback simple parser if python-dotenv is not yet installed
        for path in [".env", "backend/.env", os.path.join(os.path.dirname(__file__), ".env")]:
            if os.path.exists(path):
                with open(path, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            k, v = line.split("=", 1)
                            os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
                break

_load_env_file()


class Settings:
    """Centralised configuration loaded once from env vars."""

    # ---- AssemblyAI ----
    assemblyai_api_key: str
    
    # ---- Google Cloud ----
    gcp_project_id: str
    gcs_bucket_name: str
    
    # ---- Firebase ----
    firebase_credentials_path: Optional[str]
    
    # ---- Server ----
    host: str
    port: int
    cors_origins: list[str]
    
    # ---- Processing ----
    max_video_duration: int  # seconds
    clip_storage_days: int
    ffmpeg_path: str
    temp_dir: str
    caption_font_path: str

    def __init__(self) -> None:
        # AssemblyAI
        self.assemblyai_api_key = os.getenv("ASSEMBLYAI_API_KEY", "")

        # Google Cloud
        self.gcp_project_id = os.getenv("GCP_PROJECT_ID", "")
        self.gcs_bucket_name = os.getenv("GCS_BUCKET_NAME", "clippingcreator-media")

        # Firebase
        self.firebase_credentials_path = os.getenv(
            "GOOGLE_APPLICATION_CREDENTIALS", None
        )

        # Server
        self.host = os.getenv("HOST", "0.0.0.0")
        self.port = int(os.getenv("PORT", "8080"))
        self.cors_origins = os.getenv(
            "CORS_ORIGINS", "http://localhost:3000,http://localhost:8080"
        ).split(",")

        # Processing limits
        self.max_video_duration = int(os.getenv("MAX_VIDEO_DURATION", "3600"))  # 1 hour
        self.clip_storage_days = int(os.getenv("CLIP_STORAGE_DAYS", "7"))
        self.ffmpeg_path = os.getenv("FFMPEG_PATH", "ffmpeg")
        self.temp_dir = os.getenv("TEMP_DIR", "/tmp/clipping" if os.name != "nt" else os.path.join(os.environ.get("TEMP", "C:\\Temp"), "clipping"))
        
        # Caption Font resolution
        self.caption_font_path = os.getenv("CAPTION_FONT_PATH", "")
        if not self.caption_font_path or not os.path.exists(self.caption_font_path):
            candidate_fonts = [
                "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
                "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
                "C:/Windows/Fonts/arialbd.ttf",
                "C:/Windows/Fonts/arial.ttf",
                "C:/Windows/Fonts/segoeuib.ttf",
            ]
            for font in candidate_fonts:
                if os.path.exists(font):
                    self.caption_font_path = font
                    break
            if not self.caption_font_path:
                self.caption_font_path = candidate_fonts[0]


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return a cached singleton Settings instance."""
    return Settings()
