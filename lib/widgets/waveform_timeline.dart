import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Audio waveform visualization with draggable trim handles.
///
/// Displays a simulated waveform and allows the user to set
/// start/end trim points by dragging handles.
class WaveformTimeline extends StatefulWidget {
  final double totalDuration;  // seconds
  final double startTime;
  final double endTime;
  final double? currentPosition;
  final ValueChanged<double> onStartChanged;
  final ValueChanged<double> onEndChanged;

  const WaveformTimeline({
    super.key,
    required this.totalDuration,
    required this.startTime,
    required this.endTime,
    this.currentPosition,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  @override
  State<WaveformTimeline> createState() => _WaveformTimelineState();
}

class _WaveformTimelineState extends State<WaveformTimeline> {
  late List<double> _bars;

  @override
  void initState() {
    super.initState();
    _generateBars();
  }

  void _generateBars() {
    final rng = Random(42); // deterministic for consistency
    _bars = List.generate(100, (_) => 0.2 + rng.nextDouble() * 0.8);
  }

  String _formatTime(double seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).round();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatTime(widget.startTime),
              style: AppTheme.labelSm.copyWith(
                color: AppTheme.accentPrimary,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              'Duration: ${_formatTime(widget.endTime - widget.startTime)}',
              style: AppTheme.labelSm.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
            Text(
              _formatTime(widget.endTime),
              style: AppTheme.labelSm.copyWith(
                color: AppTheme.accentSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Waveform + handles
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final startFrac = widget.startTime / widget.totalDuration;
            final endFrac = widget.endTime / widget.totalDuration;

            return SizedBox(
              height: 72,
              child: Stack(
                children: [
                  // Waveform bars
                  CustomPaint(
                    size: Size(width, 72),
                    painter: _WaveformPainter(
                      bars: _bars,
                      startFraction: startFrac,
                      endFraction: endFrac,
                      playheadFraction: widget.currentPosition != null
                          ? widget.currentPosition! / widget.totalDuration
                          : null,
                    ),
                  ),

                  // Start handle
                  Positioned(
                    left: startFrac * width - 8,
                    top: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        final newFrac =
                            ((startFrac * width + details.delta.dx) / width)
                                .clamp(0.0, endFrac - 0.02);
                        widget.onStartChanged(
                            newFrac * widget.totalDuration);
                      },
                      child: _TrimHandle(
                        color: AppTheme.accentPrimary,
                        isStart: true,
                      ),
                    ),
                  ),

                  // End handle
                  Positioned(
                    left: endFrac * width - 8,
                    top: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        final newFrac =
                            ((endFrac * width + details.delta.dx) / width)
                                .clamp(startFrac + 0.02, 1.0);
                        widget.onEndChanged(
                            newFrac * widget.totalDuration);
                      },
                      child: _TrimHandle(
                        color: AppTheme.accentSecondary,
                        isStart: false,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Draggable trim handle widget.
class _TrimHandle extends StatelessWidget {
  final Color color;
  final bool isStart;

  const _TrimHandle({required this.color, required this.isStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
        ],
      ),
      child: Center(
        child: Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Custom painter that draws the waveform bars.
class _WaveformPainter extends CustomPainter {
  final List<double> bars;
  final double startFraction;
  final double endFraction;
  final double? playheadFraction;

  _WaveformPainter({
    required this.bars,
    required this.startFraction,
    required this.endFraction,
    this.playheadFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = bars.length;
    final barWidth = size.width / barCount * 0.7;
    final barSpacing = size.width / barCount;
    final maxHeight = size.height * 0.8;
    final centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final x = i * barSpacing;
      final fraction = i / barCount;
      final isSelected =
          fraction >= startFraction && fraction <= endFraction;

      final height = bars[i] * maxHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barSpacing / 2, centerY),
          width: barWidth,
          height: height,
        ),
        const Radius.circular(2),
      );

      final paint = Paint()
        ..color = isSelected
            ? Color.lerp(AppTheme.accentPrimary, AppTheme.accentSecondary,
                (fraction - startFraction) / (endFraction - startFraction).clamp(0.01, 1.0))!
            : AppTheme.surfaceLight;

      canvas.drawRRect(rect, paint);
    }

    // Playhead line
    if (playheadFraction != null) {
      final px = playheadFraction! * size.width;
      final linePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2;
      canvas.drawLine(Offset(px, 0), Offset(px, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.startFraction != startFraction ||
        oldDelegate.endFraction != endFraction ||
        oldDelegate.playheadFraction != playheadFraction;
  }
}
