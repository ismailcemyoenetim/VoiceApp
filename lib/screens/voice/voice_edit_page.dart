import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'dart:math' as math;
import '../../providers/voice_provider.dart';
import '../../widgets/glassmorphism_widgets.dart';

class VoiceEditPage extends StatefulWidget {
  final String audioPath;
  final Duration originalDuration;

  const VoiceEditPage({
    super.key,
    required this.audioPath,
    required this.originalDuration,
  });

  @override
  State<VoiceEditPage> createState() => _VoiceEditPageState();
}

class _VoiceEditPageState extends State<VoiceEditPage>
    with TickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late AnimationController _playButtonController;
  
  // Edit controls
  final Duration _startTime = Duration.zero;
  Duration _endTime = Duration.zero;
  Duration _currentPosition = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = true;
  
  // Waveform and timeline
  List<double> _waveformData = [];
  double _zoomLevel = 1.0;
  final double _panOffset = 0.0;
  final double _pixelsPerSecond = 50.0;
  
  // Edit state
  final bool _isDraggingStart = false;
  final bool _isDraggingEnd = false;
  final bool _isDraggingPlayhead = false;
  
  // UI Controllers
  late ScrollController _timelineController;
  late AnimationController _waveformController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAudio();
    _endTime = widget.originalDuration;
    _generateWaveformData();
  }

  void _initializeControllers() {
    _playButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _timelineController = ScrollController();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _playButtonController.dispose();
    _waveformController.dispose();
    _timelineController.dispose();
    super.dispose();
  }

  Future<void> _initializeAudio() async {
    try {
      _audioPlayer = AudioPlayer();
      
      // Check if file exists
      final audioFile = File(widget.audioPath);
      if (!audioFile.existsSync()) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Load audio
      await _audioPlayer.setFilePath(widget.audioPath);
      
      // Listen to position changes
      _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
            
            // Auto-stop if we reach the end trim point
            if (position >= _endTime && _isPlaying) {
              _pauseAudio();
            }
          });
        }
      });
      
      // Listen to player state
      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            if (_isPlaying) {
              _playButtonController.forward();
            } else {
              _playButtonController.reverse();
            }
          });
        }
      });
      
      setState(() => _isLoading = false);
      
    } catch (e) {
      debugPrint('❌ Error initializing audio: $e');
      setState(() => _isLoading = false);
    }
  }

    void _generateWaveformData() {
    // Generate realistic waveform data
    final random = math.Random();
    _waveformData = List.generate(
      (widget.originalDuration.inMilliseconds / 50).round(),
      (i) {
        // Create some variation in amplitude
        final base = 0.3 + random.nextDouble() * 0.4;
        final variation = math.sin(i * 0.1) * 0.2;
        final result = base + variation;
        return result < 0.1 ? 0.1 : (result > 0.9 ? 0.9 : result);
      },
    );
  }

  Future<void> _playAudio() async {
    try {
      await _audioPlayer.seek(_startTime);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('❌ Error playing audio: $e');
    }
  }

  Future<void> _pauseAudio() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      debugPrint('❌ Error pausing audio: $e');
    }
  }

  void _seekToPosition(Duration position) {
    Duration clampedPosition = position;
    if (position < _startTime) {
      clampedPosition = _startTime;
    } else if (position > _endTime) {
      clampedPosition = _endTime;
    }
    _audioPlayer.seek(clampedPosition);
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  double _durationToPixels(Duration duration) {
    return duration.inMilliseconds * _pixelsPerSecond * _zoomLevel / 1000;
  }

  Duration _pixelsToDuration(double pixels) {
    final milliseconds = (pixels * 1000 / (_pixelsPerSecond * _zoomLevel)).round();
    return Duration(milliseconds: milliseconds);
  }

  void _confirmEdit() {
    Navigator.of(context).pop({
      'confirmed': true,
      'startTime': _startTime,
      'endTime': _endTime,
      'originalPath': widget.audioPath,
    });
  }

  void _cancelEdit() {
    Navigator.of(context).pop({'confirmed': false});
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final totalWidth = _durationToPixels(widget.originalDuration);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _cancelEdit,
        ),
        title: const Text(
          'Edit Audio',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _confirmEdit,
            child: const Text(
              'Done',
              style: TextStyle(
                color: Color(0xFF007AFF),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF007AFF)),
            )
          : Column(
              children: [
                // Timeline Header
                _buildTimelineHeader(),
                
                // Main Waveform Area
                Expanded(
                  child: _buildWaveformArea(screenWidth, totalWidth),
                ),
                
                // Playback Controls
                _buildPlaybackControls(),
                
                // Bottom Toolbar
                _buildBottomToolbar(),
              ],
            ),
    );
  }

  Widget _buildTimelineHeader() {
    return Container(
      height: 40,
      color: const Color(0xFF1A1A1A),
      child: Row(
        children: [
          // Current time
          Container(
            width: 80,
            alignment: Alignment.center,
            child: Text(
              _formatDuration(_currentPosition),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Timeline markers
          Expanded(
            child: SingleChildScrollView(
              controller: _timelineController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _durationToPixels(widget.originalDuration),
                child: CustomPaint(
                  painter: TimelineMarkersPainter(
                    duration: widget.originalDuration,
                    pixelsPerSecond: _pixelsPerSecond * _zoomLevel,
                  ),
                  size: const Size(double.infinity, 40),
                ),
              ),
            ),
          ),
          
          // Total duration
          Container(
            width: 80,
            alignment: Alignment.center,
            child: Text(
              _formatDuration(widget.originalDuration),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformArea(double screenWidth, double totalWidth) {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: Column(
        children: [
          // Trim info
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trim: ${_formatDuration(_startTime)} - ${_formatDuration(_endTime)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Duration: ${_formatDuration(_endTime - _startTime)}',
                  style: const TextStyle(
                    color: Color(0xFF007AFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Waveform display
          Expanded(
            child: GestureDetector(
              onScaleStart: (details) {
                // Handle zoom start
              },
                             onScaleUpdate: (details) {
                 if (details.scale != 1.0) {
                   setState(() {
                     final newZoom = _zoomLevel * details.scale;
                     _zoomLevel = newZoom < 0.5 ? 0.5 : (newZoom > 5.0 ? 5.0 : newZoom);
                   });
                 }
               },
              onTapUp: (details) {
                // Seek to tapped position
                final tapX = details.localPosition.dx;
                final duration = _pixelsToDuration(tapX + _panOffset);
                _seekToPosition(duration);
              },
              child: SingleChildScrollView(
                controller: _timelineController,
                scrollDirection: Axis.horizontal,
                                 child: SizedBox(
                   width: math.max(screenWidth, totalWidth),
                   child: CustomPaint(
                     painter: ProfessionalWaveformPainter(
                       waveformData: _waveformData,
                       currentPosition: _currentPosition,
                       startTime: _startTime,
                       endTime: _endTime,
                       totalDuration: widget.originalDuration,
                       pixelsPerSecond: _pixelsPerSecond * _zoomLevel,
                     ),
                     size: Size(math.max(screenWidth, totalWidth), 200),
                   ),
                 ),
              ),
            ),
          ),
          
          // Zoom controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                                 IconButton(
                   onPressed: () {
                     setState(() {
                       final newZoom = _zoomLevel / 1.5;
                       _zoomLevel = newZoom < 0.5 ? 0.5 : (newZoom > 5.0 ? 5.0 : newZoom);
                     });
                   },
                   icon: const Icon(Icons.zoom_out, color: Colors.white70),
                 ),
                 Text(
                   '${(_zoomLevel * 100).round()}%',
                   style: const TextStyle(color: Colors.white70),
                 ),
                 IconButton(
                   onPressed: () {
                     setState(() {
                       final newZoom = _zoomLevel * 1.5;
                       _zoomLevel = newZoom < 0.5 ? 0.5 : (newZoom > 5.0 ? 5.0 : newZoom);
                     });
                   },
                   icon: const Icon(Icons.zoom_in, color: Colors.white70),
                 ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Container(
      height: 80,
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Rewind
          IconButton(
            onPressed: () {
              final newPosition = _currentPosition - const Duration(seconds: 5);
              _seekToPosition(newPosition);
            },
            icon: const Icon(Icons.replay_5, color: Colors.white, size: 28),
          ),
          
          // Play/Pause
          GestureDetector(
            onTap: _isPlaying ? _pauseAudio : _playAudio,
            child: AnimatedBuilder(
              animation: _playButtonController,
              builder: (context, child) {
                return Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF007AFF).withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                );
              },
            ),
          ),
          
          // Forward
          IconButton(
            onPressed: () {
              final newPosition = _currentPosition + const Duration(seconds: 5);
              _seekToPosition(newPosition);
            },
            icon: const Icon(Icons.forward_5, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      height: 100,
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          const Divider(color: Color(0xFF333333), height: 1),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToolButton(Icons.content_cut, 'Trim', () {
                  // Trim functionality
                }),
                _buildToolButton(Icons.speed, 'Speed', () {
                  // Speed adjustment
                }),
                _buildToolButton(Icons.volume_up, 'Volume', () {
                  // Volume adjustment
                }),
                _buildToolButton(Icons.auto_fix_high, 'Effects', () {
                  // Effects
                }),
                _buildToolButton(Icons.equalizer, 'EQ', () {
                  // Equalizer
                }),
                _buildToolButton(Icons.tune, 'Filters', () {
                  // Audio filters
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Professional Waveform Painter
class ProfessionalWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Duration currentPosition;
  final Duration startTime;
  final Duration endTime;
  final Duration totalDuration;
  final double pixelsPerSecond;

  ProfessionalWaveformPainter({
    required this.waveformData,
    required this.currentPosition,
    required this.startTime,
    required this.endTime,
    required this.totalDuration,
    required this.pixelsPerSecond,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.height / 2;
    final totalWidth = totalDuration.inMilliseconds * pixelsPerSecond / 1000;
    
    // Background
    final backgroundPaint = Paint()..color = const Color(0xFF0A0A0A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
    
    // Waveform
    final waveformPaint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 2;
      
    final selectedWaveformPaint = Paint()
      ..color = const Color(0xFF007AFF)
      ..strokeWidth = 2;
    
    final sampleWidth = totalWidth / waveformData.length;
    
    for (int i = 0; i < waveformData.length; i++) {
      final x = i * sampleWidth;
      final amplitude = waveformData[i];
      final height = amplitude * (size.height * 0.4);
      
      // Determine if this section is selected
      final sampleTime = Duration(milliseconds: (i * totalDuration.inMilliseconds / waveformData.length).round());
      final isSelected = sampleTime >= startTime && sampleTime <= endTime;
      
      final paint = isSelected ? selectedWaveformPaint : waveformPaint;
      
      // Draw waveform bar
      canvas.drawLine(
        Offset(x, center - height / 2),
        Offset(x, center + height / 2),
        paint,
      );
    }
    
    // Draw trim handles
    final startX = startTime.inMilliseconds * pixelsPerSecond / 1000;
    final endX = endTime.inMilliseconds * pixelsPerSecond / 1000;
    
    final handlePaint = Paint()..color = const Color(0xFF007AFF);
    const handleWidth = 4.0;
    const handleHeight = 20.0;
    
    // Start handle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX - handleWidth / 2, center - handleHeight / 2, handleWidth, handleHeight),
        const Radius.circular(2),
      ),
      handlePaint,
    );
    
    // End handle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(endX - handleWidth / 2, center - handleHeight / 2, handleWidth, handleHeight),
        const Radius.circular(2),
      ),
      handlePaint,
    );
    
    // Playhead
    final playheadX = currentPosition.inMilliseconds * pixelsPerSecond / 1000;
    final playheadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      playheadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Timeline Markers Painter
class TimelineMarkersPainter extends CustomPainter {
  final Duration duration;
  final double pixelsPerSecond;

  TimelineMarkersPainter({
    required this.duration,
    required this.pixelsPerSecond,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    // Draw markers every 5 seconds
    for (int seconds = 0; seconds <= duration.inSeconds; seconds += 5) {
      final x = seconds * pixelsPerSecond;
      
      // Draw tick
      canvas.drawLine(
        Offset(x, size.height - 10),
        Offset(x, size.height),
        paint,
      );
      
      // Draw time label
      textPainter.text = TextSpan(
        text: '${seconds}s',
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, 5));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 