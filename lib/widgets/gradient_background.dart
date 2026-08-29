import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated gradient background used across all screens.
///
/// Creates a subtle moving gradient effect with deep navy → purple → midnight
/// color shifts that respond to a slow animation controller.
class GradientBackground extends StatefulWidget {
  final Widget child;
  final bool animate;

  const GradientBackground({
    super.key,
    required this.child,
    this.animate = true,
  });

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.lerp(
                  const Color(0xFF0A0E1A),
                  const Color(0xFF120F2D),
                  t,
                )!,
                Color.lerp(
                  const Color(0xFF0F1629),
                  const Color(0xFF1A1040),
                  sin(t * pi),
                )!,
                Color.lerp(
                  const Color(0xFF12172B),
                  const Color(0xFF0D1525),
                  t,
                )!,
              ],
              begin: Alignment.topLeft,
              end: Alignment(0.5 + 0.5 * sin(t * pi), 1.0),
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
