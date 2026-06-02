// lib/providers/places_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place_model.dart';
import '../services/api_client.dart';
import '../screens/home/filter_sheet.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/pause_manager.dart';
import '../services/weather_recommendation_service.dart';
import 'gamification_provider.dart';

String getTimeSlot(int hour) {
  if (hour >= 6  && hour < 11) return 'breakfast';
  if (hour >= 11 && hour < 15) return 'lunch';
  if (hour >= 15 && hour < 18) return 'snack';
  if (hour >= 18 && hour < 22) return 'dinner';
  return 'latenight';
}

class PlacesProvider extends ChangeNotifier {

  List<PlaceModel> places          = [];
  bool             isLoading       = false;
  String?          errorMessage;
  String?          cityNotFound;
  List<String>     suggestions     = [];
  String           matchedCity     = '';
  String?          fallbackFrom;
  double?          fallbackDistance;
  String           currentCity     = 'delhi';
  String           currentQuery    = 'biryani';
  double           budget          = 300;

  double? userLat;
  double? userLng;
  bool    locationFetched = false;

  String _userName = '';
  String get userName => _userName;

  bool _isNotHungry = false;
  bool get isNotHungry => _isNotHungry;

  int _clickCount = 0;
  int get clickCount => _clickCount;

  Map<String, int> _cuisineClickMap = {};
  Map<String, int> get cuisineClickMap => Map.unmodifiable(_cuisineClickMap);

  FilterOptions    _filters   = const FilterOptions();
  FilterOptions    get filters => _filters;
  List<PlaceModel> _allPlaces = [];

  final Set<String> _seenCuisines = {};

  GamificationProvider? _gamification;

  void setGamificationProvider(GamificationProvider gami) {
    _gamification = gami;
  }

  String? _currentMood;
  String? get currentMood => _currentMood;

  WeatherContext? _weatherContext;
  WeatherContext? get weatherContext => _weatherContext;

  int     _streak         = 0;
  int     get streak      => _streak;
  String? _lastVisitDate;

  Map<String, String> _recentClicks = {};

  final LocationService     _locationService     = LocationService();
  final NotificationService _notificationService = NotificationService();
  final PauseManager        _pauseManager        = PauseManager();

  Map<String, dynamic>? nearbyRestaurant;

  bool get isNotificationPaused  => _pauseManager.isPaused;
  int  get pauseMinutesRemaining => _pauseManager.minutesRemaining;

  bool _trackingStarted = false;

  PlacesProvider() {
    _loadClickMap();
    _loadSeenCuisines();
    _loadStreak();
    _loadRecentClicks();
  }

  // ── SETTERS ───────────────────────────────────────────────────────────────

  void setUser({required String name, required String city}) {
    _userName   = name;
    currentCity = city;
    notifyListeners();
  }

  void setCity(String city) {
    currentCity  = city;
    cityNotFound = null;
    fallbackFrom = null;
    suggestions  = [];
    notifyListeners();
    if (_userName.isNotEmpty) fetchRecommendations(username: _userName);
  }

  void setNotHungry() {
    _isNotHungry = true;
    notifyListeners();
  }

  void clearNotHungry() {
    _isNotHungry = false;
    notifyListeners();
  }

  void applyFilters(FilterOptions f) {
    _filters = f;
    _applyLocalFilters();
    notifyListeners();
  }

  void _applyLocalFilters() {
    places = _allPlaces.where((p) {
      final budgetOk  = p.price  >= _filters.minBudget && p.price <= _filters.maxBudget;
      final ratingOk  = p.rating >= _filters.minRating;
      final cuisineOk = _filters.cuisine == null ||
          p.cuisine.toLowerCase().contains(_filters.cuisine!.toLowerCase());
      return budgetOk && ratingOk && cuisineOk;
    }).toList();
  }

