import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/glassmorphism_widgets.dart';

class MessengerPage extends StatefulWidget {
  const MessengerPage({super.key});

  @override
  State<MessengerPage> createState() => _MessengerPageState();
}

class _MessengerPageState extends State<MessengerPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassmorphismAppBar(
        title: 'Messages',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/feed');
          },
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + kToolbarHeight + 16, // Status bar + AppBar + spacing
              16,
              16,
            ),
            child: GlassmorphismContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              borderRadius: BorderRadius.circular(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: isDark 
                      ? Colors.white.withOpacity(0.6)
                      : Colors.black.withOpacity(0.6),
                  ),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
          
          // Voice-only Message Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GlassmorphismContainer(
              padding: const EdgeInsets.all(12),
              borderRadius: BorderRadius.circular(12),
              backgroundColor: Colors.black,
              child: Row(
                children: [
                  const Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Voice messages & calls only',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Conversations List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                16,
                0, // No top padding needed
                16,
                MediaQuery.of(context).padding.bottom + 100, // Home indicator + bottom controls + spacing
              ),
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                final conversation = _conversations[index];
                return GlassmorphismCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.grey.withOpacity(0.8),
                            Colors.grey.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          conversation['name'][0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      conversation['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        if (conversation['isVoice'])
                          Icon(
                            Icons.mic,
                            size: 16,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        if (conversation['isVoice']) const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            conversation['lastMessage'],
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark 
                                ? Colors.white.withOpacity(0.7)
                                : Colors.black.withOpacity(0.7),
                            ),
                          ),
                        ),
                        Text(
                          conversation['time'],
                          style: TextStyle(
                            color: isDark 
                              ? Colors.white.withOpacity(0.6)
                              : Colors.black.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: conversation['unread'] > 0
                        ? Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '${conversation['unread']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      GlassmorphismSnackBar.show(
                        context,
                        message: 'Opening chat with ${conversation['name']}',
                        icon: Icons.chat,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: GlassmorphismContainer(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Expanded(
              child: GlassmorphismButton(
                onPressed: () {
                  GlassmorphismSnackBar.show(
                    context,
                    message: '🎤 Voice recording started...',
                    icon: Icons.mic,
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic, size: 16),
                    SizedBox(width: 8),
                    Text('Record Voice Message'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            GlassmorphismFAB(
              onPressed: () {
                GlassmorphismSnackBar.show(
                  context,
                  message: '📞 Starting voice call...',
                  icon: Icons.phone,
                );
              },
              backgroundColor: Colors.green,
              child: const Icon(Icons.phone, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

final List<Map<String, dynamic>> _conversations = [
  {
    'name': 'Sarah Chen',
    'lastMessage': 'Voice message - 0:15',
    'time': '2m',
    'unread': 2,
    'isVoice': true,
    'color': Colors.pink,
  },
  {
    'name': 'Alex Johnson',
    'lastMessage': 'Voice message - 0:08',
    'time': '1h',
    'unread': 0,
    'isVoice': true,
    'color': Colors.blue,
  },
  {
    'name': 'Maria Rodriguez',
    'lastMessage': 'Voice message - 0:23',
    'time': '3h',
    'unread': 1,
    'isVoice': true,
    'color': Colors.green,
  },
  {
    'name': 'David Kim',
    'lastMessage': 'Voice message - 0:12',
    'time': '1d',
    'unread': 0,
    'isVoice': true,
    'color': Colors.orange,
  },
  {
    'name': 'Emma Thompson',
    'lastMessage': 'Voice message - 0:18',
    'time': '2d',
    'unread': 0,
    'isVoice': true,
    'color': Colors.purple,
  },
  {
    'name': 'James Wilson',
    'lastMessage': 'Voice message - 0:07',
    'time': '3d',
    'unread': 0,
    'isVoice': true,
    'color': Colors.teal,
  },
]; 