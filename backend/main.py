"""
FastAPI application — API gateway for the Clipping Creator backend.
Endpoints for job management, transcription, analysis, and rendering.
"""

from __future__ import annotations

import asyncio
import logging
import os
import uuid
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Any

from fastapi import BackgroundTasks, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from google.cloud import firestore

from backend.config import get_settings
from backend.models.schemas import (
    ClipInfo,
    ClipListResponse,
    JobCreateRequest,
    JobResponse,
    JobStatus,
    RenderRequest,
    RenderResponse,
)
from backend.services.analyzer import AnalyzerService
from backend.services.downloader import DownloaderService
from backend.services.renderer import RendererService
from backend.services.storage import StorageService
from backend.services.transcriber import TranscriberService

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Local In-Memory Fallback for Firestore (when GCP credentials not provided)
# ---------------------------------------------------------------------------

class LocalDocumentSnapshot:
    def __init__(self, data: dict | None):
        self._data = data
        self.exists = data is not None

    def to_dict(self) -> dict | None:
        return self._data.copy() if self._data else None


class LocalDocumentReference:
    def __init__(self, collection: LocalCollectionReference, doc_id: str):
        self.collection = collection
        self.id = doc_id

    def set(self, data: dict):
        self.collection.data_store[self.id] = data

    def get(self) -> LocalDocumentSnapshot:
        return LocalDocumentSnapshot(self.collection.data_store.get(self.id))

    def update(self, data: dict):
        if self.id in self.collection.data_store:
            self.collection.data_store[self.id].update(data)
        else:
            self.collection.data_store[self.id] = data

    def collection(self, sub_name: str) -> LocalCollectionReference:
        sub_key = f"{self.id}_{sub_name}"
        if sub_key not in self.collection.sub_collections:
            self.collection.sub_collections[sub_key] = LocalCollectionReference(sub_name)
        return self.collection.sub_collections[sub_key]


class LocalCollectionReference:
    def __init__(self, name: str):
        self.name = name
        self.data_store: dict[str, dict] = {}
        self.sub_collections: dict[str, LocalCollectionReference] = {}

    def document(self, doc_id: str) -> LocalDocumentReference:
        return LocalDocumentReference(self, doc_id)

    def stream(self):
        return [LocalDocumentSnapshot(doc) for doc in self.data_store.values()]


class LocalFirestoreClient:
    def __init__(self):
        self.collections: dict[str, LocalCollectionReference] = {}

    def collection(self, name: str) -> LocalCollectionReference:
        if name not in self.collections:
            self.collections[name] = LocalCollectionReference(name)
        return self.collections[name]


