// lib/screens/gamification/gamification_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/places_provider.dart';
import '../../models/badge_definitions.dart';

class GamificationScreen extends StatelessWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gami   = context.watch<GamificationProvider>();
    final places = context.watch<PlacesProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      body: CustomScrollView(
        slivers: [

          SliverAppBar(
            backgroundColor: const Color(0xFF111318),
            pinned:          true,
            expandedHeight:  0,
            title: const Text('Progress',
              style: TextStyle(
                color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          SliverToBoxAdapter(child: _LevelCard(gami: gami)),
          SliverToBoxAdapter(child: _StatsRow(gami: gami, places: places)),
          SliverToBoxAdapter(child: _TasteScoreCard(gami: gami)),

          // ── Badges header ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  const Text('Badges',
                    style: TextStyle(
                      color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w700,
                    )),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F77DD).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${gami.unlockedBadges.length}/${kAllBadges.length}',
                      style: const TextStyle(
                        color: Color(0xFF7F77DD), fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Unlocked badges ────────────────────────────────
          if (gami.unlockedBadges.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _BadgeCard(
                      badge: gami.unlockedBadges[i], unlocked: true),
                  childCount: gami.unlockedBadges.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:   3,
                  childAspectRatio: 0.9,
                  crossAxisSpacing: 10,
                  mainAxisSpacing:  10,
                ),
              ),
            ),

          // ── Locked header ──────────────────────────────────
          if (gami.lockedBadges.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text('Keep exploring to unlock',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 13,
                  )),
              ),
            ),

          // ── Locked badges ──────────────────────────────────
          if (gami.lockedBadges.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _BadgeCard(
                      badge: gami.lockedBadges[i], unlocked: false),
                  childCount: gami.lockedBadges.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:   3,
                  childAspectRatio: 0.9,
                  crossAxisSpacing: 10,
                  mainAxisSpacing:  10,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

// ── Level card ────────────────────────────────────────────────
class _LevelCard extends StatelessWidget {
  final GamificationProvider gami;
  const _LevelCard({required this.gami});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        const Color(0xFF1C2030),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF7F77DD).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Level ${gami.level}',
                style: const TextStyle(
                  color: Color(0xFF7F77DD), fontSize: 22,
                  fontWeight: FontWeight.w800,
                )),
              Text('${gami.xp} XP',
                style: const TextStyle(
                  color: Colors.white60, fontSize: 14,
                )),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value:           gami.progress,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor:
                  const AlwaysStoppedAnimation(Color(0xFF7F77DD)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text('${gami.nextLevelXp - gami.xp} XP to next level',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4), fontSize: 12,
            )),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final GamificationProvider gami;
  final PlacesProvider       places;
  const _StatsRow({required this.gami, required this.places});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _StatBox('🔥', '${gami.streak}',              'Day Streak'),
          const SizedBox(width: 10),
          _StatBox('🏅', '${gami.unlockedBadges.length}', 'Badges'),
          const SizedBox(width: 10),
          _StatBox('🍽️', '${gami.cuisineCounts.length}', 'Cuisines'),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String emoji, value, label;
  const _StatBox(this.emoji, this.value, this.label);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color:        const Color(0xFF1C2030),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 6),
              Text(value,
                style: const TextStyle(
                  color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w800,
                )),
              const SizedBox(height: 2),
              Text(label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 11,
                )),
            ],
          ),
        ),
      );
}

// ── Taste score card ──────────────────────────────────────────
class _TasteScoreCard extends StatelessWidget {
  final GamificationProvider gami;
  const _TasteScoreCard({required this.gami});

  @override
  Widget build(BuildContext context) {
    final score = gami.tasteScore;
    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        const Color(0xFF1C2030),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64, height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value:           score / 100,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFF2ECC71)),
                  strokeWidth: 6,
                ),
                Text(score.round().toString(),
                  style: const TextStyle(
                    color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w800,
                  )),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Taste Score',
                  style: TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w700,
                  )),
                const SizedBox(height: 4),
                Text(_scoreLabel(score),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 12,
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _scoreLabel(double score) {
    if (score < 20) return 'Just getting started — try new cuisines!';
    if (score < 40) return 'Budding explorer 🌱';
    if (score < 60) return 'Adventurous eater 🌍';
    if (score < 80) return 'Food connoisseur 🏆';
    return 'Master of flavours 👑';
  }
}

// ── Badge card ────────────────────────────────────────────────
// BadgeDefinition fields: id, emoji, title, description, unlockHint
class _BadgeCard extends StatelessWidget {
  final BadgeDefinition badge;
  final bool            unlocked;
  const _BadgeCard({required this.badge, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: unlocked
            ? const Color(0xFF1C2030)
            : const Color(0xFF161820),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked
              ? const Color(0xFF7F77DD).withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: unlocked ? 1.0 : 0.25,
            child: Text(badge.emoji,
                style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              // FIX: badge.title  (not .label, not .name — BadgeDefinition has .title)
              badge.title,
              textAlign: TextAlign.center,
              maxLines:  2,
              style: TextStyle(
                color: unlocked
                    ? Colors.white
                    : Colors.white.withOpacity(0.25),
                fontSize:   10,
                fontWeight: FontWeight.w600,
                height:     1.3,
              ),
            ),
          ),
          // Show unlock hint on locked badges
          if (!unlocked) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                badge.unlockHint,
                textAlign: TextAlign.center,
                maxLines:  2,
                style: TextStyle(
                  color:    Colors.white.withOpacity(0.2),
                  fontSize: 8,
                  height:   1.3,
                ),
              ),
            ),
          ],
          if (unlocked) ...[
            const SizedBox(height: 4),
            Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF7F77DD),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}