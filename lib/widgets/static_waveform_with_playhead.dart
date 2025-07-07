import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/voice_provider.dart';

class StaticWaveformWithPlayhead extends StatefulWidget {
  final String postId;
  final Color waveformColor;
  final Duration duration;
  final double height;
  final double? width;

  const StaticWaveformWithPlayhead({
    super.key,
    required this.postId,
    required this.waveformColor,
    required this.duration,
    this.height = 80.0,
    this.width,
  });

  @override
  State<StaticWaveformWithPlayhead> createState() => _StaticWaveformWithPlayheadState();
}

class _StaticWaveformWithPlayheadState extends State<StaticWaveformWithPlayhead> {
  bool _isDragging = false;
  
  @override
  Widget build(BuildContext context) {
    final width = widget.width ?? MediaQuery.of(context).size.width - 32;
    
    return Consumer<VoiceProvider>(
      builder: (context, voiceProvider, child) {
        final isCurrentlyPlaying = voiceProvider.isPlaying && 
            voiceProvider.currentPlayingPostId == widget.postId;
        
        // Calculate playhead position (0.0 to 1.0)
        double playheadPosition = 0.0;
        if (isCurrentlyPlaying && voiceProvider.playbackDuration.inMilliseconds > 0) {
          playheadPosition = voiceProvider.playbackPosition.inMilliseconds / 
              voiceProvider.playbackDuration.inMilliseconds;
          playheadPosition = playheadPosition.clamp(0.0, 1.0);
        }
        
        return GestureDetector(
          behavior: HitTestBehavior.opaque, // Tüm container'a dokunma algılaması
          onTapUp: (details) {
            if (!isCurrentlyPlaying) return;
            
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final localPosition = renderBox.globalToLocal(details.globalPosition);
            final tapPosition = localPosition.dx / width;
            final seekPosition = tapPosition.clamp(0.0, 1.0);
            
            // Calculate the target duration to seek to
            final targetDuration = Duration(
              milliseconds: (seekPosition * voiceProvider.playbackDuration.inMilliseconds).round(),
            );
            
            voiceProvider.seekTo(targetDuration);
          },
          onPanStart: (details) {
            if (!isCurrentlyPlaying) return;
            _isDragging = true;
          },
          onPanUpdate: (details) {
            if (!isCurrentlyPlaying || !_isDragging) return;
            
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final localPosition = renderBox.globalToLocal(details.globalPosition);
            final dragPosition = localPosition.dx / width;
            final seekPosition = dragPosition.clamp(0.0, 1.0);
            
            // Calculate the target duration to seek to
            final targetDuration = Duration(
              milliseconds: (seekPosition * voiceProvider.playbackDuration.inMilliseconds).round(),
            );
            
            voiceProvider.seekTo(targetDuration);
          },
          onPanEnd: (details) {
            _isDragging = false;
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
                // Static waveform
                CustomPaint(
                  painter: StaticWaveformPainter(
                    color: widget.waveformColor,
                    postId: widget.postId,
                    isPlaying: isCurrentlyPlaying,
                  ),
                  size: Size(width, widget.height),
                ),
                
                // Playhead cursor
                if (isCurrentlyPlaying)
                  Positioned(
                    left: playheadPosition * width - 1, // Center the 2px wide line
                    top: 0,
                    child: Container(
                      width: 2,
                      height: widget.height,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Playhead drag handle (larger touch target)
                if (isCurrentlyPlaying)
                  Positioned(
                    left: (playheadPosition * width) - 30, // Genişletilmiş dokunma alanı
                    top: 0,
                    child: Container(
                      width: 60, // Çok daha geniş dokunma alanı
                      height: widget.height, // Tüm yüksekliği kapsar
                      color: Colors.transparent,
                      child: Center(
                        child: Container(
                          width: _isDragging ? 12 : 10, // Görsel handle biraz büyütüldü
                          height: _isDragging ? 12 : 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.waveformColor,
                              width: 2, // Daha kalın border
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

class StaticWaveformPainter extends CustomPainter {
  final Color color;
  final String postId;
  final bool isPlaying;

  StaticWaveformPainter({
    required this.color,
    required this.postId,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(isPlaying ? 0.9 : 0.6)
      ..strokeWidth = 2;

    final barWidth = 3.0;
    final barSpacing = 2.5;
    final barCount = (size.width / (barWidth + barSpacing)).floor();

    // Create unique seed based on post ID for consistent waveform shape
    final seed = postId.hashCode;
    final random = math.Random(seed);

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + barSpacing);
      
      // Create unique random height for each bar (static, consistent)
      random.nextDouble(); // Advance state for unique per-bar randomness
      final heightPercent = 0.2 + (random.nextDouble() * 0.8); // 20% to 100% height
      
      // Static height - no animation when playing
      final height = size.height * heightPercent * 0.85;
      
      final rect = Rect.fromLTWH(
        x,
        (size.height - height) / 2,
        barWidth,
        height,
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is StaticWaveformPainter && 
           (oldDelegate.isPlaying != isPlaying || oldDelegate.color != color);
  }
} 