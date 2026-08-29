"""
Viral segment detection and scoring engine.
Scores each auto-chapter using a composite algorithm to identify
the most clip-worthy moments in a video.
"""

from __future__ import annotations

import logging
import re
import uuid
from typing import Any

from backend.models.schemas import (
    SentimentResult,
    TopicResult,
    TranscriptSegment,
    ViralCandidate,
)

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Scoring weights (must sum to 1.0)
# ---------------------------------------------------------------------------
WEIGHT_SENTIMENT = 0.30
WEIGHT_TOPIC = 0.25
WEIGHT_KEYWORD = 0.20
WEIGHT_ENGAGEMENT = 0.15
WEIGHT_LENGTH = 0.10

# Ideal clip length range (seconds)
IDEAL_MIN_LENGTH = 15.0
IDEAL_MAX_LENGTH = 90.0

# Engagement signal patterns
ENGAGEMENT_PATTERNS: list[re.Pattern] = [
    re.compile(r"\?", re.IGNORECASE),                          # questions
    re.compile(r"\b(subscribe|follow|like|share|comment)\b", re.IGNORECASE),  # CTA
    re.compile(r"\b(amazing|incredible|insane|crazy|shocking|unbelievable)\b", re.IGNORECASE),
    re.compile(r"\b(secret|hack|trick|tip|mistake)\b", re.IGNORECASE),
    re.compile(r"\b(you need to|you have to|don't miss|must see|listen)\b", re.IGNORECASE),
    re.compile(r"!", re.IGNORECASE),                           # exclamations
]


