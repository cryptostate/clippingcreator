"""
AssemblyAI transcription service.
Submits audio for transcription with auto chapters, topic detection,
sentiment analysis, entity detection, and auto highlights.
"""

from __future__ import annotations

import logging
import time
from typing import Any

import assemblyai as aai

from backend.config import get_settings
from backend.models.schemas import (
    SentimentResult,
    TopicResult,
    TranscriptSegment,
    WordTimestamp,
)

logger = logging.getLogger(__name__)


class TranscriberService:
    """Handles all AssemblyAI transcription and analysis."""

    def __init__(self) -> None:
        settings = get_settings()
        aai.settings.api_key = settings.assemblyai_api_key
        self._transcriber = aai.Transcriber()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def transcribe(self, audio_source: str) -> dict[str, Any]:
        """
        Submit audio file or URL to AssemblyAI and return structured results.
        """
        config = aai.TranscriptionConfig(
            auto_chapters=True,
            iab_categories=True,
            sentiment_analysis=True,
            entity_detection=True,
            auto_highlights=True,
            language_code="en",
            punctuate=True,
            format_text=True,
        )

        logger.info("Submitting audio for transcription: %s", audio_source)
        transcript = self._transcriber.transcribe(audio_source, config=config)

        if transcript.status == aai.TranscriptStatus.error:
            raise RuntimeError(
                f"Transcription failed: {transcript.error}"
            )

        logger.info(
            "Transcription complete — %d words, %d chapters",
            len(transcript.words or []),
            len(transcript.chapters or []),
        )

        return {
            "words": self._parse_words(transcript),
            "full_text": transcript.text or "",
            "segments": self._parse_chapters(transcript),
            "sentiments": self._parse_sentiments(transcript),
            "topics": self._parse_topics(transcript),
            "highlights": self._parse_highlights(transcript),
        }

    # ------------------------------------------------------------------
    # Parsers — convert AssemblyAI objects to our Pydantic models
    # ------------------------------------------------------------------

    @staticmethod
    def _parse_words(transcript: aai.Transcript) -> list[WordTimestamp]:
        """Extract word-level timestamps."""
        words: list[WordTimestamp] = []
        for w in transcript.words or []:
            words.append(
                WordTimestamp(
                    text=w.text,
                    start=w.start / 1000.0,   # ms → seconds
                    end=w.end / 1000.0,
                    confidence=w.confidence or 0.0,
                )
            )
        return words

    @staticmethod
    def _parse_chapters(transcript: aai.Transcript) -> list[TranscriptSegment]:
        """Convert auto-chapters into TranscriptSegments."""
        segments: list[TranscriptSegment] = []
        for i, ch in enumerate(transcript.chapters or []):
            # Collect words that fall within this chapter's time range
            chapter_words: list[WordTimestamp] = []
            ch_start_s = ch.start / 1000.0
            ch_end_s = ch.end / 1000.0

            for w in transcript.words or []:
                w_start = w.start / 1000.0
                w_end = w.end / 1000.0
                if w_start >= ch_start_s and w_end <= ch_end_s:
                    chapter_words.append(
                        WordTimestamp(
                            text=w.text,
                            start=w_start,
                            end=w_end,
                            confidence=w.confidence or 0.0,
                        )
                    )

            segments.append(
                TranscriptSegment(
                    id=f"seg_{i:03d}",
                    start=ch_start_s,
                    end=ch_end_s,
                    headline=ch.headline or "",
                    summary=ch.summary or "",
                    text=ch.gist or "",
                    words=chapter_words,
                )
            )
        return segments

    @staticmethod
    def _parse_sentiments(transcript: aai.Transcript) -> list[SentimentResult]:
        """Extract sentiment analysis results."""
        results: list[SentimentResult] = []
        for s in transcript.sentiment_analysis or []:
            results.append(
                SentimentResult(
                    text=s.text or "",
                    sentiment=s.sentiment.value if s.sentiment else "NEUTRAL",
                    confidence=s.confidence or 0.0,
                    start=s.start / 1000.0,
                    end=s.end / 1000.0,
                )
            )
        return results

    @staticmethod
    def _parse_topics(transcript: aai.Transcript) -> list[TopicResult]:
        """Extract IAB topic categories."""
        results: list[TopicResult] = []
        if transcript.iab_categories and transcript.iab_categories.summary:
            for label, relevance in transcript.iab_categories.summary.items():
                results.append(
                    TopicResult(label=str(label), relevance=float(relevance))
                )
        # Sort by relevance descending
        results.sort(key=lambda t: t.relevance, reverse=True)
        return results[:20]  # top 20 topics

    @staticmethod
    def _parse_highlights(transcript: aai.Transcript) -> list[str]:
        """Extract auto-highlighted key phrases."""
        highlights: list[str] = []
        if transcript.auto_highlights and transcript.auto_highlights.results:
            for h in transcript.auto_highlights.results:
                if h.text:
                    highlights.append(h.text)
        return highlights
