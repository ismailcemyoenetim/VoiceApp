import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import 'dart:ui';
import '../../providers/voice_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glassmorphism_widgets.dart';
import 'voice_edit_page.dart';
import 'voice_effects_page.dart';

class VoiceRecordPage extends StatefulWidget {
  const VoiceRecordPage({super.key});

  @override
  State<VoiceRecordPage> createState() => _VoiceRecordPageState();
}

class _VoiceRecordPageState extends State<VoiceRecordPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveformController;
  final TextEditingController _descriptionController = TextEditingController();
  
  // Timeline editing state
  double _trimStart = 0.0;
  double _trimEnd = 1.0;
  double _playheadPosition = 0.0;
  bool _isEditingMode = false;
  bool _isPrecisionMode = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveformController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;
    
    if (_isPrecisionMode) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}.${(milliseconds ~/ 10).toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Duration _getTrimmedDuration(Duration totalDuration) {
    final startMs = (totalDuration.inMilliseconds * _trimStart).round();
    final endMs = (totalDuration.inMilliseconds * _trimEnd).round();
    return Duration(milliseconds: endMs - startMs);
  }

  Future<void> _showVoiceEditDialog(BuildContext context) async {
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    
    if (voiceProvider.currentRecordingPath == null) {
      GlassmorphismSnackBar.show(
        context,
        message: 'No recording available to edit',
        icon: Icons.error,
      );
      return;
    }

    debugPrint('🎵 About to show voice edit dialog...');
    
    // Wait a bit for context to stabilize
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      await _showVoiceEditPage(context, voiceProvider.currentRecordingPath!);
    } else {
      debugPrint('❌ Context not mounted, cannot show voice editor');
    }
  }

  Future<void> _showVoiceEditPage(BuildContext context, String audioPath) async {
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    
    debugPrint('🎵 Showing voice edit page for: $audioPath');
    
    // Ensure context is mounted before navigation
    if (!mounted) {
      debugPrint('❌ Widget not mounted, cannot show voice editor');
      return;
    }
    
    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          VoiceEditPage(
            audioPath: audioPath,
            originalDuration: voiceProvider.recordingDuration,
          ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    
    debugPrint('🎵 Voice edit result: $result');
    
    if (result != null && result['confirmed'] == true) {
      // User confirmed the edit
      debugPrint('🎵 User confirmed voice edit');
      
      // Get edit parameters
      final startTime = result['startTime'] as Duration;
      final endTime = result['endTime'] as Duration;
      final originalPath = result['originalPath'] as String;
      
      debugPrint('🎵 Edit parameters: start=$startTime, end=$endTime');
      
      // Show save dialog with edited audio
      if (mounted) {
        await _showSaveDialog(context, 
          editedAudioPath: originalPath,
          startTime: startTime,
          endTime: endTime,
        );
      }
    } else {
      debugPrint('🎵 User cancelled voice edit');
    }
  }

  Future<void> _showSaveDialog(BuildContext context, {
    String? editedAudioPath,
    Duration? startTime,
    Duration? endTime,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassmorphismContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Save Voice Post',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                GlassmorphismContainer(
                  padding: const EdgeInsets.all(12),
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'What would you like to share?',
                      border: InputBorder.none,
                      labelStyle: TextStyle(color: Colors.white70),
                      hintStyle: TextStyle(color: Colors.white60),
                    ),
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    maxLength: 280,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GlassmorphismButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassmorphismButton(
                        onPressed: () async {
                          // Check authentication first
                          if (!authProvider.isAuthenticated) {
                            Navigator.of(context).pop();
                            GlassmorphismSnackBar.show(
                              context,
                              message: 'Please sign in to save voice posts',
                              icon: Icons.account_circle_outlined,
                            );
                            context.go('/auth/login');
                            return;
                          }
                          
                          if (voiceProvider.currentRecordingPath != null) {
                            String finalAudioPath = voiceProvider.currentRecordingPath!;
                            
                            // If we have edit parameters, create trimmed version
                            if (editedAudioPath != null && startTime != null && endTime != null) {
                              debugPrint('🎵 Creating trimmed audio: $startTime to $endTime');
                              // For now, we'll pass the trim parameters to createPost
                              // In a real implementation, you'd actually trim the audio file here
                              finalAudioPath = editedAudioPath;
                            }
                            
                            final success = await voiceProvider.createPost(
                              audioPath: finalAudioPath,
                              description: _descriptionController.text.isNotEmpty
                                  ? _descriptionController.text
                                  : null,
                              startTime: startTime,
                              endTime: endTime,
                            );
                            
                            if (mounted) {
                              Navigator.of(context).pop();
                              if (success) {
                                voiceProvider.resetRecording();
                                context.go('/feed');
                                GlassmorphismSnackBar.show(
                                  context,
                                  message: 'Voice post uploaded! 🎙️',
                                  icon: Icons.mic,
                                );
                              } else {
                                final errorMessage = voiceProvider.errorMessage ?? 'Failed to upload voice post';
                                GlassmorphismSnackBar.show(
                                  context,
                                  message: errorMessage,
                                  icon: Icons.error_outline,
                                );
                                voiceProvider.clearError();
                              }
                            }
                          }
                        },
                        child: const Text(
                          'Save Post',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showVoiceEffectsDialog(BuildContext context) async {
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    
    if (voiceProvider.currentRecordingPath == null) {
      GlassmorphismSnackBar.show(
        context,
        message: 'No recording available for effects',
        icon: Icons.error,
      );
      return;
    }

    debugPrint('🎵 About to show voice effects dialog...');
    
    // Wait a bit for context to stabilize
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      await _showVoiceEffectsPage(context, voiceProvider.currentRecordingPath!);
    } else {
      debugPrint('❌ Context not mounted, cannot show voice effects');
    }
  }

  Future<void> _showVoiceEffectsPage(BuildContext context, String audioPath) async {
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    
    debugPrint('🎵 Showing voice effects page for: $audioPath');
    
    // Ensure context is mounted before navigation
    if (!mounted) {
      debugPrint('❌ Widget not mounted, cannot show voice effects');
      return;
    }
    
    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          VoiceEffectsPage(
            audioPath: audioPath,
            originalDuration: voiceProvider.recordingDuration,
          ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    
    debugPrint('🎵 Voice effects result: $result');
    
    if (result != null && result['confirmed'] == true) {
      // User confirmed the effects
      debugPrint('🎵 User confirmed voice effects');
      
      // Get transformed audio path
      final transformedPath = result['transformedPath'] as String;
      final effectId = result['effectId'] as String;
      final intensity = result['intensity'] as double;
      
      debugPrint('🎵 Effect applied: $effectId with intensity $intensity');
      debugPrint('🎵 Transformed path: $transformedPath');
      
      // Update the current recording path to the transformed file
      voiceProvider.updateCurrentRecordingPath(transformedPath);
      
      debugPrint('🎵 Updated currentRecordingPath to transformed file');
      
      // Show success message
      if (mounted) {
        GlassmorphismSnackBar.show(
          context,
          message: 'Effect applied! ($effectId)',
          icon: Icons.auto_fix_high,
        );
      }
    } else {
      debugPrint('🎵 User cancelled voice effects');
    }
  }

    Future<void> _showPermissionDialog(BuildContext context) async {
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    final permissionStatus = await Permission.microphone.status;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassmorphismContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.mic_off,
                  color: Colors.orange,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Microphone Permission Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  permissionStatus == PermissionStatus.permanentlyDenied
                      ? 'Microphone access has been permanently denied. Please enable it in your device settings to record voice posts.'
                      : 'This app needs access to your microphone to record voice posts. Please grant permission to continue.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GlassmorphismButton(
                        onPressed: () => Navigator.of(context).pop(),
                        backgroundColor: Colors.grey.withOpacity(0.3),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassmorphismButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          
                          debugPrint('🎙️ Permission dialog button pressed');
                          debugPrint('📋 Current permission status: $permissionStatus');
                          
                          if (permissionStatus == PermissionStatus.permanentlyDenied) {
                            // Open app settings
                            debugPrint('🔧 Opening app settings...');
                            final opened = await voiceProvider.goToAppSettings();
                            debugPrint('📱 App settings opened: $opened');
                            if (mounted && opened) {
                              GlassmorphismSnackBar.show(
                                context,
                                message: 'Please enable microphone access in settings',
                                icon: Icons.settings,
                              );
                            }
                          } else {
                            // Request permission
                            debugPrint('🔄 Requesting permission...');
                            final granted = await voiceProvider.requestPermissions();
                            debugPrint('✅ Permission granted: $granted');
                            
                            // Wait a bit and refresh the permission status
                            await Future.delayed(const Duration(milliseconds: 200));
                            await voiceProvider.refreshPermissions();
                            
                            // Use a delay to ensure the dialog is fully closed
                            await Future.delayed(const Duration(milliseconds: 300));
                            
                            if (mounted) {
                              if (granted) {
                                GlassmorphismSnackBar.show(
                                  context,
                                  message: 'Microphone access granted! 🎙️',
                                  icon: Icons.mic,
                                );
                              } else {
                                // Check status again after request
                                final newStatus = await voiceProvider.getMicrophonePermissionStatus();
                                debugPrint('📋 New permission status after request: $newStatus');
                                
                                if (newStatus == PermissionStatus.permanentlyDenied) {
                                  // Show a dialog to go to settings
                                  if (mounted) {
                                    await _showSettingsDialog(context);
                                  }
                                } else {
                                  GlassmorphismSnackBar.show(
                                    context,
                                    message: 'Microphone access denied - try again or use Settings',
                                    icon: Icons.mic_off,
                                  );
                                }
                              }
                            }
                          }
                        },
                        child: Text(
                          permissionStatus == PermissionStatus.permanentlyDenied
                              ? 'Open Settings'
                              : 'Grant Permission',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassmorphismContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.settings,
                  color: Colors.blue,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Settings Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Microphone access has been permanently denied. Please enable it manually in your device settings:\n\nSettings > Privacy > Microphone > Resonance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GlassmorphismButton(
                        onPressed: () => Navigator.of(context).pop(),
                        backgroundColor: Colors.grey.withOpacity(0.3),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassmorphismButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          
                          debugPrint('🔧 Opening app settings from settings dialog...');
                          final opened = await voiceProvider.goToAppSettings();
                          debugPrint('📱 App settings opened: $opened');
                          
                          if (mounted) {
                            GlassmorphismSnackBar.show(
                              context,
                              message: 'Please enable microphone access in settings',
                              icon: Icons.settings,
                            );
                          }
                        },
                        child: const Text(
                          'Open Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassmorphismAppBar(
        title: _isEditingMode ? 'Edit Voice' : 'Record Voice',
        centerTitle: true,
        actions: [
          if (_isEditingMode)
            IconButton(
              icon: Icon(_isPrecisionMode ? Icons.timer : Icons.precision_manufacturing),
              onPressed: () => setState(() => _isPrecisionMode = !_isPrecisionMode),
            ),
        ],
      ),
      body: Consumer<VoiceProvider>(
        builder: (context, voiceProvider, child) {
          if (voiceProvider.isRecording) {
            _pulseController.repeat();
          } else {
            _pulseController.stop();
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16, 
              MediaQuery.of(context).padding.top + kToolbarHeight + 20,
              16, 
              MediaQuery.of(context).padding.bottom + 20,
            ),
            child: Column(
              children: [
                // Header with Creator Search (TikTok-style)
                if (!_isEditingMode && voiceProvider.recordingState == RecordingState.idle)
                  _buildSearchHeader(),
                
                // Recording Status
                _buildRecordingStatus(voiceProvider, isDark),
                
                // Main Content Area
                Expanded(
                  child: _isEditingMode 
                    ? _buildEditingInterface(voiceProvider, isDark)
                    : _buildRecordingInterface(voiceProvider, isDark),
                ),
                
                // Bottom Controls (TikTok-style)
                _buildBottomControls(voiceProvider, isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassmorphismContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        borderRadius: BorderRadius.circular(25),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.white60, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Search voices and creators...',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingStatus(VoiceProvider voiceProvider, bool isDark) {
    return Column(
      children: [
        Text(
          _isEditingMode
              ? 'Editing • ${_formatDuration(_getTrimmedDuration(voiceProvider.recordingDuration))}'
              : voiceProvider.recordingState == RecordingState.idle
                  ? 'Tap to start recording'
                  : voiceProvider.recordingState == RecordingState.recording
                      ? 'Recording your voice...'
                      : 'Recording complete!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        if (!_isEditingMode)
          GlassmorphismContainer(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.black,
            child: Text(
              'Max 15 seconds',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecordingInterface(VoiceProvider voiceProvider, bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 40),
        
        // Recording Button
        Center(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: voiceProvider.isRecording
                    ? 1.0 + (_pulseController.value * 0.1)
                    : 1.0,
                child: GestureDetector(
                  onTap: () async {
                    if (voiceProvider.recordingState == RecordingState.idle) {
                      await voiceProvider.startRecording();
                    } else if (voiceProvider.recordingState == RecordingState.recording) {
                      await voiceProvider.stopRecording();
                    }
                  },
                  child: GlassmorphismContainer(
                    width: 120,
                    height: 120,
                    borderRadius: BorderRadius.circular(60),
                    backgroundColor: voiceProvider.isRecording
                        ? Colors.red.withOpacity(0.8)
                        : Colors.black,
                    child: Icon(
                      voiceProvider.recordingState == RecordingState.recording
                          ? Icons.stop
                          : Icons.mic,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Waveform Display
        if (voiceProvider.recordingState != RecordingState.idle)
          _buildWaveformDisplay(voiceProvider),
        
        const Spacer(),
        
        // Duration and Progress
        if (voiceProvider.recordingState != RecordingState.idle) ...[
          Text(
            _formatDuration(voiceProvider.recordingDuration),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: voiceProvider.isRecording
                  ? Colors.red
                  : isDark 
                    ? Colors.white.withOpacity(0.8)
                    : Colors.black.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: voiceProvider.recordingDuration.inSeconds / 15.0,
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              voiceProvider.recordingDuration.inSeconds >= 13
                  ? Colors.red
                  : Colors.black,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditingInterface(VoiceProvider voiceProvider, bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 20),
        
        // Professional Timeline
        _buildProfessionalTimeline(voiceProvider),
        
        const SizedBox(height: 20),
        
        // Precision Controls
        _buildPrecisionControls(voiceProvider),
        
        const SizedBox(height: 20),
        
        // Advanced Waveform
        _buildAdvancedWaveform(voiceProvider),
        
        const Spacer(),
        
        // Edit Tools
        _buildEditTools(voiceProvider),
      ],
    );
  }

  Widget _buildProfessionalTimeline(VoiceProvider voiceProvider) {
    final duration = voiceProvider.recordingDuration;
    final totalMs = duration.inMilliseconds.toDouble();
    
    return GlassmorphismContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          // Timeline Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(Duration(milliseconds: (totalMs * _trimStart).round())),
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                'Timeline',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                _formatDuration(Duration(milliseconds: (totalMs * _trimEnd).round())),
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Timeline Visualization
          Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black.withOpacity(0.3),
            ),
            child: Stack(
              children: [
                // Waveform background
                CustomPaint(
                  painter: TimelineWavePainter(
                    amplitudeHistory: voiceProvider.amplitudeHistory,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                
                // Trim selection
                Positioned(
                  left: _trimStart * MediaQuery.of(context).size.width * 0.8,
                  width: (_trimEnd - _trimStart) * MediaQuery.of(context).size.width * 0.8,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                
                // Playhead
                Positioned(
                  left: _playheadPosition * MediaQuery.of(context).size.width * 0.8,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Trim Controls
          Row(
            children: [
              Icon(Icons.content_cut, color: Colors.white70, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: RangeSlider(
                  values: RangeValues(_trimStart, _trimEnd),
                  onChanged: (values) {
                    setState(() {
                      _trimStart = values.start;
                      _trimEnd = values.end;
                    });
                  },
                  activeColor: Colors.white,
                  inactiveColor: Colors.white30,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.content_cut, color: Colors.white70, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrecisionControls(VoiceProvider voiceProvider) {
    return GlassmorphismContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Precision Controls',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Switch(
                value: _isPrecisionMode,
                onChanged: (value) => setState(() => _isPrecisionMode = value),
                activeColor: Colors.white,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (_isPrecisionMode) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPrecisionButton(Icons.remove, 'Trim -10ms', () {
                  setState(() {
                    _trimStart = (_trimStart + 0.01).clamp(0.0, _trimEnd - 0.01);
                  });
                }),
                _buildPrecisionButton(Icons.add, 'Trim +10ms', () {
                  setState(() {
                    _trimEnd = (_trimEnd - 0.01).clamp(_trimStart + 0.01, 1.0);
                  });
                }),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPrecisionButton(Icons.skip_previous, 'Start -100ms', () {
                  setState(() {
                    _trimStart = (_trimStart - 0.01).clamp(0.0, _trimEnd - 0.01);
                  });
                }),
                _buildPrecisionButton(Icons.skip_next, 'End +100ms', () {
                  setState(() {
                    _trimEnd = (_trimEnd + 0.01).clamp(_trimStart + 0.01, 1.0);
                  });
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrecisionButton(IconData icon, String label, VoidCallback onPressed) {
    return GlassmorphismContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: BorderRadius.circular(20),
      backgroundColor: Colors.black.withOpacity(0.3),
      child: InkWell(
        onTap: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedWaveform(VoiceProvider voiceProvider) {
    return GlassmorphismContainer(
      height: 120,
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Waveform',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  Icon(Icons.zoom_in, color: Colors.white70, size: 16),
                  SizedBox(width: 4),
                  Text('Zoom', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Expanded(
            child: AnimatedBuilder(
              animation: _waveformController,
              builder: (context, child) {
                return CustomPaint(
                  painter: AdvancedWavePainter(
                    amplitudeHistory: voiceProvider.amplitudeHistory,
                    currentAmplitude: voiceProvider.currentAmplitude,
                    isRecording: voiceProvider.isRecording,
                    isPlaying: voiceProvider.isPlaying,
                    trimStart: _trimStart,
                    trimEnd: _trimEnd,
                    playheadPosition: _playheadPosition,
                    animationValue: _waveformController.value,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditTools(VoiceProvider voiceProvider) {
    return GlassmorphismContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          Text(
            'Edit Tools',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildEditTool(Icons.content_cut, 'Cut', () {
                // Apply trim
                final duration = voiceProvider.recordingDuration;
                final startTime = Duration(milliseconds: (duration.inMilliseconds * _trimStart).round());
                final endTime = Duration(milliseconds: (duration.inMilliseconds * _trimEnd).round());
                
                debugPrint('🎵 Applying trim: ${_formatDuration(startTime)} to ${_formatDuration(endTime)}');
                
                // Here you would apply the actual trim
                setState(() {
                  _isEditingMode = false;
                });
              }),
              _buildEditTool(Icons.auto_fix_high, 'Effects', () => _showVoiceEffectsDialog(context)),
              _buildEditTool(Icons.volume_up, 'Volume', () {
                // Volume adjustment
              }),
              _buildEditTool(Icons.speed, 'Speed', () {
                // Speed adjustment
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditTool(IconData icon, String label, VoidCallback onPressed) {
    return GlassmorphismContainer(
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(50),
      backgroundColor: Colors.black.withOpacity(0.3),
      child: InkWell(
        onTap: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(VoiceProvider voiceProvider, bool isDark) {
    if (voiceProvider.recordingState == RecordingState.stopped && !_isEditingMode) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Play/Pause
          _buildBottomControlButton(
            icon: voiceProvider.isPlaying ? Icons.pause : Icons.play_arrow,
            label: voiceProvider.isPlaying ? 'Pause' : 'Play',
            onPressed: () {
              if (voiceProvider.currentRecordingPath != null) {
                voiceProvider.playRecording(voiceProvider.currentRecordingPath!);
              }
            },
          ),
          
          // Edit
          _buildBottomControlButton(
            icon: Icons.edit,
            label: 'Edit',
            onPressed: () => setState(() => _isEditingMode = true),
          ),
          
          // Effects
          _buildBottomControlButton(
            icon: Icons.auto_fix_high,
            label: 'Effects',
            onPressed: () => _showVoiceEffectsDialog(context),
          ),
          
          // Save
          _buildBottomControlButton(
            icon: Icons.check,
            label: 'Save',
            onPressed: () => _showSaveDialog(context),
          ),
          
          // Delete
          _buildBottomControlButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            onPressed: () => voiceProvider.resetRecording(),
          ),
        ],
      );
    }
    
    if (_isEditingMode) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Cancel
          _buildBottomControlButton(
            icon: Icons.close,
            label: 'Cancel',
            onPressed: () => setState(() => _isEditingMode = false),
          ),
          
          // Reset
          _buildBottomControlButton(
            icon: Icons.refresh,
            label: 'Reset',
            onPressed: () => setState(() {
              _trimStart = 0.0;
              _trimEnd = 1.0;
              _playheadPosition = 0.0;
            }),
          ),
          
          // Apply
          _buildBottomControlButton(
            icon: Icons.check,
            label: 'Apply',
            onPressed: () => setState(() => _isEditingMode = false),
          ),
        ],
      );
    }
    
    return Container();
  }

  Widget _buildBottomControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GlassmorphismContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(25),
      backgroundColor: Colors.black.withOpacity(0.3),
      child: InkWell(
        onTap: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveformDisplay(VoiceProvider voiceProvider) {
    return GlassmorphismContainer(
      height: 100,
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(15),
      child: CustomPaint(
        painter: SoundWavePainter(
          isRecording: voiceProvider.isRecording,
          isPlaying: voiceProvider.isPlaying,
          color: Colors.white,
          amplitudeHistory: voiceProvider.amplitudeHistory,
          currentAmplitude: voiceProvider.currentAmplitude,
        ),
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}

/// Modern professional waveform painter inspired by premium audio apps
class SoundWavePainter extends CustomPainter {
  final bool isRecording;
  final bool isPlaying;
  final Color color;
  final List<double> amplitudeHistory;
  final double currentAmplitude;

  SoundWavePainter({
    required this.isRecording,
    required this.isPlaying,
    required this.color,
    required this.amplitudeHistory,
    required this.currentAmplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Professional waveform settings
    final barWidth = 3.0;
    final barSpacing = 2.0;
    final totalBarWidth = barWidth + barSpacing;
    final maxBars = (size.width / totalBarWidth).floor();
    final centerY = size.height / 2;

    // Create gradient colors for modern look
    final List<Color> gradientColors = isRecording 
        ? [
            Color(0xFF8B5CF6), // Purple
            Color(0xFFA78BFA), // Light purple
            Color(0xFFFBBF24), // Yellow (for peaks)
          ]
        : [
            Color(0xFF6B7280), // Gray
            Color(0xFF9CA3AF), // Light gray
            Color(0xFFD1D5DB), // Very light gray
          ];

    if ((isRecording || isPlaying) && amplitudeHistory.isNotEmpty) {
      // Real-time waveform visualization
      _drawRealTimeWaveform(canvas, size, maxBars, barWidth, totalBarWidth, centerY, gradientColors);
    } else {
      // Static elegant waveform
      _drawStaticWaveform(canvas, size, maxBars, barWidth, totalBarWidth, centerY, gradientColors);
    }
  }

  void _drawRealTimeWaveform(Canvas canvas, Size size, int maxBars, double barWidth, 
      double totalBarWidth, double centerY, List<Color> gradientColors) {
    
    for (int i = 0; i < maxBars; i++) {
      final x = i * totalBarWidth + barWidth / 2;
      
      // Get amplitude from history
      double amplitude = 0.0;
      if (amplitudeHistory.isNotEmpty) {
        final historyIndex = amplitudeHistory.length - maxBars + i;
        if (historyIndex >= 0 && historyIndex < amplitudeHistory.length) {
          amplitude = amplitudeHistory[historyIndex];
        }
      }
      
      // Calculate bar height with minimum and maximum constraints
      final minHeight = size.height * 0.05;
      final maxHeight = size.height * 0.9;
      final barHeight = max(minHeight, min(amplitude * maxHeight, maxHeight));
      
      // Color based on amplitude intensity
      Color barColor;
      if (amplitude > 0.7) {
        barColor = gradientColors[2]; // Peak color
      } else if (amplitude > 0.4) {
        barColor = gradientColors[1]; // Mid color
      } else {
        barColor = gradientColors[0]; // Base color
      }
      
      // Add opacity based on recency (recent bars are more opaque)
      final recency = i / maxBars;
      final opacity = isRecording ? (0.4 + 0.6 * recency) : 0.6;
      
      final paint = Paint()
        ..color = barColor.withOpacity(opacity)
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      // Draw symmetrical bar from center
      final barTop = centerY - barHeight / 2;
      final barBottom = centerY + barHeight / 2;
      
      canvas.drawLine(
        Offset(x, barTop),
        Offset(x, barBottom),
        paint,
      );
      
      // Add glow effect for recent high-amplitude bars
      if (isRecording && i >= maxBars - 10 && amplitude > 0.5) {
        final glowPaint = Paint()
          ..color = barColor.withOpacity(0.3)
          ..strokeWidth = barWidth + 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        
        canvas.drawLine(
          Offset(x, barTop),
          Offset(x, barBottom),
          glowPaint,
        );
      }
    }
  }

  void _drawStaticWaveform(Canvas canvas, Size size, int maxBars, double barWidth, 
      double totalBarWidth, double centerY, List<Color> gradientColors) {
    
    final time = DateTime.now().millisecondsSinceEpoch * 0.001;
    
    for (int i = 0; i < maxBars; i++) {
      final x = i * totalBarWidth + barWidth / 2;
      final normalizedPosition = i / maxBars;
      
      // Create elegant static wave pattern
      final wave1 = sin(normalizedPosition * 2 * pi + time * 0.5);
      final wave2 = sin(normalizedPosition * 4 * pi + time * 0.3) * 0.5;
      final wave3 = sin(normalizedPosition * 8 * pi + time * 0.2) * 0.25;
      
      final amplitude = (0.3 + 0.4 * (wave1 + wave2 + wave3)).abs();
      
      // Calculate bar height
      final minHeight = size.height * 0.08;
      final maxHeight = size.height * 0.6;
      final barHeight = max(minHeight, amplitude * maxHeight);
      
      // Subtle color variation
      final colorIndex = ((normalizedPosition + time * 0.1) % 1.0 * gradientColors.length).floor();
      final barColor = gradientColors[colorIndex.clamp(0, gradientColors.length - 1)];
      
      final paint = Paint()
        ..color = barColor.withOpacity(0.4)
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      // Draw symmetrical bar from center
      final barTop = centerY - barHeight / 2;
      final barBottom = centerY + barHeight / 2;
      
      canvas.drawLine(
        Offset(x, barTop),
        Offset(x, barBottom),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Professional timeline waveform painter
class TimelineWavePainter extends CustomPainter {
  final List<double> amplitudeHistory;
  final Color color;

  TimelineWavePainter({
    required this.amplitudeHistory,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final barWidth = 2.0;
    final barSpacing = 1.0;
    final totalBarWidth = barWidth + barSpacing;
    final maxBars = (size.width / totalBarWidth).floor();
    final centerY = size.height / 2;

    if (amplitudeHistory.isNotEmpty) {
      for (int i = 0; i < maxBars && i < amplitudeHistory.length; i++) {
        final x = i * totalBarWidth + barWidth / 2;
        final amplitude = amplitudeHistory[i];
        
        // Calculate bar height
        final minHeight = size.height * 0.1;
        final maxHeight = size.height * 0.8;
        final barHeight = max(minHeight, amplitude * maxHeight);
        
        final paint = Paint()
          ..color = Color(0xFF8B5CF6).withOpacity(0.5)
          ..strokeWidth = barWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        
        // Draw symmetrical bar from center
        final barTop = centerY - barHeight / 2;
        final barBottom = centerY + barHeight / 2;
        
        canvas.drawLine(
          Offset(x, barTop),
          Offset(x, barBottom),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Advanced waveform painter with precision editing controls
class AdvancedWavePainter extends CustomPainter {
  final List<double> amplitudeHistory;
  final double currentAmplitude;
  final bool isRecording;
  final bool isPlaying;
  final double trimStart;
  final double trimEnd;
  final double playheadPosition;
  final double animationValue;

  AdvancedWavePainter({
    required this.amplitudeHistory,
    required this.currentAmplitude,
    required this.isRecording,
    required this.isPlaying,
    required this.trimStart,
    required this.trimEnd,
    required this.playheadPosition,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final barWidth = 2.5;
    final barSpacing = 1.0;
    final totalBarWidth = barWidth + barSpacing;
    final maxBars = (size.width / totalBarWidth).floor();
    final centerY = size.height / 2;

    if (amplitudeHistory.isNotEmpty) {
      _drawAdvancedWaveform(canvas, size, maxBars, barWidth, totalBarWidth, centerY);
      _drawEditingControls(canvas, size);
    } else {
      _drawAnimatedBackground(canvas, size, maxBars, barWidth, totalBarWidth, centerY);
    }
  }

  void _drawAdvancedWaveform(Canvas canvas, Size size, int maxBars, double barWidth, 
      double totalBarWidth, double centerY) {
    
    for (int i = 0; i < maxBars && i < amplitudeHistory.length; i++) {
      final x = i * totalBarWidth + barWidth / 2;
      final amplitude = amplitudeHistory[i];
      final normalizedX = x / size.width;
      
      // Calculate bar height
      final minHeight = size.height * 0.08;
      final maxHeight = size.height * 0.7;
      final barHeight = max(minHeight, amplitude * maxHeight);
      
      // Color based on position relative to trim selection
      Color barColor;
      double opacity;
      
      if (normalizedX >= trimStart && normalizedX <= trimEnd) {
        // Inside selection - bright purple
        barColor = Color(0xFF8B5CF6);
        opacity = 0.9;
      } else {
        // Outside selection - dimmed
        barColor = Color(0xFF6B7280);
        opacity = 0.3;
      }
      
      final paint = Paint()
        ..color = barColor.withOpacity(opacity)
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      // Draw symmetrical bar from center
      final barTop = centerY - barHeight / 2;
      final barBottom = centerY + barHeight / 2;
      
      canvas.drawLine(
        Offset(x, barTop),
        Offset(x, barBottom),
        paint,
      );
    }
  }

  void _drawEditingControls(Canvas canvas, Size size) {
    // Trim indicators
    final trimPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 2.0;
    
    // Trim start line
    final trimStartX = size.width * trimStart;
    canvas.drawLine(
      Offset(trimStartX, 0),
      Offset(trimStartX, size.height),
      trimPaint,
    );
    
    // Trim end line
    final trimEndX = size.width * trimEnd;
    canvas.drawLine(
      Offset(trimEndX, 0),
      Offset(trimEndX, size.height),
      trimPaint,
    );
    
    // Selected region highlight
    final selectedPaint = Paint()
      ..color = Color(0xFF8B5CF6).withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(
      Rect.fromLTRB(trimStartX, 0, trimEndX, size.height),
      selectedPaint,
    );
    
    // Playhead with pulsing effect
    if (isPlaying) {
      final pulseOpacity = 0.8 + 0.2 * sin(animationValue * 2 * pi);
      final playheadPaint = Paint()
        ..color = Colors.red.withOpacity(pulseOpacity)
        ..strokeWidth = 2.0;
      
      final playheadX = size.width * playheadPosition;
      canvas.drawLine(
        Offset(playheadX, 0),
        Offset(playheadX, size.height),
        playheadPaint,
      );
      
      // Playhead glow
      final glowPaint = Paint()
        ..color = Colors.red.withOpacity(0.3)
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      
      canvas.drawLine(
        Offset(playheadX, 0),
        Offset(playheadX, size.height),
        glowPaint,
      );
    }
  }

  void _drawAnimatedBackground(Canvas canvas, Size size, int maxBars, double barWidth, 
      double totalBarWidth, double centerY) {
    
    for (int i = 0; i < maxBars; i++) {
      final x = i * totalBarWidth + barWidth / 2;
      final normalizedPosition = i / maxBars;
      
      // Create animated wave pattern
      final wave1 = sin(normalizedPosition * 3 * pi + animationValue * 2 * pi);
      final wave2 = sin(normalizedPosition * 6 * pi + animationValue * pi) * 0.5;
      final amplitude = (0.2 + 0.3 * (wave1 + wave2)).abs();
      
      // Calculate bar height
      final minHeight = size.height * 0.1;
      final maxHeight = size.height * 0.4;
      final barHeight = max(minHeight, amplitude * maxHeight);
      
      final paint = Paint()
        ..color = Color(0xFF6B7280).withOpacity(0.3)
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      // Draw symmetrical bar from center
      final barTop = centerY - barHeight / 2;
      final barBottom = centerY + barHeight / 2;
      
      canvas.drawLine(
        Offset(x, barTop),
        Offset(x, barBottom),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 