# ---------------------------------------------------------------------------
# Service singletons (initialised at startup)
# ---------------------------------------------------------------------------
storage_service: StorageService | None = None
downloader_service: DownloaderService | None = None
transcriber_service: TranscriberService | None = None
analyzer_service: AnalyzerService | None = None
renderer_service: RendererService | None = None
db: Any | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialise services on startup, cleanup on shutdown."""
    global storage_service, downloader_service, transcriber_service
    global analyzer_service, renderer_service, db

    settings = get_settings()

    # Ensure temp directory exists
    os.makedirs(settings.temp_dir, exist_ok=True)

    # Init services
    storage_service = StorageService()
    downloader_service = DownloaderService(storage_service)
    transcriber_service = TranscriberService()
    analyzer_service = AnalyzerService()
    renderer_service = RendererService()

    try:
        if settings.gcp_project_id:
            db = firestore.Client(project=settings.gcp_project_id)
        else:
            db = firestore.Client()
        logger.info("Connected to Google Cloud Firestore")
    except Exception as e:
        logger.warning(
            "GCP Firestore credentials not found (%s) — using in-memory database for local dev",
            e,
        )
        db = LocalFirestoreClient()

    logger.info("All services initialised — server ready")
    yield
    logger.info("Shutting down")


# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Clipping Creator API",
    version="1.0.0",
    description="AI-powered YouTube clipping backend",
    lifespan=lifespan,
)

settings = get_settings()
allow_all = "*" in settings.cors_origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=[] if allow_all else settings.cors_origins,
    allow_origin_regex=r"https?://.*" if allow_all else r"https?://localhost:\d+",  # Support dynamic origins
    allow_credentials=not allow_all,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Health check & Static media
# ---------------------------------------------------------------------------

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "service": "clipping-creator-api",
        "storage_mode": "local" if getattr(storage_service, "_is_local", False) else "gcp",
        "db_mode": "local" if isinstance(db, LocalFirestoreClient) else "firestore",
    }


@app.get("/media/{file_path:path}")
async def serve_media(file_path: str):
    """Serves media files stored locally during development mode."""
    settings = get_settings()
    local_path = os.path.join(settings.temp_dir, "storage", file_path.replace("/", os.sep))
    if not os.path.exists(local_path):
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(local_path)


# ---------------------------------------------------------------------------
# Jobs — Create
# ---------------------------------------------------------------------------

@app.post("/api/jobs", status_code=status.HTTP_202_ACCEPTED)
async def create_job(
    request: JobCreateRequest,
    background_tasks: BackgroundTasks,
):
    """
    Accept a YouTube URL and kick off the processing pipeline.
    Returns immediately with a job ID; processing runs in background.
    """
    job_id = uuid.uuid4().hex[:16]
    now = datetime.utcnow()

    # Create Firestore document
    job_doc = {
        "id": job_id,
        "status": JobStatus.PENDING.value,
        "youtube_url": request.youtube_url,
        "video_metadata": None,
        "segments": [],
        "viral_candidates": [],
        "clips": [],
        "error_message": None,
        "created_at": now,
        "updated_at": now,
    }
    db.collection("jobs").document(job_id).set(job_doc)

    # Queue background processing
    background_tasks.add_task(_process_job, job_id, request.youtube_url)

    return {"job_id": job_id, "status": "pending", "message": "Job created"}


# ---------------------------------------------------------------------------
# Jobs — Get status
# ---------------------------------------------------------------------------

@app.get("/api/jobs/{job_id}")
async def get_job(job_id: str):
    """Get the current state of a job including segments and viral candidates."""
    doc = db.collection("jobs").document(job_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Job not found")

    data = doc.to_dict()
    return data


# ---------------------------------------------------------------------------
# Jobs — Render clip
# ---------------------------------------------------------------------------

@app.post("/api/jobs/{job_id}/render", status_code=status.HTTP_202_ACCEPTED)
async def render_clip(
    job_id: str,
    request: RenderRequest,
    background_tasks: BackgroundTasks,
):
    """Queue a clip render from a detected segment."""
    doc = db.collection("jobs").document(job_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Job not found")

    data = doc.to_dict()
    if data.get("status") not in (JobStatus.READY.value, JobStatus.COMPLETED.value):
        raise HTTPException(
            status_code=400,
            detail=f"Job is not ready for rendering (status: {data.get('status')})",
        )

    clip_id = uuid.uuid4().hex[:12]

    # Store clip record
    clip_doc = {
        "id": clip_id,
        "job_id": job_id,
        "segment_id": request.segment_id,
        "status": "pending",
        "render_config": request.model_dump(),
        "download_url": None,
        "created_at": datetime.utcnow(),
    }
    db.collection("jobs").document(job_id).collection("clips").document(clip_id).set(clip_doc)

    # Queue render
    background_tasks.add_task(_render_clip, job_id, clip_id, request, data)

    return RenderResponse(
        clip_id=clip_id,
        job_id=job_id,
        status="pending",
        message="Render job queued",
    )


@app.get("/api/jobs/{job_id}/clips")
async def list_clips(job_id: str):
    """List all rendered clips for a job."""
    doc = db.collection("jobs").document(job_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Job not found")

    clips_ref = db.collection("jobs").document(job_id).collection("clips")
    clips = [c.to_dict() for c in clips_ref.stream()]

    return ClipListResponse(job_id=job_id, clips=clips)


# ---------------------------------------------------------------------------
# Jobs — Download clip
# ---------------------------------------------------------------------------

@app.get("/api/jobs/{job_id}/clips/{clip_id}/download")
async def download_clip(job_id: str, clip_id: str):
    """Download a rendered clip directly from the server's local storage."""
    clip_ref = (
        db.collection("jobs")
        .document(job_id)
        .collection("clips")
        .document(clip_id)
    )
    doc = clip_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Clip not found")
        
    data = doc.to_dict()
    local_path = data.get("local_path")
    if not local_path or not os.path.exists(local_path):
        raise HTTPException(status_code=404, detail="Rendered clip file not found on server")
        
    return FileResponse(
        local_path,
        media_type="video/mp4",
        filename=f"clip_{clip_id}.mp4"
    )


# ---------------------------------------------------------------------------
# Jobs — Delete / Cancel
# ---------------------------------------------------------------------------

