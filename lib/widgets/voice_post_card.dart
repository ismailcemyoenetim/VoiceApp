import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/voice_provider.dart';
import '../providers/auth_provider.dart';
import 'glassmorphism_widgets.dart';
import 'real_audio_waveform.dart';

class VoicePostCard extends StatefulWidget {
  final VoicePost post;

  const VoicePostCard({super.key, required this.post});

  @override
  State<VoicePostCard> createState() => _VoicePostCardState();
}

class _VoicePostCardState extends State<VoicePostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late bool _isLiked;
  bool _showDescription = false;
  bool _showTranscription = false;
  VoiceTranscription? _transcription;
  bool _isLoadingTranscription = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedByUser;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Set initial animation state based on like status
    if (_isLiked) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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

  Future<void> _loadTranscription() async {
    if (_isLoadingTranscription || _transcription != null) return;
    
    setState(() {
      _isLoadingTranscription = true;
    });
    
    try {
      final transcription = await Provider.of<VoiceProvider>(context, listen: false)
          .getTranscription(widget.post.id);
      
      setState(() {
        _transcription = transcription;
        _isLoadingTranscription = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTranscription = false;
      });
      debugPrint('Error loading transcription: $e');
    }
  }

  void _toggleTranscription() {
    setState(() {
      _showTranscription = !_showTranscription;
    });
    
    if (_showTranscription && _transcription == null) {
      _loadTranscription();
    }
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
    
    if (_isLiked) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }

    // Update the provider
    Provider.of<VoiceProvider>(context, listen: false)
        .likePost(widget.post.id);
  }

  // Helper function to generate color from username
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

  // Helper function to determine if it's a backend URL
  bool _isBackendUrl(String? profilePicture) {
    return profilePicture != null && profilePicture.startsWith('/uploads/');
  }

  // Helper function to get full image URL
  String _getFullImageUrl(String imagePath) {
    if (!_isBackendUrl(imagePath)) return imagePath;
    
    // Use the same logic as ApiService
    const String baseUrl = 'http://192.168.1.100:3000';
    return '$baseUrl$imagePath';
  }

  // Helper function to determine if profile picture should be shown
  bool _shouldShowProfilePicture(String? profilePicture) {
    return profilePicture != null && 
           profilePicture.isNotEmpty && 
           profilePicture.length > 1; // Not just a single character
  }

  @override
  Widget build(BuildContext context) {
    bool isAdminPost = widget.post.userId == 'admin_user';
    bool isDemoPost = widget.post.id.startsWith('demo_');
    
    return GlassmorphismCard(
      margin: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Header
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 36, // 48 * 0.75 = 36
                    height: 36, // 48 * 0.75 = 36
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: !_shouldShowProfilePicture(widget.post.profilePicture)
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isAdminPost 
                                ? [
                                    Colors.black,
                                    Colors.grey.shade800,
                                  ]
                                : [
                                    _getUserColor(widget.post.username),
                                    _getUserColor(widget.post.username).withOpacity(0.7),
                                  ],
                            )
                          : null,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                      image: _shouldShowProfilePicture(widget.post.profilePicture)
                          ? DecorationImage(
                              image: _isBackendUrl(widget.post.profilePicture)
                                  ? NetworkImage(_getFullImageUrl(widget.post.profilePicture!))
                                  : FileImage(File(widget.post.profilePicture!)) as ImageProvider,
                              fit: BoxFit.cover,
                              onError: (exception, stackTrace) {
                                debugPrint('🖼️ Error loading profile picture in post: $exception');
                              },
                            )
                          : null,
                    ),
                    child: _shouldShowProfilePicture(widget.post.profilePicture)
                        ? null // No child when showing image
                        : Center(
                            child: isAdminPost 
                              ? const Icon(Icons.verified, color: Colors.white, size: 15) // 20 * 0.75 = 15
                              : Text(
                                  widget.post.username[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14, // 18 * 0.75 = 13.5 ≈ 14
                                  ),
                                ),
                          ),
                  ),
                  if (isAdminPost)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12, // 16 * 0.75 = 12
                        height: 12, // 16 * 0.75 = 12
                        decoration: BoxDecoration(
                          color: Colors.black, // Back to pure black
                          borderRadius: BorderRadius.circular(6), // 8 * 0.75 = 6
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 8, // 10 * 0.75 = 7.5 ≈ 8
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 9), // 12 * 0.75 = 9
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
                            fontSize: 14, // 18 * 0.75 = 13.5 ≈ 14
                          ),
                        ),
                        const SizedBox(width: 5), // 6 * 0.75 = 4.5 ≈ 5
                        const Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 14, // 18 * 0.75 = 13.5 ≈ 14
                        ),
                        if (isAdminPost) ...[
                          const SizedBox(width: 5), // 6 * 0.75 = 4.5 ≈ 5
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), // 6→5, 2→1
                            decoration: BoxDecoration(
                              color: Colors.black, // Back to pure black
                              borderRadius: BorderRadius.circular(6), // 8 * 0.75 = 6
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 6, // 8 * 0.75 = 6
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (isDemoPost) ...[
                          const SizedBox(width: 5), // 6 * 0.75 = 4.5 ≈ 5
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), // 6→5, 2→1
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(6), // 8 * 0.75 = 6
                            ),
                            child: const Text(
                              'DEMO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 6, // 8 * 0.75 = 6
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatTimeAgo(widget.post.createdAt),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11, // 14 * 0.75 = 10.5 ≈ 11
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  _showOptionsMenu(context);
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Voice Player
          Consumer<VoiceProvider>(
            builder: (context, voiceProvider, child) {
              final isCurrentlyPlaying = voiceProvider.isPlaying && 
                  voiceProvider.currentPlayingPostId == widget.post.id;
              
              return GlassmorphismContainer(
                padding: const EdgeInsets.all(8),
                borderRadius: BorderRadius.circular(12),
                borderColor: Colors.black, // Back to pure black
                borderWidth: 1.5,
                child: Column(
                  children: [
                    // Real audio waveform with interactive playhead
                    RealAudioWaveform(
                      postId: widget.post.id,
                      audioUrl: widget.post.audioUrl,
                      waveformColor: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : Colors.black,
                      duration: Duration(milliseconds: widget.post.duration),
                      height: 80,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Playback Controls
                    Row(
                      children: [
                        // Play/Pause Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black, // Back to pure black
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: Icon(isCurrentlyPlaying 
                                ? Icons.pause 
                                : Icons.play_arrow),
                            color: Colors.white,
                            onPressed: () async {
                              debugPrint('🎵 Play button pressed for post: ${widget.post.id}');
                              debugPrint('📁 Audio path: ${widget.post.audioUrl}');
                              
                              if (isCurrentlyPlaying) {
                                debugPrint('⏸️ Stopping current playback');
                                await voiceProvider.stopPlayback();
                              } else {
                                debugPrint('▶️ Starting playback');
                                await voiceProvider.playPost(widget.post.id, widget.post.audioUrl);
                              }
                            },
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Duration
                        Text(
                          _formatDuration(widget.post.duration),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // Description Button
                        if (widget.post.description != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showDescription = !_showDescription;
                              });
                            },
                            child: Icon(
                              _showDescription 
                                  ? Icons.keyboard_arrow_up 
                                  : Icons.description_outlined,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        
                        const SizedBox(width: 8),
                        
                        // View transcription button - her zaman göster
                        GestureDetector(
                          onTap: _toggleTranscription,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.black.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'View transcription',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // Description (only when expanded)
          if (_showDescription && widget.post.description != null) ...[
            const SizedBox(height: 8),
            GlassmorphismContainer(
              padding: const EdgeInsets.all(12),
              borderRadius: BorderRadius.circular(8),
              backgroundColor: Colors.grey.withOpacity(0.1),
              child: Text(
                widget.post.description!,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],

          // Transcription (only when expanded)
          if (_showTranscription) ...[
            const SizedBox(height: 8),
            GlassmorphismContainer(
              padding: const EdgeInsets.all(12),
              borderRadius: BorderRadius.circular(8),
              backgroundColor: Colors.grey.withOpacity(0.1),
              child: _isLoadingTranscription
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _transcription != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _transcription!.text,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.language,
                                      size: 12,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _transcription!.language.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.analytics,
                                      size: 12,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(_transcription!.confidence * 100).round()}%',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        )
                      : const Text(
                          'Failed to load transcription',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
            ),
          ],

          const SizedBox(height: 8),

          // Action Buttons
          Row(
            children: [
              // Like Button
              GestureDetector(
                onTap: _toggleLike,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_animationController.value * 0.2),
                          child: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: _isLiked 
                                ? Colors.red // Kırmızı kalp
                                : Colors.grey[600],
                            size: 20,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.post.likesCount}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Repost Button
              GestureDetector(
                onTap: () {
                  Provider.of<VoiceProvider>(context, listen: false)
                      .repostPost(widget.post.id);
                  GlassmorphismSnackBar.show(
                    context,
                    message: 'Reposted!',
                    icon: Icons.repeat,
                    duration: const Duration(seconds: 1),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.repeat,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.post.repostsCount}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Comment Button
              GestureDetector(
                onTap: () {
                  _showCommentsSheet(context);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.post.commentsCount}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Share Button
              IconButton(
                icon: Icon(
                  Icons.share_outlined,
                  color: Colors.grey[600],
                  size: 20,
                ),
                onPressed: () {
                  GlassmorphismSnackBar.show(
                    context,
                    message: 'Share feature coming soon!',
                    icon: Icons.share_outlined,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    final isOwnPost = currentUser != null && currentUser.id == widget.post.userId;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassmorphismContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Delete button (only for own posts)
            if (isOwnPost) ...[
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  
                  // Show confirmation dialog
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Post'),
                      content: const Text('Are you sure you want to delete this voice post?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirmed == true) {
                    final success = await Provider.of<VoiceProvider>(context, listen: false)
                        .deletePost(widget.post.id);
                    
                    if (success && context.mounted) {
                      GlassmorphismSnackBar.show(
                        context,
                        message: 'Post deleted successfully',
                        icon: Icons.delete_outline,
                      );
                    } else if (context.mounted) {
                      GlassmorphismSnackBar.show(
                        context,
                        message: 'Failed to delete post',
                        icon: Icons.error_outline,
                      );
                    }
                  }
                },
              ),
            ],
            
            // Report button (for all posts)
            ListTile(
              leading: const Icon(Icons.report_outlined, color: Colors.white),
              title: const Text(
                'Report',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                GlassmorphismSnackBar.show(
                  context,
                  message: 'Report feature coming soon!',
                  icon: Icons.report_outlined,
                );
              },
            ),
            
            // Block button (only for other users' posts)
            if (!isOwnPost) ...[
              ListTile(
                leading: const Icon(Icons.block_outlined, color: Colors.white),
                title: const Text(
                  'Block User',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  GlassmorphismSnackBar.show(
                    context,
                    message: 'Block feature coming soon!',
                    icon: Icons.block_outlined,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCommentsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GlassmorphismContainer(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          children: [
            const Text(
              'Comments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: widget.post.commentsCount == 0
                  ? const Center(
                      child: Text(
                        'No comments yet. Be the first!',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : Center(
                      child: Text(
                        '${widget.post.commentsCount} comments\n\nComments feature coming soon!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }


}

 