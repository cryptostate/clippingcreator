import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Circular gradient progress indicator showing a virality score (0–100).
///
/// Displays a gradient arc around a centered score number.
class ViralScoreIndicator extends StatefulWidget {
  final double score;
  final double size;
  final double strokeWidth;
  final bool animate;

  const ViralScoreIndicator({
    super.key,
    required this.score,
    this.size = 80,
    this.strokeWidth = 6,
    this.animate = true,
  });

  @override
  State<ViralScoreIndicator> createState() => _ViralScoreIndicatorState();
}

class _ViralScoreIndicatorState extends State<ViralScoreIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: widget.score / 100)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(ViralScoreIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation = Tween<double>(begin: 0, end: widget.score / 100)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getScoreColor() {
    if (widget.score >= 75) return AppTheme.success;
    if (widget.score >= 50) return AppTheme.accentSecondary;
    if (widget.score >= 25) return AppTheme.warning;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _ScoreArcPainter(
              progress: _animation.value,
              strokeWidth: widget.strokeWidth,
              scoreColor: _getScoreColor(),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(widget.score * _animation.value / (widget.score / 100 == 0 ? 1 : 1)).round()}',
                    style: AppTheme.headingMd.copyWith(
                      color: _getScoreColor(),
                      fontSize: widget.size * 0.28,
                    ),
                  ),
                  Text(
                    'VIRAL',
                    style: AppTheme.labelSm.copyWith(
                      fontSize: widget.size * 0.1,
                      letterSpacing: 1.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreArcPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color scoreColor;

  _ScoreArcPainter({
    required this.progress,
    required this.strokeWidth,
    required this.scoreColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background arc
    final bgPaint = Paint()
      ..color = AppTheme.surfaceLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -pi / 2, 2 * pi, false, bgPaint);

    // Foreground gradient arc
    if (progress > 0) {
      final sweepAngle = 2 * pi * progress;
      final gradient = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + sweepAngle,
        colors: [
          AppTheme.accentPrimary,
          scoreColor,
        ],
        stops: const [0.0, 1.0],
      );

      final fgPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, -pi / 2, sweepAngle, false, fgPaint);

      // Glow dot at the end
      final dotAngle = -pi / 2 + sweepAngle;
      final dotCenter = Offset(
        center.dx + radius * cos(dotAngle),
        center.dy + radius * sin(dotAngle),
      );
      final glowPaint = Paint()
        ..color = scoreColor.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(dotCenter, strokeWidth, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_ScoreArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
