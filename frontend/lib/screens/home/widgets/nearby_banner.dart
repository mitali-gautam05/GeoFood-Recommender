// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FILE: lib/screens/home/widgets/nearby_banner.dart
// CREATE this as a new file — then import it in home_screen.dart
//
// This widget is a "Consumer" — it watches PlacesProvider and rebuilds
// ONLY itself when nearbyRestaurant changes. The rest of home_screen
// (your restaurant list, filters, etc.) does NOT rebuild. This is
// efficient Flutter — never wrap your whole screen in a Consumer.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/places_provider.dart';
import '../../../models/place_model.dart';
import '../restaurant_detail_page.dart';

class NearbyRestaurantBanner extends StatelessWidget {
  const NearbyRestaurantBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Consumer rebuilds only this widget when nearbyRestaurant changes.
    // It does NOT rebuild the whole home screen.
    return Consumer<PlacesProvider>(
      builder: (context, provider, _) {
        final nearby = provider.nearbyRestaurant;

        // AnimatedSwitcher smoothly fades the banner in/out.
        // When nearby == null, it shows SizedBox.shrink() — invisible, zero height.
        // When nearby != null, it slides in the banner card.
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1), // slides down from above
              end:   Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: nearby == null
              ? const SizedBox.shrink(key: ValueKey('empty'))
              : _BannerCard(key: ValueKey(nearby['name']), data: nearby),
        );
      },
    );
  }
}

// ── Private card widget ─────────────────────────────────────────────────
// Separated from the Consumer so AnimatedSwitcher gets a clean key transition.

class _BannerCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _BannerCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final provider     = context.read<PlacesProvider>();
    final theme        = Theme.of(context);
    final double dist  = (data['distance_km'] as double?) ?? 0.0;

    // Format: "450m away" if under 1km, else "1.2km away"
    final distText = dist < 1
        ? '${(dist * 1000).round()}m away'
        : '${dist.toStringAsFixed(1)}km away';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        // Uses your app's primary container color — matches AppTheme automatically
        color:        theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color:      theme.colorScheme.primary.withOpacity(0.08),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // ── Pulsing location icon ───────────────────────────────────
            Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:        theme.colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: theme.colorScheme.primary,
                size:  22,
              ),
            ),
            const SizedBox(width: 12),

            // ── Restaurant name + distance ──────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:       MainAxisSize.min,
                children: [
                  // Small label above the name
                  Text(
                    'Nearby now',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:       theme.colorScheme.primary,
                      fontWeight:  FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Restaurant name — bold, clips if too long
                  Text(
                    data['name'] ?? 'Restaurant nearby',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines:  1,
                    overflow:  TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Cuisine + distance — smaller grey text
                  Text(
                    '${data['cuisine'] ?? ''} · $distText',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── Action buttons column ───────────────────────────────────
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // "Show me" — primary action, navigates to detail page
                FilledButton(
                  onPressed: () => _openDetail(context, provider),
                  style: FilledButton.styleFrom(
                    padding:       const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize:   Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle:     const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Show me'),
                ),
                const SizedBox(height: 6),
                // "Not hungry" — pauses notifications for 60 min
                TextButton(
                  onPressed: () {
                    provider.pauseNotifications();
                    // Show a snackbar so user knows they can resume later
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Notifications paused for 60 min'),
                        behavior:       SnackBarBehavior.floating,
                        duration:       const Duration(seconds: 3),
                        action: SnackBarAction(
                          label:    'Undo',
                          onPressed: provider.resumeNotifications,
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding:       const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize:   Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle:     const TextStyle(fontSize: 11),
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: const Text('Not hungry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Navigates to the existing RestaurantDetailPage using the same slide-up
  // animation you already have across the rest of the app.
  void _openDetail(BuildContext context, PlacesProvider provider) {
    // Cancel the push notification — user is already looking at the restaurant
    provider.dismissNearbyBanner();

    final place = PlaceModel(
      name:           data['name']    ?? '',
      cuisine:        data['cuisine'] ?? '',
      price:          (data['price']  as num?)?.toInt()    ?? 0,
      rating:         (data['rating'] as num?)?.toDouble() ?? 0.0,
      score:          (data['score']  as num?)?.toDouble() ?? 0.0,
      whyRecommended: data['why_recommended'] ?? 'Highly rated near you',
      city:           data['city']    ?? provider.currentCity,
      lat:            (data['lat']    as num?)?.toDouble(),
      lng:            (data['lng']    as num?)?.toDouble(),
    );

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => RestaurantDetailPage(
          place: place,
          rank:  1,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1), // slides up from bottom — matches your existing style
            end:   Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    );
  }
}