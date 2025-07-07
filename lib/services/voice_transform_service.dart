import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class VoiceEffect {
  final String id;
  final String name;
  final String description;
  final bool isPaid;
  final String category;

  VoiceEffect({
    required this.id,
    required this.name,
    required this.description,
    this.isPaid = false,
    this.category = 'basic',
  });

  factory VoiceEffect.fromJson(Map<String, dynamic> json) {
    return VoiceEffect(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      isPaid: json['isPaid'] ?? false,
      category: json['category'] ?? 'basic',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isPaid': isPaid,
      'category': category,
    };
  }
}

class VoiceTransformResult {
  final bool success;
  final String message;
  final String? transformedFilePath;
  final double? originalDuration;
  final double? transformedDuration;
  final String? error;

  VoiceTransformResult({
    required this.success,
    required this.message,
    this.transformedFilePath,
    this.originalDuration,
    this.transformedDuration,
    this.error,
  });

  factory VoiceTransformResult.fromJson(Map<String, dynamic> json) {
    return VoiceTransformResult(
      success: json['success'],
      message: json['message'],
      transformedFilePath: json['transformed_file_path'],
      originalDuration: json['original_duration']?.toDouble(),
      transformedDuration: json['transformed_duration']?.toDouble(),
      error: json['error'],
    );
  }
}

class VoiceTransformService {
  // Change this to your actual voice transformation service URL
  static const String _baseUrl = 'http://192.168.1.100:8000';
  static const Duration _timeout = Duration(seconds: 30);

  // Available voice effects
  static final List<VoiceEffect> _effects = [
    VoiceEffect(
      id: 'robot',
      name: 'Robot',
      description: 'Robotic voice with vocoder effect',
      isPaid: false,
      category: 'basic',
    ),
    VoiceEffect(
      id: 'child',
      name: 'Child',
      description: 'Higher pitch child-like voice',
      isPaid: false,
      category: 'basic',
    ),
    VoiceEffect(
      id: 'deep',
      name: 'Deep',
      description: 'Deep, low-pitched voice',
      isPaid: false,
      category: 'basic',
    ),
    VoiceEffect(
      id: 'alien',
      name: 'Alien',
      description: 'Alien-like voice with modulation',
      isPaid: true,
      category: 'premium',
    ),
    VoiceEffect(
      id: 'whisper',
      name: 'Whisper',
      description: 'Whisper-like quiet voice',
      isPaid: true,
      category: 'premium',
    ),
    VoiceEffect(
      id: 'monster',
      name: 'Monster',
      description: 'Deep monster voice with distortion',
      isPaid: true,
      category: 'premium',
    ),
  ];

  /// Get all available voice effects
  static List<VoiceEffect> get effects => List.unmodifiable(_effects);

  /// Get free voice effects
  static List<VoiceEffect> get freeEffects => 
      _effects.where((effect) => !effect.isPaid).toList();

  /// Get premium voice effects
  static List<VoiceEffect> get premiumEffects => 
      _effects.where((effect) => effect.isPaid).toList();

