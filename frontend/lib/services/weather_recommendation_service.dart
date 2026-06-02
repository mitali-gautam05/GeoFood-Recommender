// lib/services/weather_recommendation_service.dart
// Phase 4 additions:
//   1. WeatherContext can be serialised to/from JSON for SharedPrefs caching.
//   2. WeatherRecommendationService.getContext() caches the last result
//      for 10 minutes in SharedPrefs — survives app restarts and avoids
//      hammering OpenWeatherMap on every fetchRecommendations() call.
//   3. WeatherRecommendationBanner unchanged — still a StatelessWidget
//      that reads WeatherContext? from PlacesProvider.
//   4. API key already set from Phase 1.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum WeatherType { sunny, rainy, cloudy, cold, hot, windy }

// ── WeatherContext — now JSON-serialisable for SharedPrefs caching ────────────

class WeatherContext {
  final WeatherType  type;
  final double       tempCelsius;
  final String       timeSlot;
  final List<String> suggestedTags;
  final String       emoji;
  final String       label;

  const WeatherContext({
    required this.type,
    required this.tempCelsius,
    required this.timeSlot,
    required this.suggestedTags,
    required this.emoji,
    required this.label,
  });

  // ── Phase 4: JSON serialisation ───────────────────────────
  Map<String, dynamic> toJson() => {
        'type':          type.index,
        'tempCelsius':   tempCelsius,
        'timeSlot':      timeSlot,
        'suggestedTags': suggestedTags,
        'emoji':         emoji,
        'label':         label,
      };

  factory WeatherContext.fromJson(Map<String, dynamic> j) => WeatherContext(
        type:          WeatherType.values[j['type'] as int],
        tempCelsius:   (j['tempCelsius'] as num).toDouble(),
        timeSlot:      j['timeSlot']  as String,
        suggestedTags: List<String>.from(j['suggestedTags'] as List),
        emoji:         j['emoji']     as String,
        label:         j['label']     as String,
      );
}

const Map<String, List<String>> kTimeSlotBoosts = {
  'breakfast':  ['south indian', 'north indian', 'cafe', 'healthy'],
  'lunch':      ['north indian', 'mughlai', 'biryani', 'gujarati'],
  'snack':      ['street food', 'cafe', 'desserts', 'fast food'],
  'dinner':     ['biryani', 'mughlai', 'kebab', 'north indian', 'chinese'],
  'latenight':  ['fast food', 'street food', 'pizza', 'burger'],
};

const Map<WeatherType, List<String>> kWeatherBoosts = {
  WeatherType.rainy:  ['cafe', 'street food', 'south indian'],
  WeatherType.hot:    ['desserts', 'healthy', 'cafe'],
  WeatherType.cold:   ['north indian', 'mughlai', 'kebab'],
  WeatherType.sunny:  ['healthy', 'street food'],
  WeatherType.cloudy: ['north indian', 'biryani'],
  WeatherType.windy:  ['cafe', 'north indian'],
};

String getTimeSlot(int hour) {
  if (hour >= 6  && hour < 11) return 'breakfast';
  if (hour >= 11 && hour < 15) return 'lunch';
  if (hour >= 15 && hour < 18) return 'snack';
  if (hour >= 18 && hour < 22) return 'dinner';
  return 'latenight';
}

class WeatherRecommendationService {
  static const String _apiKey         = 'e51e623e78b1d697bd6bdd2c97850352';
  static const String _cacheKey       = 'weather_context_cache';
  static const String _cacheTimeKey   = 'weather_context_time';
  static const int    _cacheTtlMinutes = 10;

