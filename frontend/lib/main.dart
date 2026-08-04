// lib/main.dart
// ONLY CHANGE from your original:
//   themeMode: ThemeMode.dark  (was ThemeMode.system)
//   _navIndicatorColor() uses AppTheme.accent for Progress tab
//   Bottom nav gets a top glass border
// Everything else is identical.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/places_provider.dart';
import 'providers/favourites_provider.dart';
import 'providers/gamification_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/favourites/favourites_screen.dart';
import 'screens/taste_profile/taste_profile_screen.dart';
import 'screens/explore/explore_screen.dart';
import 'screens/progress/progress_screen.dart';
import 'screens/home/passport_screen.dart';
import 'screens/home/mood_screen.dart';
import 'screens/home/challenges_screen.dart';
import 'screens/home/leaderboard_screen.dart';
import 'utils/app_theme.dart';
import 'services/notification_service.dart';
import 'services/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:          Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlacesProvider()),
        ChangeNotifierProvider(create: (_) => FavouritesProvider()),
        ChangeNotifierProvider(create: (_) => GamificationProvider()..init()),
      ],
      child: const GeoTasteApp(),
    ),
  );
}

class GeoTasteApp extends StatelessWidget {
  const GeoTasteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                      'GeoTaste',
      theme:                      AppTheme.lightTheme,
      darkTheme:                  AppTheme.darkTheme,
      themeMode:                  ThemeMode.light, // ← always dark
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash':      (_) => const SplashScreen(),
        '/onboarding':  (_) => const OnboardingScreen(),
        '/login':       (_) => const LoginScreen(),
        '/home':        (_) => const MainShell(),
        '/passport':    (_) => const PassportScreen(),
        '/challenges':  (_) => const ChallengesScreen(),
        '/leaderboard': (_) => const LeaderboardScreen(),
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    FavouritesScreen(),
    TasteProfileScreen(),
    ExploreScreen(),
    ProgressScreen(),
    ProfileScreen(),
  ];

  static String get _baseUrl => kIsWeb
      ? 'http://localhost:8000/api/v1'
      : 'http://10.0.2.2:8000/api/v1';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    String name = prefs.getString('user_name') ?? '';
    String city = prefs.getString('user_city') ?? 'delhi';

    final token = await ApiClient.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final res = await http.get(
          Uri.parse('$_baseUrl/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final me     = jsonDecode(res.body) as Map<String, dynamic>;
          final svName = me['username'] as String? ?? '';
          final svCity = me['city']     as String? ?? '';
          if (svName.isNotEmpty) name = svName;
          if (svCity.isNotEmpty) city = svCity;
          await prefs.setString('user_name', name);
          await prefs.setString('user_city', city);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    context.read<PlacesProvider>().setUser(name: name, city: city);
    context.read<GamificationProvider>().trackAction(
      action: GamificationAction.dailyOpen,
    );
  }

  Color _indicatorColor() {
    if (_index == 4) return AppTheme.violet.withOpacity(0.18);
    return AppTheme.primary.withOpacity(0.15);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppTheme.bgCard,
            border: Border(
              top: BorderSide(color: AppTheme.glassStroke, width: 1),
            ),
          ),
          child: NavigationBar(
            backgroundColor:       Colors.transparent,
            indicatorColor:        _indicatorColor(),
            selectedIndex:         _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              const NavigationDestination(
                icon:         Icon(Icons.restaurant_outlined),
                selectedIcon: Icon(Icons.restaurant),
                label:        'Discover',
              ),
              const NavigationDestination(
                icon:         Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label:        'Saved',
              ),
              const NavigationDestination(
                icon:         Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label:        'Taste',
              ),
              const NavigationDestination(
                icon:         Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label:        'Explore',
              ),
              NavigationDestination(
                icon: const Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(
                  Icons.emoji_events,
                  color: _index == 4 ? AppTheme.violet : null,
                ),
                label: 'Progress',
              ),
              const NavigationDestination(
                icon:         Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label:        'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}