  /// Check if voice transformation service is available
  static Future<bool> isServiceAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Voice transform service not available: $e');
      return false;
    }
  }

  /// Get available effects from the service
  static Future<List<VoiceEffect>> getAvailableEffects() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/effects'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final effects = data['effects'] as Map<String, dynamic>;
        
        // Convert to VoiceEffect objects
        return effects.entries.map((entry) {
          final effectData = entry.value as Map<String, dynamic>;
          return VoiceEffect(
            id: entry.key,
            name: _formatEffectName(entry.key),
            description: effectData['description'] ?? '',
            isPaid: _isPaidEffect(entry.key),
            category: _isPaidEffect(entry.key) ? 'premium' : 'basic',
          );
        }).toList();
      }
      
      // Fallback to local effects if service is unavailable
      return _effects;
    } catch (e) {
      debugPrint('Error fetching effects: $e');
      return _effects;
    }
  }

  /// Transform audio with specified effect
  static Future<VoiceTransformResult> transformAudio({
    required String audioFilePath,
    required String effectId,
    double intensity = 1.0,
  }) async {
    try {
      debugPrint('🎵 Starting voice transformation...');
      debugPrint('🎵 Audio file: $audioFilePath');
      debugPrint('🎵 Effect: $effectId');
      debugPrint('🎵 Intensity: $intensity');
      
      // Validate input file
      final audioFile = File(audioFilePath);
      if (!audioFile.existsSync()) {
        return VoiceTransformResult(
          success: false,
          message: 'Audio file not found',
          error: 'File does not exist: $audioFilePath',
        );
      }

      // Prepare multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/transform'),
      );

      // Add form fields
      request.fields['effect'] = effectId;
      request.fields['intensity'] = intensity.toString();

      // Add audio file
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioFilePath,
          filename: path.basename(audioFilePath),
        ),
      );

      debugPrint('🎵 Sending request to voice transformation service...');
      
      // Send request
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('🎵 Response status: ${response.statusCode}');
      debugPrint('🎵 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          // Download the transformed file
          final downloadUrl = data['transformed_file_url'];
          final localPath = await _downloadTransformedFile(downloadUrl);
          
          return VoiceTransformResult(
            success: true,
            message: data['message'],
            transformedFilePath: localPath,
            originalDuration: data['original_duration']?.toDouble(),
            transformedDuration: data['transformed_duration']?.toDouble(),
          );
        } else {
          return VoiceTransformResult(
            success: false,
            message: data['message'] ?? 'Transformation failed',
            error: data['error'],
          );
        }
      } else {
        return VoiceTransformResult(
          success: false,
          message: 'Service error: ${response.statusCode}',
          error: response.body,
        );
      }
    } catch (e) {
      debugPrint('❌ Voice transformation error: $e');
      return VoiceTransformResult(
        success: false,
        message: 'Network error occurred',
        error: e.toString(),    );
    }
  }

  /// Download transformed file from service
  static Future<String> _downloadTransformedFile(String downloadUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$downloadUrl'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        // Save to local storage
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'transformed_${DateTime.now().millisecondsSinceEpoch}.wav';
        final localPath = path.join(directory.path, fileName);
        
        final localFile = File(localPath);
        await localFile.writeAsBytes(response.bodyBytes);
        
        debugPrint('✅ Transformed file saved: $localPath');
        return localPath;
      } else {
        throw Exception('Failed to download transformed file: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error downloading transformed file: $e');
      rethrow;
    }
  }

  /// Preview audio effect without saving
  static Future<VoiceTransformResult> previewEffect({
    required String audioFilePath,
    required String effectId,
    double intensity = 1.0,
  }) async {
    // For preview, we can use the same transform method but with a flag
    // indicating it's a preview (you might want to implement a separate preview endpoint)
    return transformAudio(
      audioFilePath: audioFilePath,
      effectId: effectId,
      intensity: intensity,
    );
  }

  /// Clean up temporary files
  static Future<void> cleanupTransformedFile(String filePath) async {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
        debugPrint('🗑️ Cleaned up transformed file: $filePath');
      }
    } catch (e) {
      debugPrint('⚠️ Error cleaning up file: $e');
    }
  }

  /// Check if user has access to premium effects
  static bool hasPremiumAccess() {
    // TODO: Implement premium access check
    // This could check user subscription status, in-app purchases, etc.
    return false; // Default to no premium access
  }

  /// Purchase premium access
  static Future<bool> purchasePremiumAccess() async {
    // TODO: Implement in-app purchase logic
    // This would integrate with your payment system
    return false;
  }

  // Helper methods
  static String _formatEffectName(String effectId) {
    switch (effectId) {
      case 'robot':
        return 'Robot';
      case 'child':
        return 'Child';
      case 'deep':
        return 'Deep';
      case 'alien':
        return 'Alien';
      case 'whisper':
        return 'Whisper';
      case 'monster':
        return 'Monster';
      default:
        return effectId.split('_').map((word) => 
          word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }

  static bool _isPaidEffect(String effectId) {
    const paidEffects = ['alien', 'whisper', 'monster'];
    return paidEffects.contains(effectId);
  }
} 