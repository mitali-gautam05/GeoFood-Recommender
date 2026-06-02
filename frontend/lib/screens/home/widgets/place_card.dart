import 'package:flutter/material.dart';
import '../../../models/place_model.dart';
import '../../../utils/app_theme.dart';
import 'score_breakdown_sheet.dart';

class PlaceCard extends StatelessWidget {
  final PlaceModel place;
  final int        rank;
  final String     username;
  final Function   onFeedback;

  const PlaceCard({
    super.key,
    required this.place,
    required this.rank,
    required this.username,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = AppTheme.scoreColor(place.score);

    return GestureDetector(
      // ── Tap card → open score breakdown ──────────────────────────────
      onTap: () => ScoreBreakdownSheet.show(context, place),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Rank + Name + Score ─────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '#$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      place.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scoreColor),
                    ),
                    child: Text(
                      place.scorePercent,
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Cuisine ─────────────────────────────────────────────
              Text(
                place.cuisine,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 10),

              // ── Chips ───────────────────────────────────────────────
              Row(
                children: [
                  _chip(place.formattedRating, Colors.amber),
                  const SizedBox(width: 8),
                  _chip(place.formattedPrice,  Colors.green),
                  const SizedBox(width: 8),
                  _chip(place.city.toUpperCase(), Colors.blue),
                  const Spacer(),
                  // Tap hint
                  Text(
                    'Tap for details',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Why recommended ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 16, color: AppTheme.primaryOrange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        place.whyRecommended,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Feedback buttons ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _feedbackBtn('😋 Interested', Colors.green,
                      () => onFeedback('interested')),
                  _feedbackBtn('👎 Not for me', Colors.red,
                      () => onFeedback('declined')),
                  _feedbackBtn('😌 Not hungry', Colors.orange,
                      () => onFeedback('not_hungry')),
                ],
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