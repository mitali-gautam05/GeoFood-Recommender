// lib/screens/progress/progress_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/places_provider.dart';
import '../../models/badge_definitions.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gami   = context.watch<GamificationProvider>();
    final places = context.watch<PlacesProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111318),
        title: const Text('Progress',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Level ${gami.level}',
                        style: const TextStyle(
                            color: Color(0xFF7F77DD),
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    Text('${gami.xp} XP',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: gami.progress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF7F77DD)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text('${gami.nextLevelXp - gami.xp} XP to next level',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(child: _StatTile('🔥', '${places.streak}', 'Day Streak')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile('🏅', '${gami.unlockedBadges.length}', 'Badges')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile('🍽️', '${places.cuisineClickMap.length}', 'Cuisines')),
          ]),
          const SizedBox(height: 20),

          const Text('Badges',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (gami.unlockedBadges.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No badges yet — keep exploring!',
                    style: TextStyle(color: Colors.white38)),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: gami.unlockedBadges.map((b) => _BadgeTile(b)).toList(),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2030),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: child,
      );
}

class _StatTile extends StatelessWidget {
  final String emoji, value, label;
  const _StatTile(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2030),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Color(0xFF7F77DD),
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      );
}

// FIX: typed as BadgeDefinition (not dynamic) so .title is known at compile time
// FIX: badge.name → badge.title  (BadgeDefinition has no .name field)
class _BadgeTile extends StatelessWidget {
  final BadgeDefinition badge;
  const _BadgeTile(this.badge);
  @override
  Widget build(BuildContext context) => Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2030),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF7F77DD).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              badge.title, // ← FIX: was badge.name which doesn't exist
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(color: Colors.white70, fontSize: 9),
            ),
          ],
        ),
      );
}