"""
YouTube video downloader service using yt-dlp.
Downloads video + extracts audio for transcription.
"""

from __future__ import annotations

import logging
import os
import uuid
from typing import Any

import yt_dlp

from backend.config import get_settings
from backend.models.schemas import VideoMetadata
from backend.services.storage import StorageService

logger = logging.getLogger(__name__)


class DownloaderService:
    """Downloads YouTube videos and extracts audio for processing."""

    def __init__(self, storage_service: StorageService | None = None) -> None:
        self._settings = get_settings()
        self._storage = storage_service or StorageService()
        self._temp_dir = self._settings.temp_dir
        self._cookie_file = self._setup_cookies()

    def _setup_cookies(self) -> str | None:
        """Find or create the cookies file for yt-dlp."""
        # 1. Check local files
        for path in ["backend/cookies.txt", "cookies.txt", os.path.join(os.path.dirname(__file__), "..", "cookies.txt")]:
            if os.path.exists(path):
                logger.info("Using local cookies file: %s", path)
                return os.path.abspath(path)

        # 2. Check environment variable YOUTUBE_COOKIES (useful for Render deployment)
        cookies_env = os.getenv("YOUTUBE_COOKIES", "")
        if cookies_env.strip():
            logger.info("Found YOUTUBE_COOKIES environment variable. Writing to temp file.")
            temp_cookie_path = os.path.join(self._temp_dir, "temp_cookies.txt")
            try:
                os.makedirs(self._temp_dir, exist_ok=True)
                with open(temp_cookie_path, "w", encoding="utf-8") as f:
                    f.write(cookies_env)
                return temp_cookie_path
            except Exception as e:
                logger.error("Failed to write temporary cookies file: %s", e)
        
        return None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def download_local(
        self, youtube_url: str, job_id: str
    ) -> dict[str, Any]:
        """
        Download a YouTube video, extract audio, and keep both locally.
        """
        work_dir = os.path.join(self._temp_dir, job_id)
        os.makedirs(work_dir, exist_ok=True)

        # Step 1: Extract metadata without downloading
        metadata = self._extract_metadata(youtube_url)

        # Check duration limit
        if metadata.duration > self._settings.max_video_duration:
            raise ValueError(
                f"Video duration {metadata.duration:.0f}s exceeds "
                f"maximum allowed {self._settings.max_video_duration}s"
            )

        # Step 2: Download video (best quality, mp4)
        video_path = self._download_video(youtube_url, work_dir)
        logger.info("Downloaded video to %s", video_path)

        # Step 3: Extract audio as WAV for transcription
        audio_path = self._extract_audio(youtube_url, work_dir)
        logger.info("Extracted audio to %s", audio_path)

        # Ensure consistent filenames
        dest_video = os.path.join(work_dir, "source.mp4")
        if video_path != dest_video:
            if os.path.exists(dest_video):
                os.remove(dest_video)
            os.rename(video_path, dest_video)
            video_path = dest_video

        dest_audio = os.path.join(work_dir, "audio.wav")
        if audio_path != dest_audio:
            if os.path.exists(dest_audio):
                os.remove(dest_audio)
            os.rename(audio_path, dest_audio)
            audio_path = dest_audio

        return {
            "video_metadata": metadata,
            "video_local_path": video_path,
            "audio_local_path": audio_path,
        }

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _extract_metadata(self, url: str) -> VideoMetadata:
        """Extract video metadata without downloading."""
        opts = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "extractor_args": {
                "youtube": {
                    "player_client": ["ios", "android"]
                }
            }
        }
        if self._cookie_file:
            opts["cookiefile"] = self._cookie_file
            
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=False)

        return VideoMetadata(
            title=info.get("title", ""),
            channel=info.get("channel", info.get("uploader", "")),
            duration=float(info.get("duration", 0)),
            thumbnail_url=info.get("thumbnail", ""),
            description=info.get("description", "")[:500],  # truncate
        )

    def _download_video(self, url: str, work_dir: str) -> str:
        """Download the best quality video as mp4."""
        output_path = os.path.join(work_dir, "source.mp4")
        opts = {
            "format": "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
            "outtmpl": output_path,
            "quiet": True,
            "no_warnings": True,
            "merge_output_format": "mp4",
            "postprocessor_args": ["-strict", "-2"],
            "extractor_args": {
                "youtube": {
                    "player_client": ["ios", "android"]
                }
            }
        }
        if self._cookie_file:
            opts["cookiefile"] = self._cookie_file

        with yt_dlp.YoutubeDL(opts) as ydl:
            ydl.download([url])

        # yt-dlp may append the extension; find the actual file
        if os.path.exists(output_path):
            return output_path
        # Fallback: look for any mp4 in the work dir
        for f in os.listdir(work_dir):
            if f.endswith(".mp4"):
                return os.path.join(work_dir, f)
        raise FileNotFoundError(f"Downloaded video not found in {work_dir}")

    def _extract_audio(self, url: str, work_dir: str) -> str:
        """Extract audio as WAV (PCM 16-bit, 16kHz mono) for transcription."""
        output_template = os.path.join(work_dir, "audio")
        opts = {
            "format": "bestaudio/best",
            "outtmpl": output_template,
            "quiet": True,
            "no_warnings": True,
            "postprocessors": [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "wav",
                    "preferredquality": "0",
                }
            ],
            "postprocessor_args": [
                "-ar", "16000",   # 16kHz sample rate
                "-ac", "1",       # mono
                "-sample_fmt", "s16",  # 16-bit PCM
                "-strict", "-2",
            ],
            "extractor_args": {
                "youtube": {
                    "player_client": ["ios", "android"]
                }
            }
        }
        if self._cookie_file:
            opts["cookiefile"] = self._cookie_file

        with yt_dlp.YoutubeDL(opts) as ydl:
            ydl.download([url])

        wav_path = output_template + ".wav"
        if os.path.exists(wav_path):
            return wav_path
        # Fallback
        for f in os.listdir(work_dir):
            if f.endswith(".wav"):
                return os.path.join(work_dir, f)
        raise FileNotFoundError(f"Extracted audio not found in {work_dir}")

    @staticmethod
    def _cleanup_local(work_dir: str) -> None:
        """Remove temporary local files."""
        import shutil
        try:
            if os.path.exists(work_dir):
                shutil.rmtree(work_dir)
                logger.info("Cleaned up temp dir %s", work_dir)
        except Exception as e:
            logger.warning("Failed to cleanup %s: %s", work_dir, e)
