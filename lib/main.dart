import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'widgets/glassmorphism_widgets.dart';

import 'screens/auth/login_page.dart';
import 'screens/auth/signup_page.dart';
import 'screens/home/main_feed_page.dart';
import 'screens/profile/profile_page.dart';
import 'screens/voice/voice_record_page.dart';
import 'screens/search/search_page.dart';
import 'screens/discover/discover_page.dart';
import 'screens/messenger/messenger_page.dart';
import 'providers/auth_provider.dart';
import 'providers/voice_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay for full-screen glassmorphism
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  
  // Enable edge-to-edge mode
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );
  
  // Request permissions only on mobile platforms
  if (Platform.isIOS || Platform.isAndroid) {
    await [
      Permission.microphone,
      Permission.storage,
    ].request();
  }
  
  runApp(const ResonanceApp());
}

class ResonanceApp extends StatelessWidget {
  const ResonanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VoiceProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, authProvider, themeProvider, _) {
          return MaterialApp.router(
            title: 'Resonance',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: _createRouter(authProvider),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }

  GoRouter _createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/feed',
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isAuthRoute = ['/login', '/signup'].contains(state.fullPath);
        
        if (!isAuthenticated && !isAuthRoute) {
          return '/login';
        }
        if (isAuthenticated && isAuthRoute) {
          return '/feed';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const LoginPage(),
          ),
        ),
        GoRoute(
          path: '/signup',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const SignupPage(),
          ),
        ),
        ShellRoute(
          builder: (context, state, child) => MainScaffold(child: child),
          routes: [
            GoRoute(
              path: '/feed',
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: const MainFeedPage(),
              ),
            ),
            GoRoute(
              path: '/search',
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: const SearchPage(),
              ),
            ),
            GoRoute(
              path: '/record',
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: const VoiceRecordPage(),
              ),
            ),
            GoRoute(
              path: '/discover',
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: const DiscoverPage(),
              ),
            ),
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: const ProfilePage(),
              ),
            ),
            GoRoute(
              path: '/messenger',
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: const MessengerPage(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class MainScaffold extends StatefulWidget {
  final Widget child;
  
  const MainScaffold({super.key, required this.child});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  void _updateCurrentIndex(String path) {
    setState(() {
      switch (path) {
        case '/feed':
          _currentIndex = 0;
          break;
        case '/search':
          _currentIndex = 1;
          break;
        case '/record':
          _currentIndex = 2;
          break;
        case '/discover':
          _currentIndex = 3;
          break;
        case '/profile':
          _currentIndex = 4;
          break;
        default:
          _currentIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Update current index based on current route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentRoute = GoRouterState.of(context).uri.path;
      _updateCurrentIndex(currentRoute);
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkGradient : AppTheme.lightGradient,
        ),
        child: widget.child,
      ),
      bottomNavigationBar: GlassmorphismBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          switch (index) {
            case 0:
              context.go('/feed');
              break;
            case 1:
              context.go('/search');
              break;
            case 2:
              context.go('/record');
              break;
            case 3:
              context.go('/discover');
              break;
            case 4:
              context.go('/profile');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        backgroundColor: Colors.transparent,
        selectedItemColor: isDark ? Colors.white : Colors.black,
        unselectedItemColor: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
        elevation: 0,
        iconSize: 27, // 25'ten 27'ye büyütüldü (2 tık)
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, size: 27),
            activeIcon: Icon(Icons.home, size: 27),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined, size: 27),
            activeIcon: Icon(Icons.search, size: 27),
            label: 'Search',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.mic_outlined, size: 27),
            activeIcon: Icon(Icons.mic, size: 27),
            label: 'Record',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined, size: 27),
            activeIcon: Icon(Icons.explore, size: 27),
            label: 'Discover',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined, size: 27),
            activeIcon: Icon(Icons.person, size: 27),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
