// lib/widgets/restaurant_card.dart
//
// Reusable Swiggy-style "box" card: photo on top with the name and rating
// overlaid at the bottom of the photo, details underneath. Independent of
// PlaceModel on purpose, so the chat screen (ChatRecommendation) and the
// dashboard (PlaceModel) can both use it by passing plain values.
//
// Theme-aware: surface / onSurface / dividerColor come from the active
// ColorScheme. Only the brand accent and the green rating pill are fixed.

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class RestaurantBoxCard extends StatelessWidget {
  final String name;
  final String cuisine;
  final double rating;
  final double price;
  final String? imageUrl;
  final String? note;        // short "why recommended" line
  final int? rank;           // optional "#1" badge
  final double imageHeight;
  final VoidCallback onTap;
  final VoidCallback? onLike;

  const RestaurantBoxCard({
    super.key,
    required this.name,
    required this.cuisine,
    required this.rating,
    required this.price,
    required this.onTap,
    this.imageUrl,
    this.note,
    this.rank,
    this.onLike,
    this.imageHeight = 130,
  });

  Widget _placeholder() {
    return Container(
      height: imageHeight,
      width: double.infinity,
      color: AppTheme.primary.withOpacity(0.12),
      child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 34))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;

    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Photo with name + rating overlay ──────────────────────
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    else
                      _placeholder(),
                    // dark gradient so white text is readable on any photo
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC000000)],
                          stops: [0.45, 1.0],
                        ),
                      ),
                    ),
                    if (rank != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('#$rank',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 8,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1BA672),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '★ ${rating.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Details ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cuisine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: onSurface.withOpacity(0.7),
                                fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹${price.toStringAsFixed(0)}',
                          style: TextStyle(
                              color: onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (note != null && note!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          note!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: onSurface.withOpacity(0.75),
                              fontSize: 11,
                              height: 1.3),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onLike != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4, bottom: 2),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onLike,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      icon: const Icon(Icons.favorite_border,
                          size: 16, color: AppTheme.primary),
                      label: const Text('I like this',
                          style: TextStyle(
                              color: AppTheme.primary, fontSize: 12)),
                    ),
                  ),
                )
              else
                const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}