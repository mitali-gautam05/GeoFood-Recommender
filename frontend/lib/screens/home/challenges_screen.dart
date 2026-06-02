// lib/screens/home/challenges_screen.dart
// CHANGES from previous version:
//   • _claimReward() now also calls ApiClient.reportChallengeComplete()
//     so XP is persisted to backend and shows on leaderboard
//   • city is passed from PlacesProvider so backend can bucket by city

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../providers/places_provider.dart';
import '../../../providers/gamification_provider.dart';
import '../../../services/api_client.dart';

// ── Challenge model ───────────────────────────────────────────────────────────
class FoodChallenge {
  final String  id;
  final String  title;
  final String  description;
  final String  emoji;
  final int     xpReward;
  final int     targetCount;
  final String? requireCuisine;
  final Color   color;

  const FoodChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.xpReward,
    required this.targetCount,
    this.requireCuisine,
    required this.color,
  });
}

// ── Weekly sets ───────────────────────────────────────────────────────────────
List<FoodChallenge> getChallengesForWeek() {
  final weekNum = DateTime.now().difference(DateTime(2024, 1, 1)).inDays ~/ 7;
  final all = [_set1, _set2, _set3];
  return all[weekNum % all.length];
}

const _set1 = [
  FoodChallenge(
    id: 'south_indian_week', title: 'South Indian Explorer',
    description: 'Try any South Indian restaurant this week',
    emoji: '🥘', xpReward: 100, targetCount: 1,
    requireCuisine: 'south indian', color: Color(0xFF2ECC71),
  ),
  FoodChallenge(
    id: 'new_3_cuisines', title: 'Cuisine Hopper',
    description: 'Try 3 different cuisines in one week',
    emoji: '🌍', xpReward: 200, targetCount: 3,
    color: Color(0xFF9C27B0),
  ),
  FoodChallenge(
    id: 'street_food_2', title: 'Street Food Lover',
    description: 'Visit 2 street food spots this week',
    emoji: '🌮', xpReward: 75, targetCount: 2,
    requireCuisine: 'street food', color: Color(0xFFF39C12),
  ),
  FoodChallenge(
    id: 'daily_7', title: 'Food Explorer',
    description: 'Discover a new restaurant every day',
    emoji: '🗺️', xpReward: 350, targetCount: 7,
    color: Color(0xFFFF6B35),
  ),
];

const _set2 = [
  FoodChallenge(
    id: 'rare_find', title: 'Rare Find',
    description: 'Try a rare cuisine (Bengali/Thai/Kerala)',
    emoji: '💎', xpReward: 150, targetCount: 1,
    color: Color(0xFF9C27B0),
  ),
  FoodChallenge(
    id: 'biryani_3', title: 'Biryani Connoisseur',
    description: 'Compare 3 biryani restaurants this week',
    emoji: '🍚', xpReward: 120, targetCount: 3,
    requireCuisine: 'biryani', color: Color(0xFFE67E22),
  ),
  FoodChallenge(
    id: 'healthy_3', title: 'Healthy Habits',
    description: 'Pick 3 healthy spots this week',
    emoji: '🥗', xpReward: 100, targetCount: 3,
    requireCuisine: 'healthy', color: Color(0xFF8BC34A),
  ),
  FoodChallenge(
    id: 'dessert_2', title: 'Sweet Tooth',
    description: 'Visit 2 dessert places this week',
    emoji: '🍮', xpReward: 80, targetCount: 2,
    requireCuisine: 'desserts', color: Color(0xFFFF69B4),
  ),
];

const _set3 = [
  FoodChallenge(
    id: 'budget_master', title: 'Budget Master',
    description: 'Find 5 places under ₹200 this week',
    emoji: '💰', xpReward: 150, targetCount: 5,
    color: Color(0xFF2ECC71),
  ),
  FoodChallenge(
    id: 'mughlai_2', title: 'Royal Feast',
    description: 'Try 2 Mughlai restaurants this week',
    emoji: '👑', xpReward: 100, targetCount: 2,
    requireCuisine: 'mughlai', color: Color(0xFF8E44AD),
  ),
  FoodChallenge(
    id: 'cafe_3', title: 'Café Crawler',
    description: 'Visit 3 different cafés this week',
    emoji: '☕', xpReward: 90, targetCount: 3,
    requireCuisine: 'cafe', color: Color(0xFF795548),
  ),
  FoodChallenge(
    id: 'pizza_italian', title: 'Pizza Night',
    description: 'Find the best pizza or Italian spot',
    emoji: '🍕', xpReward: 80, targetCount: 2,
    requireCuisine: 'pizza', color: Color(0xFFE74C3C),
  ),
];

