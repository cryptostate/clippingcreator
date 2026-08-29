import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/job_provider.dart';
import '../providers/editor_provider.dart';
import '../widgets/gradient_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/processing_stepper.dart';
import '../widgets/segment_card.dart';
import 'editor_screen.dart';

/// Analysis dashboard — shows processing progress, transcript,
/// and viral segment candidates.
class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final jobProvider = context.watch<JobProvider>();
    final job = jobProvider.currentJob;

    return Scaffold(
      body: GradientBackground(
        animate: false,
        child: SafeArea(
          child: Column(
            children: [
              // ── App Bar ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      color: AppTheme.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        job?.videoMetadata?.title ?? 'Analyzing...',
                        style: AppTheme.headingSm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Content ────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingL,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Video Metadata ─────────────────────────────
                      if (job?.videoMetadata != null) ...[
                        GlassCard(
                          child: Row(
                            children: [
                              // Thumbnail placeholder
                              Container(
                                width: 100,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusXs),
                                  image: job!.videoMetadata!.thumbnailUrl
                                          .isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            job.videoMetadata!.thumbnailUrl,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: job.videoMetadata!.thumbnailUrl.isEmpty
                                    ? const Icon(Icons.play_circle_rounded,
                                        color: AppTheme.textMuted)
                                    : null,
                              ),
                              const SizedBox(width: AppTheme.spacingM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      job.videoMetadata!.channel,
                                      style: AppTheme.labelSm.copyWith(
                                        color: AppTheme.accentSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDuration(
                                          job.videoMetadata!.duration),
                                      style: AppTheme.bodySm,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                      ],

                      // ── Processing Stepper ─────────────────────────
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingL,
                        ),
                        child: ProcessingStepper(
                          currentStatus: job?.status ?? 'pending',
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingL),

                      // ── Error state ────────────────────────────────
                      if (job?.isFailed == true || jobProvider.error != null) ...[
                        GlassCard(
                          borderColor: AppTheme.error.withValues(alpha: 0.5),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppTheme.error, size: 40),
                              const SizedBox(height: 12),
                              Text(
                                'Connection or Processing Failed',
                                style: AppTheme.headingSm
                                    .copyWith(color: AppTheme.error),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                jobProvider.error ?? job?.errorMessage ?? 'Unknown error occurred',
                                style: AppTheme.bodyMd,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppTheme.spacingM),
                              OutlinedButton.icon(
                                onPressed: () {
                                  jobProvider.clearError();
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Go Back'),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Processing state ───────────────────────────
                      if (job?.isProcessing == true) ...[
                        const SizedBox(height: AppTheme.spacingXl),
                        Center(
                          child: Column(
                            children: [
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: AppTheme.accentPrimary,
                                  backgroundColor: AppTheme.surfaceLight,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingM),
                              Text(
                                _getStatusMessage(job!.status),
                                style: AppTheme.bodyMd,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This may take a few minutes...',
                                style: AppTheme.bodySm,
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Viral Candidates (when ready) ──────────────
                      if (job?.isReady == true &&
                          job!.viralCandidates.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Viral Segments',
                              style: AppTheme.headingLg,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusXl),
                              ),
                              child: Text(
                                '${job.viralCandidates.length} found',
                                style: AppTheme.labelSm.copyWith(
                                  color: AppTheme.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingM),

                        ...job.viralCandidates.map((candidate) {
                          return Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppTheme.spacingM),
                            child: SegmentCard(
                              headline: candidate.suggestedTitle.isNotEmpty
                                  ? candidate.suggestedTitle
                                  : candidate.segment.headline,
                              summary: candidate.segment.summary,
                              score: candidate.score,
                              startTime: candidate.segment.start,
                              endTime: candidate.segment.end,
                              topics: candidate.topics
                                  .map((t) => t.label)
                                  .toList(),
                              highlights: candidate.highlights,
                              onCreateClip: () {
                                final editor = context.read<EditorProvider>();
                                editor.selectCandidate(candidate);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const EditorScreen(),
                                  ),
                                );
                              },
                            ),
                          );
                        }),

                        const SizedBox(height: AppTheme.spacingXl),
                      ],

                      // ── Full Transcript (when ready) ───────────────
                      if (job?.isReady == true &&
                          job!.segments.isNotEmpty) ...[
                        Text('Full Transcript', style: AppTheme.headingMd),
                        const SizedBox(height: AppTheme.spacingS),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: job.segments.map((seg) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentPrimary
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _formatTimestamp(seg.start),
                                            style: AppTheme.bodySm.copyWith(
                                              color: AppTheme.accentPrimary,
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (seg.headline.isNotEmpty)
                                          Expanded(
                                            child: Text(
                                              seg.headline,
                                              style: AppTheme.labelMd,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (seg.summary.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        seg.summary,
                                        style: AppTheme.bodyMd,
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXl),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(double seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).round();
    if (m > 60) {
      final h = m ~/ 60;
      return '${h}h ${m % 60}m';
    }
    return '${m}m ${s}s';
  }

  String _formatTimestamp(double seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).round();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'downloading':
        return 'Downloading video from YouTube...';
      case 'transcribing':
        return 'Transcribing audio with AI...';
      case 'analyzing':
        return 'Detecting viral segments...';
      default:
        return 'Processing...';
    }
  }
}