class AnalyzerService:
    """Scores transcript segments for viral potential."""

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def analyze(
        self,
        segments: list[TranscriptSegment],
        sentiments: list[SentimentResult],
        topics: list[TopicResult],
        highlights: list[str],
        max_candidates: int = 10,
    ) -> list[ViralCandidate]:
        """
        Score and rank segments by virality.

        Returns up to *max_candidates* ViralCandidate objects sorted by
        composite score descending.
        """
        if not segments:
            logger.warning("No segments to analyze")
            return []

        candidates: list[ViralCandidate] = []

        for seg in segments:
            sentiment_score = self._score_sentiment(seg, sentiments)
            topic_score = self._score_topics(seg, topics)
            keyword_score = self._score_keywords(seg, highlights)
            engagement_score = self._score_engagement(seg)
            length_score = self._score_length(seg)

            composite = (
                WEIGHT_SENTIMENT * sentiment_score
                + WEIGHT_TOPIC * topic_score
                + WEIGHT_KEYWORD * keyword_score
                + WEIGHT_ENGAGEMENT * engagement_score
                + WEIGHT_LENGTH * length_score
            )

            # Collect relevant topics for this segment
            seg_topics = self._get_segment_topics(seg, topics)

            # Collect highlights that appear in this segment
            seg_highlights = [
                h for h in highlights
                if h.lower() in (seg.text + " " + seg.summary).lower()
            ]

            candidate = ViralCandidate(
                id=f"viral_{uuid.uuid4().hex[:8]}",
                segment=seg,
                score=round(composite, 1),
                sentiment_score=round(sentiment_score, 1),
                topic_score=round(topic_score, 1),
                keyword_score=round(keyword_score, 1),
                engagement_score=round(engagement_score, 1),
                length_score=round(length_score, 1),
                suggested_title=self._generate_title(seg),
                topics=seg_topics[:5],
                highlights=seg_highlights[:5],
            )
            candidates.append(candidate)

        # Sort by score descending
        candidates.sort(key=lambda c: c.score, reverse=True)
        result = candidates[:max_candidates]

        logger.info(
            "Analyzed %d segments → %d candidates (top score: %.1f)",
            len(segments),
            len(result),
            result[0].score if result else 0,
        )
        return result

    # ------------------------------------------------------------------
    # Individual scoring functions (each returns 0–100)
    # ------------------------------------------------------------------

    @staticmethod
    def _score_sentiment(
        segment: TranscriptSegment,
        sentiments: list[SentimentResult],
    ) -> float:
        """
        Score based on sentiment intensity within the segment.
        Strong positive OR negative sentiment = high score.
        Neutral = low score.
        """
        seg_sentiments = [
            s for s in sentiments
            if s.start >= segment.start and s.end <= segment.end
        ]

        if not seg_sentiments:
            return 30.0  # neutral default

        # Calculate average absolute sentiment intensity
        positive_count = sum(1 for s in seg_sentiments if s.sentiment == "POSITIVE")
        negative_count = sum(1 for s in seg_sentiments if s.sentiment == "NEGATIVE")
        total = len(seg_sentiments)

        # Strong sentiment in either direction is good for virality
        intensity = (positive_count + negative_count) / total if total else 0
        avg_confidence = sum(s.confidence for s in seg_sentiments) / total

        # Bonus for emotional variety (mixed sentiment = engaging debate)
        variety_bonus = 10.0 if positive_count > 0 and negative_count > 0 else 0.0

        score = (intensity * 70.0 + avg_confidence * 20.0 + variety_bonus)
        return min(score, 100.0)

    @staticmethod
    def _score_topics(
        segment: TranscriptSegment,
        topics: list[TopicResult],
    ) -> float:
        """
        Score based on how many high-relevance topics overlap
        with the segment's content.
        """
        if not topics:
            return 40.0

        segment_text = (segment.text + " " + segment.summary + " " + segment.headline).lower()

        matching_relevance = 0.0
        matches = 0
        for topic in topics[:15]:  # top 15 topics
            # Check if any part of the topic label appears in segment text
            label_parts = topic.label.lower().replace(">", " ").split()
            for part in label_parts:
                if len(part) > 3 and part in segment_text:
                    matching_relevance += topic.relevance
                    matches += 1
                    break

        if matches == 0:
            return 30.0

        # Normalize: more high-relevance matches = higher score
        score = min(matching_relevance * 100.0 / matches * matches * 0.5, 100.0)
        return max(score, 20.0)

    @staticmethod
    def _score_keywords(
        segment: TranscriptSegment,
        highlights: list[str],
    ) -> float:
        """
        Score based on density of highlighted key phrases
        within the segment.
        """
        if not highlights:
            return 40.0

        segment_text = (segment.text + " " + segment.summary).lower()
        duration = max(segment.end - segment.start, 1.0)

        hit_count = sum(1 for h in highlights if h.lower() in segment_text)

        if hit_count == 0:
            return 20.0

        # Keywords per minute
        density = (hit_count / duration) * 60.0

        # 3+ keywords/minute is very dense
        score = min(density / 3.0 * 80.0 + 20.0, 100.0)
        return score

    @staticmethod
    def _score_engagement(segment: TranscriptSegment) -> float:
        """
        Score based on engagement signals: questions, CTAs,
        emotional language, exclamations.
        """
        text = segment.text + " " + segment.summary
        if not text.strip():
            return 30.0

        total_signals = 0
        for pattern in ENGAGEMENT_PATTERNS:
            total_signals += len(pattern.findall(text))

        # Normalize: 5+ engagement signals is excellent
        score = min(total_signals / 5.0 * 80.0 + 20.0, 100.0)
        return score

    @staticmethod
    def _score_length(segment: TranscriptSegment) -> float:
        """
        Score based on segment duration.
        15-90 seconds is ideal for short-form clips.
        """
        duration = segment.end - segment.start

        if IDEAL_MIN_LENGTH <= duration <= IDEAL_MAX_LENGTH:
            return 100.0

        if duration < IDEAL_MIN_LENGTH:
            # Too short — linear penalty
            return max(duration / IDEAL_MIN_LENGTH * 100.0, 10.0)

        # Too long — gradual penalty
        excess = duration - IDEAL_MAX_LENGTH
        penalty = min(excess / 120.0 * 60.0, 60.0)  # max 60-point penalty
        return max(100.0 - penalty, 20.0)

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _get_segment_topics(
        segment: TranscriptSegment,
        topics: list[TopicResult],
    ) -> list[TopicResult]:
        """Get topics relevant to a specific segment."""
        segment_text = (segment.text + " " + segment.summary).lower()
        relevant: list[TopicResult] = []
        for topic in topics:
            label_parts = topic.label.lower().replace(">", " ").split()
            for part in label_parts:
                if len(part) > 3 and part in segment_text:
                    relevant.append(topic)
                    break
        return relevant

    @staticmethod
    def _generate_title(segment: TranscriptSegment) -> str:
        """Generate a suggested clip title from the segment headline/summary."""
        if segment.headline:
            title = segment.headline
        elif segment.summary:
            # Take first sentence
            title = segment.summary.split(".")[0]
        else:
            title = segment.text[:80] if segment.text else "Untitled Clip"

        # Clean and truncate
        title = title.strip()
        if len(title) > 100:
            title = title[:97] + "..."
        return title
