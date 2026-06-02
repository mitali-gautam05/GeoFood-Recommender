// lib/screens/explore/explore_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/places_provider.dart';
import '../../providers/gamification_provider.dart';
import '../home/passport_screen.dart';
import '../home/challenges_screen.dart';
import '../home/leaderboard_screen.dart';
import '../home/mood_screen.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlacesProvider>();
    final gami     = context.watch<GamificationProvider>();
    // FIX: userName lives in PlacesProvider — was previously undefined 'name'
    final name     = provider.userName.isNotEmpty
        ? provider.userName.split(' ').first
        : 'Explorer';

    final unlockedCount = provider.cuisineClickMap.keys.length;
    const totalCuisines = 22;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'What do you want to explore today?',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // pass provider (PlacesProvider) so streak reads correctly
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
                    gradient:      const [Color(0xFF1A1F2E), Color(0xFF252B3B)],
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
                    gradient: const [Color(0xFF1A1500), Color(0xFF252000)],
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
                    gradient: const [Color(0xFF0A001A), Color(0xFF15002A)],
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
                    const Text('Pick a mood',
                      style: TextStyle(
                        color: Colors.white,
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          // FIX: totalXp → xp  (GamificationProvider exposes `xp`, not `totalXp`)
          _strip('⚡', '${gami.xp}',                  'Total XP',   const Color(0xFFFF6B35)),
          _div(),
          // FIX: gami.streak → places.streak (streak lives in PlacesProvider)
          _strip('🔥', '${places.streak}',            'Day Streak', const Color(0xFFF39C12)),
          _div(),
          // FIX: gami.badges → gami.unlockedBadges  (correct getter name)
          _strip('🏅', '${gami.unlockedBadges.length}', 'Badges',   const Color(0xFF9C27B0)),
          _div(),
          // gami.level is correctly defined in GamificationProvider
          _strip('📈', 'Lv ${gami.level}',            'Level',      const Color(0xFF2ECC71)),
        ],
      ),
    );
  }

  Widget _strip(String emoji, String val, String label, Color color) =>
    Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(
            color: color, fontSize: 14, fontWeight: FontWeight.w800,
          )),
          Text(label, style: const TextStyle(
            color: Colors.white30, fontSize: 9,
          )),
        ],
      ),
    );

  Widget _div() => Container(
    width: 1, height: 36,
    color: Colors.white.withOpacity(0.07),
  );
}

// ── Big feature card ──────────────────────────────────────────
class _BigCard extends StatelessWidget {
  final String       emoji;
  final String       title;
  final String       subtitle;
  final List<Color>  gradient;
  final Color        accent;
  final double?      progress;
  final String?      progressLabel;
  final VoidCallback onTap;

  const _BigCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.accent,
    required this.onTap,
    this.progress,
    this.progressLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color:  accent.withOpacity(0.15),
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
                  Text(title, style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
                  )),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 12,
                  )),
                  if (progress != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:            progress,
                        backgroundColor:  Colors.white.withOpacity(0.07),
                        valueColor:       AlwaysStoppedAnimation(accent),
                        minHeight:        4,
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
                color: accent.withOpacity(0.6), size: 14),
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