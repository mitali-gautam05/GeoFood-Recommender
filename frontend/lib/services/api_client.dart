// lib/services/api_client.dart
// Phase 4 update: register() now accepts optional city parameter
// and sends it in the JSON body so the backend stores it in User.city.
// All other methods IDENTICAL to Phase 2 version.

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place_model.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

// ── Auth models ───────────────────────────────────────────────────────────────

class AuthToken {
  final String accessToken;
  final String tokenType;
  const AuthToken({required this.accessToken, required this.tokenType});

  factory AuthToken.fromJson(Map<String, dynamic> j) => AuthToken(
        accessToken: j['access_token'] as String,
        tokenType:   j['token_type']   as String,
      );
}

class RegisteredUser {
  final int    id;
  final String email;
  final String username;
  final bool   isActive;
  final String city;   // ← Phase 4

  const RegisteredUser({
    required this.id,
    required this.email,
    required this.username,
    required this.isActive,
    this.city = '',
  });

  factory RegisteredUser.fromJson(Map<String, dynamic> j) => RegisteredUser(
        id:       j['id']        as int,
        email:    j['email']     as String,
        username: j['username']  as String,
        isActive: j['is_active'] as bool?   ?? true,
        city:     j['city']      as String? ?? '',
      );
}

// ── Leaderboard model ─────────────────────────────────────────────────────────

class LeaderboardEntryModel {
  final int    rank;
  final String username;
  final int    weeklyXp;
  final int    totalXp;
  final String city;
  final int    badgeCount;

  const LeaderboardEntryModel({
    required this.rank,
    required this.username,
    required this.weeklyXp,
    required this.totalXp,
    required this.city,
    required this.badgeCount,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> j) =>
      LeaderboardEntryModel(
        rank:       j['rank']        as int,
        username:   j['username']    as String,
        weeklyXp:   j['weekly_xp']   as int,
        totalXp:    j['total_xp']    as int,
        city:       j['city']        as String? ?? '',
        badgeCount: j['badge_count'] as int?    ?? 0,
      );

  bool get isYou => false;
}

class LeaderboardResult {
  final String                      status;
  final String                      city;
  final String                      weekStart;
  final List<LeaderboardEntryModel> entries;
  final LeaderboardEntryModel?      myEntry;
  final bool                        isEmpty;

  const LeaderboardResult({
    required this.status,
    required this.city,
    required this.weekStart,
    required this.entries,
    this.myEntry,
    this.isEmpty = false,
  });
}

// ── API Client ────────────────────────────────────────────────────────────────

class ApiClient {
  static String get _baseUrl => kIsWeb
      ? 'http://localhost:8000/api/v1'
      : 'http://10.0.2.2:8000/api/v1';

  // Expose _baseUrl for main.dart /me call
  static String get baseUrl => _baseUrl;

  static const _tokenKey    = 'auth_token';
  static const _usernameKey = 'username';

  // ── Username helpers ───────────────────────────────────────────────────────

