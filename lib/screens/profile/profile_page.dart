import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/auth_provider.dart';
import '../../providers/voice_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glassmorphism_widgets.dart';
import 'profile_photo_preview.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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

  // Helper function to determine if gradient should be shown
  bool _shouldShowGradient(String? profilePicture) {
    return profilePicture == null || 
           (profilePicture.length == 1) || // Single emoji character
           (!_isBackendUrl(profilePicture) && !File(profilePicture).existsSync()); // Local file doesn't exist
  }

  // Helper function to determine if image should be shown
  bool _shouldShowImage(String? profilePicture) {
    if (profilePicture == null || profilePicture.length == 1) return false;
    
    if (_isBackendUrl(profilePicture)) {
      return true; // Assume backend URLs are valid
    } else {
      return File(profilePicture).existsSync(); // Check if local file exists
    }
  }

  // Helper function to determine if it's a backend URL
  bool _isBackendUrl(String profilePicture) {
    return profilePicture.startsWith('/uploads/');
  }

  // Helper function to get full image URL
  String _getFullImageUrl(String imagePath) {
    if (!_isBackendUrl(imagePath)) return imagePath;
    
    // Use the same logic as ApiService
    const String baseUrl = 'http://192.168.1.100:3000';
    return '$baseUrl$imagePath';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final user = authProvider.user;
            return ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.1),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: AppBar(
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user?.username ?? 'Profile',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 20,
                        ),
                      ],
                    ),
                    centerTitle: false,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.white),
                        onPressed: () {
                          _showSettingsSheet(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      body: Consumer2<AuthProvider, VoiceProvider>(
        builder: (context, authProvider, voiceProvider, child) {
          final user = authProvider.user;
          debugPrint('🖼️ Building profile page - user profile picture: ${user?.profilePicture}');
          final userPosts = voiceProvider.voicePosts
              .where((post) => post.userId == user?.id)
              .toList();

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + kToolbarHeight, // Status bar + AppBar only
              16,
              MediaQuery.of(context).padding.bottom + 16, // Home indicator + spacing
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header - Instagram Style
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Profile Picture + Stats
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Profile Picture - Bigger, Instagram style
                          Stack(
                            children: [
                              Container(
                                width: 90, // Much bigger like Instagram
                                height: 90,
                                                              decoration: BoxDecoration(
                                gradient: _shouldShowGradient(user?.profilePicture)
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: user?.isAdmin == true 
                                        ? [
                                            Colors.black,
                                            Colors.grey.shade800,
                                          ]
                                        : [
                                            _getUserColor(user?.username ?? 'User'),
                                            _getUserColor(user?.username ?? 'User').withOpacity(0.7),
                                          ],
                                    )
                                  : null,
                                color: user?.profilePicture == null ? Colors.grey.withOpacity(0.3) : null,
                                borderRadius: BorderRadius.circular(45),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                                image: _shouldShowImage(user?.profilePicture)
                                  ? () {
                                      debugPrint('🖼️ Showing image for: ${user!.profilePicture}');
                                      final fullImageUrl = _getFullImageUrl(user.profilePicture!);
                                      debugPrint('🖼️ Full image URL: $fullImageUrl');
                                      return DecorationImage(
                                        image: _isBackendUrl(user.profilePicture!)
                                          ? NetworkImage(fullImageUrl)
                                          : FileImage(File(user.profilePicture!)) as ImageProvider,
                                        fit: BoxFit.cover,
                                        onError: (exception, stackTrace) {
                                          debugPrint('🖼️ Error loading image: $exception');
                                        },
                                      );
                                    }()
                                  : null,
                              ),
                                child: _shouldShowGradient(user?.profilePicture)
                                  ? user?.profilePicture != null && user!.profilePicture!.length == 1
                                    ? Center(
                                        child: Text(
                                          user.profilePicture!,
                                          style: const TextStyle(
                                            fontSize: 40,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.white.withOpacity(0.7),
                                      )
                                  : null,
                              ),
                              
                              // Add Photo Button
                              if (_shouldShowGradient(user?.profilePicture))
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: GestureDetector(
                                    onTap: authProvider.isUploadingProfilePicture 
                                      ? null 
                                      : () => _showImagePickerDialog(context),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: authProvider.isUploadingProfilePicture 
                                          ? Colors.grey 
                                          : Colors.blue,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: authProvider.isUploadingProfilePicture
                                        ? const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.add,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          
                          const SizedBox(width: 24),
                          
                          // Stats Row - Instagram style (horizontal)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Real name above stats
                                Text(
                                  'Cem Yönetim',
                                  style: TextStyle(
                                    fontSize: 14, // 16'dan 14'e küçültüldü
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Stats row - soldan hizalı
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start, // spaceEvenly'den start'a değişti
                                  children: [
                                    _buildInstagramStatItem('${userPosts.length}', 'Posts', isDark),
                                    const SizedBox(width: 24), // Aralarına boşluk eklendi
                                    _buildInstagramStatItem('0', 'Followers', isDark),
                                    const SizedBox(width: 24),
                                    _buildInstagramStatItem('0', 'Following', isDark),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Bio (if available)
                      if (user?.bio != null) ...[
                        Text(
                          user!.bio!,
                          style: TextStyle(
                            color: isDark 
                              ? Colors.white.withOpacity(0.8)
                              : Colors.black.withOpacity(0.8),
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      
                      // Link (if available)
                      if (user?.link != null) ...[
                        GestureDetector(
                          onTap: () {
                            GlassmorphismSnackBar.show(
                              context,
                              message: 'Link: ${user.link}',
                              icon: Icons.link,
                            );
                          },
                          child: Text(
                            user!.link!,
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // Member since
                      Text(
                        'Member since ${_formatDate(user?.createdAt)}',
                        style: TextStyle(
                          color: isDark 
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Action Buttons - Minimal glass style
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _showEditProfileDialog(context),
                                  child: Center(
                                    child: Text(
                                      'Edit profile',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    GlassmorphismSnackBar.show(
                                      context,
                                      message: 'Share profile feature coming soon!',
                                      icon: Icons.share,
                                    );
                                  },
                                  child: Center(
                                    child: Text(
                                      'Share profile',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Separator
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        isDark 
                          ? Colors.white.withOpacity(0.2)
                          : Colors.black.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // My Takes (Voice Posts) - Instagram-style Grid
                Text(
                  'My Takes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Seperator line
                Container(
                  height: 0.5,
                  color: isDark 
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
                ),
                const SizedBox(height: 8),
                
                if (userPosts.isNotEmpty) ...[
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 1.5,
                      mainAxisSpacing: 1.5,
                      childAspectRatio: 1,
                    ),
                    itemCount: userPosts.length,
                                        itemBuilder: (context, index) {
                      final post = userPosts[index];
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: isDark 
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                        ),
                        child: Stack(
                          children: [
                            // Center play button
                            Center(
                              child: GestureDetector(
                                onTap: () {
                                  // Play audio
                                  final audioUrl = post.audioUrl;
                                  // Use VoiceProvider to play the audio
                                  final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
                                  voiceProvider.playRecording(audioUrl);
                                  
                                  GlassmorphismSnackBar.show(
                                    context,
                                    message: 'Playing voice post...',
                                    icon: Icons.play_arrow,
                                  );
                                                                },
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    size: 36,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            
                            // Like count - bottom left
                            Positioned(
                              bottom: 6,
                              left: 6,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${post.likesCount}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 2,
                                          offset: Offset(1, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Play count - bottom right  
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_arrow,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${post.likesCount * 3}', // Mock play count
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 2,
                                          offset: Offset(1, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ] else ...[
                  // Empty State
                  GlassmorphismCard(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.mic_off_outlined,
                          size: 48,
                          color: isDark 
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No voice posts yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Share your first voice post to get started!',
                          style: TextStyle(
                            color: isDark 
                              ? Colors.white.withOpacity(0.7)
                              : Colors.black.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        GlassmorphismButton(
                          onPressed: () => context.go('/record'),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic, size: 16),
                              SizedBox(width: 8),
                              Text('Record First Post'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 100), // Bottom padding for nav bar
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20, // Increased from 16
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isDark 
              ? Colors.white.withOpacity(0.6)
              : Colors.black.withOpacity(0.6),
            fontSize: 12, // Increased from 10
          ),
        ),
      ],
    );
  }

  Widget _buildInstagramStatItem(String value, String label, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isDark 
              ? Colors.white.withOpacity(0.6)
              : Colors.black.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    return '${dateTime.month}/${dateTime.year}';
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

  void _showSettingsSheet(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => GlassmorphismContainer(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark 
                    ? Colors.white.withOpacity(0.3)
                    : Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              
              // Settings List
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      // Record New Voice Post
                      ListTile(
                        leading: const Icon(Icons.mic),
                        title: const Text('Record New Voice Post'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pop(context);
                          context.go('/record');
                        },
                      ),
                      const Divider(height: 1),
                      
                      // Edit Profile
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Edit Profile'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pop(context);
                          _showEditProfileDialog(context);
                        },
                      ),
                      
                      // Admin-only actions
                      if (user?.isAdmin == true) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.admin_panel_settings, color: Colors.black),
                          title: Text(
                            'Admin Dashboard',
                            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w500),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.pop(context);
                            GlassmorphismSnackBar.show(
                              context,
                              message: '🛡️ Admin dashboard coming soon! Manage users, content, and platform settings.',
                              icon: Icons.admin_panel_settings,
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.analytics, color: Colors.black),
                          title: Text(
                            'Platform Analytics',
                            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w500),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.pop(context);
                            GlassmorphismSnackBar.show(
                              context,
                              message: '📊 Platform analytics coming soon! View user engagement and content metrics.',
                              icon: Icons.analytics,
                            );
                          },
                        ),
                      ],
                      
                      const Divider(height: 1),
                      
                      // Theme
                      Consumer<ThemeProvider>(
                        builder: (context, themeProvider, _) {
                          return ListTile(
                            leading: Icon(
                              themeProvider.themeMode == ThemeMode.dark
                                  ? Icons.dark_mode
                                  : themeProvider.themeMode == ThemeMode.light
                                      ? Icons.light_mode
                                      : Icons.brightness_auto,
                            ),
                            title: const Text('Theme'),
                            subtitle: Text(themeProvider.themeModeString),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _showThemeSelector(context, themeProvider),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      
                      // Notifications
                      ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: const Text('Notifications'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pop(context);
                          GlassmorphismSnackBar.show(
                            context,
                            message: 'Notifications settings coming soon!',
                            icon: Icons.notifications_outlined,
                          );
                        },
                      ),
                      const Divider(height: 1),
                      
                      // Privacy & Safety
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy & Safety'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pop(context);
                          GlassmorphismSnackBar.show(
                            context,
                            message: 'Privacy settings coming soon!',
                            icon: Icons.privacy_tip_outlined,
                          );
                        },
                      ),
                      const Divider(height: 1),
                      
                      // Help & Support
                      ListTile(
                        leading: const Icon(Icons.help_outline),
                        title: const Text('Help & Support'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pop(context);
                          GlassmorphismSnackBar.show(
                            context,
                            message: 'Help & Support coming soon!',
                            icon: Icons.help_outline,
                          );
                        },
                      ),
                      const Divider(height: 1),
                      
                      // About Resonance
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('About Resonance'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pop(context);
                          _showAboutDialog(context);
                        },
                      ),
                      
                      // Spacer
                      const SizedBox(height: 20),
                      
                      // Sign Out Button
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                        onTap: () {
                          Navigator.pop(context);
                          _showSignOutDialog(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassmorphismContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'About Resonance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Resonance is a voice-first social media platform where users share 15-second audio clips.\n\nThis is a demo version showcasing the core features.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              GlassmorphismButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user == null) return;

    final usernameController = TextEditingController(text: user.username);
    final bioController = TextEditingController(text: user.bio ?? '');
    final linkController = TextEditingController(text: user.link ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassmorphismContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    children: [
                      const Icon(Icons.edit, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Profile Picture Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.photo, color: Colors.white.withOpacity(0.7), size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Profile Photo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Current Profile Picture
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: _shouldShowGradient(user.profilePicture)
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: user.isAdmin == true 
                                        ? [Colors.black, Colors.grey.shade800]
                                        : [
                                            _getUserColor(user.username ?? 'User'),
                                            _getUserColor(user.username ?? 'User').withOpacity(0.7),
                                          ],
                                    )
                                  : null,
                                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                                image: _shouldShowImage(user.profilePicture)
                                  ? DecorationImage(
                                      image: _isBackendUrl(user.profilePicture!)
                                        ? NetworkImage(_getFullImageUrl(user.profilePicture!))
                                        : FileImage(File(user.profilePicture!)) as ImageProvider,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              ),
                              child: _shouldShowGradient(user.profilePicture)
                                ? user.profilePicture != null && user.profilePicture!.length == 1
                                  ? Center(
                                      child: Text(
                                        user.profilePicture!,
                                        style: const TextStyle(fontSize: 20, color: Colors.white),
                                      ),
                                    )
                                  : Icon(Icons.person, size: 20, color: Colors.white.withOpacity(0.7))
                                : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: GlassmorphismButton(
                                onPressed: authProvider.isUploadingProfilePicture 
                                  ? null 
                                  : () {
                                      Navigator.of(context).pop(); // Close edit dialog first
                                      _showImagePickerDialog(context); // Show image picker
                                    },
                                backgroundColor: authProvider.isUploadingProfilePicture 
                                  ? Colors.grey.withOpacity(0.3)
                                  : Colors.blue.withOpacity(0.3),
                                child: authProvider.isUploadingProfilePicture
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Uploading...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'Change Photo',
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
                  
                  const SizedBox(height: 16),
                  
                  // Username Field
                  _buildEditField(
                    controller: usernameController,
                    label: 'Username',
                    icon: Icons.person,
                    maxLength: 30,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Bio Field
                  _buildEditField(
                    controller: bioController,
                    label: 'Bio',
                    icon: Icons.description,
                    maxLines: 4,
                    maxLength: 200,
                    hint: 'Tell us about yourself...',
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Link Field
                  _buildEditField(
                    controller: linkController,
                    label: 'Link',
                    icon: Icons.link,
                    maxLength: 100,
                    hint: 'https://example.com',
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action Buttons
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
                            // Validate inputs
                            if (usernameController.text.trim().isEmpty) {
                              GlassmorphismSnackBar.show(
                                context,
                                message: 'Username cannot be empty',
                                icon: Icons.error,
                              );
                              return;
                            }
                            
                            // Update profile
                            await authProvider.updateProfile(
                              username: usernameController.text.trim(),
                              bio: bioController.text.trim().isNotEmpty 
                                  ? bioController.text.trim() 
                                  : null,
                              link: linkController.text.trim().isNotEmpty 
                                  ? linkController.text.trim() 
                                  : null,
                            );
                            
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              GlassmorphismSnackBar.show(
                                context,
                                                                message: 'Profile updated successfully! ✨',
                                icon: Icons.check_circle,
                              );
                            }
                          },
                          child: const Text(
                            'Save Changes',
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
          ),
        );
      },
    );
  }

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GlassmorphismContainer(
          padding: const EdgeInsets.all(12),
          borderRadius: BorderRadius.circular(12),
          borderColor: Colors.white.withOpacity(0.2),
          borderWidth: 1,
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              counterStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
        ),
      ],
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassmorphismContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to sign out?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GlassmorphismButton(
                      onPressed: () => Navigator.pop(context),
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
                      onPressed: () {
                        Navigator.pop(context);
                        Provider.of<AuthProvider>(context, listen: false).signOut();
                        context.go('/login');
                      },
                      child: const Text(
                        'Sign Out',
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
      ),
    );
  }

  void _showThemeSelector(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
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
                  'Choose Theme',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.brightness_auto, color: Colors.white),
                  title: const Text(
                    'System',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text(
                    'Follow device theme',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  trailing: themeProvider.themeMode == ThemeMode.system
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                  onTap: () {
                    themeProvider.setThemeMode(ThemeMode.system);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.light_mode, color: Colors.white),
                  title: const Text(
                    'Light',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text(
                    'Always use light theme',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  trailing: themeProvider.themeMode == ThemeMode.light
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                  onTap: () {
                    themeProvider.setThemeMode(ThemeMode.light);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.dark_mode, color: Colors.white),
                  title: const Text(
                    'Dark',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text(
                    'Always use dark theme',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  trailing: themeProvider.themeMode == ThemeMode.dark
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                  onTap: () {
                    themeProvider.setThemeMode(ThemeMode.dark);
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 16),
                GlassmorphismButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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

  void _showImagePickerDialog(BuildContext context) {
    showDialog(
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
                // Dialog Header
                Row(
                  children: [
                    const Icon(Icons.add_a_photo, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Add Profile Photo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Camera Option
                ListTile(
                  leading: Icon(
                    Icons.camera_alt, 
                    color: context.watch<AuthProvider>().isUploadingProfilePicture 
                      ? Colors.grey 
                      : Colors.white,
                  ),
                  title: Text(
                    'Take Photo',
                    style: TextStyle(
                      color: context.watch<AuthProvider>().isUploadingProfilePicture 
                        ? Colors.grey 
                        : Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    'Use camera to take a new photo',
                    style: TextStyle(
                      color: context.watch<AuthProvider>().isUploadingProfilePicture 
                        ? Colors.grey 
                        : Colors.white70,
                    ),
                  ),
                  onTap: context.watch<AuthProvider>().isUploadingProfilePicture 
                    ? null 
                    : () {
                        Navigator.of(context).pop();
                        _pickImage(context, ImageSource.camera);
                      },
                ),
                
                const Divider(color: Colors.white24),
                
                // Gallery Option
                ListTile(
                  leading: Icon(
                    Icons.photo_library, 
                    color: context.watch<AuthProvider>().isUploadingProfilePicture 
                      ? Colors.grey 
                      : Colors.white,
                  ),
                  title: Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      color: context.watch<AuthProvider>().isUploadingProfilePicture 
                        ? Colors.grey 
                        : Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    'Select from your photo library',
                    style: TextStyle(
                      color: context.watch<AuthProvider>().isUploadingProfilePicture 
                        ? Colors.grey 
                        : Colors.white70,
                    ),
                  ),
                  onTap: context.watch<AuthProvider>().isUploadingProfilePicture 
                    ? null 
                    : () {
                        Navigator.of(context).pop();
                        _pickImage(context, ImageSource.gallery);
                      },
                ),
                
                const SizedBox(height: 16),
                
                // Cancel Button
                GlassmorphismButton(
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
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      debugPrint('📸 Starting image picker...');
      
      // Save AuthProvider reference BEFORE image picker
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Check if upload is already in progress
      if (authProvider.isUploadingProfilePicture) {
        debugPrint('⏳ Profile picture upload already in progress, blocking image picker');
        if (mounted) {
          GlassmorphismSnackBar.show(
            context,
            message: 'Profile photo upload in progress. Please wait.',
            icon: Icons.warning,
          );
        }
        return;
      }
      
      // Store the navigator for later use
      final navigator = Navigator.of(context);
      
      // For iOS, try to pick image directly first, then handle permission errors
      if (Platform.isIOS) {
        try {
          // Try to pick image directly - iOS will show permission dialog automatically
          final ImagePicker picker = ImagePicker();
          final XFile? image = await picker.pickImage(
            source: source,
            maxWidth: 800,
            maxHeight: 800,
            imageQuality: 85,
          );
          
          if (image != null) {
            debugPrint('✅ Image selected: ${image.path}');
            debugPrint('🖼️ Widget mounted: $mounted');
            
            // Show preview using stored navigator
            debugPrint('🖼️ About to show preview...');
            
            // Wait a bit for UI to stabilize
            await Future.delayed(const Duration(milliseconds: 300));
            
            if (mounted) {
              await _showProfilePhotoPreviewSafe(navigator, image.path);
              debugPrint('🖼️ Preview completed');
            } else {
              debugPrint('❌ Widget not mounted, cannot show preview');
            }
          } else {
            debugPrint('❌ No image selected');
          }
          return;
        } catch (e) {
          debugPrint('⚠️ iOS direct pick failed: $e');
          // Continue to permission handling
        }
      }
      
      // Fallback permission handling for Android or iOS permission issues
      late PermissionStatus permissionStatus;
      
      if (source == ImageSource.camera) {
        permissionStatus = await Permission.camera.request();
        debugPrint('📷 Camera permission: $permissionStatus');
      } else {
        // For gallery access
        if (Platform.isIOS) {
          // Try multiple permission types for iOS
          permissionStatus = await Permission.photos.request();
          debugPrint('🖼️ iOS Photos permission: $permissionStatus');
          
          // If photos permission fails, try storage
          if (permissionStatus.isDenied) {
            permissionStatus = await Permission.storage.request();
            debugPrint('🖼️ iOS Storage permission: $permissionStatus');
          }
        } else {
          // Android 13+ uses different permissions
          permissionStatus = await Permission.storage.request();
          if (permissionStatus.isDenied) {
            permissionStatus = await Permission.photos.request();
          }
        }
        debugPrint('🖼️ Photo library permission: $permissionStatus');
      }
      
      // Check if permission is granted
      if (permissionStatus.isDenied) {
        if (mounted) {
          GlassmorphismSnackBar.show(
            context,
            message: 'Permission denied. Please allow access in settings.',
            icon: Icons.error,
          );
        }
        return;
      }
      
      if (permissionStatus.isPermanentlyDenied) {
        if (mounted) {
          _showPermissionDeniedDialog(context, source);
        }
        return;
      }
      
      // Pick image
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        debugPrint('✅ Image selected: ${image.path}');
        
        // Show preview with context check
        debugPrint('🖼️ About to show preview (permission flow)...');
        
        // Wait a bit for UI to stabilize
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (mounted) {
          await _showProfilePhotoPreviewSafe(navigator, image.path);
          debugPrint('🖼️ Preview completed (permission flow)');
        } else {
          debugPrint('❌ Widget not mounted in permission flow');
        }
      } else {
        debugPrint('❌ No image selected');
      }
      
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      if (mounted) {
        GlassmorphismSnackBar.show(
          context,
          message: 'Error selecting image: $e',
          icon: Icons.error,
        );
      }
    }
  }



    Future<void> _showProfilePhotoPreview(BuildContext context, String imagePath) async {
    debugPrint('🖼️ Showing profile photo preview for: $imagePath');
    
    // Ensure context is mounted before navigation
    if (!mounted) {
      debugPrint('❌ Widget not mounted, cannot show preview');
      return;
    }
    
    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          ProfilePhotoPreview(imagePath: imagePath),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    
    debugPrint('🖼️ Preview result: $result');
    
    if (result != null && result is String) {
      // User confirmed the photo and we got the cropped image path
      debugPrint('🖼️ User confirmed profile photo, cropped image: $result');
      
      // Get authProvider reference while context is available
      if (!mounted) {
        debugPrint('❌ Widget not mounted after preview');
        return;
      }
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      debugPrint('🖼️ Before update - current profile picture: ${authProvider.user?.profilePicture}');
      
      // Show loading indicator
      if (mounted) {
        GlassmorphismSnackBar.show(
          context,
          message: 'Uploading profile photo... Please wait',
          icon: Icons.upload,
          duration: const Duration(seconds: 2),
        );
      }
      
      final updateResult = await authProvider.updateProfile(profilePicture: result);
      debugPrint('🖼️ Update result: $updateResult');
      debugPrint('🖼️ After update - current profile picture: ${authProvider.user?.profilePicture}');
      
      if (mounted) {
        if (updateResult) {
          GlassmorphismSnackBar.show(
            context,
            message: 'Profile photo updated! 📸',
            icon: Icons.check_circle,
          );
        } else {
          GlassmorphismSnackBar.show(
            context,
            message: 'Failed to upload profile photo. Please try again.',
            icon: Icons.error,
          );
        }
      }
    } else {
      debugPrint('🖼️ User cancelled photo selection');
    }
  }

  // Safe preview method that doesn't depend on context
  Future<void> _showProfilePhotoPreviewSafe(NavigatorState navigator, String imagePath) async {
    debugPrint('🖼️ Showing profile photo preview (safe) for: $imagePath');
    
    // Ensure widget is still mounted
    if (!mounted) {
      debugPrint('❌ Widget not mounted, cannot show preview');
      return;
    }
    
    final result = await navigator.push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          ProfilePhotoPreview(imagePath: imagePath),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    
    debugPrint('🖼️ Preview result (safe): $result');
    
    if (result != null && result is String) {
      // User confirmed the photo and we got the cropped image path
      debugPrint('🖼️ User confirmed profile photo, cropped image: $result');
      
      // Check if widget is still mounted
      if (!mounted) {
        debugPrint('❌ Widget not mounted after preview');
        return;
      }
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      debugPrint('🖼️ Before update - current profile picture: ${authProvider.user?.profilePicture}');
      
      // Show loading indicator
      if (mounted) {
        GlassmorphismSnackBar.show(
          context,
          message: 'Uploading profile photo... Please wait',
          icon: Icons.upload,
          duration: const Duration(seconds: 2),
        );
      }
      
      final updateResult = await authProvider.updateProfile(profilePicture: result);
      debugPrint('🖼️ Update result: $updateResult');
      debugPrint('🖼️ After update - current profile picture: ${authProvider.user?.profilePicture}');
      
      if (mounted) {
        if (updateResult) {
          GlassmorphismSnackBar.show(
            context,
            message: 'Profile photo updated! 📸',
            icon: Icons.check_circle,
          );
        } else {
          GlassmorphismSnackBar.show(
            context,
            message: 'Failed to upload profile photo. Please try again.',
            icon: Icons.error,
          );
        }
      }
    } else {
      debugPrint('🖼️ User cancelled photo selection');
    }
  }

  void _showPermissionDeniedDialog(BuildContext context, ImageSource source) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassmorphismContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                source == ImageSource.camera ? Icons.camera_alt : Icons.photo_library,
                color: Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Permission Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                source == ImageSource.camera 
                    ? 'Camera access has been permanently denied.\n\nTo enable:\n1. Go to Settings > Privacy & Security > Camera\n2. Find "VoiceApp" and toggle it ON\n3. Return to the app and try again'
                    : 'Photo library access has been permanently denied.\n\nTo enable:\n1. Go to Settings > Privacy & Security > Photos\n2. Find "VoiceApp" and select "All Photos"\n3. Return to the app and try again',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GlassmorphismButton(
                      onPressed: () => Navigator.pop(context),
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
                      onPressed: () {
                        Navigator.pop(context);
                        openAppSettings();
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
      ),
    );
  }
} 