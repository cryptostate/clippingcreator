import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Color grading panel with three sliders: opacity, saturation, brightness.
///
/// Each slider has a gradient track reflecting the parameter's effect.
class ColorGradingPanel extends StatelessWidget {
  final double opacity;
  final double saturation;
  final double brightness;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onSaturationChanged;
  final ValueChanged<double> onBrightnessChanged;

  const ColorGradingPanel({
    super.key,
    required this.opacity,
    required this.saturation,
    required this.brightness,
    required this.onOpacityChanged,
    required this.onSaturationChanged,
    required this.onBrightnessChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color Grading', style: AppTheme.headingSm),
        const SizedBox(height: AppTheme.spacingM),

        // Opacity
        _GradingSlider(
          label: 'Opacity',
          value: opacity,
          min: 0.0,
          max: 1.0,
          displayValue: '${(opacity * 100).round()}%',
          trackGradient: const LinearGradient(
            colors: [Colors.transparent, Colors.white],
          ),
          onChanged: onOpacityChanged,
        ),
        const SizedBox(height: AppTheme.spacingM),

        // Saturation
        _GradingSlider(
          label: 'Saturation',
          value: saturation,
          min: 0.0,
          max: 3.0,
          displayValue: '${(saturation * 100).round()}%',
          trackGradient: const LinearGradient(
            colors: [
              Color(0xFF808080), // grayscale
              Color(0xFFFF0000), // saturated red
              Color(0xFFFF00FF), // oversaturated
            ],
          ),
          onChanged: onSaturationChanged,
        ),
        const SizedBox(height: AppTheme.spacingM),

        // Brightness
        _GradingSlider(
          label: 'Brightness',
          value: brightness,
          min: -1.0,
          max: 1.0,
          displayValue: '${(brightness * 100).round().abs()}%'
              '${brightness >= 0 ? " +" : " -"}',
          trackGradient: const LinearGradient(
            colors: [Colors.black, Colors.white],
          ),
          onChanged: onBrightnessChanged,
        ),

        const SizedBox(height: AppTheme.spacingS),

        // Reset button
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              onOpacityChanged(1.0);
              onSaturationChanged(1.0);
              onBrightnessChanged(0.0);
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text('Reset', style: AppTheme.labelSm),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// A single grading slider with label, gradient track, and value display.
class _GradingSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final Gradient trackGradient;
  final ValueChanged<double> onChanged;

  const _GradingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.trackGradient,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTheme.labelMd),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
              ),
              child: Text(
                displayValue,
                style: AppTheme.labelSm.copyWith(
                  color: AppTheme.accentSecondary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          alignment: Alignment.center,
          children: [
            // Gradient track background
            Container(
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: trackGradient,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Slider on top
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Colors.white,
                overlayColor: AppTheme.accentPrimary.withValues(alpha: 0.15),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 9,
                  elevation: 4,
                ),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
