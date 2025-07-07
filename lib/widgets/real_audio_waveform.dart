import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:async';
import '../providers/voice_provider.dart';

class RealAudioWaveform extends StatefulWidget {
  final String postId;
  final String audioUrl;
  final Color waveformColor;
  final Duration duration;
  final double height;
  final double? width;

  const RealAudioWaveform({
    super.key,
    required this.postId,
    required this.audioUrl,
    required this.waveformColor,
    required this.duration,
    this.height = 80.0,
    this.width,
  });

  @override
  State<RealAudioWaveform> createState() => _RealAudioWaveformState();
}

class _RealAudioWaveformState extends State<RealAudioWaveform> {
  PlayerController? _playerController;
  List<double> _waveformData = [];
  bool _isWaveformLoading = true;
  bool _isDragging = false;
  
  // Performance optimizations
  Timer? _seekThrottleTimer;
  final double _lastPlayheadPosition = 0.0;
  static const Duration _seekThrottleInterval = Duration(milliseconds: 16); // 60fps için daha responsive
  
  // Cached paint objects to avoid recreating them
  late Paint _unplayedPaint;
  late Paint _playedPaint;
  late Paint _highlightPaint;
  late Paint _glowPaint;
  late Paint _playheadPaint;
  late Paint _shadowPaint;

  @override
  void initState() {
    super.initState();
    _initializePaintObjects();
    _initializeWaveform();
  }

  void _initializePaintObjects() {
    _unplayedPaint = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    
    _playedPaint = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    
    _highlightPaint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    
    _glowPaint = Paint()
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    
    _playheadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    
    _shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
  }

  void _updatePaintColors() {
    _unplayedPaint.color = widget.waveformColor.withOpacity(0.4);
    _playedPaint.color = widget.waveformColor.withOpacity(0.9);
    _highlightPaint.color = widget.waveformColor.withOpacity(1.0);
    _glowPaint.color = widget.waveformColor.withOpacity(0.15);
  }

