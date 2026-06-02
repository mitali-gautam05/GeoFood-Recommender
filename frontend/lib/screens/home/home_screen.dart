// ============================================================
// screens/home/home_screen.dart
// Phase 1 fixes applied:
//   1. Leaderboard IconButton added to AppBar actions
//   2. Import comments corrected — MoodChipRow comes from streak_widget.dart
//      NOT from weather_recommendation_service.dart
//   3. WeatherRecommendationBanner now uses weatherContext from
//      PlacesProvider (no more per-rebuild API calls)
//   4. All imports verified against provider getters
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/places_provider.dart';
import '../../../providers/favourites_provider.dart';
import '../../../providers/gamification_provider.dart';
import '../../../widgets/badge_toast.dart';
import '../../../widgets/city_autocomplete_field.dart';
import 'restaurant_detail_page.dart';
import 'widgets/place_card.dart';
import 'widgets/hunger_dialog.dart';
import 'widgets/nearby_banner.dart';
import 'filter_sheet.dart';
import 'meal_time_banner.dart';
import 'passport_screen.dart';
import 'mood_screen.dart';
import 'challenges_screen.dart';
import 'leaderboard_screen.dart';
// StreakBanner AND MoodChipRow both live in streak_widget.dart
import '../../../widgets/streak_widget.dart';
// WeatherRecommendationBanner lives in weather_recommendation_service.dart
// MoodChipRow does NOT come from here
import '../../../services/weather_recommendation_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hungerAsked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_hungerAsked && mounted) {
        _hungerAsked = true;
        await showHungerDialog(context);
      }
    });
  }

  // ── Change city sheet ─────────────────────────────────────
  void _showChangeCitySheet() {
    final provider = context.read<PlacesProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Change city', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            CityAutocompleteField(
              initialValue: provider.currentCity,
              hintText: 'Search for a city…',
              decoration: InputDecoration(
                hintText: 'Search for a city…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onCitySelected: (city) async {
                Navigator.pop(ctx);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_city', city);
                if (context.mounted) {
                  context.read<PlacesProvider>().setCity(city);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Open MoodScreen as full-screen dialog ──────────────────
  void _openMoodScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const MoodScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlacesProvider>();
    final hasFilters = provider.filters.cuisine != null ||
        provider.filters.minRating > 3.0 ||
        provider.filters.minBudget > 0 ||
        provider.filters.maxBudget < 1500;

    return BadgeToastListener(
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: _showChangeCitySheet,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 4),
                Text(
                  provider.currentCity.isEmpty
                      ? 'GeoTaste'
                      : provider.currentCity,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
          centerTitle: false,
          actions: [
            // Passport shortcut
            IconButton(
              icon: const Text('🍽️', style: TextStyle(fontSize: 18)),
              tooltip: 'My Passport',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PassportScreen()),
              ),
            ),
            // Challenges shortcut
            IconButton(
              icon: const Icon(Icons.military_tech_outlined),
              tooltip: 'Challenges',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChallengesScreen()),
              ),
            ),
            // Leaderboard shortcut (was imported but missing from AppBar — fixed)
            IconButton(
              icon: const Icon(Icons.leaderboard_outlined),
              tooltip: 'Leaderboard',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
              ),
            ),
            // Filter icon
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Filters',
                  onPressed: () => FilterSheet.show(
                    context,
                    provider.filters,
                    (f) => provider.applyFilters(f),
                  ),
                ),
                if (hasFilters)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            // Refresh icon
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: provider.isLoading
                  ? null
                  : () => provider.fetchRecommendations(
                        username: provider.userName,
                      ),
            ),
          ],
        ),

        // Mood FAB (bottom-right)
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openMoodScreen,
          icon: const Text('😊', style: TextStyle(fontSize: 18)),
          label: const Text('Mood'),
          backgroundColor: const Color(0xFFFF6B35),
          foregroundColor: Colors.white,
          elevation: 4,
        ),

        body: Column(
          children: [
            // Streak banner — reads PlacesProvider.streak (correct per Critical Rule #4)
            const StreakBanner(),

            // Nearby restaurant GPS banner
            const NearbyRestaurantBanner(),

            Expanded(child: _buildBody(provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(PlacesProvider provider) {
    final theme = Theme.of(context);

    // Not hungry state
    if (provider.isNotHungry) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😌', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text("We'll be here when you're ready.",
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                provider.clearNotHungry();
                provider.fetchRecommendations(username: provider.userName);
              },
              child: const Text("Actually, I'm hungry now"),
            ),
          ],
        ),
      );
    }

    // City not found
    if (provider.cityNotFound != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🗺️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('City not found', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('"${provider.cityNotFound}"',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey)),
              const SizedBox(height: 16),
              if (provider.suggestions.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: provider.suggestions
                      .map((s) => ActionChip(
                            label: Text(s),
                            onPressed: () => provider.setCity(s),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      );
    }

    // Loading
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error
    if (provider.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(provider.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    provider.fetchRecommendations(username: provider.userName),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Empty
    if (provider.places.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍃', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('No restaurants found',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _showChangeCitySheet,
              child: const Text('Try a different city'),
            ),
          ],
        ),
      );
    }

    // Main restaurant list
    return RefreshIndicator(
      onRefresh: () =>
          provider.fetchRecommendations(username: provider.userName),
      child: CustomScrollView(
        slivers: [
          // WeatherRecommendationBanner — reads weatherContext FROM PlacesProvider
          // so it does NOT fire its own API call on every rebuild.
          // PlacesProvider already fetches weather inside fetchRecommendations().
          SliverToBoxAdapter(
            child: WeatherRecommendationBanner(
              weatherContext: provider.weatherContext,
              onTap: () => provider.fetchRecommendations(
                username: provider.userName,
              ),
            ),
          ),

          // MealTimeBanner
          SliverToBoxAdapter(
            child: MealTimeBanner(
              onSuggestionTap: (query) {
                provider.fetchRecommendations(
                  username: provider.userName,
                  query: query,
                );
              },
            ),
          ),

          // MoodChipRow — from streak_widget.dart (NOT weather service)
          SliverToBoxAdapter(
            child: MoodChipRow(
              currentMood: provider.currentMood,
              onMoodChanged: (mood) {
                if (mood != null) {
                  provider.fetchRecommendationsWithMood(
                    username: provider.userName,
                    mood: mood,
                  );
                } else {
                  provider.clearMood();
                  provider.fetchRecommendations(username: provider.userName);
                }
              },
            ),
          ),

          // Fallback city banner
          if (provider.fallbackFrom != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_searching,
                        color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"${provider.fallbackFrom}" not in dataset — '
                        'showing nearest city: '
                        '${provider.matchedCity.toUpperCase()} '
                        '(${provider.fallbackDistance?.toStringAsFixed(0)} km away)',
                        style: const TextStyle(
                            color: Colors.amber, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                '${provider.places.length} restaurants found',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ),
          ),

          // Restaurant list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final place = provider.places[i];
                return GestureDetector(
                  onTap: () =>
                      RestaurantDetailPage.show(context, place, i + 1),
                  child: PlaceCard(
                    place: place,
                    rank: i + 1,
                    username: provider.userName,
                    onFeedback: (String action) async {
                      if (action == 'interested') {
                        await provider.recordClick(
                          provider.userName,
                          place.cuisine,
                        );
                        context
                            .read<FavouritesProvider>()
                            .add(place);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Noted! More like ${place.name} 😋'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } else if (action == 'declined') {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Got it, skipping this one 👎'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } else if (action == 'not_hungry') {
                        provider.setNotHungry();
                      }
                    },
                  ),
                );
              },
              childCount: provider.places.length,
            ),
          ),

          // Extra space for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}