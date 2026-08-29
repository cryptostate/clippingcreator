"""
Google Cloud Storage helper service.
Handles upload, download, signed URL generation, and cleanup of media files.
"""

from __future__ import annotations

import logging
import os
import uuid
from datetime import datetime, timedelta
from typing import Optional

from google.cloud import storage

from backend.config import get_settings

logger = logging.getLogger(__name__)


class StorageService:
    """Manages all interactions with Google Cloud Storage (with local disk fallback for dev)."""

    def __init__(self) -> None:
        settings = get_settings()
        self._bucket_name = settings.gcs_bucket_name
        self._storage_days = settings.clip_storage_days
        self._is_local = False
        self._local_storage_dir = os.path.join(settings.temp_dir, "storage")
        os.makedirs(self._local_storage_dir, exist_ok=True)

        try:
            if settings.gcp_project_id:
                self._client = storage.Client(project=settings.gcp_project_id)
            else:
                self._client = storage.Client()
            self._bucket = self._client.bucket(self._bucket_name)
        except Exception as e:
            logger.warning(
                "GCP Storage credentials not found (%s) — using local filesystem storage at %s",
                e,
                self._local_storage_dir,
            )
            self._client = None
            self._bucket = None
            self._is_local = True

    # ------------------------------------------------------------------
    # Upload
    # ------------------------------------------------------------------

    def upload_file(
        self,
        local_path: str,
        destination_blob: str,
        content_type: Optional[str] = None,
    ) -> str:
        """
        Upload a local file to GCS (or local fallback).
        Returns the gs:// or file:// URI.
        """
        if self._is_local or not self._bucket:
            dest_path = os.path.join(self._local_storage_dir, destination_blob.replace("/", os.sep))
            os.makedirs(os.path.dirname(dest_path), exist_ok=True)
            import shutil
            shutil.copy2(local_path, dest_path)
            local_uri = f"file://{dest_path}"
            logger.info("Local storage: copied %s → %s", local_path, dest_path)
            return local_uri

        blob = self._bucket.blob(destination_blob)
        if content_type:
            blob.content_type = content_type

        blob.upload_from_filename(local_path)
        gs_uri = f"gs://{self._bucket_name}/{destination_blob}"
        logger.info("Uploaded %s → %s", local_path, gs_uri)
        return gs_uri

    def upload_bytes(
        self,
        data: bytes,
        destination_blob: str,
        content_type: str = "application/octet-stream",
    ) -> str:
        """Upload raw bytes to GCS (or local fallback)."""
        if self._is_local or not self._bucket:
            dest_path = os.path.join(self._local_storage_dir, destination_blob.replace("/", os.sep))
            os.makedirs(os.path.dirname(dest_path), exist_ok=True)
            with open(dest_path, "wb") as f:
                f.write(data)
            return f"file://{dest_path}"

        blob = self._bucket.blob(destination_blob)
        blob.upload_from_string(data, content_type=content_type)
        gs_uri = f"gs://{self._bucket_name}/{destination_blob}"
        logger.info("Uploaded %d bytes → %s", len(data), gs_uri)
        return gs_uri

    # ------------------------------------------------------------------
    # Download
    # ------------------------------------------------------------------

    def download_file(self, source_blob: str, local_path: str) -> str:
        """Download a GCS object to a local file. Returns the local path."""
        if self._is_local or not self._bucket:
            src_path = os.path.join(self._local_storage_dir, source_blob.replace("/", os.sep))
            if not os.path.exists(src_path):
                raise FileNotFoundError(f"Local storage object not found: {src_path}")
            os.makedirs(os.path.dirname(local_path), exist_ok=True)
            import shutil
            shutil.copy2(src_path, local_path)
            return local_path

        blob = self._bucket.blob(source_blob)
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        blob.download_to_filename(local_path)
        logger.info("Downloaded %s → %s", source_blob, local_path)
        return local_path

    # ------------------------------------------------------------------
    # Signed URLs
    # ------------------------------------------------------------------

    def generate_signed_url(
        self,
        blob_name: str,
        expiration_hours: int = 24,
    ) -> str:
        """Generate a signed download URL valid for *expiration_hours*."""
        if self._is_local or not self._bucket:
            # For local dev, return the static or public endpoint URL
            settings = get_settings()
            return f"http://localhost:{settings.port}/media/{blob_name}"

        blob = self._bucket.blob(blob_name)
        url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(hours=expiration_hours),
            method="GET",
        )
        return url

    def generate_upload_signed_url(
        self,
        blob_name: str,
        content_type: str = "video/mp4",
        expiration_minutes: int = 60,
    ) -> str:
        """Generate a signed URL for uploading (PUT)."""
        if self._is_local or not self._bucket:
            settings = get_settings()
            return f"http://localhost:{settings.port}/upload/{blob_name}"

        blob = self._bucket.blob(blob_name)
        url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=expiration_minutes),
            method="PUT",
            content_type=content_type,
        )
        return url

    # ------------------------------------------------------------------
    # Public URL (for AssemblyAI ingestion)
    # ------------------------------------------------------------------

    def make_public(self, blob_name: str) -> str:
        """Make a blob publicly readable and return its public URL."""
        if self._is_local or not self._bucket:
            return self.get_public_url(blob_name)

        blob = self._bucket.blob(blob_name)
        blob.make_public()
        return blob.public_url

    def get_public_url(self, blob_name: str) -> str:
        """Get the public URL without changing permissions."""
        if self._is_local or not self._bucket:
            settings = get_settings()
            return f"http://localhost:{settings.port}/media/{blob_name}"
        return f"https://storage.googleapis.com/{self._bucket_name}/{blob_name}"

    # ------------------------------------------------------------------
    # Cleanup
    # ------------------------------------------------------------------

    def delete_blob(self, blob_name: str) -> None:
        """Delete a single blob."""
        if self._is_local or not self._bucket:
            path = os.path.join(self._local_storage_dir, blob_name.replace("/", os.sep))
            if os.path.exists(path):
                os.remove(path)
            return

        blob = self._bucket.blob(blob_name)
        blob.delete()
        logger.info("Deleted blob %s", blob_name)

    def cleanup_expired(self, prefix: str = "") -> int:
        """Delete blobs older than the configured storage retention period."""
        if self._is_local or not self._bucket:
            return 0

        cutoff = datetime.utcnow() - timedelta(days=self._storage_days)
        deleted = 0
        for blob in self._bucket.list_blobs(prefix=prefix):
            if blob.time_created and blob.time_created.replace(tzinfo=None) < cutoff:
                blob.delete()
                deleted += 1
        logger.info("Cleaned up %d expired blobs under prefix '%s'", deleted, prefix)
        return deleted

    def cleanup_job(self, job_id: str) -> int:
        """Delete all blobs associated with a job."""
        if self._is_local or not self._bucket:
            job_dir = os.path.join(self._local_storage_dir, "jobs", job_id)
            if os.path.exists(job_dir):
                import shutil
                shutil.rmtree(job_dir)
            return 1

        prefix = f"jobs/{job_id}/"
        deleted = 0
        for blob in self._bucket.list_blobs(prefix=prefix):
            blob.delete()
            deleted += 1
        logger.info("Cleaned up %d blobs for job %s", deleted, job_id)
        return deleted

    def get_local_path(self, blob_name: str) -> Optional[str]:
        """Get the local file path of a blob if running in local mode."""
        if self._is_local or not self._bucket:
            return os.path.join(self._local_storage_dir, blob_name.replace("/", os.sep))
        return None

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def blob_exists(self, blob_name: str) -> bool:
        """Check if a blob exists."""
        return self._bucket.blob(blob_name).exists()

    @staticmethod
    def generate_blob_path(job_id: str, filename: str) -> str:
        """Generate a consistent blob path for a job artifact."""
        return f"jobs/{job_id}/{filename}"

    @staticmethod
    def generate_clip_path(job_id: str, clip_id: Optional[str] = None) -> str:
        """Generate blob path for a rendered clip."""
        clip_id = clip_id or uuid.uuid4().hex[:12]
        return f"jobs/{job_id}/clips/{clip_id}.mp4"
