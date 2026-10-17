// lib/screens/explore/explore_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/places_provider.dart';
import '../../providers/gamification_provider.dart';
import '../home/passport_screen.dart';
import '../home/challenges_screen.dart';
import '../home/leaderboard_screen.dart';
import '../home/mood_screen.dart';

// THEME FIX: this screen used hardcoded dark colors (0xFF0D1117 bg,
// Colors.white text, fixed dark gradients). Now everything neutral comes
// from the active ColorScheme; only brand accents stay fixed.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlacesProvider>();
    final gami     = context.watch<GamificationProvider>();
    final cs       = Theme.of(context).colorScheme;
    final bg       = Theme.of(context).scaffoldBackgroundColor;

    final name = provider.userName.isNotEmpty
        ? provider.userName.split(' ').first
        : 'Explorer';

    final unlockedCount = provider.cuisineClickMap.keys.length;
    const totalCuisines = 22;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hey $name 👋',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'What do you want to explore today?',
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.55),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _XpStrip(gami: gami, places: provider),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _BigCard(
                    emoji:         '🛂',
                    title:         'Food Passport',
                    subtitle:      '$unlockedCount of $totalCuisines cuisines unlocked',
                    accent:        const Color(0xFFFF6B35),
                    progress:      unlockedCount / totalCuisines,
                    progressLabel: '${(unlockedCount / totalCuisines * 100).round()}% complete',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PassportScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _BigCard(
                    emoji:    '🏆',
                    title:    'Weekly Challenges',
                    subtitle: 'Complete missions to earn bonus XP',
                    accent:   const Color(0xFFF39C12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChallengesScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _BigCard(
                    emoji:    '📊',
                    title:    'City Leaderboard',
                    subtitle: 'Top food explorers in ${provider.currentCity}',
                    accent:   const Color(0xFF9C27B0),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                    ),
                  ),
                  const SizedBox(height: 20),
                ]),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Pick a mood',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => const MoodScreen(),
                        ),
                      ),
                      child: const Text('See all →',
                        style: TextStyle(color: Color(0xFFFF6B35), fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _MoodMiniRow(
                onMoodSelected: (mood) {
                  provider.fetchRecommendationsWithMood(
                    username: provider.userName,
                    mood:     mood,
                  );
                  Navigator.pushNamed(context, '/home');
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ── XP strip — reads streak from PlacesProvider ───────────────
class _XpStrip extends StatelessWidget {
  final GamificationProvider gami;
  final PlacesProvider       places;
  const _XpStrip({required this.gami, required this.places});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          _strip(cs, '⚡', '${gami.xp}',                    'Total XP',   const Color(0xFFFF6B35)),
          _div(cs),
          _strip(cs, '🔥', '${places.streak}',              'Day Streak', const Color(0xFFF39C12)),
          _div(cs),
          _strip(cs, '🏅', '${gami.unlockedBadges.length}', 'Badges',     const Color(0xFF9C27B0)),
          _div(cs),
          _strip(cs, '📈', 'Lv ${gami.level}',              'Level',      const Color(0xFF2ECC71)),
        ],
      ),
    );
  }

  Widget _strip(ColorScheme cs, String emoji, String val, String label, Color color) =>
    Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(
            color: color, fontSize: 14, fontWeight: FontWeight.w800,
          )),
          Text(label, style: TextStyle(
            color: cs.onSurface.withOpacity(0.45), fontSize: 9,
          )),
        ],
      ),
    );

  Widget _div(ColorScheme cs) => Container(
    width: 1, height: 36,
    color: cs.onSurface.withOpacity(0.08),
  );
}

// ── Big feature card ──────────────────────────────────────────
class _BigCard extends StatelessWidget {
  final String       emoji;
  final String       title;
  final String       subtitle;
  final Color        accent;
  final double?      progress;
  final String?      progressLabel;
  final VoidCallback onTap;

  const _BigCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.progress,
    this.progressLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Theme-aware gradient: accent tint laid over the current surface color.
    // Dark mode -> dark tinted card, light mode -> soft pastel card.
    final c1 = Color.alphaBlend(accent.withOpacity(0.12), cs.surface);
    final c2 = Color.alphaBlend(accent.withOpacity(0.04), cs.surface);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c1, c2],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.28)),
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w700,
                  )),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(
                    color: cs.onSurface.withOpacity(0.55), fontSize: 12,
                  )),
                  if (progress != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:           progress,
                        backgroundColor: cs.onSurface.withOpacity(0.08),
                        valueColor:      AlwaysStoppedAnimation(accent),
                        minHeight:       4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(progressLabel ?? '', style: TextStyle(
                      color: accent, fontSize: 10, fontWeight: FontWeight.w600,
                    )),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: accent.withOpacity(0.7), size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Mood mini row ─────────────────────────────────────────────
class _MoodMiniRow extends StatelessWidget {
  final Function(String) onMoodSelected;
  const _MoodMiniRow({required this.onMoodSelected});

  static const _moods = [
    {'id': 'celebrating', 'emoji': '🎉', 'label': 'Celebrate', 'color': Color(0xFFFF6B35)},
    {'id': 'comfort',     'emoji': '🤗', 'label': 'Comfort',   'color': Color(0xFF2ECC71)},
    {'id': 'adventurous', 'emoji': '🌍', 'label': 'Adventure', 'color': Color(0xFF9C27B0)},
    {'id': 'spicy',       'emoji': '🌶️', 'label': 'Spicy',     'color': Color(0xFFE74C3C)},
    {'id': 'healthy',     'emoji': '🥗', 'label': 'Healthy',   'color': Color(0xFF8BC34A)},
    {'id': 'sweet',       'emoji': '🍮', 'label': 'Sweet',     'color': Color(0xFFFF69B4)},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection:  Axis.horizontal,
        padding:          const EdgeInsets.symmetric(horizontal: 16),
        itemCount:        _moods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final m     = _moods[i];
          final color = m['color'] as Color;
          return GestureDetector(
            onTap: () => onMoodSelected(m['id'] as String),
            child: Container(
              width: 72,
              decoration: BoxDecoration(
                color:        color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border:       Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(m['emoji'] as String,
                    style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 6),
                  Text(m['label'] as String,
                    style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w600,
                    )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}