  Future<void> _initializeWaveform() async {
    try {
      _playerController = PlayerController();
      
      // Try to download and extract real waveform data
      final extractedData = await _extractRealWaveformData();
      if (extractedData != null && extractedData.isNotEmpty) {
        _waveformData = extractedData;
        debugPrint('✅ Successfully extracted real waveform data (${extractedData.length} samples)');
      } else {
        // Fallback to realistic simulation
        _generateRealisticWaveform();
      }
      
      setState(() {
        _isWaveformLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error initializing waveform: $e');
      // Fallback to random data if extraction fails
      _generateFallbackWaveform();
      setState(() {
        _isWaveformLoading = false;
      });
    }
  }

  Future<List<double>?> _extractRealWaveformData() async {
    try {
      // Download audio file temporarily
      final tempFile = await _downloadAudioFile();
      if (tempFile == null) return null;

      // Extract waveform data using audio_waveforms
      final waveformData = await _playerController?.extractWaveformData(
        path: tempFile.path,
        noOfSamples: 100, // Reduced for better performance
      );

      // Clean up temporary file
      await tempFile.delete();

      return waveformData;
    } catch (e) {
      debugPrint('❌ Error in _extractRealWaveformData: $e');
      return null;
    }
  }

  Future<File?> _downloadAudioFile() async {
    try {
      final response = await http.get(Uri.parse(widget.audioUrl));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final tempFile = File('${directory.path}/temp_audio_${widget.postId}.m4a');
        await tempFile.writeAsBytes(response.bodyBytes);
        return tempFile;
      }
    } catch (e) {
      debugPrint('❌ Error downloading audio file: $e');
    }
    return null;
  }

  void _generateRealisticWaveform() {
    final random = math.Random(widget.postId.hashCode);
    const sampleCount = 100; // Reduced sample count for better performance
    
    _waveformData = List.generate(sampleCount, (index) {
      final progress = index / sampleCount;
      
      // Create a more realistic audio waveform pattern
      double amplitude = 0.0;
      
      // Add multiple sine waves to create speech-like patterns
      amplitude += math.sin(progress * 2 * math.pi * 3) * 0.4;
      amplitude += math.sin(progress * 2 * math.pi * 7) * 0.2;
      amplitude += math.sin(progress * 2 * math.pi * 11) * 0.1;
      
      // Add some randomness
      amplitude += (random.nextDouble() - 0.5) * 0.3;
      
      // Add speech-like envelope
      final envelope = math.sin(progress * math.pi);
      amplitude *= envelope;
      
      // Normalize
      amplitude = (amplitude + 1.0) / 2.0;
      amplitude = 0.1 + amplitude * 0.8;
      
      return amplitude.clamp(0.0, 1.0);
    });
  }

  void _generateFallbackWaveform() {
    final random = math.Random(widget.postId.hashCode);
    _waveformData = List.generate(100, (index) {
      return 0.2 + random.nextDouble() * 0.6;
    });
  }

  // Throttled seek function for better performance
  void _throttledSeek(Duration targetDuration) {
    _seekThrottleTimer?.cancel();
    _seekThrottleTimer = Timer(_seekThrottleInterval, () {
      Provider.of<VoiceProvider>(context, listen: false).seekTo(targetDuration);
    });
  }

  @override
  void dispose() {
    _seekThrottleTimer?.cancel();
    _playerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.width ?? MediaQuery.of(context).size.width - 32;
    
    if (_isWaveformLoading) {
      return Container(
        height: widget.height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.withOpacity(0.1),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Consumer<VoiceProvider>(
      builder: (context, voiceProvider, child) {
        final isCurrentlyPlaying = voiceProvider.isPlaying && 
            voiceProvider.currentPlayingPostId == widget.postId;
        
        // Calculate playhead position with throttling
        double playheadPosition = 0.0;
        if (isCurrentlyPlaying && voiceProvider.playbackDuration.inMilliseconds > 0) {
          playheadPosition = voiceProvider.playbackPosition.inMilliseconds / 
              voiceProvider.playbackDuration.inMilliseconds;
          playheadPosition = playheadPosition.clamp(0.0, 1.0);
        }

        // Update paint colors only when needed
        _updatePaintColors();
        
        return GestureDetector(
          behavior: HitTestBehavior.opaque, // Tüm container'a dokunma algılaması
          onTapUp: (details) {
            if (!isCurrentlyPlaying) return;
            
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final localPosition = renderBox.globalToLocal(details.globalPosition);
            final tapPosition = localPosition.dx / width;
            final seekPosition = tapPosition.clamp(0.0, 1.0);
            
            final targetDuration = Duration(
              milliseconds: (seekPosition * voiceProvider.playbackDuration.inMilliseconds).round(),
            );
            
            // Use immediate seek for tap (no throttling)
            voiceProvider.seekTo(targetDuration);
          },
          onPanStart: (details) {
            if (!isCurrentlyPlaying) return;
            setState(() {
              _isDragging = true;
            });
          },
          onPanUpdate: (details) {
            if (!isCurrentlyPlaying || !_isDragging) return;
            
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final localPosition = renderBox.globalToLocal(details.globalPosition);
            final dragPosition = localPosition.dx / width;
            final seekPosition = dragPosition.clamp(0.0, 1.0);
            
            final targetDuration = Duration(
              milliseconds: (seekPosition * voiceProvider.playbackDuration.inMilliseconds).round(),
            );
            
            // Use throttled seek for drag
            _throttledSeek(targetDuration);
          },
          onPanEnd: (details) {
            setState(() {
              _isDragging = false;
            });
            _seekThrottleTimer?.cancel(); // Cancel any pending seeks
          },
          child: Container(
            height: widget.height,
            width: width,
            padding: const EdgeInsets.symmetric(vertical: 8.0), // Dikey dokunma alanı genişletme
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // Optimized waveform visualization
                CustomPaint(
                  painter: OptimizedWaveformPainter(
                    waveformData: _waveformData,
                    playheadPosition: playheadPosition,
                    isPlaying: isCurrentlyPlaying,
                    unplayedPaint: _unplayedPaint,
                    playedPaint: _playedPaint,
                    highlightPaint: _highlightPaint,
                    glowPaint: _glowPaint,
                    playheadPaint: _playheadPaint,
                    shadowPaint: _shadowPaint,
                  ),
                  size: Size(width, widget.height),
                ),
                
                // Playhead handle - only show when playing
                if (isCurrentlyPlaying)
                  Positioned(
                    left: (playheadPosition * width) - 30,
                    top: 0,
                    child: Container(
                      width: 60,
                      height: widget.height,
                      color: Colors.transparent,
                      child: Center(
                        child: Container(
                          width: _isDragging ? 12 : 10,
                          height: _isDragging ? 12 : 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.waveformColor,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
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
        );
      },
    );
  }
}

class OptimizedWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double playheadPosition;
  final bool isPlaying;
  final Paint unplayedPaint;
  final Paint playedPaint;
  final Paint highlightPaint;
  final Paint glowPaint;
  final Paint playheadPaint;
  final Paint shadowPaint;

  OptimizedWaveformPainter({
    required this.waveformData,
    required this.playheadPosition,
    required this.isPlaying,
    required this.unplayedPaint,
    required this.playedPaint,
    required this.highlightPaint,
    required this.glowPaint,
    required this.playheadPaint,
    required this.shadowPaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    // İyileştirilmiş bar boyutlandırma
    final double availableWidth = size.width - 16; // Padding için boşluk
    final int targetBarCount = (availableWidth / 4.0).floor().clamp(50, 120); // Min 50, Max 120 bar
    
    final barWidth = 2.5;
    final barSpacing = (availableWidth - (targetBarCount * barWidth)) / (targetBarCount - 1);
    final actualBarSpacing = barSpacing.clamp(1.0, 3.0); // Min 1px, Max 3px spacing
    
    final barCount = ((availableWidth + actualBarSpacing) / (barWidth + actualBarSpacing)).floor();
    final samplesPerBar = waveformData.length / barCount;
    final centerY = size.height / 2;

    // Pre-calculate playhead position in pixels
    final playheadX = playheadPosition * size.width;

    // Draw waveform bars with minimal calculations
    for (int i = 0; i < barCount; i++) {
      final x = 8.0 + (i * (barWidth + actualBarSpacing)) + barWidth / 2; // 8px padding'den başla
      final sampleIndex = (i * samplesPerBar).floor().clamp(0, waveformData.length - 1);
      final amplitude = waveformData[sampleIndex];
      
      // Calculate bar height - daha dinamik yükseklik hesaplaması
      final maxBarHeight = size.height * 0.85; // Max yükseklik %85
      final minBarHeight = size.height * 0.15; // Min yükseklik %15
      final barHeight = minBarHeight + (amplitude * (maxBarHeight - minBarHeight));
      
      final barTop = centerY - barHeight / 2;
      final barBottom = centerY + barHeight / 2;
      
      // Determine paint based on position relative to playhead
      Paint currentPaint;
      if (isPlaying && x <= playheadX) {
        // Check if very close to playhead for highlight
        final distanceFromPlayhead = (x - playheadX).abs();
        if (distanceFromPlayhead < 12) {
          currentPaint = highlightPaint;
          // Draw glow effect
          canvas.drawLine(
            Offset(x, barTop),
            Offset(x, barBottom),
            glowPaint,
          );
        } else {
          currentPaint = playedPaint;
        }
      } else {
        currentPaint = unplayedPaint;
      }
      
      // Draw main bar
      canvas.drawLine(
        Offset(x, barTop),
        Offset(x, barBottom),
        currentPaint,
      );
    }

    // Draw playhead line
    if (isPlaying) {
      // Draw shadow first
      canvas.drawLine(
        Offset(playheadX + 0.5, 0),
        Offset(playheadX + 0.5, size.height),
        shadowPaint,
      );
      
      // Draw main line
      canvas.drawLine(
        Offset(playheadX, 0),
        Offset(playheadX, size.height),
        playheadPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant OptimizedWaveformPainter oldDelegate) {
    // Only repaint when necessary
    return oldDelegate.playheadPosition != playheadPosition ||
           oldDelegate.isPlaying != isPlaying ||
           oldDelegate.waveformData != waveformData;
  }
} 