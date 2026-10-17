// lib/providers/favourites_provider.dart
//
// FIXES:
// 1. Race condition: add()/remove() now wait for the initial load to finish,
//    so a fast add() can no longer overwrite the saved list with a partial one.
// 2. Silent data loss: a failed load no longer resets _favourites to [], and
//    one bad entry no longer drops the whole list (each item parsed separately).

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place_model.dart';

class FavouritesProvider extends ChangeNotifier {
  List<PlaceModel> _favourites = [];
  List<PlaceModel> get favourites => List.unmodifiable(_favourites);

  // Completes once the saved list has been read from storage.
  late final Future<void> _ready;

  FavouritesProvider() {
    _ready = _load();
  }

  bool isFavourite(String name) =>
      _favourites.any((p) => p.name == name);

  Future<void> add(PlaceModel place) async {
    await _ready; // wait for the initial load before touching the list
    if (!isFavourite(place.name)) {
      _favourites.add(place);
      notifyListeners();
      await _save();
    }
  }

  Future<void> remove(String name) async {
    await _ready;
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
        // FIX: these were never saved, so favourites reloaded without a photo
        // (placeholder icon) and without coordinates.
        'image_url':       p.imageUrl,
        'lat':             p.lat,
        'lng':             p.lng,
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

      // Parse each item separately so one bad entry doesn't wipe the list.
      final loaded = <PlaceModel>[];
      for (final e in decoded.whereType<Map<String, dynamic>>()) {
        try {
          loaded.add(PlaceModel.fromJson(e));
        } catch (err) {
          debugPrint('Skipping bad favourite: $err');
        }
      }
      _favourites = loaded;
      notifyListeners();
    } catch (e) {
      // Deliberately NOT resetting _favourites here: keep whatever we have
      // so a load error can't cause the next save to erase stored data.
      debugPrint('FavouritesProvider _load error: $e');
    }
  }
}