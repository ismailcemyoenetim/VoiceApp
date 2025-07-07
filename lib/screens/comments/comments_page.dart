import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../providers/voice_provider.dart';
import '../../widgets/glassmorphism_widgets.dart';
import '../../widgets/voice_comment_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';

class CommentsPage extends StatefulWidget {
  final VoicePost post;

  const CommentsPage({super.key, required this.post});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> with TickerProviderStateMixin {
  List<VoiceComment> _comments = [];
  bool _isLoading = true;
  final TextEditingController _commentController = TextEditingController();
  
  // Voice comment recording state
  bool _isRecording = false;
  bool _showVoiceRecorder = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  late AnimationController _recordingPulseController;
  late AnimationController _voiceRecorderController;
  final Record _audioRecorder = Record();
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _recordingPulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _voiceRecorderController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _recordingPulseController.dispose();
    _voiceRecorderController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    final comments = await voiceProvider.getComments(widget.post.id);

    setState(() {
      _comments = comments;
      _isLoading = false;
    });
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    final newComment = await voiceProvider.addComment(
      widget.post.id,
      _commentController.text.trim(),
    );

    if (newComment != null) {
      setState(() {
        _comments.insert(0, newComment);
      });
      _commentController.clear();
      
      GlassmorphismSnackBar.show(
        context,
        message: 'Comment added successfully',
        icon: Icons.comment,
      );
    }
  }

  Future<void> _toggleVoiceRecorder() async {
    if (_showVoiceRecorder) {
      // Hide voice recorder
      _voiceRecorderController.reverse();
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _showVoiceRecorder = false;
      });
    } else {
      // Show voice recorder
      setState(() {
        _showVoiceRecorder = true;
      });
      _voiceRecorderController.forward();
    }
  }

  Future<void> _startRecording() async {
    // Request microphone permission
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      GlassmorphismSnackBar.show(
        context,
        message: 'Microphone permission required',
        icon: Icons.mic_off,
      );
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'voice_comment_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = '${tempDir.path}/$fileName';

      await _audioRecorder.start(
        path: _recordingPath!,
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        samplingRate: 44100,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      _recordingPulseController.repeat();
      
      // Start recording timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
      });

      GlassmorphismSnackBar.show(
        context,
        message: 'Recording started',
        icon: Icons.mic,
      );
    } catch (e) {
      GlassmorphismSnackBar.show(
        context,
        message: 'Failed to start recording',
        icon: Icons.error,
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      _recordingTimer?.cancel();
      _recordingPulseController.stop();
      
      setState(() {
        _isRecording = false;
      });

      if (_recordingPath != null && _recordingDuration.inSeconds > 0) {
        await _showVoiceCommentPreview();
      }
    } catch (e) {
      GlassmorphismSnackBar.show(
        context,
        message: 'Failed to stop recording',
        icon: Icons.error,
      );
    }
  }

  Future<void> _showVoiceCommentPreview() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassmorphismContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Voice Comment Preview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Voice comment preview card
                GlassmorphismCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue.shade400,
                              Colors.purple.shade400,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Voice Comment',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(_recordingDuration),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.mic,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GlassmorphismButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _discardRecording();
                        },
                        child: const Text(
                          'Discard',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassmorphismButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _submitVoiceComment();
                        },
                        child: const Text(
                          'Post',
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

  Future<void> _submitVoiceComment() async {
    if (_recordingPath == null) return;

    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    
    // Create voice comment
    final newVoiceComment = await voiceProvider.addVoiceComment(
      widget.post.id,
      _recordingPath!,
      _recordingDuration,
    );

    if (newVoiceComment != null) {
      setState(() {
        _comments.insert(0, newVoiceComment);
      });
      
      GlassmorphismSnackBar.show(
        context,
        message: 'Voice comment added successfully',
        icon: Icons.mic,
      );
    }

    _discardRecording();
    await _toggleVoiceRecorder();
  }

  void _discardRecording() {
    if (_recordingPath != null) {
      // Clean up temporary file
      final file = File(_recordingPath!);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    
    setState(() {
      _recordingPath = null;
      _recordingDuration = Duration.zero;
      _isRecording = false;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassmorphismAppBar(
        title: 'Comments',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadComments,
          ),
        ],
      ),
      body: Column(
        children: [
          // Original post preview
          Container(
            margin: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + kToolbarHeight + 16,
              16,
              8,
            ),
            child: GlassmorphismCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade800,
                    child: Text(
                      widget.post.username[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.post.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: Colors.blue,
                              size: 16,
                            ),
                          ],
                        ),
                        if (widget.post.description != null)
                          Text(
                            widget.post.description!,
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.play_arrow,
                    color: Colors.grey[400],
                    size: 32,
                  ),
                ],
              ),
            ),
          ),

          // Comments section
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassmorphismCard(
                padding: const EdgeInsets.all(16),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _comments.isEmpty
                        ? const Center(
                            child: Text(
                              'No comments yet.\nBe the first to comment!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              return VoiceCommentWidget(
                                comment: _comments[index],
                                isCompact: false,
                              );
                            },
                          ),
              ),
            ),
          ),

          // Voice recorder section (when visible)
          if (_showVoiceRecorder)
            AnimatedBuilder(
              animation: _voiceRecorderController,
              builder: (context, child) {
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  height: _voiceRecorderController.value * 80,
                  child: Opacity(
                    opacity: _voiceRecorderController.value,
                    child: GlassmorphismCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Recording indicator
                          if (_isRecording)
                            AnimatedBuilder(
                              animation: _recordingPulseController,
                              builder: (context, child) {
                                return Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red.withOpacity(
                                      0.5 + 0.5 * _recordingPulseController.value,
                                    ),
                                  ),
                                );
                              },
                            ),
                          
                          if (_isRecording) const SizedBox(width: 12),
                          
                          Expanded(
                            child: Text(
                              _isRecording
                                  ? 'Recording... ${_formatDuration(_recordingDuration)}'
                                  : 'Tap to record voice comment',
                              style: TextStyle(
                                color: _isRecording ? Colors.red[300] : Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          
                          // Record button
                          GestureDetector(
                            onTap: _isRecording ? _stopRecording : _startRecording,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _isRecording
                                      ? [Colors.red.shade400, Colors.red.shade600]
                                      : [Colors.blue.shade400, Colors.purple.shade400],
                                ),
                              ),
                              child: Icon(
                                _isRecording ? Icons.stop : Icons.mic,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          // Add comment section
          Container(
            margin: const EdgeInsets.all(16),
            child: GlassmorphismCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  
                  // Voice comment button (+)
                  GestureDetector(
                    onTap: _toggleVoiceRecorder,
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _showVoiceRecorder
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.red.shade400, Colors.red.shade600],
                              )
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.blue.shade400, Colors.purple.shade400],
                              ),
                      ),
                      child: Icon(
                        _showVoiceRecorder ? Icons.close : Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  
                  // Send text comment button
                  IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.blue,
                    ),
                    onPressed: _addComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 