// Data models for jobs, transcription segments, and viral candidates.
//
// Mirror the backend Pydantic schemas for type-safe deserialization.

class VideoMetadata {
  final String title;
  final String channel;
  final double duration;
  final String thumbnailUrl;
  final String description;

  const VideoMetadata({
    this.title = '',
    this.channel = '',
    this.duration = 0,
    this.thumbnailUrl = '',
    this.description = '',
  });

  factory VideoMetadata.fromJson(Map<String, dynamic> json) {
    return VideoMetadata(
      title: json['title'] ?? '',
      channel: json['channel'] ?? '',
      duration: (json['duration'] ?? 0).toDouble(),
      thumbnailUrl: json['thumbnail_url'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'channel': channel,
        'duration': duration,
        'thumbnail_url': thumbnailUrl,
        'description': description,
      };
}

class WordTimestamp {
  final String text;
  final double start;
  final double end;
  final double confidence;

  const WordTimestamp({
    required this.text,
    required this.start,
    required this.end,
    this.confidence = 0,
  });

  factory WordTimestamp.fromJson(Map<String, dynamic> json) {
    return WordTimestamp(
      text: json['text'] ?? '',
      start: (json['start'] ?? 0).toDouble(),
      end: (json['end'] ?? 0).toDouble(),
      confidence: (json['confidence'] ?? 0).toDouble(),
    );
  }
}

class TranscriptSegment {
  final String id;
  final double start;
  final double end;
  final String headline;
  final String summary;
  final String text;
  final List<WordTimestamp> words;

  const TranscriptSegment({
    required this.id,
    required this.start,
    required this.end,
    this.headline = '',
    this.summary = '',
    this.text = '',
    this.words = const [],
  });

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      id: json['id'] ?? '',
      start: (json['start'] ?? 0).toDouble(),
      end: (json['end'] ?? 0).toDouble(),
      headline: json['headline'] ?? '',
      summary: json['summary'] ?? '',
      text: json['text'] ?? '',
      words: (json['words'] as List<dynamic>?)
              ?.map((w) => WordTimestamp.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start,
        'end': end,
        'headline': headline,
        'summary': summary,
        'text': text,
      };
}

class TopicResult {
  final String label;
  final double relevance;

  const TopicResult({required this.label, this.relevance = 0});

  factory TopicResult.fromJson(Map<String, dynamic> json) {
    return TopicResult(
      label: json['label'] ?? '',
      relevance: (json['relevance'] ?? 0).toDouble(),
    );
  }
}

class ViralCandidate {
  final String id;
  final TranscriptSegment segment;
  final double score;
  final double sentimentScore;
  final double topicScore;
  final double keywordScore;
  final double engagementScore;
  final double lengthScore;
  final String suggestedTitle;
  final List<TopicResult> topics;
  final List<String> highlights;

  const ViralCandidate({
    required this.id,
    required this.segment,
    required this.score,
    this.sentimentScore = 0,
    this.topicScore = 0,
    this.keywordScore = 0,
    this.engagementScore = 0,
    this.lengthScore = 0,
    this.suggestedTitle = '',
    this.topics = const [],
    this.highlights = const [],
  });

  factory ViralCandidate.fromJson(Map<String, dynamic> json) {
    return ViralCandidate(
      id: json['id'] ?? '',
      segment: TranscriptSegment.fromJson(
          json['segment'] as Map<String, dynamic>? ?? {}),
      score: (json['score'] ?? 0).toDouble(),
      sentimentScore: (json['sentiment_score'] ?? 0).toDouble(),
      topicScore: (json['topic_score'] ?? 0).toDouble(),
      keywordScore: (json['keyword_score'] ?? 0).toDouble(),
      engagementScore: (json['engagement_score'] ?? 0).toDouble(),
      lengthScore: (json['length_score'] ?? 0).toDouble(),
      suggestedTitle: json['suggested_title'] ?? '',
      topics: (json['topics'] as List<dynamic>?)
              ?.map((t) => TopicResult.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      highlights: (json['highlights'] as List<dynamic>?)
              ?.map((h) => h.toString())
              .toList() ??
          [],
    );
  }
}

class ClipInfo {
  final String id;
  final String jobId;
  final String segmentId;
  final String status;
  final String? downloadUrl;
  final double duration;
  final int fileSize;

  const ClipInfo({
    required this.id,
    required this.jobId,
    required this.segmentId,
    this.status = 'pending',
    this.downloadUrl,
    this.duration = 0,
    this.fileSize = 0,
  });

  factory ClipInfo.fromJson(Map<String, dynamic> json) {
    return ClipInfo(
      id: json['id'] ?? '',
      jobId: json['job_id'] ?? '',
      segmentId: json['segment_id'] ?? '',
      status: json['status'] ?? 'pending',
      downloadUrl: json['download_url'],
      duration: (json['duration'] ?? 0).toDouble(),
      fileSize: json['file_size'] ?? 0,
    );
  }
}

/// Full job model combining all pipeline outputs.
class Job {
  final String id;
  final String status;
  final String youtubeUrl;
  final VideoMetadata? videoMetadata;
  final List<TranscriptSegment> segments;
  final List<ViralCandidate> viralCandidates;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Job({
    required this.id,
    required this.status,
    required this.youtubeUrl,
    this.videoMetadata,
    this.segments = const [],
    this.viralCandidates = const [],
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] ?? '',
      status: json['status'] ?? 'pending',
      youtubeUrl: json['youtube_url'] ?? '',
      videoMetadata: json['video_metadata'] != null
          ? VideoMetadata.fromJson(
              json['video_metadata'] as Map<String, dynamic>)
          : null,
      segments: (json['segments'] as List<dynamic>?)
              ?.map((s) =>
                  TranscriptSegment.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      viralCandidates: (json['viral_candidates'] as List<dynamic>?)
              ?.map((v) =>
                  ViralCandidate.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
      errorMessage: json['error_message'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
    );
  }

  bool get isProcessing =>
      status == 'pending' ||
      status == 'downloading' ||
      status == 'transcribing' ||
      status == 'analyzing';

  bool get isReady => status == 'ready' || status == 'completed';
  bool get isFailed => status == 'failed';
}
