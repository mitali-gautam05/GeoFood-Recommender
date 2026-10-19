// lib/screens/home/widgets/place_card.dart
//
// Swiggy-style BOX card for the dashboard grid.
//   - photo on top, name + rating overlaid at the bottom of the photo
//   - #rank badge (top-left) and match-% pill (top-right)
//   - cuisine, price/city chips, "why recommended" box, feedback buttons
//
// Same constructor as before (place, rank, username, onFeedback), so
// home_screen only needs to change how it lays the cards out.
//
// TAP BEHAVIOUR (fixed): tapping the box opens RestaurantDetailPage.
// Tapping the match-% pill opens the score breakdown sheet. Previously the
// card's own GestureDetector (score sheet) swallowed the tap, so the detail
// page opened by home_screen's outer GestureDetector never fired.
//
// Theme-aware: surface / onSurface / dividerColor come from the ColorScheme.

import 'package:flutter/material.dart';
import '../../../models/place_model.dart';
import '../../../utils/app_theme.dart';
import '../restaurant_detail_page.dart';
import 'score_breakdown_sheet.dart';

class PlaceCard extends StatelessWidget {
  final PlaceModel place;
  final int        rank;
  final String     username;
  // Optional now: pass onFeedback for the Discover grid (Interested / Not for
  // me / Not hungry), or onRemove for the Favourites grid (Remove button).
  final Function?     onFeedback;
  final VoidCallback? onRemove;
  final bool          showRank;

  const PlaceCard({
    super.key,
    required this.place,
    required this.rank,
    required this.username,
    this.onFeedback,
    this.onRemove,
    this.showRank = true,
  });

  static const double _imageHeight = 150;

  static String _title(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  Widget _placeholder() => Container(
        color: AppTheme.primaryOrange.withOpacity(0.12),
        child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 36))),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;
    final scoreColor = AppTheme.scoreColor(place.score);
    final hasImage = place.imageUrl != null && place.imageUrl!.isNotEmpty;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: () => RestaurantDetailPage.show(context, place, rank),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Photo + overlays ────────────────────────────────────
              SizedBox(
                height: _imageHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      Image.network(
                        place.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : Container(
                                    color: onSurface.withOpacity(0.06),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ),
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    else
                      _placeholder(),

                    // dark gradient so white text reads on any photo
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

                    // #rank badge
                    if (showRank)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#$rank',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),

                    // match % pill -> score breakdown
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => ScoreBreakdownSheet.show(context, place),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: scoreColor),
                          ),
                          child: Text(
                            place.scorePercent,
                            style: TextStyle(
                              color: scoreColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // name + rating over the photo
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _title(place.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1BA672),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '★ ${place.formattedRating}',
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

              // ── Details ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.cuisine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: onSurface.withOpacity(0.65), fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _chip(place.formattedPrice, Colors.green),
                        _chip(place.city.toUpperCase(), Colors.blue),
                      ],
                    ),
                    if (place.whyRecommended.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline,
                                size: 16, color: AppTheme.primaryOrange),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                place.whyRecommended,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryOrange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    if (onRemove != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: onRemove,
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.redAccent),
                          label: const Text('Remove',
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 12)),
                        ),
                      ),

                    // Wrap (not Row) so 3 buttons never overflow a narrow box
                    if (onFeedback != null)
                    Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _feedbackBtn('😋 Interested', Colors.green,
                            () => onFeedback!('interested')),
                        _feedbackBtn('👎 Not for me', Colors.red,
                            () => onFeedback!('declined')),
                        _feedbackBtn('😌 Not hungry', Colors.orange,
                            () => onFeedback!('not_hungry')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _feedbackBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}