@app.delete("/api/jobs/{job_id}")
async def delete_job(job_id: str):
    """Cancel a job and clean up associated storage."""
    doc_ref = db.collection("jobs").document(job_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Job not found")

    # Update status
    doc_ref.update({
        "status": JobStatus.CANCELLED.value,
        "updated_at": datetime.utcnow(),
    })

    # Clean up local files
    try:
        import shutil
        work_dir = os.path.join(get_settings().temp_dir, job_id)
        if os.path.exists(work_dir):
            shutil.rmtree(work_dir)
            logger.info("Deleted local job folder: %s", work_dir)
    except Exception as e:
        logger.warning("Failed to cleanup job %s local files: %s", job_id, e)

    return {"job_id": job_id, "status": "cancelled"}


# ---------------------------------------------------------------------------
# Background processing pipeline
# ---------------------------------------------------------------------------

async def _process_job(job_id: str, youtube_url: str) -> None:
    """
    Full processing pipeline:
      1. Download video + extract audio
      2. Transcribe via AssemblyAI
      3. Analyze for viral segments
    """
    doc_ref = db.collection("jobs").document(job_id)

    try:
        # --- Step 1: Download ---
        _update_status(doc_ref, JobStatus.DOWNLOADING)
        download_result = await downloader_service.download_local(
            youtube_url, job_id
        )

        doc_ref.update({
            "video_metadata": download_result["video_metadata"].model_dump(),
            "updated_at": datetime.utcnow(),
        })

        # --- Step 2: Transcribe ---
        _update_status(doc_ref, JobStatus.TRANSCRIBING)
        
        audio_target = download_result["audio_local_path"]
        transcript_result = await transcriber_service.transcribe(audio_target)

        # Store segments (chapters)
        segments_data = [s.model_dump() for s in transcript_result["segments"]]
        doc_ref.update({
            "segments": segments_data,
            "full_text": transcript_result["full_text"],
            "words": [w.model_dump() for w in transcript_result["words"]],
            "updated_at": datetime.utcnow(),
        })

        # --- Step 3: Analyze ---
        _update_status(doc_ref, JobStatus.ANALYZING)
        candidates = analyzer_service.analyze(
            segments=transcript_result["segments"],
            sentiments=transcript_result["sentiments"],
            topics=transcript_result["topics"],
            highlights=transcript_result["highlights"],
        )

        doc_ref.update({
            "viral_candidates": [c.model_dump() for c in candidates],
            "status": JobStatus.READY.value,
            "updated_at": datetime.utcnow(),
        })

        logger.info("Job %s processing complete — %d candidates", job_id, len(candidates))

    except Exception as e:
        logger.exception("Job %s failed: %s", job_id, e)
        doc_ref.update({
            "status": JobStatus.FAILED.value,
            "error_message": str(e)[:500],
            "updated_at": datetime.utcnow(),
        })


async def _render_clip(
    job_id: str,
    clip_id: str,
    config: RenderRequest,
    job_data: dict[str, Any],
) -> None:
    """Background task: download source video, render clip, upload result."""
    clip_ref = (
        db.collection("jobs")
        .document(job_id)
        .collection("clips")
        .document(clip_id)
    )

    try:
        clip_ref.update({"status": "rendering"})

        # Use source video already stored locally
        local_video = os.path.join(get_settings().temp_dir, job_id, "source.mp4")
        if not os.path.exists(local_video):
            raise FileNotFoundError(f"Source video not found on server at {local_video}")

        # Get word timestamps for captions
        words_data = job_data.get("words", [])
        from backend.models.schemas import WordTimestamp
        words = [WordTimestamp(**w) for w in words_data]

        # Render
        output_path = renderer_service.render_clip(
            source_video_path=local_video,
            render_config=config,
            words=words,
        )

        # Apply transitions if configured
        if config.transition_intro:
            output_path = renderer_service.apply_transition(
                output_path, config.transition_intro, "intro", config.transition_duration
            )
        if config.transition_outro:
            output_path = renderer_service.apply_transition(
                output_path, config.transition_outro, "outro", config.transition_duration
            )

        # Set download URL to point directly to our server's download endpoint
        settings = get_settings()
        download_url = f"/api/jobs/{job_id}/clips/{clip_id}/download"

        # Update clip record
        clip_ref.update({
            "status": "completed",
            "download_url": download_url,
            "local_path": output_path,
            "file_size": os.path.getsize(output_path),
            "duration": config.end_time - config.start_time,
        })

        # Update job status
        db.collection("jobs").document(job_id).update({
            "status": JobStatus.COMPLETED.value,
            "updated_at": datetime.utcnow(),
        })

        logger.info("Clip %s rendered successfully for job %s", clip_id, job_id)

    except Exception as e:
        logger.exception("Render failed for clip %s: %s", clip_id, e)
        clip_ref.update({
            "status": "failed",
            "error_message": str(e)[:500],
        })


def _update_status(doc_ref, new_status: JobStatus) -> None:
    """Helper to update job status in Firestore."""
    doc_ref.update({
        "status": new_status.value,
        "updated_at": datetime.utcnow(),
    })


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=settings.host, port=settings.port)
