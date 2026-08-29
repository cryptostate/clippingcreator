import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../providers/job_provider.dart';
import '../providers/editor_provider.dart';
import '../models/job.dart';
import '../services/download_service.dart';
import '../widgets/gradient_background.dart';
import '../widgets/glass_card.dart';

/// Export screen — shows render progress and final download.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _pollTimer;
  ClipInfo? _clip;
  bool _isComplete = false;
  bool _hasFailed = false;
  bool _isDownloading = false;
  String? _downloadedFilePath;
  final DownloadService _downloadService = DownloadService();

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..forward();

    // Start polling for clip status
    _startPolling();
  }

  void _startPolling() {
    final jobProvider = context.read<JobProvider>();
    final editor = context.read<EditorProvider>();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      final clips = await jobProvider.getClips();

      if (!mounted) return;
      if (editor.clipId != null && clips.isNotEmpty) {
        final clip = clips.firstWhere(
          (c) => c.id == editor.clipId,
          orElse: () => clips.last,
        );

        setState(() {
          _clip = clip;
          if (clip.status == 'completed') {
            _isComplete = true;
            _pollTimer?.cancel();
            _progressController.stop();
          } else if (clip.status == 'failed') {
            _hasFailed = true;
            _pollTimer?.cancel();
            _progressController.stop();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<EditorProvider>();

    return Scaffold(
      body: GradientBackground(
        animate: false,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingL,
              vertical: AppTheme.spacingXl,
            ),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // ── Status Icon ──────────────────────────────────────
                _buildStatusIcon(),
                const SizedBox(height: AppTheme.spacingL),

                // ── Title ────────────────────────────────────────────
                Text(
                  _isComplete
                      ? 'Clip Ready!'
                      : _hasFailed
                          ? 'Render Failed'
                          : 'Rendering...',
                  style: AppTheme.headingXl,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  _isComplete
                      ? 'Your vertical clip is ready for download'
                      : _hasFailed
                          ? 'Something went wrong during rendering'
                          : 'Processing your clip with AI captions',
                  style: AppTheme.bodyMd,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppTheme.spacingXl),

                // ── Progress / Result ────────────────────────────────
                if (!_isComplete && !_hasFailed) ...[
                  // Progress bar
                  GlassCard(
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) {
                            return Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _progressController.value,
                                    backgroundColor: AppTheme.surfaceLight,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      AppTheme.accentPrimary,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${(_progressController.value * 100).round()}%',
                                      style: AppTheme.labelMd.copyWith(
                                        color: AppTheme.accentPrimary,
                                      ),
                                    ),
                                    Text(
                                      'ETA: ~${(30 * (1 - _progressController.value)).round()}s',
                                      style: AppTheme.bodySm,
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        _InfoRow(
                          label: 'Resolution',
                          value: '720 × 1280',
                        ),
                        _InfoRow(
                          label: 'Duration',
                          value: '${editor.duration.round()}s',
                        ),
                        _InfoRow(
                          label: 'Format',
                          value: 'MP4 (H.264 + AAC)',
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Completed state ──────────────────────────────────
                if (_isComplete && _clip != null) ...[
                  // Clip preview card
                  GlassCard(
                    borderColor: AppTheme.success.withValues(alpha: 0.4),
                    child: Column(
                      children: [
                        // Preview container
                        Container(
                          width: 180,
                          height: 320,
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundSecondary,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            border: Border.all(
                              color: AppTheme.success.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.success.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.success,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text('720 × 1280',
                                    style: AppTheme.bodySm.copyWith(
                                        fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),

                        _InfoRow(
                          label: 'Resolution',
                          value: '720 × 1280',
                        ),
                        _InfoRow(
                          label: 'Duration',
                          value: '${_clip!.duration.round()}s',
                        ),
                        _InfoRow(
                          label: 'File Size',
                          value: _formatFileSize(_clip!.fileSize),
                        ),
                        _InfoRow(
                          label: 'Format',
                          value: 'MP4 (H.264)',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingL),

                  // Download button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                        boxShadow: AppTheme.glowShadow(
                            AppTheme.accentPrimary, blur: 16),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isDownloading ? null : _handleDownload,
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded),
                        label: Text(
                          _isDownloading
                              ? 'Saving to Device...'
                              : _downloadedFilePath != null
                                  ? 'Downloaded!'
                                  : 'Download Clip',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingM),

                  // Share button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _handleShare,
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share Clip'),
                    ),
                  ),
                ],

                // ── Failed state ─────────────────────────────────────
                if (_hasFailed) ...[
                  GlassCard(
                    borderColor: AppTheme.error.withValues(alpha: 0.4),
                    child: Column(
                      children: [
                        Text(
                          'An error occurred during rendering.',
                          style: AppTheme.bodyMd,
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back to Editor'),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppTheme.spacingL),

                // ── Create Another Clip ──────────────────────────────
                TextButton.icon(
                  onPressed: () {
                    // Pop back to analysis screen
                    Navigator.of(context)
                      ..pop()  // editor
                      ..pop(); // back to analysis (if needed)
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create Another Clip'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentSecondary,
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (_isComplete) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.success.withValues(alpha: 0.15),
          boxShadow: AppTheme.glowShadow(AppTheme.success),
        ),
        child: const Icon(
          Icons.check_rounded,
          color: AppTheme.success,
          size: 40,
        ),
      );
    }

    if (_hasFailed) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.error.withValues(alpha: 0.15),
        ),
        child: const Icon(
          Icons.error_outline_rounded,
          color: AppTheme.error,
          size: 40,
        ),
      );
    }

    // Processing spinner
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: AppTheme.accentPrimary,
              backgroundColor: AppTheme.surfaceLight,
            ),
          ),
          const Icon(
            Icons.movie_creation_rounded,
            color: AppTheme.accentPrimary,
            size: 32,
          ),
        ],
      ),
    );
  }

  Future<void> _handleDownload() async {
    final downloadUrl = _clip?.downloadUrl;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download URL is not available yet.')),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final filename = 'clip_${_clip?.id ?? DateTime.now().millisecondsSinceEpoch}.mp4';
      final path = await _downloadService.downloadFile(downloadUrl, filename);
      setState(() {
        _downloadedFilePath = path;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Clip saved to: $path'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      // If direct download fails, fallback to browser / url_launcher
      try {
        final uri = Uri.parse(downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download error: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _handleShare() async {
    if (_downloadedFilePath != null) {
      await Share.shareXFiles([XFile(_downloadedFilePath!)], text: 'Created with ClipCreator AI');
    } else if (_clip?.downloadUrl != null && _clip!.downloadUrl!.isNotEmpty) {
      await Share.share(
        'Check out my vertical clip: ${_clip!.downloadUrl}',
        subject: 'My ClipCreator Video',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No clip available to share yet.')),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodySm),
          Text(
            value,
            style: AppTheme.labelSm.copyWith(
              color: AppTheme.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
