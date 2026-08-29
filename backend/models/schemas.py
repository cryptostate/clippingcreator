"""
Pydantic models for all API request/response schemas.
Covers jobs, transcription, viral analysis, clip configuration, and rendering.
"""

from __future__ import annotations

import enum
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, HttpUrl


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class JobStatus(str, enum.Enum):
    """Lifecycle states of a processing job."""
    PENDING = "pending"
    DOWNLOADING = "downloading"
    TRANSCRIBING = "transcribing"
    ANALYZING = "analyzing"
    READY = "ready"              # segments available, awaiting render request
    RENDERING = "rendering"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class TransitionType(str, enum.Enum):
    """FFmpeg xfade transition names."""
    FADE = "fade"
    SLIDE_LEFT = "slideleft"
    SLIDE_RIGHT = "slideright"
    SLIDE_UP = "slideup"
    SLIDE_DOWN = "slidedown"
    WIPE_LEFT = "wipeleft"
    CIRCLE_OPEN = "circleopen"
    DIAMOND = "diamond"
    PIXELIZE = "pixelize"
    ZOOM_IN = "zoompan"          # custom implementation via zoompan filter


class CaptionPosition(str, enum.Enum):
    TOP = "top"
    CENTER = "center"
    BOTTOM = "bottom"


class CaptionStylePreset(str, enum.Enum):
    TIKTOK_BOLD = "tiktok_bold"
    MINIMAL = "minimal"
    NEON_GLOW = "neon_glow"
    BOXED = "boxed"


# ---------------------------------------------------------------------------
# Transcript / Analysis models
# ---------------------------------------------------------------------------

class WordTimestamp(BaseModel):
    """A single word with its timestamp range."""
    text: str
    start: float = Field(..., description="Start time in seconds")
    end: float = Field(..., description="End time in seconds")
    confidence: float = Field(0.0, ge=0.0, le=1.0)


class TranscriptSegment(BaseModel):
    """An auto-chapter or manually split segment of the transcript."""
    id: str
    start: float
    end: float
    headline: str = ""
    summary: str = ""
    text: str = ""
    words: list[WordTimestamp] = Field(default_factory=list)


class SentimentResult(BaseModel):
    """Sentiment for a span of text."""
    text: str
    sentiment: str  # POSITIVE, NEGATIVE, NEUTRAL
    confidence: float
    start: float
    end: float


class TopicResult(BaseModel):
    """IAB topic detected in a segment."""
    label: str
    relevance: float = Field(0.0, ge=0.0, le=1.0)


class ViralCandidate(BaseModel):
    """A segment scored as potentially viral-worthy."""
    id: str
    segment: TranscriptSegment
    score: float = Field(..., ge=0.0, le=100.0, description="Composite virality score 0-100")
    sentiment_score: float = 0.0
    topic_score: float = 0.0
    keyword_score: float = 0.0
    engagement_score: float = 0.0
    length_score: float = 0.0
    suggested_title: str = ""
    topics: list[TopicResult] = Field(default_factory=list)
    highlights: list[str] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Color grading / editing models
# ---------------------------------------------------------------------------

class ColorGrading(BaseModel):
    """Color grading controls for the rendered clip."""
    opacity: float = Field(1.0, ge=0.0, le=1.0, description="0.0 = transparent, 1.0 = opaque")
    saturation: float = Field(1.0, ge=0.0, le=3.0, description="0.0 = grayscale, 1.0 = normal, 3.0 = oversaturated")
    brightness: float = Field(0.0, ge=-1.0, le=1.0, description="-1.0 = black, 0.0 = normal, 1.0 = white")


class CaptionConfig(BaseModel):
    """Configuration for burnt-in captions."""
    enabled: bool = True
    font_size: int = Field(48, ge=16, le=96)
    position: CaptionPosition = CaptionPosition.BOTTOM
    style_preset: CaptionStylePreset = CaptionStylePreset.TIKTOK_BOLD
    highlight_color: str = Field("#FACC15", description="Hex color for the active word")
    text_color: str = Field("#FFFFFF", description="Hex color for inactive words")
    background_opacity: float = Field(0.6, ge=0.0, le=1.0)


# ---------------------------------------------------------------------------
# Job / API request-response models
# ---------------------------------------------------------------------------

class JobCreateRequest(BaseModel):
    """Request body for creating a new processing job."""
    youtube_url: str = Field(..., description="YouTube video URL")


class VideoMetadata(BaseModel):
    """Basic metadata about the source YouTube video."""
    title: str = ""
    channel: str = ""
    duration: float = 0.0       # seconds
    thumbnail_url: str = ""
    description: str = ""


class JobResponse(BaseModel):
    """Full job state returned by GET /api/jobs/{job_id}."""
    id: str
    status: JobStatus
    youtube_url: str
    video_metadata: Optional[VideoMetadata] = None
    segments: list[TranscriptSegment] = Field(default_factory=list)
    viral_candidates: list[ViralCandidate] = Field(default_factory=list)
    error_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class RenderRequest(BaseModel):
    """Request body to render a clip from a detected segment."""
    segment_id: str
    start_time: float
    end_time: float
    transition_intro: Optional[TransitionType] = None
    transition_outro: Optional[TransitionType] = None
    transition_duration: float = Field(0.5, ge=0.1, le=2.0)
    color_grading: ColorGrading = Field(default_factory=ColorGrading)
    captions: CaptionConfig = Field(default_factory=CaptionConfig)
    resolution: str = "720p"  # "480p" (or 420p as requested), "720p", "1080p"


class ClipInfo(BaseModel):
    """Information about a rendered clip."""
    id: str
    job_id: str
    segment_id: str
    status: str = "pending"     # pending | rendering | completed | failed
    download_url: Optional[str] = None
    duration: float = 0.0
    file_size: int = 0          # bytes
    width: int = 720
    height: int = 1280
    created_at: datetime = Field(default_factory=datetime.utcnow)


class RenderResponse(BaseModel):
    """Response after a render request is accepted."""
    clip_id: str
    job_id: str
    status: str = "pending"
    message: str = "Render job queued"


class ClipListResponse(BaseModel):
    """List of clips for a job."""
    job_id: str
    clips: list[ClipInfo] = Field(default_factory=list)
