import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/voice_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glassmorphism_widgets.dart';
import '../../widgets/voice_post_card.dart';

class MainFeedPage extends StatefulWidget {
  const MainFeedPage({super.key});

  @override
  State<MainFeedPage> createState() => _MainFeedPageState();
}

class _MainFeedPageState extends State<MainFeedPage> {
  final ScrollController _scrollController = ScrollController();
  bool _hasLoadedPosts = false;

  @override
  void initState() {
    super.initState();
  }

  void _loadPostsIfAuthenticated() {
    if (!_hasLoadedPosts) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
      
      if (authProvider.isAuthenticated) {
        _hasLoadedPosts = true;
        voiceProvider.loadVoicePosts();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshFeed() async {
    // Reload posts from API
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    _hasLoadedPosts = false; // Reset flag to allow reload
    await voiceProvider.loadVoicePosts();
    _hasLoadedPosts = true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassmorphismAppBar(
        title: 'VoiceApp',
        actions: [
          IconButton(
            icon: const Icon(Icons.message_outlined),
            onPressed: () {
              context.go('/messenger');
            },
          ),
        ],
      ),
      body: Consumer2<VoiceProvider, AuthProvider>(
        builder: (context, voiceProvider, authProvider, child) {
          // Load posts when authenticated
          if (authProvider.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadPostsIfAuthenticated();
            });
          }
          
          // Check if user is authenticated
          if (!authProvider.isAuthenticated) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_circle_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Sign in to continue',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create an account or sign in to start sharing voice posts!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GlassmorphismButton(
                          onPressed: () {
                            context.go('/auth/login');
                          },
                          backgroundColor: Colors.blue.withOpacity(0.7),
                          child: const Text('Sign In'),
                        ),
                        GlassmorphismButton(
                          onPressed: () {
                            context.go('/auth/signup');
                          },
                          child: const Text('Sign Up'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
          
          final posts = voiceProvider.voicePosts;
          
          // Show loading if posts are being loaded
          if (voiceProvider.isLoading && posts.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          // Show error if there's an error loading posts
          if (voiceProvider.errorMessage != null && posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Error loading posts',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      voiceProvider.errorMessage!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    GlassmorphismButton(
                      onPressed: () {
                        voiceProvider.loadVoicePosts();
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 20),
                          SizedBox(width: 8),
                          Text('Retry'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.mic_none,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No voice posts yet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Record your first voice post to get started!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    GlassmorphismButton(
                      onPressed: () {
                        context.go('/voice');
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic, size: 20),
                          SizedBox(width: 8),
                          Text('Start Recording'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshFeed,
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + kToolbarHeight + 16, // Status bar + AppBar + spacing
                16,
                MediaQuery.of(context).padding.bottom + 16, // Home indicator + spacing
              ),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: VoicePostCard(post: post),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none,
            size: 64,
            color: isDark 
                ? Colors.white.withOpacity(0.3)
                : Colors.black.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No voice posts yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark 
                  ? Colors.white.withOpacity(0.8)
                  : Colors.black.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start recording to see posts here',
            style: TextStyle(
              color: isDark 
                  ? Colors.white.withOpacity(0.6)
                  : Colors.black.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
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
} 