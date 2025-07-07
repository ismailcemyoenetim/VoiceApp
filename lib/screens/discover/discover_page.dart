import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/glassmorphism_widgets.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassmorphismAppBar(
        title: 'Discover',
        actions: [
          IconButton(
            icon: const Icon(Icons.message_outlined),
            onPressed: () {
              context.go('/messenger');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          0,
          MediaQuery.of(context).padding.top + kToolbarHeight + 16, // Status bar + AppBar + spacing
          0,
          MediaQuery.of(context).padding.bottom + 16, // Home indicator + spacing
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Featured Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Featured Topics',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _featuredTopics.length,
                      itemBuilder: (context, index) {
                        final topic = _featuredTopics[index];
                        return GlassmorphismContainer(
                          width: 200,
                          height: 120,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(16),
                          borderRadius: BorderRadius.circular(16),
                          backgroundColor: Colors.black,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                topic['icon'],
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      topic['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${topic['count']} voices',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Popular Categories
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Popular Categories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return GlassmorphismCard(
                        margin: EdgeInsets.zero,
                        onTap: () {
                          GlassmorphismSnackBar.show(
                            context,
                            message: 'Exploring ${category['name']}...',
                            icon: category['icon'],
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                category['icon'],
                                color: isDark ? Colors.white : Colors.black,
                                size: 22,
                              ),
                              const SizedBox(height: 6),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      category['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: isDark ? Colors.white : Colors.black,
                                        height: 1.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '${category['count']} voices',
                                      style: TextStyle(
                                        color: isDark 
                                          ? Colors.white.withOpacity(0.6)
                                          : Colors.black.withOpacity(0.6),
                                        fontSize: 11,
                                        height: 1.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final List<Map<String, dynamic>> _featuredTopics = [
  {
    'name': 'Trending Now',
    'count': '1.2K',
    'icon': Icons.trending_up,
    'gradientColors': [Colors.purple, Colors.deepPurple],
  },
  {
    'name': 'Tech Reviews',
    'count': '856',
    'icon': Icons.smartphone,
    'gradientColors': [Colors.blue, Colors.blueAccent],
  },
  {
    'name': 'Music Discovery',
    'count': '2.1K',
    'icon': Icons.headphones,
    'gradientColors': [Colors.pink, Colors.pinkAccent],
  },
  {
    'name': 'Daily Podcasts',
    'count': '743',
    'icon': Icons.podcasts,
    'gradientColors': [Colors.green, Colors.lightGreen],
  },
];

final List<Map<String, dynamic>> _categories = [
  {
    'name': 'Education',
    'count': '1.5K',
    'icon': Icons.school,
    'color': Colors.blue,
  },
  {
    'name': 'Entertainment',
    'count': '2.8K',
    'icon': Icons.movie,
    'color': Colors.red,
  },
  {
    'name': 'Sports',
    'count': '1.2K',
    'icon': Icons.sports_soccer,
    'color': Colors.green,
  },
  {
    'name': 'News',
    'count': '967',
    'icon': Icons.newspaper,
    'color': Colors.orange,
  },
  {
    'name': 'Health',
    'count': '823',
    'icon': Icons.favorite,
    'color': Colors.pink,
  },
  {
    'name': 'Business',
    'count': '654',
    'icon': Icons.business,
    'color': Colors.indigo,
  },
]; 