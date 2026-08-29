import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';
import 'viral_score_indicator.dart';

/// Card widget displaying a viral segment candidate.
///
/// Shows virality score, headline, summary, topic tags,
/// timestamp range, and a "Create Clip" action button.
class SegmentCard extends StatelessWidget {
  final String headline;
  final String summary;
  final double score;
  final double startTime;
  final double endTime;
  final List<String> topics;
  final List<String> highlights;
  final VoidCallback onCreateClip;

  const SegmentCard({
    super.key,
    required this.headline,
    required this.summary,
    required this.score,
    required this.startTime,
    required this.endTime,
    this.topics = const [],
    this.highlights = const [],
    required this.onCreateClip,
  });

  String _formatTimestamp(double seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).round();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final duration = endTime - startTime;
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: score indicator + headline
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ViralScoreIndicator(score: score, size: 64, strokeWidth: 5),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline.isNotEmpty ? headline : 'Untitled Segment',
                      style: AppTheme.headingSm,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatTimestamp(startTime)} – ${_formatTimestamp(endTime)}',
                          style: AppTheme.bodySm.copyWith(fontFamily: 'monospace'),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.timelapse_rounded,
                            size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${duration.round()}s',
                          style: AppTheme.bodySm,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Summary
          if (summary.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingS),
            Text(
              summary,
              style: AppTheme.bodyMd,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Topic tags
          if (topics.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingS),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: topics.take(4).map((topic) {
                // Extract last part of IAB label (e.g., "Sports>Football" → "Football")
                final label = topic.contains('>')
                    ? topic.split('>').last.trim()
                    : topic;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(
                      color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    label,
                    style: AppTheme.bodySm.copyWith(
                      color: AppTheme.accentPrimary,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Highlights
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingS),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: highlights.take(3).map((h) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department_rounded,
                          size: 12, color: AppTheme.warning),
                      const SizedBox(width: 4),
                      Text(
                        h,
                        style: AppTheme.bodySm.copyWith(
                          color: AppTheme.accentSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: AppTheme.spacingM),

          // Create Clip button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCreateClip,
              icon: const Icon(Icons.content_cut_rounded, size: 18),
              label: const Text('Create Clip'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