  // ── Phase 4: try cache first, fetch only if stale ─────────
  static Future<WeatherContext> getContext({
    required double lat,
    required double lng,
  }) async {
    // 1. Check SharedPrefs cache
    final cached = await _loadCached();
    if (cached != null) return cached;

    // 2. Cache miss — fetch from OpenWeatherMap
    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=$lat&lon=$lng&appid=$_apiKey&units=metric',
      );
      final response =
          await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return await _loadOrFallback();
      }

      final data      = jsonDecode(response.body) as Map<String, dynamic>;
      final temp      = (data['main']['temp'] as num).toDouble();
      final weatherId = (data['weather'] as List).first['id'] as int;
      final type      = _parseType(weatherId, temp);
      final slot      = getTimeSlot(DateTime.now().hour);
      final tags      = {
        ...kTimeSlotBoosts[slot] ?? <String>[],
        ...kWeatherBoosts[type]  ?? <String>[],
      }.toList();

      final ctx = WeatherContext(
        type:          type,
        tempCelsius:   temp,
        timeSlot:      slot,
        suggestedTags: tags,
        emoji:         _emoji(type),
        label:         _label(type, temp, slot),
      );

      // 3. Persist to cache
      await _saveCache(ctx);
      return ctx;
    } catch (_) {
      // Network error — use last cached or fallback
      return await _loadOrFallback();
    }
  }

  // ── Cache helpers ─────────────────────────────────────────

  static Future<WeatherContext?> _loadCached() async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final timeStr   = prefs.getString(_cacheTimeKey);
      final cachedStr = prefs.getString(_cacheKey);
      if (timeStr == null || cachedStr == null) return null;

      final savedAt = DateTime.tryParse(timeStr);
      if (savedAt == null) return null;

      final age = DateTime.now().difference(savedAt).inMinutes;
      if (age > _cacheTtlMinutes) return null; // stale

      // Still update label for current time slot so greeting is correct
      final ctx      = WeatherContext.fromJson(
          jsonDecode(cachedStr) as Map<String, dynamic>);
      final nowSlot  = getTimeSlot(DateTime.now().hour);
      if (ctx.timeSlot == nowSlot) return ctx;

      // Time slot changed — rebuild label but keep weather type
      return WeatherContext(
        type:          ctx.type,
        tempCelsius:   ctx.tempCelsius,
        timeSlot:      nowSlot,
        suggestedTags: {
          ...kTimeSlotBoosts[nowSlot] ?? <String>[],
          ...kWeatherBoosts[ctx.type] ?? <String>[],
        }.toList(),
        emoji: ctx.emoji,
        label: _label(ctx.type, ctx.tempCelsius, nowSlot),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCache(WeatherContext ctx) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey,     jsonEncode(ctx.toJson()));
      await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Returns last cached context if available, otherwise fallback.
  static Future<WeatherContext> _loadOrFallback() async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_cacheKey);
      if (cachedStr != null) {
        return WeatherContext.fromJson(
            jsonDecode(cachedStr) as Map<String, dynamic>);
      }
    } catch (_) {}
    return fallbackContext();
  }

  static WeatherContext fallbackContext() {
    final slot = getTimeSlot(DateTime.now().hour);
    return WeatherContext(
      type:          WeatherType.sunny,
      tempCelsius:   28,
      timeSlot:      slot,
      suggestedTags: kTimeSlotBoosts[slot] ?? [],
      emoji:         '🍽️',
      label:         _slotGreeting(slot),
    );
  }

  static WeatherType _parseType(int id, double temp) {
    if (id >= 200 && id < 700) return WeatherType.rainy;
    if (temp > 35)              return WeatherType.hot;
    if (temp < 15)              return WeatherType.cold;
    if (id == 800)              return WeatherType.sunny;
    return WeatherType.cloudy;
  }

  static String _emoji(WeatherType t) {
    switch (t) {
      case WeatherType.rainy:  return '🌧️';
      case WeatherType.hot:    return '🌡️';
      case WeatherType.cold:   return '🧊';
      case WeatherType.sunny:  return '☀️';
      case WeatherType.cloudy: return '☁️';
      case WeatherType.windy:  return '💨';
    }
  }

  static String _label(WeatherType t, double temp, String slot) {
    final base = _slotGreeting(slot);
    switch (t) {
      case WeatherType.rainy:
        return '$base • Perfect for chai ☕';
      case WeatherType.hot:
        return '$base • ${temp.round()}°C — Try something cool 🍦';
      case WeatherType.cold:
        return '$base • ${temp.round()}°C — Something warm? 🍲';
      default:
        return base;
    }
  }

  static String _slotGreeting(String slot) {
    switch (slot) {
      case 'breakfast':  return 'Good morning! Breakfast time 🌅';
      case 'lunch':      return 'Lunch time! 🍱';
      case 'snack':      return "Snack o'clock! 🧆";
      case 'dinner':     return 'Dinner time! 🌙';
      case 'latenight':  return 'Late night cravings? 🌃';
      default:           return 'What sounds good? 🍽️';
    }
  }
}

// ════════════════════════════════════════════════════════════
// WeatherRecommendationBanner — unchanged from Phase 1
// StatelessWidget — reads WeatherContext? from PlacesProvider.
// ════════════════════════════════════════════════════════════

class WeatherRecommendationBanner extends StatelessWidget {
  final WeatherContext? weatherContext;
  final VoidCallback?   onTap;

  const WeatherRecommendationBanner({
    super.key,
    required this.weatherContext,
    this.onTap,
  });

  static List<Color> _colors(WeatherType t) {
    switch (t) {
      case WeatherType.rainy:
        return [const Color(0xFF1565C0), const Color(0xFF1E88E5)];
      case WeatherType.hot:
        return [const Color(0xFFBF360C), const Color(0xFFFF7043)];
      case WeatherType.cold:
        return [const Color(0xFF006064), const Color(0xFF00ACC1)];
      case WeatherType.sunny:
        return [const Color(0xFFE65100), const Color(0xFFFFB300)];
      default:
        return [const Color(0xFF37474F), const Color(0xFF546E7A)];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (weatherContext == null) return const SizedBox.shrink();
    final ctx = weatherContext!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:  const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _colors(ctx.type),
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(ctx.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(ctx.label,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            if (onTap != null)
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white60, size: 13),
          ],
        ),
      ),
    );
  }
}