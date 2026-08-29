import 'package:flutter/foundation.dart';
import '../models/clip_config.dart';
import '../models/job.dart';

/// Manages the clip editor state: selected segment, transitions,
/// color grading, and caption configuration.
class EditorProvider extends ChangeNotifier {
  // ── Selected segment ──────────────────────────────────────────────────
  ViralCandidate? _selectedCandidate;
  double _startTime = 0;
  double _endTime = 0;

  // ── Transitions ───────────────────────────────────────────────────────
  TransitionType? _transitionIntro;
  TransitionType? _transitionOutro;
  double _transitionDuration = 0.5;

  // ── Color grading ─────────────────────────────────────────────────────
  ColorGrading _colorGrading = const ColorGrading();

  // ── Captions ──────────────────────────────────────────────────────────
  CaptionConfig _captions = const CaptionConfig();

  // ── Render state ──────────────────────────────────────────────────────
  bool _isRendering = false;
  String? _renderError;
  String? _clipId;
  String _resolution = '720p';

  // ── Getters ───────────────────────────────────────────────────────────
  ViralCandidate? get selectedCandidate => _selectedCandidate;
  double get startTime => _startTime;
  double get endTime => _endTime;
  double get duration => _endTime - _startTime;

  TransitionType? get transitionIntro => _transitionIntro;
  TransitionType? get transitionOutro => _transitionOutro;
  double get transitionDuration => _transitionDuration;

  ColorGrading get colorGrading => _colorGrading;
  CaptionConfig get captions => _captions;

  bool get isRendering => _isRendering;
  String? get renderError => _renderError;
  String? get clipId => _clipId;
  String get resolution => _resolution;

  // ── Segment selection ─────────────────────────────────────────────────

  void selectCandidate(ViralCandidate candidate) {
    _selectedCandidate = candidate;
    _startTime = candidate.segment.start;
    _endTime = candidate.segment.end;
    // Reset editing state
    _transitionIntro = null;
    _transitionOutro = null;
    _colorGrading = const ColorGrading();
    _captions = const CaptionConfig();
    _resolution = '720p';
    _isRendering = false;
    _renderError = null;
    _clipId = null;
    notifyListeners();
  }

  void setStartTime(double time) {
    _startTime = time.clamp(0, _endTime - 1);
    notifyListeners();
  }

  void setEndTime(double time) {
    _endTime = time.clamp(_startTime + 1, double.infinity);
    notifyListeners();
  }

  // ── Transitions ───────────────────────────────────────────────────────

  void setTransitionIntro(String? transitionValue) {
    _transitionIntro = TransitionType.fromValue(transitionValue);
    notifyListeners();
  }

  void setTransitionOutro(String? transitionValue) {
    _transitionOutro = TransitionType.fromValue(transitionValue);
    notifyListeners();
  }

  void setTransitionDuration(double duration) {
    _transitionDuration = duration.clamp(0.1, 2.0);
    notifyListeners();
  }

  // ── Color grading ─────────────────────────────────────────────────────

  void setOpacity(double value) {
    _colorGrading = _colorGrading.copyWith(opacity: value);
    notifyListeners();
  }

  void setSaturation(double value) {
    _colorGrading = _colorGrading.copyWith(saturation: value);
    notifyListeners();
  }

  void setBrightness(double value) {
    _colorGrading = _colorGrading.copyWith(brightness: value);
    notifyListeners();
  }

  // ── Captions ──────────────────────────────────────────────────────────

  void setCaptionEnabled(bool enabled) {
    _captions = _captions.copyWith(enabled: enabled);
    notifyListeners();
  }

  void setCaptionFontSize(int size) {
    _captions = _captions.copyWith(fontSize: size);
    notifyListeners();
  }

  void setCaptionPosition(String position) {
    final pos = CaptionPosition.values.firstWhere(
      (p) => p.value == position,
      orElse: () => CaptionPosition.bottom,
    );
    _captions = _captions.copyWith(position: pos);
    notifyListeners();
  }

  void setCaptionStylePreset(String preset) {
    final style = CaptionStylePreset.values.firstWhere(
      (s) => s.value == preset,
      orElse: () => CaptionStylePreset.tiktokBold,
    );
    _captions = _captions.copyWith(stylePreset: style);
    notifyListeners();
  }

  // ── Resolution ────────────────────────────────────────────────────────

  void setResolution(String value) {
    _resolution = value;
    notifyListeners();
  }

  // ── Build render config ───────────────────────────────────────────────

  ClipConfig buildClipConfig() {
    return ClipConfig(
      segmentId: _selectedCandidate?.id ?? '',
      startTime: _startTime,
      endTime: _endTime,
      transitionIntro: _transitionIntro,
      transitionOutro: _transitionOutro,
      transitionDuration: _transitionDuration,
      colorGrading: _colorGrading,
      captions: _captions,
      resolution: _resolution,
    );
  }

  // ── Render state management ───────────────────────────────────────────

  void setRendering(bool rendering) {
    _isRendering = rendering;
    _renderError = null;
    notifyListeners();
  }

  void setRenderResult(String clipId) {
    _clipId = clipId;
    _isRendering = false;
    notifyListeners();
  }

  void setRenderError(String error) {
    _renderError = error;
    _isRendering = false;
    notifyListeners();
  }

  // ── Reset ─────────────────────────────────────────────────────────────

  void reset() {
    _selectedCandidate = null;
    _startTime = 0;
    _endTime = 0;
    _transitionIntro = null;
    _transitionOutro = null;
    _transitionDuration = 0.5;
    _colorGrading = const ColorGrading();
    _captions = const CaptionConfig();
    _resolution = '720p';
    _isRendering = false;
    _renderError = null;
    _clipId = null;
    notifyListeners();
  }
}
