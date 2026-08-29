import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Caption configuration editor panel.
///
/// Controls: toggle on/off, font size, position (top/center/bottom),
/// and style presets (TikTok Bold, Minimal, Neon Glow, Boxed).
class CaptionEditor extends StatelessWidget {
  final bool enabled;
  final int fontSize;
  final String position;     // "top", "center", "bottom"
  final String stylePreset;  // "tiktok_bold", "minimal", "neon_glow", "boxed"
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onFontSizeChanged;
  final ValueChanged<String> onPositionChanged;
  final ValueChanged<String> onStylePresetChanged;

  const CaptionEditor({
    super.key,
    required this.enabled,
    required this.fontSize,
    required this.position,
    required this.stylePreset,
    required this.onEnabledChanged,
    required this.onFontSizeChanged,
    required this.onPositionChanged,
    required this.onStylePresetChanged,
  });

  static const _positions = [
    {'id': 'top', 'label': 'Top', 'icon': Icons.vertical_align_top_rounded},
    {'id': 'center', 'label': 'Center', 'icon': Icons.vertical_align_center_rounded},
    {'id': 'bottom', 'label': 'Bottom', 'icon': Icons.vertical_align_bottom_rounded},
  ];

  static const _styles = [
    {'id': 'tiktok_bold', 'label': 'TikTok Bold', 'color': Color(0xFFFF0050)},
    {'id': 'minimal', 'label': 'Minimal', 'color': Color(0xFFE2E8F0)},
    {'id': 'neon_glow', 'label': 'Neon Glow', 'color': Color(0xFF00FFFF)},
    {'id': 'boxed', 'label': 'Boxed', 'color': Color(0xFFFACC15)},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Captions', style: AppTheme.headingSm),
            Switch(
              value: enabled,
              onChanged: onEnabledChanged,
              activeThumbColor: AppTheme.accentPrimary,
              activeTrackColor: AppTheme.accentPrimary.withValues(alpha: 0.3),
            ),
          ],
        ),

        if (enabled) ...[
          const SizedBox(height: AppTheme.spacingM),

          // Font size slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Font Size', style: AppTheme.labelMd),
              Text(
                '${fontSize}px',
                style: AppTheme.labelSm.copyWith(
                  color: AppTheme.accentSecondary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Slider(
            value: fontSize.toDouble(),
            min: 16,
            max: 96,
            divisions: 20,
            onChanged: (v) => onFontSizeChanged(v.round()),
          ),

          const SizedBox(height: AppTheme.spacingM),

          // Position selector
          Text('Position', style: AppTheme.labelMd),
          const SizedBox(height: AppTheme.spacingS),
          Row(
            children: _positions.map((p) {
              final isSelected = position == p['id'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => onPositionChanged(p['id'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentPrimary.withValues(alpha: 0.2)
                          : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.accentPrimary
                            : AppTheme.surfaceBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          p['icon'] as IconData,
                          size: 20,
                          color: isSelected
                              ? AppTheme.accentPrimary
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p['label'] as String,
                          style: AppTheme.bodySm.copyWith(
                            color: isSelected
                                ? AppTheme.accentPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppTheme.spacingM),

          // Style presets
          Text('Style', style: AppTheme.labelMd),
          const SizedBox(height: AppTheme.spacingS),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _styles.map((s) {
              final isSelected = stylePreset == s['id'];
              final color = s['color'] as Color;
              return GestureDetector(
                onTap: () => onStylePresetChanged(s['id'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.15)
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(
                      color: isSelected ? color : AppTheme.surfaceBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s['label'] as String,
                        style: AppTheme.labelSm.copyWith(
                          color:
                              isSelected ? color : AppTheme.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