  Future<void> resetClickHistory() async {
    _clickCount         = 0;
    _cuisineClickMap    = {};
    _recentClicks       = {};
    _seenCuisines.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cuisine_clicks');
    await prefs.remove('seen_cuisines');
    await prefs.remove('recent_clicks');
    notifyListeners();
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

  Future<void> fetchUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        locationFetched = true;
        notifyListeners();
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        locationFetched = true;
        notifyListeners();
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      userLat         = position.latitude;
      userLng         = position.longitude;
      locationFetched = true;
      notifyListeners();
    } catch (_) {
      locationFetched = true;
      notifyListeners();
    }
  }

  // ── LOCATION TRACKING ─────────────────────────────────────────────────────

  Future<void> initLocationTracking() async {
    if (_trackingStarted) return;
    _trackingStarted = true;

    _notificationService.onNotHungryTapped = () {
      _pauseManager.pause();
      nearbyRestaurant = null;
      notifyListeners();
    };

    _pauseManager.onResumed = () {
      notifyListeners();
      _checkAndNotify();
    };

    await _locationService.startTracking();

    _locationService.positionStream.listen((position) {
      userLat         = position.latitude;
      userLng         = position.longitude;
      locationFetched = true;
      notifyListeners();
      _checkAndNotify();
    });
  }

  Future<void> _checkAndNotify() async {
    if (_pauseManager.isPaused) return;
    if (userLat == null || userLng == null) return;
    if (_userName.isEmpty) return;

    try {
      final result = await ApiClient.getRecommendations(
        username: _userName,
        query:    currentQuery,
        city:     currentCity,
        budget:   budget,
        userLat:  userLat,
        userLng:  userLng,
        topN:     1,
      );

      if (result['status'] == 'city_not_found') return;

      final rawList = result['places'] as List<PlaceModel>? ?? [];
      if (rawList.isEmpty) return;

      final best = rawList.first;
      final dist = LocationService.distanceKm(
        userLat!, userLng!,
        best.lat ?? userLat!, best.lng ?? userLng!,
      );

      nearbyRestaurant = {
        'name':        best.name,
        'cuisine':     best.cuisine,
        'price':       best.price,
        'rating':      best.rating,
        'score':       best.score,
        'distance_km': dist,
        'place':       best,
      };
      notifyListeners();

      await _notificationService.showRestaurantNotification(
        restaurantName: best.name,
        distanceKm:     dist,
        cuisine:        best.cuisine,
        restaurantId:   best.name,
      );
    } catch (_) {}
  }

  void pauseNotifications() {
    _pauseManager.pause();
    nearbyRestaurant = null;
    setNotHungry();
    notifyListeners();
    if (_userName.isNotEmpty) notHungry(_userName);
  }

  void resumeNotifications() {
    _pauseManager.resume();
    clearNotHungry();
    notifyListeners();
    _checkAndNotify();
  }

  void dismissNearbyBanner() {
    nearbyRestaurant = null;
    notifyListeners();
  }

  void trackNearbyVisited() {
    _gamification?.trackAction(action: GamificationAction.nearbyVisited);
  }

  // ── MOOD ──────────────────────────────────────────────────────────────────

  Future<void> fetchRecommendationsWithMood({
    required String username,
    required String mood,
  }) async {
    _currentMood = mood;
    notifyListeners();
    await fetchRecommendations(username: username, mood: mood);
  }

  void clearMood() {
    _currentMood = null;
    notifyListeners();
  }

  // ── FETCH RECOMMENDATIONS ─────────────────────────────────────────────────

  Future<void> fetchRecommendations({
    required String username,
    String? city,
    String? query,
    double? budgetOverride,
    String? mood,
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

    if (userLat != null && userLng != null) {
      _weatherContext = await WeatherRecommendationService.getContext(
        lat: userLat!, lng: userLng!,
      );
    } else {
      _weatherContext = WeatherRecommendationService.fallbackContext();
    }

    final timeSlot      = getTimeSlot(DateTime.now().hour);
    final weatherTags   = _weatherContext?.suggestedTags ?? [];
    final avoidCuisines = _getRecentCuisines();

    try {
      final result = await ApiClient.getRecommendations(
        username:      username,
        query:         currentQuery,
        city:          currentCity,
        budget:        budget,
        userLat:       userLat,
        userLng:       userLng,
        mood:          _currentMood,
        timeSlot:      timeSlot,
        weatherTags:   weatherTags,
        avoidCuisines: avoidCuisines,
      );

      if (result['status'] == 'city_not_found') {
        cityNotFound = currentCity;
        suggestions  = List<String>.from(result['suggestions'] ?? []);
        _allPlaces   = [];
        places       = [];
      } else {
        _allPlaces       = List<PlaceModel>.from(result['places'] ?? []);
        matchedCity      = result['matched_city']      ?? '';
        fallbackFrom     = result['fallback_from']     as String?;
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

  // ── RECORD CLICK ──────────────────────────────────────────────────────────

  Future<void> recordClick(String username, String cuisine) async {
    _clickCount++;
    final key = cuisine.trim().toLowerCase();
    _cuisineClickMap[key] = (_cuisineClickMap[key] ?? 0) + 1;

    _recentClicks[key] = DateTime.now().toIso8601String();
    await _saveRecentClicks();

    notifyListeners();
    await _saveClickMap();

    // Organic click → backend (for ML history)
    await ApiClient.recordClick(username, cuisine);

    // ── NEW: sync full passport map so leaderboard XP stays accurate ──────
    ApiClient.syncPassport(
      username:      username,
      cuisineCounts: Map<String, int>.from(_cuisineClickMap),
      city:          currentCity,
    );
    // ─────────────────────────────────────────────────────────────────────

    await _updateStreak();

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

  Future<void> notHungry(String username) async {
    await ApiClient.setNotHungry(username);
  }

  // ── ANTI-REPEAT ───────────────────────────────────────────────────────────

  List<String> _getRecentCuisines() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _recentClicks.entries
        .where((e) => DateTime.tryParse(e.value)?.isAfter(cutoff) ?? false)
        .map((e) => e.key)
        .toList();
  }

  // ── STREAK ────────────────────────────────────────────────────────────────

  Future<void> _updateStreak() async {
    final today    = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    if (_lastVisitDate == null) {
      _streak = 1;
    } else {
      final last = DateTime.tryParse(_lastVisitDate!);
      if (last != null) {
        final diff = DateTime(today.year, today.month, today.day)
            .difference(DateTime(last.year, last.month, last.day))
            .inDays;
        if (diff == 0) {
          // same day — unchanged
        } else if (diff == 1) {
          _streak++;
        } else {
          _streak = 1;
        }
      }
    }

    _lastVisitDate = todayStr;
    notifyListeners();
    await _saveStreak();

    if (_gamification != null) {
      if (_streak == 7 || _streak == 14 || _streak == 30) {
        await _gamification!.trackAction(
          action: GamificationAction.nearbyVisited,
        );
      }
    }
  }

  // ── PERSISTENCE ───────────────────────────────────────────────────────────

  Future<void> _saveClickMap() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cuisine_clicks', jsonEncode(_cuisineClickMap));
  }

  Future<void> _loadClickMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('cuisine_clicks');
    if (raw != null) {
      final decoded    = jsonDecode(raw) as Map<String, dynamic>;
      _cuisineClickMap = decoded.map((k, v) => MapEntry(k, v as int));
      _clickCount      = _cuisineClickMap.values.fold(0, (a, b) => a + b);
      notifyListeners();
    }
  }

  Future<void> _saveSeenCuisines() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seen_cuisines', jsonEncode(_seenCuisines.toList()));
  }

  Future<void> _loadSeenCuisines() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('seen_cuisines');
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _seenCuisines.addAll(list.cast<String>());
    }
  }

  Future<void> _saveStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('streak', _streak);
    if (_lastVisitDate != null) {
      await prefs.setString('last_visit_date', _lastVisitDate!);
    }
  }

  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    _streak        = prefs.getInt('streak') ?? 0;
    _lastVisitDate = prefs.getString('last_visit_date');
  }

  Future<void> _saveRecentClicks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recent_clicks', jsonEncode(_recentClicks));
  }

  Future<void> _loadRecentClicks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('recent_clicks');
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _recentClicks = decoded.map((k, v) => MapEntry(k, v as String));
    }
  }

  @override
  void dispose() {
    _locationService.dispose();
    _pauseManager.dispose();
    super.dispose();
  }
}