import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/voice_provider.dart';

class VoiceCommentWidget extends StatefulWidget {
  final VoiceComment comment;
  final bool isCompact;

  const VoiceCommentWidget({
    super.key,
    required this.comment,
    this.isCompact = false,
  });

  @override
  State<VoiceCommentWidget> createState() => _VoiceCommentWidgetState();
}

class _VoiceCommentWidgetState extends State<VoiceCommentWidget> {
  bool _isPlaying = false;

  Color _getUserColor(String username) {
    final hash = username.hashCode;
    final colors = [
      Colors.purple,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.pink,
      Colors.indigo,
      Colors.teal,
      Colors.cyan,
      Colors.lime,
      Colors.amber,
      Colors.deepOrange,
    ];
    return colors[hash.abs() % colors.length];
  }

  bool _isBackendUrl(String? profilePicture) {
    return profilePicture != null && profilePicture.startsWith('/uploads/');
  }

  String _getFullImageUrl(String imagePath) {
    if (!_isBackendUrl(imagePath)) return imagePath;
    const String baseUrl = 'http://192.168.1.100:3000';
    return '$baseUrl$imagePath';
  }

  bool _shouldShowProfilePicture(String? profilePicture) {
    return profilePicture != null && 
           profilePicture.isNotEmpty && 
           profilePicture.length > 1;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '0:00';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _togglePlayback() async {
    if (widget.comment.audioUrl == null) return;

    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    
    if (_isPlaying) {
      await voiceProvider.stopPlayback();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await voiceProvider.playPost(widget.comment.id, widget.comment.audioUrl!);
      setState(() {
        _isPlaying = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = widget.isCompact ? 24.0 : 32.0;
    final fontSize = widget.isCompact ? 12.0 : 14.0;

    return Container(
      margin: EdgeInsets.only(bottom: widget.isCompact ? 4 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile picture
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: !_shouldShowProfilePicture(widget.comment.profilePicture)
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getUserColor(widget.comment.username),
                        _getUserColor(widget.comment.username).withOpacity(0.7),
                      ],
                    )
                  : null,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
              image: _shouldShowProfilePicture(widget.comment.profilePicture)
                  ? DecorationImage(
                      image: _isBackendUrl(widget.comment.profilePicture)
                          ? NetworkImage(_getFullImageUrl(widget.comment.profilePicture!))
                          : FileImage(File(widget.comment.profilePicture!)) as ImageProvider,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _shouldShowProfilePicture(widget.comment.profilePicture)
                ? null
                : Center(
                    child: Text(
                      widget.comment.username[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: widget.isCompact ? 10 : 12,
                      ),
                    ),
                  ),
          ),
          
          SizedBox(width: widget.isCompact ? 6 : 8),
          
          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username and timestamp
                Row(
                  children: [
                    Text(
                      widget.comment.username,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: widget.isCompact ? 11 : 12,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: widget.isCompact ? 4 : 6),
                    Text(
                      _formatTimeAgo(widget.comment.createdAt),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: widget.isCompact ? 9 : 10,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.isCompact ? 2 : 4),
                
                // Comment content (text or voice)
                if (widget.comment.isVoiceComment)
                  // Voice comment
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade400.withOpacity(0.3),
                          Colors.purple.shade400.withOpacity(0.3),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Play button
                        GestureDetector(
                          onTap: _togglePlayback,
                          child: Container(
                            width: 32,
                            height: 32,
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
                            child: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // Duration and voice indicator
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voice Comment',
                              style: TextStyle(
                                fontSize: widget.isCompact ? 10 : 11,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDuration(widget.comment.duration),
                              style: TextStyle(
                                fontSize: widget.isCompact ? 9 : 10,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(width: 8),
                        Icon(
                          Icons.mic,
                          color: Colors.grey[400],
                          size: 16,
                        ),
                      ],
                    ),
                  )
                else
                  // Text comment
                  Text(
                    widget.comment.content,
                    style: TextStyle(
                      fontSize: fontSize,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 