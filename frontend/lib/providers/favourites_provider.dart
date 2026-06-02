import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place_model.dart';

class FavouritesProvider extends ChangeNotifier {
  List<PlaceModel> _favourites = [];
  List<PlaceModel> get favourites => List.unmodifiable(_favourites);

  FavouritesProvider() {
    _load();
  }

  bool isFavourite(String name) =>
      _favourites.any((p) => p.name == name);

  Future<void> add(PlaceModel place) async {
    if (!isFavourite(place.name)) {
      _favourites.add(place);
      notifyListeners();
      await _save();
    }
  }

  Future<void> remove(String name) async {
    _favourites.removeWhere((p) => p.name == name);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _favourites.map((p) => {
        'name':            p.name,
        'cuisine':         p.cuisine,
        'price':           p.price,
        'rating':          p.rating,
        'score':           p.score,
        'why_recommended': p.whyRecommended,
        'city':            p.city,
        'matched_city':    p.matchedCity,
        'sim_score':       p.simScore,
        'rating_score':    p.ratingScore,
        'budget_score':    p.budgetScore,
        'time_boost':      p.timeBoost,
        'pref_score':      p.prefScore,
        'popularity_norm': p.popularityNorm,
      }).toList();
      await prefs.setString('favourites', jsonEncode(list));
    } catch (e) {
      debugPrint('FavouritesProvider _save error: $e');
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('favourites');
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      _favourites = decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => PlaceModel.fromJson(e))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('FavouritesProvider _load error: $e');
      _favourites = [];
    }
  }
}