// lib/providers/gamification_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/badge_definitions.dart';

// ── XP values for each action ─────────────────────────────────────────────────
class XpAction {
  static const int restaurantTap   = 10;
  static const int newCuisineTried = 25;
  static const int nearbyVisited   = 50;
  static const int dailyOpen       = 5;
}

// ── Level thresholds ──────────────────────────────────────────────────────────
// Level N requires N*100 total XP. So level 1 = 100, level 5 = 500, etc.
int levelFromXp(int xp) => (xp / 100).floor().clamp(1, 99);
int xpForNextLevel(int xp) {
  final level = levelFromXp(xp);
  return (level + 1) * 100;
}
double levelProgress(int xp) {
  final level = levelFromXp(xp);
  final levelStart = level * 100;
  final levelEnd   = (level + 1) * 100;
  return ((xp - levelStart) / (levelEnd - levelStart)).clamp(0.0, 1.0);
}

class GamificationProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  int    _xp              = 0;
  int    _streak          = 0;
  String _lastOpenDate    = '';
  Set<String> _unlockedBadgeIds = {};
  Map<String, int> _cuisineCounts = {};   // cuisine → times tapped
  String? _lastUnlockedBadgeId;           // used to trigger toast

  // ── Public getters ─────────────────────────────────────────────────────────
  int    get xp              => _xp;
  int    get streak          => _streak;
  int    get level           => levelFromXp(_xp);
  double get progress        => levelProgress(_xp);
  int    get nextLevelXp     => xpForNextLevel(_xp);
  Set<String> get unlockedBadgeIds => _unlockedBadgeIds;
  String? get lastUnlockedBadgeId  => _lastUnlockedBadgeId;

  List<BadgeDefinition> get unlockedBadges =>
      kAllBadges.where((b) => _unlockedBadgeIds.contains(b.id)).toList();

  List<BadgeDefinition> get lockedBadges =>
      kAllBadges.where((b) => !_unlockedBadgeIds.contains(b.id)).toList();

  // ── Taste score (0–100, diversity-based) ──────────────────────────────────
  // Higher when taps are spread across many different cuisines.
  double get tasteScore {
    if (_cuisineCounts.isEmpty) return 0;
    final total    = _cuisineCounts.values.fold(0, (a, b) => a + b);
    final distinct = _cuisineCounts.length;
    // Shannon entropy normalised to [0,100]
    double entropy = 0;
    for (final count in _cuisineCounts.values) {
      final p = count / total;
      if (p > 0) entropy -= p * (p > 0 ? _log2(p) : 0);
    }
    final maxEntropy = distinct > 1 ? _log2(distinct.toDouble()) : 1;
    final diversity  = maxEntropy > 0 ? (entropy / maxEntropy) : 0;
    // Blend diversity with breadth (distinct cuisines, capped at 10)
    final breadth = (distinct / 10).clamp(0.0, 1.0);
    return ((diversity * 0.6 + breadth * 0.4) * 100).clamp(0, 100);
  }

  double _log2(double x) => x > 0 ? (x == 1 ? 0 : _ln(x) / _ln(2)) : 0;
  double _ln(double x)   => x > 0 ? _lnApprox(x) : 0;
  double _lnApprox(double x) {
    // Fast natural log approximation — accurate enough for score display
    int n = 0;
    while (x >= 2) { x /= 2; n++; }
    while (x < 1)  { x *= 2; n--; }
    x -= 1;
    final t = x / (x + 2);
    return (n * 0.6931471805599453) +
           2 * (t + t*t*t/3 + t*t*t*t*t/5 + t*t*t*t*t*t*t/7);
  }

  // ── Cuisine breakdown for radar/chart display ──────────────────────────────
  Map<String, int> get cuisineCounts => Map.unmodifiable(_cuisineCounts);

  // ── Initialise from SharedPreferences ─────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _xp              = prefs.getInt('gami_xp')     ?? 0;
    _streak          = prefs.getInt('gami_streak')  ?? 0;
    _lastOpenDate    = prefs.getString('gami_last') ?? '';
    _unlockedBadgeIds = Set<String>.from(
        jsonDecode(prefs.getString('gami_badges') ?? '[]') as List);
    _cuisineCounts = Map<String, int>.from(
        jsonDecode(prefs.getString('gami_cuisines') ?? '{}') as Map);
    _updateStreak(prefs);    // check streak on boot
    notifyListeners();
  }

  // ── Core action tracker ────────────────────────────────────────────────────
  // Call this from PlacesProvider whenever a meaningful action happens.
  Future<void> trackAction({
    required GamificationAction action,
    String? cuisine,             // for restaurantTap + newCuisineTried
    int? hour,                   // current hour, for time-based badges
  }) async {
    // 1. Award XP
    final xpEarned = _xpForAction(action, cuisine: cuisine);
    _xp += xpEarned;

    // 2. Track cuisine
    if (cuisine != null && cuisine.isNotEmpty) {
      final key = cuisine.toLowerCase().trim();
      _cuisineCounts[key] = (_cuisineCounts[key] ?? 0) + 1;
    }

    // 3. Check badges
    await _checkAndAwardBadges(action: action, hour: hour);

    // 4. Persist + notify
    await _save();
    notifyListeners();
  }

  int _xpForAction(GamificationAction action, {String? cuisine}) {
    switch (action) {
      case GamificationAction.restaurantTap:
        return XpAction.restaurantTap;
      case GamificationAction.newCuisineTried:
        return XpAction.newCuisineTried;
      case GamificationAction.nearbyVisited:
        return XpAction.nearbyVisited;
      case GamificationAction.dailyOpen:
        return XpAction.dailyOpen;
    }
  }

  // ── Badge checker ──────────────────────────────────────────────────────────
  Future<void> _checkAndAwardBadges({
    required GamificationAction action,
    int? hour,
  }) async {
    final toCheck = <String>[];

    // Always check XP milestones
    toCheck.addAll(['xp_100', 'xp_500']);

    // Action-specific checks
    switch (action) {
      case GamificationAction.restaurantTap:
        toCheck.addAll(['first_tap', 'biryani_boss', 'street_foodie',
                        'chai_lover', 'explorer_5', 'explorer_10']);
        final h = hour ?? DateTime.now().hour;
        if (h >= 22 || h < 5)  toCheck.add('night_owl');
        if (h >= 5 && h < 8)   toCheck.add('early_bird');
      case GamificationAction.nearbyVisited:
        toCheck.add('nearby_visited');
      case GamificationAction.dailyOpen:
        toCheck.addAll(['streak_3', 'streak_7', 'streak_30']);
      case GamificationAction.newCuisineTried:
        toCheck.addAll(['explorer_5', 'explorer_10']);
    }

    for (final id in toCheck) {
      if (!_unlockedBadgeIds.contains(id) && _badgeConditionMet(id)) {
        _unlockedBadgeIds.add(id);
        _lastUnlockedBadgeId = id;  // UI reads this to show toast
      }
    }
  }

  bool _badgeConditionMet(String id) {
    final biryaniCount = _cuisineCounts.entries
        .where((e) => e.key.contains('biryani'))
        .fold(0, (a, b) => a + b.value);
    final streetCount = _cuisineCounts.entries
        .where((e) => e.key.contains('street'))
        .fold(0, (a, b) => a + b.value);
    final chaiCount = _cuisineCounts.entries
        .where((e) => e.key.contains('beverage') ||
                      e.key.contains('chai') ||
                      e.key.contains('cafe'))
        .fold(0, (a, b) => a + b.value);
    final distinctCuisines = _cuisineCounts.length;
    final totalTaps = _cuisineCounts.values.fold(0, (a, b) => a + b);

    switch (id) {
      case 'first_tap':      return totalTaps >= 1;
      case 'biryani_boss':   return biryaniCount >= 10;
      case 'street_foodie':  return streetCount >= 8;
      case 'chai_lover':     return chaiCount >= 5;
      case 'explorer_5':     return distinctCuisines >= 5;
      case 'explorer_10':    return distinctCuisines >= 10;
      case 'night_owl':      return true;  // condition checked before calling
      case 'early_bird':     return true;  // condition checked before calling
      case 'streak_3':       return _streak >= 3;
      case 'streak_7':       return _streak >= 7;
      case 'streak_30':      return _streak >= 30;
      case 'xp_100':         return _xp >= 100;
      case 'xp_500':         return _xp >= 500;
      case 'nearby_visited': return true;  // granted directly on action
      default:               return false;
    }
  }

  // ── Streak logic ──────────────────────────────────────────────────────────
  void _updateStreak(SharedPreferences prefs) {
    final today    = _todayKey();
    final lastDate = _lastOpenDate;

    if (lastDate == today) return;  // already counted today

    if (lastDate == _yesterdayKey()) {
      _streak++;                    // continued streak
    } else if (lastDate.isEmpty || lastDate != today) {
      _streak = lastDate.isEmpty ? 1 : 1;  // broken or new
    }

    _lastOpenDate = today;
    prefs.setInt('gami_streak', _streak);
    prefs.setString('gami_last', today);
  }

  String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }

  String _yesterdayKey() {
    final d = DateTime.now().subtract(const Duration(days: 1));
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }

  // ── Call this after showing the badge toast so it doesn't re-trigger ──────
  void clearLastUnlockedBadge() {
    _lastUnlockedBadgeId = null;
    notifyListeners();
  }

  // ── Persistence ───────────────────────────────────────────────────────────
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gami_xp',       _xp);
    await prefs.setInt('gami_streak',   _streak);
    await prefs.setString('gami_last',  _lastOpenDate);
    await prefs.setString('gami_badges',  jsonEncode(_unlockedBadgeIds.toList()));
    await prefs.setString('gami_cuisines', jsonEncode(_cuisineCounts));
  }
}

// ── Action enum ───────────────────────────────────────────────────────────────
enum GamificationAction {
  restaurantTap,
  newCuisineTried,
  nearbyVisited,
  dailyOpen,
}