import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/job.dart';
import '../services/api_service.dart';

/// Manages job lifecycle: creation, polling, and state updates.
///
/// Uses ChangeNotifier for Riverpod-compatible state management.
class JobProvider extends ChangeNotifier {
  final ApiService _api;

  Job? _currentJob;
  final List<Job> _recentJobs = [];
  bool _isCreating = false;
  String? _error;
  Timer? _pollTimer;

  JobProvider({ApiService? apiService})
      : _api = apiService ?? ApiService();

  // ── Getters ───────────────────────────────────────────────────────────
  Job? get currentJob => _currentJob;
  List<Job> get recentJobs => _recentJobs;
  bool get isCreating => _isCreating;
  String? get error => _error;
  bool get isProcessing => _currentJob?.isProcessing ?? false;
  bool get isReady => _currentJob?.isReady ?? false;

  // ── Job Creation ──────────────────────────────────────────────────────

  /// Create a new job from a YouTube URL.
  Future<void> createJob(String youtubeUrl) async {
    _isCreating = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.createJob(youtubeUrl);
      final jobId = response['job_id'] as String;

      // Fetch initial state
      await refreshJob(jobId);

      // Start polling for updates
      _startPolling(jobId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  // ── Job Refresh ───────────────────────────────────────────────────────

  /// Fetch the latest state of a job.
  Future<void> refreshJob(String jobId) async {
    try {
      final data = await _api.getJob(jobId);
      _currentJob = Job.fromJson(data);
      _error = null;
      
      // Update in recent jobs list
      final idx = _recentJobs.indexWhere((j) => j.id == jobId);
      if (idx != -1) {
        _recentJobs[idx] = _currentJob!;
      } else {
        _recentJobs.insert(0, _currentJob!);
      }
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  /// Set the active job (e.g., when selected from Projects list).
  void setCurrentJob(Job job) {
    _currentJob = job;
    _error = null;

    // Add or update in recent jobs list
    final idx = _recentJobs.indexWhere((j) => j.id == job.id);
    if (idx != -1) {
      _recentJobs[idx] = job;
    } else {
      _recentJobs.insert(0, job);
    }

    notifyListeners();

    // If the job is still processing, resume polling
    if (job.isProcessing) {
      _startPolling(job.id);
    } else {
      _stopPolling();
    }
  }

  // ── Polling ───────────────────────────────────────────────────────────

  void _startPolling(String jobId) {
    _stopPolling();

    // Poll every 3 seconds with exponential backoff
    int interval = 3;
    _pollTimer = Timer.periodic(Duration(seconds: interval), (timer) async {
      await refreshJob(jobId);

      // Stop polling when job reaches a terminal state
      if (_currentJob != null && !_currentJob!.isProcessing) {
        _stopPolling();
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ── Render ────────────────────────────────────────────────────────────

  /// Request a clip render for the current job.
  Future<Map<String, dynamic>?> renderClip(
    Map<String, dynamic> renderConfig,
  ) async {
    if (_currentJob == null) return null;

    try {
      final response = await _api.renderClip(
        _currentJob!.id,
        renderConfig,
      );
      return response;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Fetch list of rendered clips for the current job.
  Future<List<ClipInfo>> getClips() async {
    if (_currentJob == null) return [];

    try {
      final data = await _api.getClips(_currentJob!.id);
      final clipsList = data['clips'] as List<dynamic>? ?? [];
      return clipsList
          .map((c) => ClipInfo.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────

  Future<void> deleteJob(String jobId) async {
    try {
      await _api.deleteJob(jobId);
      if (_currentJob?.id == jobId) {
        _currentJob = null;
      }
      _recentJobs.removeWhere((j) => j.id == jobId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