// ════════════════════════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════════════════════════
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final List<FoodChallenge> _challenges = getChallengesForWeek();
  Set<String> _completedIds = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadCompleted();
  }

  Future<void> _loadCompleted() async {
    final prefs   = await SharedPreferences.getInstance();
    final weekKey = _weekKey;
    final raw     = prefs.getString(weekKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      setState(() { _completedIds = list.cast<String>().toSet(); });
    }
    setState(() => _loaded = true);
  }

  String get _weekKey {
    final week = DateTime.now().difference(DateTime(2024, 1, 1)).inDays ~/ 7;
    return 'challenges_week_$week';
  }

  Future<void> _claimReward(FoodChallenge challenge) async {
    final gami     = context.read<GamificationProvider>();
    final places   = context.read<PlacesProvider>();
    final username = places.userName;
    final city     = places.currentCity;

    // 1. Award XP locally (GamificationProvider)
    await gami.trackAction(action: GamificationAction.nearbyVisited);

    // 2. Persist to backend (fire-and-forget — never blocks UI)
    ApiClient.reportChallengeComplete(
      username:    username,
      challengeId: challenge.id,
      xpReward:    challenge.xpReward,
      city:        city,
    );

    // 3. Mark as completed locally
    setState(() => _completedIds.add(challenge.id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_weekKey, jsonEncode(_completedIds.toList()));

    if (mounted) _showReward(challenge);
  }

  void _showReward(FoodChallenge challenge) {
    showDialog(
      context: context,
      builder: (_) => _RewardDialog(challenge: challenge),
    );
  }

  int _getProgress(FoodChallenge challenge, Map<String, int> clickMap) {
    if (challenge.requireCuisine != null) {
      return clickMap[challenge.requireCuisine!] ?? 0;
    }
    return clickMap.values.fold(0, (a, b) => a + b);
  }

  int get _daysLeft {
    final now    = DateTime.now();
    final monday = now.add(Duration(days: 7 - now.weekday));
    return monday.difference(now).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final clickMap = context.watch<PlacesProvider>().cuisineClickMap;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'WEEKLY CHALLENGES',
          style: TextStyle(
            color: Colors.white, fontSize: 15,
            fontWeight: FontWeight.w700, letterSpacing: 2.5,
          ),
        ),
      ),
      body: _loaded
          ? CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                    child: _ResetTimer(daysLeft: _daysLeft)),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final c         = _challenges[i];
                        final progress  = _getProgress(c, clickMap);
                        final completed = _completedIds.contains(c.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ChallengeCard(
                            challenge: c,
                            progress:  progress.clamp(0, c.targetCount),
                            completed: completed,
                            onClaim:   completed
                                ? null
                                : () => _claimReward(c),
                          ),
                        );
                      },
                      childCount: _challenges.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF6B35).withOpacity(0.12),
                            const Color(0xFF9C27B0).withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFFFF6B35).withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Text('🔥',
                              style: TextStyle(fontSize: 32)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_completedIds.length}/${_challenges.length} this week',
                                  style: const TextStyle(
                                    color: Colors.white, fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Complete all challenges for a bonus 🏅',
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFFFF6B35))),
    );
  }
}

// ── Reset timer ───────────────────────────────────────────────────────────────
class _ResetTimer extends StatelessWidget {
  final int daysLeft;
  const _ResetTimer({required this.daysLeft});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined,
                color: Colors.white30, size: 16),
            const SizedBox(width: 8),
            Text(
              'Challenges reset in $daysLeft day${daysLeft == 1 ? '' : 's'} • Monday midnight',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
}

// ── Challenge card ────────────────────────────────────────────────────────────
class _ChallengeCard extends StatelessWidget {
  final FoodChallenge challenge;
  final int           progress;
  final bool          completed;
  final VoidCallback? onClaim;

  const _ChallengeCard({
    required this.challenge,
    required this.progress,
    required this.completed,
    this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final pct    = (progress / challenge.targetCount).clamp(0.0, 1.0);
    final color  = challenge.color;
    final isDone = progress >= challenge.targetCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed
              ? Colors.white12
              : isDone
                  ? color.withOpacity(0.5)
                  : Colors.white.withOpacity(0.06),
          width: isDone && !completed ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(challenge.emoji,
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(challenge.title,
                        style: TextStyle(
                          color: completed
                              ? Colors.white30
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        )),
                    Text(challenge.description,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              if (!completed)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border:       Border.all(
                        color: color.withOpacity(0.3)),
                  ),
                  child: Text('+${challenge.xpReward} XP',
                      style: TextStyle(
                          color: color, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                )
              else
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white24, size: 24),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:           completed ? 1.0 : pct,
                    backgroundColor: Colors.white.withOpacity(0.06),
                    valueColor:      AlwaysStoppedAnimation(
                        completed ? Colors.white24 : color),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                completed
                    ? 'Done!'
                    : '$progress / ${challenge.targetCount}',
                style: TextStyle(
                  color: completed ? Colors.white24 : color,
                  fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (isDone && !completed) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onClaim,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('🎉  Claim Reward',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Reward dialog ─────────────────────────────────────────────────────────────
class _RewardDialog extends StatelessWidget {
  final FoodChallenge challenge;
  const _RewardDialog({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color:        const Color(0xFF161B27),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: challenge.color.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
                color:      challenge.color.withOpacity(0.2),
                blurRadius: 40),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(challenge.emoji,
                style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            const Text('Challenge Complete!',
                style: TextStyle(
                    color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(challenge.title,
                style:
                    TextStyle(color: challenge.color, fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color:        challenge.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('+${challenge.xpReward} XP Earned',
                  style: TextStyle(
                      color: challenge.color, fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Nice! 🚀',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}