  static Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }

  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey) ?? 'guest';
  }

  // ── Token helpers ──────────────────────────────────────────────────────────

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── Register ───────────────────────────────────────────────────────────────
  // Phase 4: city parameter added — now sent in JSON body so backend
  // stores it in User.city and /me can return it on next launch.

  static Future<RegisteredUser> register({
    required String email,
    required String username,
    required String password,
    String          city = '',    // ← Phase 4
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':    email,
          'username': username,
          'password': password,
          'city':     city,       // ← Phase 4
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        return RegisteredUser.fromJson(data);
      }
      throw ApiException(data['detail'] as String? ?? 'Registration failed');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Cannot connect to server. Is it running?');
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  // Form-encoded body (OAuth2PasswordRequestForm).
  // Email goes in the `username` field — OAuth2 spec naming.

  static Future<AuthToken> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': email,
          'password': password,
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final token = AuthToken.fromJson(data);
        await _saveToken(token.accessToken);
        return token;
      }
      throw ApiException(data['detail'] as String? ?? 'Login failed');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Cannot connect to server. Is it running?');
    }
  }

  // ── City search ────────────────────────────────────────────────────────────

  static Future<List<String>> searchCities(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/cities/search')
          .replace(queryParameters: {'q': query});
      final response =
          await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['cities'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  // ── Main recommendations endpoint ──────────────────────────────────────────

  static Future<Map<String, dynamic>> getRecommendations({
    required String username,
    required String query,
    required String city,
    required double budget,
    double?       userLat,
    double?       userLng,
    double        minRating     = 3.5,
    int           topN          = 8,
    String        hungerMode    = 'hungry',
    String?       mood,
    String?       timeSlot,
    List<String>? weatherTags,
    List<String>? avoidCuisines,
  }) async {
    try {
      final body = <String, dynamic>{
        'username':    username,
        'query':       query,
        'city':        city,
        'budget':      budget,
        'min_rating':  minRating,
        'top_n':       topN,
        'hunger_mode': hungerMode,
      };

      if (userLat       != null) body['user_lat']       = userLat;
      if (userLng       != null) body['user_lng']       = userLng;
      if (mood          != null) body['mood']           = mood;
      if (timeSlot      != null) body['time_slot']      = timeSlot;
      if (weatherTags   != null && weatherTags.isNotEmpty)
        body['weather_tags']   = weatherTags;
      if (avoidCuisines != null && avoidCuisines.isNotEmpty)
        body['avoid_cuisines'] = avoidCuisines;

      final response = await http.post(
        Uri.parse('$_baseUrl/recommend'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'status':            data['status']            ?? 'ok',
          'matched_city':      data['matched_city']      ?? '',
          'suggestions':       data['suggestions']       ?? [],
          'fallback_from':     data['fallback_from'],
          'fallback_distance': data['fallback_distance'],
          'places': ((data['recommendations'] ?? []) as List)
              .map((e) => PlaceModel.fromJson(e as Map<String, dynamic>))
              .toList(),
        };
      } else {
        throw ApiException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Cannot connect to server. Is it running?');
    }
  }

  // ── Click recording ────────────────────────────────────────────────────────

  static Future<void> recordClick(String username, String foodType) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/click'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'food_type': foodType}),
      );
    } catch (_) {}
  }

  // ── Not hungry ─────────────────────────────────────────────────────────────

  static Future<void> setNotHungry(String username) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/not-hungry'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'food_type': ''}),
      );
    } catch (_) {}
  }

  // ── Leaderboard ────────────────────────────────────────────────────────────

  static Future<LeaderboardResult> getLeaderboard({
    required String city,
    String? username,
  }) async {
    try {
      final params = <String, String>{'city': city};
      if (username != null && username.isNotEmpty) params['username'] = username;

      final uri = Uri.parse('$_baseUrl/leaderboard')
          .replace(queryParameters: params);
      final response =
          await http.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'empty') {
          return LeaderboardResult(
              status: 'empty', city: city, weekStart: '',
              entries: [], isEmpty: true);
        }
        final entries = (data['entries'] as List? ?? [])
            .map((e) => LeaderboardEntryModel.fromJson(
                e as Map<String, dynamic>))
            .toList();
        LeaderboardEntryModel? myEntry;
        if (data['my_entry'] != null) {
          myEntry = LeaderboardEntryModel.fromJson(
              data['my_entry'] as Map<String, dynamic>);
        }
        return LeaderboardResult(
          status:    data['status']     as String? ?? 'ok',
          city:      data['city']       as String? ?? city,
          weekStart: data['week_start'] as String? ?? '',
          entries:   entries,
          myEntry:   myEntry,
        );
      }
    } catch (_) {}
    return LeaderboardResult(
        status: 'error', city: city, weekStart: '',
        entries: [], isEmpty: true);
  }

  // ── Challenge complete ─────────────────────────────────────────────────────

  static Future<void> reportChallengeComplete({
    required String username,
    required String challengeId,
    required int    xpReward,
    String?         city,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/challenge/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username':     username,
          'challenge_id': challengeId,
          'xp_reward':    xpReward,
          'city':         city ?? '',
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // ── Passport sync ──────────────────────────────────────────────────────────

  static Future<void> syncPassport({
    required String           username,
    required Map<String, int> cuisineCounts,
    String?                   city,
  }) async {
    if (cuisineCounts.isEmpty) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/passport/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username':       username,
          'cuisine_counts': cuisineCounts,
          'city':           city ?? '',
        }),
      ).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  // ── Get passport ───────────────────────────────────────────────────────────

  static Future<Map<String, int>> getPassport(String username) async {
    try {
      final uri = Uri.parse('$_baseUrl/passport')
          .replace(queryParameters: {'username': username});
      final response =
          await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data   = jsonDecode(response.body) as Map<String, dynamic>;
        final counts = data['cuisine_counts'] as Map<String, dynamic>? ?? {};
        return counts.map((k, v) => MapEntry(k, (v as num).toInt()));
      }
    } catch (_) {}
    return {};
  }
}