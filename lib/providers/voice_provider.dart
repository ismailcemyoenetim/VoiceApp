import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VoicePost {
  final String id;
  final String userId;
  final String username;
  final String? profilePicture;
  final String audioUrl;
  final String? description;
  final int duration; // in milliseconds
  final int likesCount;
  final int repostsCount;
  final int commentsCount;
  final bool isLikedByUser;
  final bool hasTranscription;
  final DateTime createdAt;

  VoicePost({
    required this.id,
    required this.userId,
    required this.username,
    this.profilePicture,
    required this.audioUrl,
    this.description,
    required this.duration,
    required this.likesCount,
    required this.repostsCount,
    required this.commentsCount,
    required this.isLikedByUser,
    required this.hasTranscription,
    required this.createdAt,
  });

  factory VoicePost.fromJson(Map<String, dynamic> json) {
    // Convert relative audio URL to full URL
    String audioUrl = json['audio_url'];
    if (audioUrl.startsWith('uploads/')) {
      // Convert relative path to full URL
      audioUrl = 'http://192.168.1.100:3000/$audioUrl';
    }
    
    // Helper function to safely convert to int
    int parseIntValue(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }
    
    return VoicePost(
      id: json['id'],
      userId: json['user_id'],
      username: json['username'],
      profilePicture: json['profile_picture'],
      audioUrl: audioUrl,
      description: json['description'],
      duration: parseIntValue(json['duration_ms']),
      likesCount: parseIntValue(json['likes_count']),
      repostsCount: parseIntValue(json['reposts_count']),
      commentsCount: parseIntValue(json['comments_count']),
      isLikedByUser: json['is_liked_by_user'] ?? false,
      hasTranscription: json['has_transcription'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'audio_url': audioUrl,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'duration_ms': duration,
      'likes_count': likesCount,
      'reposts_count': repostsCount,
      'comments_count': commentsCount,
      'profile_picture': profilePicture,
      'is_liked_by_user': isLikedByUser,
      'has_transcription': hasTranscription,
    };
  }
}

class VoiceTranscription {
  final String text;
  final String language;
  final double confidence;
  final String provider;
  final DateTime createdAt;

  VoiceTranscription({
    required this.text,
    required this.language,
    required this.confidence,
    required this.provider,
    required this.createdAt,
  });

  factory VoiceTranscription.fromJson(Map<String, dynamic> json) {
    // Safe parsing for confidence value (can be String or double)
    double parseConfidence(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }
    
    return VoiceTranscription(
      text: json['text'] ?? '',
      language: json['language'] ?? 'unknown',
      confidence: parseConfidence(json['confidence']),
      provider: json['provider'] ?? 'unknown',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

enum RecordingState {
  idle,
  recording,
  paused,
  stopped,
}

enum PlaybackState {
  idle,
  playing,
  paused,
  stopped,
}

class VoiceProvider extends ChangeNotifier {
  final Record _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  RecordingState _recordingState = RecordingState.idle;
  PlaybackState _playbackState = PlaybackState.idle;
  
  String? _currentRecordingPath;
  Duration _recordingDuration = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Timer? _recordingTimer;
  Timer? _amplitudeTimer;
  String? _currentPlayingPostId;
  
  double _currentAmplitude = 0.0;
  final List<double> _amplitudeHistory = [];
  static const int _maxAmplitudeHistory = 50;
  
  // Playback amplitude monitoring
  Timer? _playbackAmplitudeTimer;
  final List<double> _playbackAmplitudeHistory = [];
  
  List<VoicePost> _voicePosts = [];
  bool _hasPermission = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  RecordingState get recordingState => _recordingState;
  PlaybackState get playbackState => _playbackState;
  String? get currentRecordingPath => _currentRecordingPath;
  Duration get recordingDuration => _recordingDuration;
  Duration get playbackDuration => _playbackDuration;
  Duration get playbackPosition => _playbackPosition;
  List<VoicePost> get voicePosts => _voicePosts;
  bool get hasPermission => _hasPermission;
  bool get isRecording => _recordingState == RecordingState.recording;
  bool get isPlaying => _playbackState == PlaybackState.playing;
  String? get currentPlayingPostId => _currentPlayingPostId;
  double get currentAmplitude => _currentAmplitude;
  List<double> get amplitudeHistory => List.unmodifiable(_amplitudeHistory);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  VoiceProvider() {
    _initializeAudioPlayer();
    _checkPermissions();
    // Note: loadVoicePosts() will be called from MainFeedPage after auth is ready
  }

  void _initializeAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      _playbackDuration = duration;
      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((position) {
      _playbackPosition = position;
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _playbackState = PlaybackState.stopped;
      _playbackPosition = Duration.zero;
      _currentPlayingPostId = null;
      notifyListeners();
    });
  }

  Future<void> _checkPermissions() async {
    debugPrint('🔍 Checking microphone permissions...');
    
    if (Platform.isIOS) {
      // On iOS, use the record package as the primary source of truth
      try {
        final recordPermission = await _audioRecorder.hasPermission();
        debugPrint('🎙️ Record package permission status: $recordPermission');
        
        // Also check permission_handler for additional info
        final systemPermission = await Permission.microphone.status;
        debugPrint('📋 System permission status: $systemPermission');
        
        // Use record package as primary source since it's more reliable for audio recording
        _hasPermission = recordPermission;
        
      } catch (e) {
        debugPrint('❌ Error checking iOS permissions: $e');
        _hasPermission = false;
      }
    } else if (Platform.isAndroid) {
      final microphoneStatus = await Permission.microphone.status;
      debugPrint('📋 Android microphone status: $microphoneStatus');
      _hasPermission = microphoneStatus == PermissionStatus.granted;
    } else {
      _hasPermission = true; // Assume permission on desktop platforms
    }
    
    debugPrint('✅ Has permission: $_hasPermission');
    notifyListeners();
  }

  Future<bool> requestPermissions() async {
    debugPrint('🎙️ Requesting microphone permissions...');
    
    if (Platform.isIOS) {
      debugPrint('📱 iOS detected - requesting audio permission...');
      return await _requestIOSMicrophonePermission();
    } else if (Platform.isAndroid) {
      // Android logic
      final microphoneStatus = await Permission.microphone.status;
      debugPrint('🔍 Current microphone status: $microphoneStatus');
      
      if (microphoneStatus == PermissionStatus.granted) {
        debugPrint('✅ Permission already granted');
        _hasPermission = true;
        notifyListeners();
        return true;
      }
      
      // If permanently denied, we need to open app settings
      if (microphoneStatus == PermissionStatus.permanentlyDenied) {
        debugPrint('🚫 Permission permanently denied - need settings');
        _hasPermission = false;
        notifyListeners();
        return false;
      }
      
      // Request permission on Android
      debugPrint('🔄 Requesting Android permission...');
      final result = await Permission.microphone.request();
      debugPrint('📋 Permission request result: $result');
      _hasPermission = result == PermissionStatus.granted;
      notifyListeners();
      return _hasPermission;
    } else {
      debugPrint('💻 Desktop platform - assuming permission granted');
      _hasPermission = true;
      notifyListeners();
      return true;
    }
  }

  Future<bool> _requestIOSMicrophonePermission() async {
    debugPrint('🍎 iOS specific microphone permission request...');
    
    try {
      // First, check if we already have permission using the record package
      final recordHasPermission = await _audioRecorder.hasPermission();
      debugPrint('🔍 iOS Record package permission status: $recordHasPermission');
      
      if (recordHasPermission) {
        debugPrint('✅ iOS permission already granted via record package');
        _hasPermission = true;
        notifyListeners();
        return true;
      }
      
      // Try using permission_handler first as it's more standard
      debugPrint('🔄 Trying permission_handler request...');
      final systemResult = await Permission.microphone.request();
      debugPrint('📋 System permission request result: $systemResult');
      
      if (systemResult == PermissionStatus.granted) {
        debugPrint('✅ iOS permission granted via system dialog');
        _hasPermission = true;
        notifyListeners();
        return true;
      }
      
      // If system dialog failed, try the record package approach
      debugPrint('🎤 iOS - attempting to start recording to trigger permission dialog...');
      
      // Create a temporary recording path
      final directory = await getApplicationDocumentsDirectory();
      final tempPath = '${directory.path}/temp_permission_test.m4a';
      
      // Try to start recording - this will trigger the iOS permission dialog
      try {
        await _audioRecorder.start(path: tempPath);
        debugPrint('📋 iOS recording started successfully');
        
        // Stop recording immediately
        await _audioRecorder.stop();
        debugPrint('🛑 iOS recording stopped');
        
        // Delete the temporary file
        if (File(tempPath).existsSync()) {
          await File(tempPath).delete();
        }
        
        // Check permission again using both methods
        final recordPermissionAfter = await _audioRecorder.hasPermission();
        final systemPermissionAfter = await Permission.microphone.status;
        
        debugPrint('✅ iOS permission after recording attempt - Record: $recordPermissionAfter, System: $systemPermissionAfter');
        
        _hasPermission = recordPermissionAfter;
        notifyListeners();
        return recordPermissionAfter;
      } catch (e) {
        debugPrint('❌ iOS recording failed: $e');
        
        // Final check - sometimes permission is granted even if recording fails initially
        final finalRecordCheck = await _audioRecorder.hasPermission();
        debugPrint('🔍 Final record permission check: $finalRecordCheck');
        
        _hasPermission = finalRecordCheck;
        notifyListeners();
        return finalRecordCheck;
      }
    } catch (e) {
      debugPrint('❌ iOS permission request failed: $e');
      _hasPermission = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> goToAppSettings() async {
    debugPrint('🔧 Opening app settings...');
    
    if (Platform.isIOS || Platform.isAndroid) {
      try {
        final opened = await openAppSettings();
        debugPrint('📱 App settings opened: $opened');
        return opened;
      } catch (e) {
        debugPrint('❌ Failed to open app settings: $e');
        return false;
      }
    }
    
    return false;
  }

  Future<void> refreshPermissions() async {
    debugPrint('🔄 Refreshing permission status...');
    await _checkPermissions();
  }

  Future<PermissionStatus> getMicrophonePermissionStatus() async {
    debugPrint('🔍 Getting microphone permission status...');
    
    if (Platform.isIOS) {
      // Check both systems for iOS
      final recordPermission = await _audioRecorder.hasPermission();
      final systemPermission = await Permission.microphone.status;
      
      debugPrint('📋 iOS - Record: $recordPermission, System: $systemPermission');
      
      // If record package says we have permission, trust it
      if (recordPermission) {
        return PermissionStatus.granted;
      } else {
        return systemPermission;
      }
    } else if (Platform.isAndroid) {
      final status = await Permission.microphone.status;
      debugPrint('📋 Android microphone status: $status');
      return status;
    }
    
    return PermissionStatus.granted; // Assume granted on desktop platforms
  }

  Future<bool> repostPost(String postId) async {
    debugPrint('🔁 Reposting post: $postId');
    
    // For now, just show a success message
    // In a real app, you would send this to your backend
    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Update local post repost count
      final postIndex = _voicePosts.indexWhere((post) => post.id == postId);
      if (postIndex != -1) {
        final post = _voicePosts[postIndex];
        _voicePosts[postIndex] = VoicePost(
          id: post.id,
          userId: post.userId,
          username: post.username,
          audioUrl: post.audioUrl,
          description: post.description,
          createdAt: post.createdAt,
          duration: post.duration,
          likesCount: post.likesCount,
          repostsCount: post.repostsCount + 1,
          commentsCount: post.commentsCount,
          profilePicture: post.profilePicture,
          isLikedByUser: post.isLikedByUser,
          hasTranscription: post.hasTranscription,
        );
        
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Repost failed: $e');
      return false;
    }
  }

  // BACKEND INTEGRATION METHODS

  Future<void> loadVoicePosts({int page = 1, int limit = 20}) async {
    if (_isLoading && page == 1) return;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.getAllPosts(page: page, limit: limit);
      
      if (response['success'] == true) {
        final List<dynamic> postsData = response['data']['posts'];
        final List<VoicePost> posts = postsData.map((json) => VoicePost.fromJson(json)).toList();
        
        if (page == 1) {
          _voicePosts = posts;
        } else {
          _voicePosts.addAll(posts);
        }
        
        _isLoading = false;
        notifyListeners();
      } else {
        _errorMessage = response['message'] ?? 'Failed to load posts';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = 'Network error. Please check your connection.';
      }
      notifyListeners();
      debugPrint('Load posts error: $e');
    }
  }

  Future<bool> createPost({
    required String audioPath, 
    String? description,
    Duration? startTime,
    Duration? endTime,
  }) async {
    if (!File(audioPath).existsSync()) {
      _errorMessage = 'Audio file not found';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final audioFile = File(audioPath);
      
      // Calculate final duration based on trim parameters
      int durationMs;
      if (startTime != null && endTime != null) {
        durationMs = (endTime - startTime).inMilliseconds;
        debugPrint('🎵 Trimmed duration: ${durationMs}ms (${startTime.inSeconds}s to ${endTime.inSeconds}s)');
      } else {
        durationMs = _recordingDuration.inMilliseconds;
        debugPrint('🎵 Full duration: ${durationMs}ms');
      }
      
      final response = await ApiService.createPost(
        audioFile: audioFile,
        durationMs: durationMs,
        description: description,
      );

      if (response['success'] == true) {
        final newPost = VoicePost.fromJson(response['data']);
        _voicePosts.insert(0, newPost);
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to create post';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = 'Network error. Please check your connection.';
      }
      notifyListeners();
      debugPrint('Create post error: $e');
      return false;
    }
  }

  Future<bool> likePost(String postId) async {
    try {
      final response = await ApiService.likePost(postId);
      
      if (response['success'] == true) {
        // Update local post like count
        final postIndex = _voicePosts.indexWhere((post) => post.id == postId);
        if (postIndex != -1) {
          final post = _voicePosts[postIndex];
          final isLiked = response['liked'] ?? false;
          
          _voicePosts[postIndex] = VoicePost(
            id: post.id,
            userId: post.userId,
            username: post.username,
            audioUrl: post.audioUrl,
            description: post.description,
            createdAt: post.createdAt,
            duration: post.duration,
            likesCount: isLiked ? post.likesCount + 1 : post.likesCount - 1,
            repostsCount: post.repostsCount,
            commentsCount: post.commentsCount,
            profilePicture: post.profilePicture,
            isLikedByUser: isLiked,
            hasTranscription: post.hasTranscription,
          );
          
          notifyListeners();
        }
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to like post';
        notifyListeners();
        return false;
      }
    } catch (e) {
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = 'Network error. Please check your connection.';
      }
      notifyListeners();
      debugPrint('Like post error: $e');
      return false;
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      final response = await ApiService.deletePost(postId);
      
      if (response['success'] == true) {
        _voicePosts.removeWhere((post) => post.id == postId);
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to delete post';
        notifyListeners();
        return false;
      }
    } catch (e) {
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = 'Network error. Please check your connection.';
      }
      notifyListeners();
      debugPrint('Delete post error: $e');
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // RECORDING METHODS (keeping existing functionality)
  
  Future<bool> startRecording() async {
    if (!_hasPermission) {
      debugPrint('❌ No microphone permission');
      return false;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = '${directory.path}/$fileName';

      await _audioRecorder.start(path: _currentRecordingPath!);
      
      _recordingState = RecordingState.recording;
      _recordingDuration = Duration.zero;
      
      _startRecordingTimer();
      _startAmplitudeMonitoring();
      
      debugPrint('🎙️ Recording started: $_currentRecordingPath');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Recording start failed: $e');
      _recordingState = RecordingState.idle;
      notifyListeners();
      return false;
    }
  }

  Future<void> stopRecording() async {
    if (_recordingState != RecordingState.recording) return;

    try {
      await _audioRecorder.stop();
      _recordingState = RecordingState.stopped;
      _recordingTimer?.cancel();
      _amplitudeTimer?.cancel();
      
      debugPrint('🛑 Recording stopped');
      debugPrint('📁 File saved: $_currentRecordingPath');
      debugPrint('⏱️ Duration: ${_recordingDuration.inSeconds} seconds');
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Recording stop failed: $e');
      _recordingState = RecordingState.idle;
      notifyListeners();
    }
  }

  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _recordingDuration += const Duration(milliseconds: 100);
      notifyListeners();
    });
  }

  void _startAmplitudeMonitoring() {
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
      try {
        final amplitude = await _audioRecorder.getAmplitude();
        _currentAmplitude = amplitude.current;
        
        _amplitudeHistory.add(_currentAmplitude);
        if (_amplitudeHistory.length > _maxAmplitudeHistory) {
          _amplitudeHistory.removeAt(0);
        }
        
        notifyListeners();
      } catch (e) {
        debugPrint('Amplitude monitoring error: $e');
      }
    });
  }

  // PLAYBACK METHODS (keeping existing functionality)
  
  Future<void> playPost(String postId, String audioUrl) async {
    if (_playbackState == PlaybackState.playing) {
      await stopPlayback();
    }

    try {
      await _audioPlayer.play(UrlSource(audioUrl));
      _playbackState = PlaybackState.playing;
      _currentPlayingPostId = postId;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Playback failed: $e');
      _playbackState = PlaybackState.idle;
      _currentPlayingPostId = null;
      notifyListeners();
    }
  }

  Future<void> pausePlayback() async {
    if (_playbackState == PlaybackState.playing) {
      await _audioPlayer.pause();
      _playbackState = PlaybackState.paused;
      notifyListeners();
    }
  }

  Future<void> resumePlayback() async {
    if (_playbackState == PlaybackState.paused) {
      await _audioPlayer.resume();
      _playbackState = PlaybackState.playing;
      notifyListeners();
    }
  }

  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
    _playbackState = PlaybackState.stopped;
    _playbackPosition = Duration.zero;
    _currentPlayingPostId = null;
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      _playbackPosition = position;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Seek failed: $e');
    }
  }

  Future<void> playRecording([String? recordingPath]) async {
    final pathToPlay = recordingPath ?? _currentRecordingPath;
    if (pathToPlay == null) return;

    try {
      await _audioPlayer.play(DeviceFileSource(pathToPlay));
      _playbackState = PlaybackState.playing;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Recording playback failed: $e');
      _playbackState = PlaybackState.idle;
      notifyListeners();
    }
  }

  void resetRecording() {
    _currentRecordingPath = null;
    _recordingDuration = Duration.zero;
    _recordingState = RecordingState.idle;
    _amplitudeHistory.clear();
    _currentAmplitude = 0.0;
    notifyListeners();
  }

  // Update current recording path (used after applying voice effects)
  void updateCurrentRecordingPath(String newPath) {
    debugPrint('🎵 Updating currentRecordingPath from: $_currentRecordingPath');
    debugPrint('🎵 Updating currentRecordingPath to: $newPath');
    _currentRecordingPath = newPath;
    notifyListeners();
  }

  // Transcription functionality
  static const String _baseUrl = 'http://192.168.1.100:3000';
  
  Future<VoiceTranscription?> getTranscription(String postId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/posts/$postId/transcription'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return VoiceTranscription.fromJson(data['transcription']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting transcription: $e');
      return null;
    }
  }

  Future<bool> deleteTranscription(String postId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/posts/$postId/transcription'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting transcription: $e');
      return false;
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _amplitudeTimer?.cancel();
    _playbackAmplitudeTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
} 