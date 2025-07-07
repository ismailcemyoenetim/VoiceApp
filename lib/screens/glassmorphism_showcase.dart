import 'package:flutter/material.dart';
import '../widgets/glassmorphism_widgets.dart';
import '../theme/app_theme.dart';

class GlassmorphismShowcasePage extends StatefulWidget {
  const GlassmorphismShowcasePage({super.key});

  @override
  State<GlassmorphismShowcasePage> createState() => _GlassmorphismShowcasePageState();
}

class _GlassmorphismShowcasePageState extends State<GlassmorphismShowcasePage> {
  bool _isDark = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: _isDark ? AppTheme.darkGradient : AppTheme.lightGradient,
          ),
          child: CustomScrollView(
            slivers: [
              // Glassmorphism App Bar
              SliverAppBar(
                expandedHeight: 120.0,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text('Glassmorphism Showcase'),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: _isDark ? AppTheme.darkGradient : AppTheme.lightGradient,
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(_isDark ? Icons.light_mode : Icons.dark_mode),
                    onPressed: () {
                      setState(() {
                        _isDark = !_isDark;
                      });
                    },
                  ),
                ],
              ),
              
              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cards Section
                      _buildSectionTitle('Glassmorphism Cards'),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: GlassmorphismCard(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    size: 32,
                                    color: _isDark ? Colors.white : Colors.black,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Likes',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '1,234',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: _isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GlassmorphismCard(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.comment,
                                    size: 32,
                                    color: _isDark ? Colors.white : Colors.black,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Comments',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '567',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: _isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Buttons Section
                      _buildSectionTitle('Glassmorphism Buttons'),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: GlassmorphismButton(
                              onPressed: () {
                                                              GlassmorphismSnackBar.show(
                                context,
                                message: 'Primary button pressed!',
                                icon: Icons.touch_app,
                              );
                              },
                              child: const Text('Primary Button'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GlassmorphismButton(
                              onPressed: () {
                                                              GlassmorphismSnackBar.show(
                                context,
                                message: 'Secondary button pressed!',
                                icon: Icons.star,
                              );
                              },
                              backgroundColor: _isDark ? Colors.purple : Colors.pink,
                              child: const Text('Secondary Button'),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Container Section
                      _buildSectionTitle('Glassmorphism Container'),
                      const SizedBox(height: 16),
                      
                      GlassmorphismContainer(
                        height: 200,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.mic,
                              size: 48,
                              color: _isDark ? Colors.white : Colors.black,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Voice Recording',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: _isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Beautiful glassmorphism effect with backdrop blur',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: _isDark ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Feature Card
                      _buildSectionTitle('Feature Card'),
                      const SizedBox(height: 16),
                      
                      GlassmorphismCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome,
                                    color: _isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Glassmorphism UI',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: _isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Modern frosted glass design',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'This voice app now features beautiful glassmorphism effects that provide depth and elegance to the user interface. The translucent elements with backdrop blur create a modern, sophisticated look.',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: _isDark ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Feature List
                      _buildSectionTitle('Features'),
                      const SizedBox(height: 16),
                      
                      ...['Backdrop Blur Effects', 'Translucent Elements', 'Modern Design', 'Smooth Animations', 'Dark/Light Mode Support'].map((feature) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: GlassmorphismCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  feature,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: _isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Glassmorphism FAB
        floatingActionButton: GlassmorphismFAB(
          onPressed: () {
                      GlassmorphismSnackBar.show(
            context,
            message: 'Recording started!',
            icon: Icons.mic,
          );
          },
          child: const Icon(Icons.mic, color: Colors.white),
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _isDark ? Colors.white : Colors.black,
      ),
    );
  }
} 