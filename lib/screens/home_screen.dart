import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/job_provider.dart';
import '../widgets/gradient_background.dart';
import '../widgets/glass_card.dart';
import 'analysis_screen.dart';
import '../services/api_service.dart';

/// Home screen shell — premium dashboard containing Bottom Navigation Tabs
/// (Home, Projects, and Settings).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  late TextEditingController _apiBaseUrlController;
  final _formKey = GlobalKey<FormState>();
  late AnimationController _glowController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _apiBaseUrlController = TextEditingController(text: ApiService.activeBaseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiBaseUrlController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  bool _isValidYouTubeUrl(String url) {
    final patterns = [
      RegExp(r'^https?://(www\.)?youtube\.com/watch\?v='),
      RegExp(r'^https?://youtu\.be/'),
      RegExp(r'^https?://(www\.)?youtube\.com/shorts/'),
    ];
    return patterns.any((p) => p.hasMatch(url.trim()));
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
    }
  }

  void _submitUrl() {
    if (!_formKey.currentState!.validate()) return;

    final jobProvider = context.read<JobProvider>();
    jobProvider.createJob(_urlController.text.trim());

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AnalysisScreen()),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.blueGrey;
      case 'downloading':
        return AppTheme.accentSecondary;
      case 'transcribing':
        return Colors.purple;
      case 'analyzing':
        return AppTheme.accentPrimary;
      case 'ready':
      case 'completed':
        return AppTheme.success;
      case 'failed':
        return AppTheme.error;
      case 'cancelled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'downloading':
        return 'Downloading';
      case 'transcribing':
        return 'Transcribing';
      case 'analyzing':
        return 'Analyzing';
      case 'ready':
        return 'Ready';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobProvider = context.watch<JobProvider>();

    Widget currentView;
    switch (_currentIndex) {
      case 0:
        currentView = _buildHomeView(context, jobProvider);
        break;
      case 1:
        currentView = _buildProjectsView(context, jobProvider);
        break;
      case 2:
        currentView = _buildSettingsView(context);
        break;
      default:
        currentView = _buildHomeView(context, jobProvider);
    }

    return Scaffold(
      body: currentView,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // ── Home View ──────────────────────────────────────────────────────────
  Widget _buildHomeView(BuildContext context, JobProvider jobProvider) {
    return GradientBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingL,
            vertical: AppTheme.spacingXl,
          ),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ── Logo / Brand ──────────────────────────────────────
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.accentGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentPrimary
                              .withValues(alpha: 0.3 + _glowController.value * 0.3),
                          blurRadius: 20 + _glowController.value * 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.content_cut_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  );
                },
              ),

              const SizedBox(height: AppTheme.spacingL),

              // ── Title ─────────────────────────────────────────────
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.accentGradient.createShader(bounds),
                child: Text(
                  'ClipCreator',
                  style: AppTheme.headingXl.copyWith(
                    fontSize: 36,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'AI-Powered YouTube Clipping',
                style: AppTheme.bodyMd.copyWith(color: AppTheme.textMuted),
              ),

              const SizedBox(height: AppTheme.spacingXxl),

              // ── URL Input ─────────────────────────────────────────
              GlassCard(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paste YouTube URL', style: AppTheme.headingSm),
                      const SizedBox(height: 4),
                      Text(
                        'We\'ll transcribe, analyze, and find viral moments',
                        style: AppTheme.bodySm,
                      ),
                      const SizedBox(height: AppTheme.spacingM),

                      TextFormField(
                        controller: _urlController,
                        style: AppTheme.bodyLg,
                        decoration: InputDecoration(
                          hintText: 'https://youtube.com/watch?v=...',
                          prefixIcon: const Icon(
                            Icons.link_rounded,
                            color: AppTheme.accentPrimary,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.content_paste_rounded,
                              color: AppTheme.textMuted,
                            ),
                            onPressed: _pasteFromClipboard,
                            tooltip: 'Paste from clipboard',
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a YouTube URL';
                          }
                          if (!_isValidYouTubeUrl(value)) {
                            return 'Please enter a valid YouTube URL';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submitUrl(),
                      ),

                      const SizedBox(height: AppTheme.spacingM),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: jobProvider.isCreating ? null : _submitUrl,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                            ),
                          ),
                          child: jobProvider.isCreating
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.auto_awesome_rounded,
                                        size: 20),
                                    const SizedBox(width: 10),
                                    Text('Analyze Video',
                                        style: AppTheme.button),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Error display ─────────────────────────────────────
              if (jobProvider.error != null) ...[
                const SizedBox(height: AppTheme.spacingM),
                GlassCard(
                  borderColor: AppTheme.error.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppTheme.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          jobProvider.error!,
                          style: AppTheme.bodySm.copyWith(
                              color: AppTheme.error),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: jobProvider.clearError,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppTheme.spacingXxl),

              // ── Features showcase ─────────────────────────────────
              _FeatureRow(
                icon: Icons.auto_awesome_rounded,
                title: 'AI Viral Detection',
                subtitle: 'Identifies high-engagement moments',
                color: AppTheme.accentPrimary,
              ),
              const SizedBox(height: AppTheme.spacingM),
              _FeatureRow(
                icon: Icons.subtitles_rounded,
                title: 'Smart Captions',
                subtitle: 'Word-by-word animated text overlay',
                color: AppTheme.accentSecondary,
              ),
              const SizedBox(height: AppTheme.spacingM),
              _FeatureRow(
                icon: Icons.movie_filter_rounded,
                title: '10 Transitions',
                subtitle: 'Fade, slide, diamond, zoom & more',
                color: AppTheme.warning,
              ),
              const SizedBox(height: AppTheme.spacingM),
              _FeatureRow(
                icon: Icons.tune_rounded,
                title: 'Color Grading',
                subtitle: 'Opacity, saturation & brightness',
                color: AppTheme.success,
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Projects View ──────────────────────────────────────────────────────
  Widget _buildProjectsView(BuildContext context, JobProvider jobProvider) {
    final jobs = jobProvider.recentJobs;

    return GradientBackground(
      animate: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingL,
            vertical: AppTheme.spacingM,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'My Projects',
                style: AppTheme.headingLg,
              ),
              const SizedBox(height: 4),
              Text(
                'Manage and review your clipping jobs',
                style: AppTheme.bodySm.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: AppTheme.spacingL),
              Expanded(
                child: jobs.isEmpty
                    ? Center(
                        child: GlassCard(
                          padding: const EdgeInsets.all(AppTheme.spacingL),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_open_rounded,
                                size: 48,
                                color: AppTheme.textMuted.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: AppTheme.spacingM),
                              Text(
                                'No Projects Yet',
                                style: AppTheme.headingSm,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create a clipping job by pasting a YouTube link in the Home tab.',
                                style: AppTheme.bodySm.copyWith(color: AppTheme.textMuted),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: jobs.length,
                        itemBuilder: (context, index) {
                          final job = jobs[index];
                          final formattedDate =
                              DateFormat('MMM dd, yyyy · hh:mm a')
                                  .format(job.createdAt);

                          return Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppTheme.spacingM),
                            child: GlassCard(
                              padding: const EdgeInsets.all(AppTheme.spacingM),
                              onTap: () {
                                jobProvider.setCurrentJob(job);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const AnalysisScreen()),
                                );
                              },
                              child: Row(
                                children: [
                                  // Video Thumbnail or Placeholder
                                  Container(
                                    width: 80,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusXs),
                                      image: job.videoMetadata != null &&
                                              job.videoMetadata!.thumbnailUrl
                                                  .isNotEmpty
                                          ? DecorationImage(
                                              image: NetworkImage(job
                                                  .videoMetadata!.thumbnailUrl),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: job.videoMetadata == null ||
                                            job.videoMetadata!.thumbnailUrl
                                                .isEmpty
                                        ? const Icon(
                                            Icons.video_library_rounded,
                                            color: AppTheme.textMuted)
                                        : null,
                                  ),
                                  const SizedBox(width: AppTheme.spacingM),

                                  // Title and Date
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          job.videoMetadata?.title ??
                                              'Processing Clip...',
                                          style: AppTheme.labelMd,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formattedDate,
                                          style: AppTheme.bodySm.copyWith(
                                              color: AppTheme.textMuted),
                                        ),
                                        const SizedBox(height: 6),

                                        // Status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(job.status)
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _getStatusLabel(job.status),
                                            style: AppTheme.labelSm.copyWith(
                                              color: _getStatusColor(job.status),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Delete option
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppTheme.error,
                                        size: 20),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Project?'),
                                          content: const Text(
                                              'Are you sure you want to delete this clipping project?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                jobProvider.deleteJob(job.id);
                                                Navigator.of(ctx).pop();
                                              },
                                              child: const Text('Delete',
                                                  style: TextStyle(
                                                      color: AppTheme.error)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Settings View ──────────────────────────────────────────────────────
  Widget _buildSettingsView(BuildContext context) {
    return GradientBackground(
      animate: false,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingL,
            vertical: AppTheme.spacingM,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Settings',
                style: AppTheme.headingLg,
              ),
              const SizedBox(height: 4),
              Text(
                'Configure application preferences',
                style: AppTheme.bodySm.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: AppTheme.spacingL),

              // Export quality section
              Text(
                'Video Export Settings',
                style: AppTheme.labelMd.copyWith(color: AppTheme.accentPrimary),
              ),
              const SizedBox(height: AppTheme.spacingS),
              GlassCard(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Icon(Icons.hd_rounded,
                          color: AppTheme.accentPrimary, size: 24),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export Quality',
                            style: AppTheme.labelMd,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '720p (720x1280) HD · 9:16 Vertical',
                            style: AppTheme.bodySm,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Locked resolution optimized for YouTube Shorts, Instagram Reels, and TikTok.',
                            style: AppTheme.bodySm.copyWith(
                                color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingL),

              // Backend config section
              Text(
                'API & Services Configuration',
                style:
                    AppTheme.labelMd.copyWith(color: AppTheme.accentSecondary),
              ),
              const SizedBox(height: AppTheme.spacingS),
              GlassCard(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  children: [
                    // API Endpoint
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accentSecondary.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: const Icon(Icons.cloud_sync_rounded,
                              color: AppTheme.accentSecondary, size: 24),
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Backend API Base URL',
                                style: AppTheme.labelMd,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _apiBaseUrlController,
                                      style: AppTheme.bodySm.copyWith(fontFamily: 'monospace'),
                                      decoration: InputDecoration(
                                        hintText: 'https://clippingcreator-backend.onrender.com',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        fillColor: AppTheme.surfaceLight,
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 38,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        final url = _apiBaseUrlController.text.trim();
                                        if (url.isNotEmpty) {
                                          ApiService.activeBaseUrl = url;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Backend API URL updated to: $url'),
                                              backgroundColor: AppTheme.success,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        backgroundColor: AppTheme.accentSecondary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                                        ),
                                      ),
                                      child: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: AppTheme.surfaceBorder, height: 1),
                    ),

                    // AssemblyAI API
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: const Icon(Icons.check_circle_outline_rounded,
                              color: AppTheme.success, size: 24),
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AssemblyAI Audio Ingestion',
                                style: AppTheme.labelMd,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Status: Connected (API Active)',
                                style: AppTheme.bodySm
                                    .copyWith(color: AppTheme.success),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingL),

              // App Info section
              Center(
                child: Column(
                  children: [
                    Text(
                      'Clipping Creator App v1.0.0',
                      style: AppTheme.bodySm.copyWith(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI Video Clipping Tool',
                      style: AppTheme.bodySm
                          .copyWith(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom Nav Bar Widget ──────────────────────────────────────────────
  Widget _buildBottomNavBar() {
    return Container(
      height: 72,
      margin: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.folder_special_rounded, 'Projects'),
              _buildNavItem(2, Icons.settings_rounded, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: AppTheme.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.accentPrimary : AppTheme.textMuted,
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTheme.labelSm.copyWith(
                  color: AppTheme.accentPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.labelMd),
              Text(subtitle, style: AppTheme.bodySm),
            ],
          ),
        ),
      ],
    );
  }
}
