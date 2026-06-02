// ============================================================
// places_provider_additions.dart
// GeotTaste — New methods to ADD to your existing PlacesProvider
//
// DON'T replace your existing places_provider.dart.
// Add these methods and fields into your existing class.
//
// Changes needed:
//   1. Add the new fields (marked ← ADD)
//   2. Add the new methods (marked ← ADD METHOD)
//   3. Update fetchRecommendations to accept mood param
//   4. Update ApiClient.getRecommendations to pass mood + time_slot
// ============================================================

// ────────────────────────────────────────────────────────────
// STEP 1: Add these imports at the top of places_provider.dart
// ────────────────────────────────────────────────────────────
// import '../services/weather_recommendation_service.dart';

// ────────────────────────────────────────────────────────────
// STEP 2: Add these fields inside PlacesProvider class
// ────────────────────────────────────────────────────────────
/*
  // ← ADD: current mood selected by user
  String? _currentMood;
  String? get currentMood => _currentMood;

  // ← ADD: weather context (updated on each location change)
  WeatherContext? _weatherContext;
  WeatherContext? get weatherContext => _weatherContext;

  // ← ADD: streak tracking
  int    _streak       = 0;
  int    get streak    => _streak;
  String? _lastVisitDate;

  // ← ADD: anti-repeat — cuisines clicked in last 7 days
  // key = cuisine, value = ISO date string of last click
  Map<String, String> _recentClicks = {};
*/

// ────────────────────────────────────────────────────────────
// STEP 3: Add these methods inside PlacesProvider class
// ────────────────────────────────────────────────────────────

extension PlacesProviderExtensions on Object {
  // Not a real extension — copy these methods into the class body
}

// ── METHOD: fetchRecommendationsWithMood ─────────────────────
// Called by MoodScreen after user picks a mood.
// Internally calls fetchRecommendations with mood param.
/*
Future<void> fetchRecommendationsWithMood({
  required String username,
  required String mood,
}) async {
  _currentMood = mood;
  notifyListeners();
  await fetchRecommendations(username: username, mood: mood);
}
*/

// ── METHOD: Updated fetchRecommendations ─────────────────────
// Add `mood` and `timeSlot` to the existing signature.
// Replace your existing fetchRecommendations body with this.
/*
Future<void> fetchRecommendations({
  required String username,
  String? city,
  String? query,
  double? budgetOverride,
  String? mood,            // ← ADD param
}) async {
  isLoading    = true;
  errorMessage = null;
  cityNotFound = null;
  fallbackFrom = null;
  suggestions  = [];
  notifyListeners();

  if (city           != null) currentCity  = city;
  if (query          != null) currentQuery = query;
  if (budgetOverride != null) budget       = budgetOverride;
  if (mood           != null) _currentMood = mood;

  if (!locationFetched) await fetchUserLocation();

  // ← ADD: fetch weather context when we have location
  if (userLat != null && userLng != null) {
    _weatherContext = await WeatherRecommendationService.getContext(
      lat: userLat!, lng: userLng!,
    );
  }

  // ← ADD: get anti-repeat cuisine list
  final recentCuisines = _getRecentCuisines();

  // ← ADD: get time slot
  final timeSlot = getTimeSlot(DateTime.now().hour);

  try {
    final result = await ApiClient.getRecommendations(
      username:        username,
      query:           currentQuery,
      city:            currentCity,
      budget:          budget,
      userLat:         userLat,
      userLng:         userLng,
      mood:            _currentMood,            // ← ADD
      timeSlot:        timeSlot,                // ← ADD
      weatherTags:     _weatherContext?.suggestedTags, // ← ADD
      avoidCuisines:   recentCuisines,          // ← ADD (anti-repeat)
    );

    // same as before...
    if (result['status'] == 'city_not_found') {
      cityNotFound = currentCity;
      suggestions  = List<String>.from(result['suggestions'] ?? []);
      _allPlaces   = [];
      places       = [];
    } else {
      _allPlaces       = List<PlaceModel>.from(result['places'] ?? []);
      matchedCity      = result['matched_city']     ?? '';
      fallbackFrom     = result['fallback_from']    as String?;
      fallbackDistance = (result['fallback_distance'] as num?)?.toDouble();
      cityNotFound     = null;
      suggestions      = [];
      _applyLocalFilters();
    }
  } catch (e) {
    errorMessage = e.toString();
    places       = [];
  }

  isLoading = false;
  notifyListeners();
}
*/

// ── METHOD: _getRecentCuisines (anti-repeat engine) ──────────
// Returns cuisines clicked in the last 7 days so backend can
// deprioritize them and push discovery.
/*
List<String> _getRecentCuisines() {
  final cutoff = DateTime.now().subtract(const Duration(days: 7));
  return _recentClicks.entries
      .where((e) => DateTime.tryParse(e.value)?.isAfter(cutoff) ?? false)
      .map((e) => e.key)
      .toList();
}
*/

