"""
FFmpeg rendering engine.
Handles segment extraction, vertical scaling, color grading,
caption burning, transitions, and final encoding to 720×1280.
"""

from __future__ import annotations

import json
import logging
import os
import shlex
import subprocess
import uuid
from typing import Optional

from backend.config import get_settings
from backend.models.schemas import (
    CaptionConfig,
    CaptionPosition,
    CaptionStylePreset,
    ColorGrading,
    RenderRequest,
    TransitionType,
    WordTimestamp,
)

logger = logging.getLogger(__name__)

# Output dimensions
OUTPUT_WIDTH = 720
OUTPUT_HEIGHT = 1280


class RendererService:
    """Builds and executes FFmpeg commands to produce vertical short-form clips."""

    def __init__(self) -> None:
        self._settings = get_settings()
        self._ffmpeg = self._settings.ffmpeg_path
        self._temp_dir = self._settings.temp_dir
        self.width = 720
        self.height = 1280

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def render_clip(
        self,
        source_video_path: str,
        render_config: RenderRequest,
        words: list[WordTimestamp],
        output_path: Optional[str] = None,
    ) -> str:
        # Determine output dimensions dynamically
        res = getattr(render_config, "resolution", "720p")
        if res == "480p" or res == "420p":
            self.width, self.height = 480, 854
        elif res == "1080p":
            self.width, self.height = 1080, 1920
        else:
            self.width, self.height = 720, 1280

        """
        Render a vertical clip from the source video.

        Steps:
          1. Extract segment by timestamp
          2. Scale/crop to 720×1280
          3. Apply color grading
          4. Burn in animated captions
          5. Apply intro/outro transitions
          6. Encode with H.264 + AAC

        Returns the path to the rendered clip.
        """
        work_dir = os.path.join(self._temp_dir, f"render_{uuid.uuid4().hex[:8]}")
        os.makedirs(work_dir, exist_ok=True)

        if output_path is None:
            output_path = os.path.join(work_dir, "output.mp4")

        try:
            # Build the filter complex chain
            filter_chain = self._build_filter_complex(
                render_config, words, work_dir
            )

            # Build the full FFmpeg command
            cmd = self._build_command(
                source_video_path,
                render_config,
                filter_chain,
                output_path,
            )

            logger.info("Executing FFmpeg render: %s", " ".join(cmd[:6]) + " ...")
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=600,  # 10 minute timeout
            )

            if result.returncode != 0:
                logger.error("FFmpeg stderr: %s", result.stderr[-2000:])
                raise RuntimeError(f"FFmpeg failed with code {result.returncode}")

            if not os.path.exists(output_path):
                raise FileNotFoundError(f"Output file not created: {output_path}")

            file_size = os.path.getsize(output_path)
            logger.info("Rendered clip: %s (%.2f MB)", output_path, file_size / 1e6)
            return output_path

        except subprocess.TimeoutExpired:
            raise RuntimeError("FFmpeg render timed out after 10 minutes")

    # ------------------------------------------------------------------
    # Filter complex builder
    # ------------------------------------------------------------------

    def _build_filter_complex(
        self,
        config: RenderRequest,
        words: list[WordTimestamp],
        work_dir: str,
    ) -> str:
        """Build the FFmpeg -filter_complex string."""
        filters: list[str] = []

        # --- 1. Scale and crop to vertical ---
        filters.append(
            f"scale={self.width}:{self.height}:"
            f"force_original_aspect_ratio=increase"
        )
        filters.append(
            f"crop={self.width}:{self.height}"
        )

        # --- 2. Color grading ---
        cg = config.color_grading
        eq_parts: list[str] = []
        if cg.brightness != 0.0:
            eq_parts.append(f"brightness={cg.brightness}")
        if cg.saturation != 1.0:
            eq_parts.append(f"saturation={cg.saturation}")
        if eq_parts:
            filters.append(f"eq={':'.join(eq_parts)}")

        # Opacity via colorchannelmixer (alpha channel)
        if cg.opacity < 1.0:
            a = cg.opacity
            filters.append(
                f"colorchannelmixer=aa={a}"
            )

        # --- 3. Pixel format for compatibility ---
        filters.append("format=yuv420p")

        # --- 4. Captions (drawtext for each word) ---
        if config.captions.enabled and words:
            caption_filters = self._build_caption_filters(config, words, work_dir)
            filters.extend(caption_filters)

        return ",".join(filters)

    # ------------------------------------------------------------------
    # Caption filter builder
    # ------------------------------------------------------------------

    def _build_caption_filters(
        self,
        config: RenderRequest,
        words: list[WordTimestamp],
        work_dir: str,
    ) -> list[str]:
        """
        Build drawtext filters for word-by-word animated captions.
        Each word is shown during its timestamp; the active word
        is highlighted in a different color.
        """
        caption_cfg = config.captions
        filters: list[str] = []

        # Determine Y position
        y_pos = self._get_caption_y(caption_cfg.position, caption_cfg.font_size)

        # Get style parameters
        style = self._get_caption_style(caption_cfg, self._settings.caption_font_path)

        # Filter words to segment time range
        seg_start = config.start_time
        seg_end = config.end_time
        segment_words = [
            w for w in words
            if w.start >= seg_start and w.end <= seg_end
        ]

        if not segment_words:
            return filters

        # Group words into lines (approx 4-5 words per line for vertical video)
        lines = self._group_words_into_lines(segment_words, max_words_per_line=5)

        for line_words in lines:
            if not line_words:
                continue

            line_start = line_words[0].start - seg_start
            line_end = line_words[-1].end - seg_start
            full_text = " ".join(w.text for w in line_words)

            # Background box for the line
            escaped_text = self._escape_drawtext(full_text)
            bg_filter = (
                f"drawtext="
                f"text='{escaped_text}':"
                f"fontfile={style['font_path']}:"
                f"fontsize={caption_cfg.font_size}:"
                f"fontcolor={caption_cfg.text_color}:"
                f"x=(w-text_w)/2:"
                f"y={y_pos}:"
                f"{style['extra']}:"
                f"enable='between(t,{line_start:.3f},{line_end:.3f})'"
            )
            filters.append(bg_filter)

            # Per-word highlight overlay
            x_offset = 0
            for i, word in enumerate(line_words):
                w_start = word.start - seg_start
                w_end = word.end - seg_start
                escaped_word = self._escape_drawtext(word.text)

                highlight_filter = (
                    f"drawtext="
                    f"text='{escaped_word}':"
                    f"fontfile={style['font_path']}:"
                    f"fontsize={caption_cfg.font_size}:"
                    f"fontcolor={caption_cfg.highlight_color}:"
                    f"x=(w-text_w)/2:"
                    f"y={y_pos}:"
                    f"enable='between(t,{w_start:.3f},{w_end:.3f})'"
                )
                filters.append(highlight_filter)

        return filters

    # ------------------------------------------------------------------
    # Full command builder
    # ------------------------------------------------------------------

    def _build_command(
        self,
        source_path: str,
        config: RenderRequest,
        filter_complex: str,
        output_path: str,
    ) -> list[str]:
        """Build the complete FFmpeg command."""
        duration = config.end_time - config.start_time

        cmd = [
            self._ffmpeg,
            "-y",                           # overwrite output
            "-ss", f"{config.start_time:.3f}",  # seek to start
            "-i", source_path,
            "-t", f"{duration:.3f}",        # duration
            "-vf", filter_complex,
            "-c:v", "libx264",
            "-preset", "medium",
            "-crf", "23",
            "-c:a", "aac",
            "-b:a", "128k",
            "-ar", "44100",
            "-ac", "2",
            "-movflags", "+faststart",      # web-optimized
            "-map_metadata", "-1",          # strip metadata
            output_path,
        ]

        return cmd

    # ------------------------------------------------------------------
    # Transition helpers
    # ------------------------------------------------------------------

    def apply_transition(
        self,
        clip_path: str,
        transition_type: TransitionType,
        position: str = "intro",  # "intro" or "outro"
        duration: float = 0.5,
    ) -> str:
        """
        Apply a transition effect to the beginning or end of a clip.
        Returns path to the transitioned clip.
        """
        work_dir = os.path.dirname(clip_path)
        output_path = os.path.join(
            work_dir, f"transitioned_{position}_{os.path.basename(clip_path)}"
        )

        if transition_type == TransitionType.ZOOM_IN:
            # Custom zoom implementation using zoompan
            filter_str = self._build_zoom_transition(position, duration)
        else:
            # Standard fade-based transitions
            filter_str = self._build_fade_transition(
                transition_type, position, duration
            )

        cmd = [
            self._ffmpeg, "-y",
            "-i", clip_path,
            "-vf", filter_str,
            "-c:v", "libx264", "-preset", "medium", "-crf", "23",
            "-c:a", "copy",
            output_path,
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if result.returncode != 0:
            logger.warning("Transition failed, returning original: %s", result.stderr[-500:])
            return clip_path

        return output_path

    @staticmethod
    def _build_fade_transition(
        transition_type: TransitionType,
        position: str,
        duration: float,
    ) -> str:
        """Build a fade/xfade filter string."""
        if position == "intro":
            return f"fade=t=in:st=0:d={duration}"
        else:
            # For outro, we need to know the duration, so we use negative offset
            return f"fade=t=out:d={duration}"

    def _build_zoom_transition(self, position: str, duration: float) -> str:
        """Build a zoom-in transition using zoompan."""
        fps = 30
        frames = int(duration * fps)
        if position == "intro":
            # Zoom from 1.5x to 1.0x (zoom out to reveal)
            return (
                f"zoompan=z='if(lte(on,{frames}),1.5-0.5*on/{frames},1)'"
                f":d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'"
                f":s={self.width}x{self.height}:fps={fps}"
            )
        else:
            # Zoom from 1.0x to 1.5x (zoom in to close)
            return (
                f"zoompan=z='if(gte(on,max(1,in_w-{frames})),1+0.5*(on-(in_w-{frames}))/{frames},1)'"
                f":d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'"
                f":s={self.width}x{self.height}:fps={fps}"
            )

    # ------------------------------------------------------------------
    # Caption style helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _get_caption_y(position: CaptionPosition, font_size: int) -> str:
        """Calculate Y coordinate for caption placement."""
        if position == CaptionPosition.TOP:
            return f"{font_size + 40}"
        elif position == CaptionPosition.CENTER:
            return f"(h-text_h)/2"
        else:  # BOTTOM
            return f"h-{font_size + 80}"

    @staticmethod
    def _get_caption_style(caption_cfg: CaptionConfig, font_path: Optional[str] = None) -> dict:
        """Get font path and extra drawtext parameters based on style preset."""
        resolved_font = font_path or "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
        # Escaped for FFmpeg on Windows/POSIX
        safe_font_path = resolved_font.replace("\\", "/").replace(":", "\\:")

        styles = {
            CaptionStylePreset.TIKTOK_BOLD: {
                "font_path": safe_font_path,
                "extra": (
                    f"borderw=4:bordercolor=black:"
                    f"shadowcolor=black@0.5:shadowx=2:shadowy=2"
                ),
            },
            CaptionStylePreset.MINIMAL: {
                "font_path": safe_font_path.replace("-Bold", "").replace("bd.ttf", ".ttf"),
                "extra": "borderw=1:bordercolor=black@0.3",
            },
            CaptionStylePreset.NEON_GLOW: {
                "font_path": safe_font_path,
                "extra": (
                    "borderw=3:bordercolor=0x00FFFF:"
                    "shadowcolor=0x00FFFF@0.6:shadowx=0:shadowy=0"
                ),
            },
            CaptionStylePreset.BOXED: {
                "font_path": safe_font_path,
                "extra": (
                    f"box=1:boxcolor=black@{caption_cfg.background_opacity}:"
                    f"boxborderw=12"
                ),
            },
        }

        return styles.get(caption_cfg.style_preset, styles[CaptionStylePreset.TIKTOK_BOLD])

    @staticmethod
    def _group_words_into_lines(
        words: list[WordTimestamp], max_words_per_line: int = 5
    ) -> list[list[WordTimestamp]]:
        """Group words into display lines for caption rendering."""
        lines: list[list[WordTimestamp]] = []
        current_line: list[WordTimestamp] = []

        for word in words:
            current_line.append(word)
            if len(current_line) >= max_words_per_line:
                lines.append(current_line)
                current_line = []

        if current_line:
            lines.append(current_line)

        return lines

    @staticmethod
    def _escape_drawtext(text: str) -> str:
        """Escape special characters for FFmpeg drawtext filter."""
        # FFmpeg drawtext needs these characters escaped
        text = text.replace("\\", "\\\\")
        text = text.replace("'", "\\'")
        text = text.replace(":", "\\:")
        text = text.replace("[", "\\[")
        text = text.replace("]", "\\]")
        text = text.replace("%", "%%")
        return text

    # ------------------------------------------------------------------
    # Probe helper
    # ------------------------------------------------------------------

    def get_video_duration(self, video_path: str) -> float:
        """Get the duration of a video file in seconds."""
        cmd = [
            self._ffmpeg.replace("ffmpeg", "ffprobe"),
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            video_path,
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            data = json.loads(result.stdout)
            return float(data.get("format", {}).get("duration", 0))
        return 0.0
