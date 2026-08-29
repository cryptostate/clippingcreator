import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/job_provider.dart';
import '../providers/editor_provider.dart';
import '../widgets/gradient_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/waveform_timeline.dart';
import '../widgets/transition_picker.dart';
import '../widgets/color_grading_panel.dart';
import '../widgets/caption_editor.dart';
import 'export_screen.dart';

/// Clip editor screen — the core editing interface.
///
/// Contains: 9:16 preview, timeline scrubber, transitions panel,
/// color grading controls, caption editor, and export button.
class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<EditorProvider>();
    final job = context.watch<JobProvider>().currentJob;
    final candidate = editor.selectedCandidate;

    if (candidate == null) {
      return const Scaffold(
        body: Center(child: Text('No segment selected')),
      );
    }

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
                        'Edit Clip',
                        style: AppTheme.headingSm,
                      ),
                    ),
                    // Export button
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                        boxShadow: AppTheme.glowShadow(
                            AppTheme.accentPrimary, blur: 12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          onTap: editor.isRendering
                              ? null
                              : () => _startRender(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.movie_creation_rounded,
                                    size: 18, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'Export',
                                  style: AppTheme.button
                                      .copyWith(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable Editor Content ──────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingL,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Video Preview (9:16 aspect ratio) ──────────
                      Center(
                        child: Container(
                          width: 220,
                          height: 390,
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundSecondary,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                              color: AppTheme.surfaceBorder,
                              width: 2,
                            ),
                            boxShadow: AppTheme.subtleShadow,
                          ),
                          child: Stack(
                            children: [
                              // Preview placeholder
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentPrimary
                                            .withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: AppTheme.accentPrimary,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '720 × 1280',
                                      style: AppTheme.bodySm.copyWith(
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Preview',
                                      style: AppTheme.bodySm,
                                    ),
                                  ],
                                ),
                              ),

                              // Caption preview overlay
                              if (editor.captions.enabled)
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  bottom: editor.captions.position.value ==
                                          'bottom'
                                      ? 40
                                      : null,
                                  top: editor.captions.position.value == 'top'
                                      ? 40
                                      : null,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Caption Preview',
                                        style: AppTheme.bodySm.copyWith(
                                          color: Colors.white,
                                          fontSize: (editor.captions.fontSize *
                                                  0.25)
                                              .clamp(10, 18),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),

                              // Color grading overlay preview
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusMd - 2),
                                      color: editor.colorGrading.brightness > 0
                                          ? Colors.white.withValues(alpha: 
                                              editor.colorGrading.brightness *
                                                  0.3)
                                          : Colors.black.withValues(alpha: 
                                              -editor.colorGrading.brightness *
                                                  0.3),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // ── Segment info ───────────────────────────────
                      GlassCard(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded,
                                color: AppTheme.accentPrimary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                candidate.suggestedTitle.isNotEmpty
                                    ? candidate.suggestedTitle
                                    : candidate.segment.headline,
                                style: AppTheme.labelMd,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Resolution Selector ─────────────────────────
                      Text('Export Quality', style: AppTheme.headingSm),
                      const SizedBox(height: AppTheme.spacingS),
                      GlassCard(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child: Row(
                          children: [
                            _buildResolutionOption(
                              context,
                              editor,
                              id: '480p',
                              label: '480p',
                              sub: 'Fast Render',
                              icon: Icons.flash_on_rounded,
                            ),
                            const SizedBox(width: 8),
                            _buildResolutionOption(
                              context,
                              editor,
                              id: '720p',
                              label: '720p',
                              sub: 'HD Standard',
                              icon: Icons.hd_rounded,
                            ),
                            const SizedBox(width: 8),
                            _buildResolutionOption(
                              context,
                              editor,
                              id: '1080p',
                              label: '1080p',
                              sub: 'Full HD',
                              icon: Icons.high_quality_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingL),

                      // ── Timeline ───────────────────────────────────
                      Text('Timeline', style: AppTheme.headingSm),
                      const SizedBox(height: AppTheme.spacingS),
                      GlassCard(
                        child: WaveformTimeline(
                          totalDuration:
                              job?.videoMetadata?.duration ?? 300,
                          startTime: editor.startTime,
                          endTime: editor.endTime,
                          onStartChanged: editor.setStartTime,
                          onEndChanged: editor.setEndTime,
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // ── Transitions ────────────────────────────────
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Intro Transition',
                                style: AppTheme.labelSm),
                            const SizedBox(height: 8),
                            TransitionPicker(
                              selectedTransition:
                                  editor.transitionIntro?.value,
                              onChanged: editor.setTransitionIntro,
                            ),
                            const SizedBox(height: AppTheme.spacingM),
                            Text('Outro Transition',
                                style: AppTheme.labelSm),
                            const SizedBox(height: 8),
                            TransitionPicker(
                              selectedTransition:
                                  editor.transitionOutro?.value,
                              onChanged: editor.setTransitionOutro,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // ── Color Grading ──────────────────────────────
                      GlassCard(
                        child: ColorGradingPanel(
                          opacity: editor.colorGrading.opacity,
                          saturation: editor.colorGrading.saturation,
                          brightness: editor.colorGrading.brightness,
                          onOpacityChanged: editor.setOpacity,
                          onSaturationChanged: editor.setSaturation,
                          onBrightnessChanged: editor.setBrightness,
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // ── Captions ───────────────────────────────────
                      GlassCard(
                        child: CaptionEditor(
                          enabled: editor.captions.enabled,
                          fontSize: editor.captions.fontSize,
                          position: editor.captions.position.value,
                          stylePreset: editor.captions.stylePreset.value,
                          onEnabledChanged: editor.setCaptionEnabled,
                          onFontSizeChanged: editor.setCaptionFontSize,
                          onPositionChanged: editor.setCaptionPosition,
                          onStylePresetChanged:
                              editor.setCaptionStylePreset,
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingXxl),
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

  void _startRender(BuildContext context) async {
    final editor = context.read<EditorProvider>();
    final jobProvider = context.read<JobProvider>();

    editor.setRendering(true);

    final clipConfig = editor.buildClipConfig();
    final result = await jobProvider.renderClip(clipConfig.toJson());

    if (result != null && result['clip_id'] != null) {
      editor.setRenderResult(result['clip_id']);
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ExportScreen()),
        );
      }
    } else {
      editor.setRenderError(
          jobProvider.error ?? 'Failed to start render');
    }
  }

  Widget _buildResolutionOption(
    BuildContext context,
    EditorProvider editor, {
    required String id,
    required String label,
    required String sub,
    required IconData icon,
  }) {
    final isSelected = editor.resolution == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => editor.setResolution(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accentPrimary.withValues(alpha: 0.15)
                : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: isSelected ? AppTheme.accentPrimary : AppTheme.surfaceBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.accentPrimary : AppTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTheme.labelMd.copyWith(
                  color: isSelected ? AppTheme.accentPrimary : AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: AppTheme.bodySm.copyWith(
                  color: isSelected ? AppTheme.accentPrimary.withValues(alpha: 0.7) : AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
