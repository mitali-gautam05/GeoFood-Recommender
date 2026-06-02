class PlaceModel {
  final String name;
  final String cuisine;
  final int    price;
  final double rating;
  final double score;
  final String whyRecommended;
  final String city;
  final String matchedCity;

  // Score breakdown signals
  final double simScore;
  final double ratingScore;
  final double budgetScore;
  final double timeBoost;
  final double prefScore;
  final double popularityNorm;

  // ── NEW: GPS coordinates ───────────────────────────────────────────────
  // nullable because older API responses may not include them yet.
  // places_provider._checkAndNotify() uses these to calculate distance.
  final double? lat;
  final double? lng;

  PlaceModel({
    required this.name,
    required this.cuisine,
    required this.price,
    required this.rating,
    required this.score,
    required this.whyRecommended,
    required this.city,
    this.matchedCity    = '',
    this.simScore       = 0,
    this.ratingScore    = 0,
    this.budgetScore    = 0,
    this.timeBoost      = 0,
    this.prefScore      = 0,
    this.popularityNorm = 0,
    this.lat,   // NEW — optional, defaults to null
    this.lng,   // NEW — optional, defaults to null
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      name:           json['name']            ?? '',
      cuisine:        json['cuisine']         ?? '',
      price:          (json['price'] as num).toInt(),
      rating:         (json['rating'] as num).toDouble(),
      score:          (json['score']  as num).toDouble(),
      whyRecommended: json['why_recommended'] ?? '',
      city:           json['city']            ?? '',
      matchedCity:    json['matched_city']    ?? '',
      simScore:       (json['sim_score']        ?? 0).toDouble(),
      ratingScore:    (json['rating_score']     ?? 0).toDouble(),
      budgetScore:    (json['budget_score']     ?? 0).toDouble(),
      timeBoost:      (json['time_boost']       ?? 0).toDouble(),
      prefScore:      (json['pref_score']       ?? 0).toDouble(),
      popularityNorm: (json['popularity_norm']  ?? 0).toDouble(),
      // NEW — parse lat/lng from API response if present
      lat:            (json['lat'] as num?)?.toDouble(),
      lng:            (json['lng'] as num?)?.toDouble(),
    );
  }

  String get formattedRating => '★ $rating';
  String get formattedPrice  => '₹$price';
  String get scorePercent    => '${(score * 100).toInt()}%';
  bool   get isHighlyRated   => score >= 0.7;
}