// ── METHOD: updateStreak ──────────────────────────────────────
// Call this inside recordClick(). Updates the daily streak
// counter. Streak increments if user clicked today AND yesterday.
/*
Future<void> _updateStreak() async {
  final today     = DateTime.now();
  final todayStr  = '${today.year}-${today.month}-${today.day}';

  if (_lastVisitDate == null) {
    _streak = 1;
  } else {
    final last    = DateTime.parse(_lastVisitDate!);
    final diff    = today.difference(last).inDays;
    if (diff == 0) {
      // same day, streak unchanged
    } else if (diff == 1) {
      _streak++;             // consecutive day
    } else {
      _streak = 1;           // streak broken
    }
  }

  _lastVisitDate = todayStr;
  notifyListeners();

  // Persist
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('streak', _streak);
  await prefs.setString('last_visit_date', todayStr);

  // Award bonus XP for streak milestones
  if (_gamification != null) {
    if (_streak == 7)  await _gamification!.trackAction(action: GamificationAction.nearbyVisited); // 7-day bonus
    if (_streak == 30) await _gamification!.trackAction(action: GamificationAction.nearbyVisited); // month bonus
  }
}
*/

// ── UPDATE: recordClick — add streak + anti-repeat tracking ──
// Replace your existing recordClick with this:
/*
Future<void> recordClick(String username, String cuisine) async {
  _clickCount++;
  final key = cuisine.trim().toLowerCase();
  _cuisineClickMap[key] = (_cuisineClickMap[key] ?? 0) + 1;

  // ← ADD: anti-repeat tracking
  _recentClicks[key] = DateTime.now().toIso8601String();

  notifyListeners();
  await _saveClickMap();
  await ApiClient.recordClick(username, cuisine);

  // ← ADD: update streak
  await _updateStreak();

  // Gamification XP (existing logic)
  if (_gamification != null) {
    final isNew = !_seenCuisines.contains(key);
    await _gamification!.trackAction(
      action:  isNew
          ? GamificationAction.newCuisineTried
          : GamificationAction.restaurantTap,
      cuisine: cuisine,
      hour:    DateTime.now().hour,
    );
    if (isNew) {
      _seenCuisines.add(key);
      await _saveSeenCuisines();
    }
  }
}
*/

// ────────────────────────────────────────────────────────────
// STEP 4: Backend changes needed in your Python/FastAPI backend
// ────────────────────────────────────────────────────────────
/*
BACKEND: api_client.dart — add these params to getRecommendations()

static Future<Map<String, dynamic>> getRecommendations({
  required String username,
  required String query,
  required String city,
  required double budget,
  double? userLat,
  double? userLng,
  int topN = 10,
  String? mood,            // ← ADD
  String? timeSlot,        // ← ADD
  List<String>? weatherTags,  // ← ADD
  List<String>? avoidCuisines, // ← ADD (anti-repeat)
}) async {
  final body = {
    'username': username,
    'query':    query,
    'city':     city,
    'budget':   budget,
    if (userLat != null) 'lat': userLat,
    if (userLng != null) 'lng': userLng,
    'top_n':    topN,
    if (mood           != null) 'mood':           mood,          // ← ADD
    if (timeSlot       != null) 'time_slot':      timeSlot,      // ← ADD
    if (weatherTags    != null) 'weather_tags':   weatherTags,   // ← ADD
    if (avoidCuisines  != null) 'avoid_cuisines': avoidCuisines, // ← ADD
  };
  // ... rest of your existing API call code
}

─────────────────────────────────────────────────────────────
BACKEND: Python recommendation logic additions

# In your recommend() function, after computing base scores:

# 1. TIME SLOT BOOST
time_boosts = {
    'breakfast': ['south indian', 'north indian', 'cafe', 'healthy'],
    'lunch':     ['north indian', 'mughlai', 'biryani', 'gujarati'],
    'snack':     ['street food', 'cafe', 'desserts', 'fast food'],
    'dinner':    ['biryani', 'mughlai', 'kebab', 'north indian'],
    'latenight': ['fast food', 'street food', 'pizza', 'burger'],
}
boosted = time_boosts.get(time_slot, [])
for place in places:
    if place.cuisine.lower() in boosted:
        place.score *= 1.15   # 15% boost for right time

# 2. WEATHER BOOST
if weather_tags:
    for place in places:
        if place.cuisine.lower() in weather_tags:
            place.score *= 1.10   # 10% weather boost

# 3. MOOD MAPPING
mood_cuisines = {
    'celebrating': ['biryani', 'mughlai', 'kebab'],
    'comfort':     ['north indian', 'south indian', 'gujarati'],
    'adventurous': ['thai', 'bengali', 'kerala', 'italian'],
    'date':        ['italian', 'continental', 'mughlai'],
    'tired':       ['street food', 'fast food'],
    'spicy':       ['mughlai', 'north indian', 'chinese'],
    'healthy':     ['healthy', 'south indian'],
    'sweet':       ['desserts'],
}
if mood and mood in mood_cuisines:
    for place in places:
        if place.cuisine.lower() in mood_cuisines[mood]:
            place.score *= 1.25   # 25% mood boost

# 4. ANTI-REPEAT (deprioritize recently seen cuisines)
if avoid_cuisines:
    for place in places:
        if place.cuisine.lower() in avoid_cuisines:
            place.score *= 0.70   # 30% penalty for recent cuisine

# Re-sort by score
places = sorted(places, key=lambda p: p.score, reverse=True)
*/