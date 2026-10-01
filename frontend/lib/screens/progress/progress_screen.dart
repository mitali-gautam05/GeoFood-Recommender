// lib/screens/progress/progress_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/places_provider.dart';
import '../../models/badge_definitions.dart';

// FIX: this screen was entirely hardcoded dark (Color(0xFF111318),
// Colors.white/white54/white38, Color(0xFF1C2030)...) with no
// Theme.of(context) usage at all, so it stayed dark even when the app
// was switched to light theme. All colors below now come from the
// active ColorScheme, matching passport_screen.dart / challenges_screen.dart
// / leaderboard_screen.dart, which were already theme-aware.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gami   = context.watch<GamificationProvider>();
    final places = context.watch<PlacesProvider>();
    final cs     = Theme.of(context).colorScheme;
    final bg     = Theme.of(context).scaffoldBackgroundColor;
    const purple = Color(0xFF7F77DD); // brand accent, stays fixed in both themes

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Progress',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
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
                            color: purple,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    Text('${gami.xp} XP',
                        style: TextStyle(
                            color: cs.onSurface.withOpacity(0.54), fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: gami.progress,
                    backgroundColor: cs.onSurface.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation(purple),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text('${gami.nextLevelXp - gami.xp} XP to next level',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.38), fontSize: 11)),
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

          Text('Badges',
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (gami.unlockedBadges.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No badges yet — keep exploring!',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.38))),
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withOpacity(0.07)),
      ),
      child: child,
    );
  }
}

class _StatTile extends StatelessWidget {
  final String emoji, value, label;
  const _StatTile(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withOpacity(0.07)),
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
              style: TextStyle(color: cs.onSurface.withOpacity(0.38), fontSize: 10)),
        ],
      ),
    );
  }
}

// FIX: typed as BadgeDefinition (not dynamic) so .title is known at compile time
// FIX: badge.name → badge.title  (BadgeDefinition has no .name field)
class _BadgeTile extends StatelessWidget {
  final BadgeDefinition badge;
  const _BadgeTile(this.badge);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7F77DD).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(badge.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 4),
          Text(
            badge.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 9),
          ),
        ],
      ),
    );
  }
}