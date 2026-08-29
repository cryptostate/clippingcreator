import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated multi-step progress indicator for the processing pipeline.
///
/// Steps: Download → Transcribe → Analyze → Ready
class ProcessingStepper extends StatelessWidget {
  final String currentStatus;

  const ProcessingStepper({
    super.key,
    required this.currentStatus,
  });

  static const List<_StepData> _steps = [
    _StepData('pending', 'Queued', Icons.hourglass_empty_rounded),
    _StepData('downloading', 'Downloading', Icons.cloud_download_rounded),
    _StepData('transcribing', 'Transcribing', Icons.mic_rounded),
    _StepData('analyzing', 'Analyzing', Icons.auto_awesome_rounded),
    _StepData('ready', 'Ready', Icons.check_circle_rounded),
  ];

  int get _currentIndex {
    final idx = _steps.indexWhere((s) => s.id == currentStatus);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < _currentIndex;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: isCompleted
                      ? const LinearGradient(
                          colors: [AppTheme.accentPrimary, AppTheme.accentSecondary],
                        )
                      : null,
                  color: isCompleted ? null : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }

          // Step circle
          final stepIndex = index ~/ 2;
          final step = _steps[stepIndex];
          final isCompleted = stepIndex < _currentIndex;
          final isActive = stepIndex == _currentIndex;
          final isPending = stepIndex > _currentIndex;

          return _StepCircle(
            step: step,
            isCompleted: isCompleted,
            isActive: isActive,
            isPending: isPending,
          );
        }),
      ),
    );
  }
}

class _StepData {
  final String id;
  final String label;
  final IconData icon;
  const _StepData(this.id, this.label, this.icon);
}

class _StepCircle extends StatefulWidget {
  final _StepData step;
  final bool isCompleted;
  final bool isActive;
  final bool isPending;

  const _StepCircle({
    required this.step,
    required this.isCompleted,
    required this.isActive,
    required this.isPending,
  });

  @override
  State<_StepCircle> createState() => _StepCircleState();
}

class _StepCircleState extends State<_StepCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_StepCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = widget.isActive
                ? 1.0 + _pulseController.value * 0.1
                : 1.0;
            return Transform.scale(
              scale: scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isCompleted
                      ? AppTheme.success
                      : widget.isActive
                          ? AppTheme.accentPrimary
                          : AppTheme.surfaceLight,
                  border: Border.all(
                    color: widget.isCompleted
                        ? AppTheme.success
                        : widget.isActive
                            ? AppTheme.accentPrimary
                            : AppTheme.surfaceBorder,
                    width: 2,
                  ),
                  boxShadow: widget.isActive
                      ? AppTheme.glowShadow(AppTheme.accentPrimary, blur: 16)
                      : widget.isCompleted
                          ? AppTheme.glowShadow(AppTheme.success, blur: 10)
                          : null,
                ),
                child: Icon(
                  widget.isCompleted
                      ? Icons.check_rounded
                      : widget.step.icon,
                  size: 20,
                  color: widget.isPending
                      ? AppTheme.textMuted
                      : Colors.white,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          widget.step.label,
          style: AppTheme.bodySm.copyWith(
            color: widget.isCompleted
                ? AppTheme.success
                : widget.isActive
                    ? AppTheme.accentPrimary
                    : AppTheme.textMuted,
            fontWeight:
                widget.isActive ? FontWeight.w600 : FontWeight.w400,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
