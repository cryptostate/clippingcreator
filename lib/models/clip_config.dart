// Models for clip editing configuration.
//
// Covers transition type, color grading, caption style, and full clip config.

enum TransitionType {
  fade('fade', 'Crossfade'),
  slideLeft('slideleft', 'Slide Left'),
  slideRight('slideright', 'Slide Right'),
  slideUp('slideup', 'Slide Up'),
  slideDown('slidedown', 'Slide Down'),
  wipeLeft('wipeleft', 'Wipe Left'),
  circleOpen('circleopen', 'Circle Open'),
  diamond('diamond', 'Diamond'),
  pixelize('pixelize', 'Pixelize'),
  zoomIn('zoompan', 'Zoom In');

  final String value;
  final String label;
  const TransitionType(this.value, this.label);

  static TransitionType? fromValue(String? value) {
    if (value == null) return null;
    return TransitionType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => TransitionType.fade,
    );
  }
}

enum CaptionPosition {
  top('top'),
  center('center'),
  bottom('bottom');

  final String value;
  const CaptionPosition(this.value);
}

enum CaptionStylePreset {
  tiktokBold('tiktok_bold', 'TikTok Bold'),
  minimal('minimal', 'Minimal'),
  neonGlow('neon_glow', 'Neon Glow'),
  boxed('boxed', 'Boxed');

  final String value;
  final String label;
  const CaptionStylePreset(this.value, this.label);
}

class ColorGrading {
  final double opacity;
  final double saturation;
  final double brightness;

  const ColorGrading({
    this.opacity = 1.0,
    this.saturation = 1.0,
    this.brightness = 0.0,
  });

  ColorGrading copyWith({
    double? opacity,
    double? saturation,
    double? brightness,
  }) {
    return ColorGrading(
      opacity: opacity ?? this.opacity,
      saturation: saturation ?? this.saturation,
      brightness: brightness ?? this.brightness,
    );
  }

  Map<String, dynamic> toJson() => {
        'opacity': opacity,
        'saturation': saturation,
        'brightness': brightness,
      };
}

class CaptionConfig {
  final bool enabled;
  final int fontSize;
  final CaptionPosition position;
  final CaptionStylePreset stylePreset;
  final String highlightColor;
  final String textColor;
  final double backgroundOpacity;

  const CaptionConfig({
    this.enabled = true,
    this.fontSize = 48,
    this.position = CaptionPosition.bottom,
    this.stylePreset = CaptionStylePreset.tiktokBold,
    this.highlightColor = '#FACC15',
    this.textColor = '#FFFFFF',
    this.backgroundOpacity = 0.6,
  });

  CaptionConfig copyWith({
    bool? enabled,
    int? fontSize,
    CaptionPosition? position,
    CaptionStylePreset? stylePreset,
    String? highlightColor,
    String? textColor,
    double? backgroundOpacity,
  }) {
    return CaptionConfig(
      enabled: enabled ?? this.enabled,
      fontSize: fontSize ?? this.fontSize,
      position: position ?? this.position,
      stylePreset: stylePreset ?? this.stylePreset,
      highlightColor: highlightColor ?? this.highlightColor,
      textColor: textColor ?? this.textColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'font_size': fontSize,
        'position': position.value,
        'style_preset': stylePreset.value,
        'highlight_color': highlightColor,
        'text_color': textColor,
        'background_opacity': backgroundOpacity,
      };
}

/// Full render request config sent to the backend.
class ClipConfig {
  final String segmentId;
  final double startTime;
  final double endTime;
  final TransitionType? transitionIntro;
  final TransitionType? transitionOutro;
  final double transitionDuration;
  final ColorGrading colorGrading;
  final CaptionConfig captions;
  final String resolution; // "480p", "720p", "1080p"

  const ClipConfig({
    required this.segmentId,
    required this.startTime,
    required this.endTime,
    this.transitionIntro,
    this.transitionOutro,
    this.transitionDuration = 0.5,
    this.colorGrading = const ColorGrading(),
    this.captions = const CaptionConfig(),
    this.resolution = '720p',
  });

  ClipConfig copyWith({
    String? segmentId,
    double? startTime,
    double? endTime,
    TransitionType? transitionIntro,
    TransitionType? transitionOutro,
    double? transitionDuration,
    ColorGrading? colorGrading,
    CaptionConfig? captions,
    String? resolution,
  }) {
    return ClipConfig(
      segmentId: segmentId ?? this.segmentId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      transitionIntro: transitionIntro ?? this.transitionIntro,
      transitionOutro: transitionOutro ?? this.transitionOutro,
      transitionDuration: transitionDuration ?? this.transitionDuration,
      colorGrading: colorGrading ?? this.colorGrading,
      captions: captions ?? this.captions,
      resolution: resolution ?? this.resolution,
    );
  }

  Map<String, dynamic> toJson() => {
        'segment_id': segmentId,
        'start_time': startTime,
        'end_time': endTime,
        'transition_intro': transitionIntro?.value,
        'transition_outro': transitionOutro?.value,
        'transition_duration': transitionDuration,
        'color_grading': colorGrading.toJson(),
        'captions': captions.toJson(),
        'resolution': resolution,
      };
}
