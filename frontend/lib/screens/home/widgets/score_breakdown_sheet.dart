import 'package:flutter/material.dart';
import '../../../models/place_model.dart';
import '../../../utils/app_theme.dart';

class ScoreBreakdownSheet extends StatelessWidget {
  final PlaceModel place;

  const ScoreBreakdownSheet({super.key, required this.place});

  static void show(BuildContext context, PlaceModel place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScoreBreakdownSheet(place: place),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = AppTheme.scoreColor(place.score);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Handle bar ────────────────────────────────────────────────
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Header ───────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.cuisine,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Overall score circle
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scoreColor, width: 2.5),
                  color: scoreColor.withOpacity(0.1),
                ),
                alignment: Alignment.center,
                child: Text(
                  place.scorePercent,
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Why recommended box ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryOrange.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: AppTheme.primaryOrange,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    place.whyRecommended,
                    style: const TextStyle(
                      color: AppTheme.primaryOrange,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Score breakdown title ─────────────────────────────────────
          Text(
            'SCORE BREAKDOWN',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // ── Signal bars ───────────────────────────────────────────────
          _SignalBar(
            label:    'Cuisine Match',
            value:    place.simScore,
            weight:   '30%',
            icon:     Icons.restaurant_menu,
            color:    const Color(0xFFFF6B35),
          ),
          _SignalBar(
            label:    'Rating Quality',
            value:    place.ratingScore,
            weight:   '20%',
            icon:     Icons.star_outline,
            color:    Colors.amber,
          ),
          _SignalBar(
            label:    'Popularity',
            value:    place.popularityNorm,
            weight:   '15%',
            icon:     Icons.trending_up,
            color:    Colors.green,
          ),
          _SignalBar(
            label:    'Budget Fit',
            value:    place.budgetScore,
            weight:   '15%',
            icon:     Icons.currency_rupee,
            color:    const Color(0xFF2ECC71),
          ),
          _SignalBar(
            label:    'Your Preference',
            value:    place.prefScore,
            weight:   '10%',
            icon:     Icons.favorite_outline,
            color:    Colors.pinkAccent,
          ),
          _SignalBar(
            label:    'Time Context',
            value:    place.timeBoost,
            weight:   '5%',
            icon:     Icons.access_time,
            color:    const Color(0xFF3498DB),
          ),

          const SizedBox(height: 20),

          // ── Quick info row ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _InfoChip(
                icon: Icons.star,
                label: '${place.rating}★',
                color: Colors.amber,
              ),
              _InfoChip(
                icon: Icons.currency_rupee,
                label: '₹${place.price}',
                color: Colors.green,
              ),
              _InfoChip(
                icon: Icons.location_on_outlined,
                label: place.city.toUpperCase(),
                color: const Color(0xFF3498DB),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalBar extends StatelessWidget {
  final String label;
  final double value;
  final String weight;
  final IconData icon;
  final Color  color;

  const _SignalBar({
    required this.label,
    required this.value,
    required this.weight,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          // Icon
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),

          // Label
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),

          // Bar
          Expanded(
            child: Stack(
              children: [
                // Background
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Fill
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Percentage
          SizedBox(
            width: 36,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),

          // Weight
          SizedBox(
            width: 32,
            child: Text(
              weight,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}