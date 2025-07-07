import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/glassmorphism_widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
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
        title: 'Search',
        actions: [
          IconButton(
            icon: const Icon(Icons.message_outlined),
            onPressed: () {
              context.go('/messenger');
            },
          ),
        ],
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
                  hintText: 'Search voices and creators...',
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
          
          // Discover Cards
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                16,
                0, // No top padding needed, search bar handles it
                16,
                MediaQuery.of(context).padding.bottom + 16, // Home indicator + spacing
              ),
              itemCount: _discoverItems.length,
              itemBuilder: (context, index) {
                final item = _discoverItems[index];
                return GlassmorphismCard(
                  margin: const EdgeInsets.only(bottom: 12),
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
                      child: Icon(
                        item['icon'],
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      item['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      '${item['category']} • ${item['followers']} followers',
                      style: TextStyle(
                        color: isDark 
                          ? Colors.white.withOpacity(0.7)
                          : Colors.black.withOpacity(0.7),
                      ),
                    ),
                    trailing: GlassmorphismButton(
                      onPressed: () {
                        GlassmorphismSnackBar.show(
                          context,
                          message: 'Following ${item['name']}!',
                          icon: Icons.favorite,
                        );
                      },
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      borderRadius: BorderRadius.circular(20),
                      child: const Text('Follow'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final List<Map<String, dynamic>> _discoverItems = [
  {
    'name': 'Trending Music',
    'category': 'Music',
    'followers': '2.3K',
    'color': Colors.purple,
    'icon': Icons.music_note,
  },
  {
    'name': 'Tech Talks',
    'category': 'Technology',
    'followers': '1.8K',
    'color': Colors.blue,
    'icon': Icons.computer,
  },
  {
    'name': 'Daily Stories',
    'category': 'Lifestyle',
    'followers': '3.1K',
    'color': Colors.green,
    'icon': Icons.auto_stories,
  },
  {
    'name': 'Comedy Central',
    'category': 'Entertainment',
    'followers': '4.2K',
    'color': Colors.red,
    'icon': Icons.theater_comedy,
  },
  {
    'name': 'Wellness Tips',
    'category': 'Health',
    'followers': '1.5K',
    'color': Colors.orange,
    'icon': Icons.health_and_safety,
  },
  {
    'name': 'Book Reviews',
    'category': 'Education',
    'followers': '967',
    'color': Colors.indigo,
    'icon': Icons.menu_book,
  },
  {
    'name': 'Sports Update',
    'category': 'Sports',
    'followers': '2.8K',
    'color': Colors.teal,
    'icon': Icons.sports_soccer,
  },
  {
    'name': 'Food & Recipes',
    'category': 'Food',
    'followers': '1.2K',
    'color': Colors.pink,
    'icon': Icons.restaurant,
  },
]; 