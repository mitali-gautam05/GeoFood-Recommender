// ============================================================
// lib/widgets/streak_widget.dart
// Phase 1 fixes applied:
//   1. Colors.white54 / Colors.white24 replaced with
//      Theme.of(context).colorScheme.onSurface.withOpacity(...)
//      so text is visible in BOTH light and dark themes.
//   2. MoodChipRow "Mood" label same fix.
//   3. All logic and animation unchanged.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/places_provider.dart';

// ════════════════════════════════════════════════════════════
// 1. STREAK BANNER
// Reads from PlacesProvider.streak (correct — Critical Rule #4)
// ════════════════════════════════════════════════════════════

class StreakBanner extends StatefulWidget {
  const StreakBanner({super.key});
  @override
  State<StreakBanner> createState() => _StreakBannerState();
}

class _StreakBannerState extends State<StreakBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _flameCtrl;
  late Animation<double> _flameAnim;

  @override
  void initState() {
    super.initState();
    _flameCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _flameAnim = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _flameCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streak = context.watch<PlacesProvider>().streak;
    if (streak == 0) return const SizedBox.shrink();

    final isHot = streak >= 7;
    final color = isHot ? const Color(0xFFFF6B35) : const Color(0xFFF39C12);

    // Theme-aware muted text — works on both light and dark backgrounds
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final mutedText = onSurface.withOpacity(0.55);
    final dimText   = onSurface.withOpacity(0.30);

    final String milestone;
    if (streak < 7)       milestone = '${7  - streak} days to week badge 🗓️';
    else if (streak < 30) milestone = '${30 - streak} days to month badge 🏆';
    else                  milestone = 'Legendary explorer! 🌟';

    final int milestoneTarget = streak < 7 ? 7 : streak < 30 ? 30 : 100;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _flameAnim,
            builder: (_, __) => Transform.scale(
              scale: _flameAnim.value,
              child: Text(
                isHot ? '🔥' : '⚡',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      TextSpan(
                        text: '$streak day streak! ',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: isHot
                            ? "You're on fire 🌶️"
                            : 'Keep it up!',
                        // FIXED: was Colors.white54 — invisible on light theme
                        style: TextStyle(color: mutedText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  milestone,
                  style: TextStyle(
                    color: color.withOpacity(0.65),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Progress to milestone
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (streak / milestoneTarget).clamp(0.0, 1.0),
                    backgroundColor: onSurface.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$streak/$milestoneTarget',
                  // FIXED: was Colors.white24 — invisible on light theme
                  style: TextStyle(color: dimText, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 2. MOOD CHIP ROW
// Used in home_screen.dart inside the CustomScrollView.
// MoodChipRow lives HERE — not in weather_recommendation_service.dart.
// ════════════════════════════════════════════════════════════

class MoodChipRow extends StatelessWidget {
  final String? currentMood;
  final Function(String?) onMoodChanged;

  const MoodChipRow({
    super.key,
    required this.currentMood,
    required this.onMoodChanged,
  });

  static const _moods = [
    {'id': 'celebrating', 'label': '🎉 Party',     'color': Color(0xFFFF6B35)},
    {'id': 'comfort',     'label': '🤗 Comfort',   'color': Color(0xFF2ECC71)},
    {'id': 'adventurous', 'label': '🌍 Adventure', 'color': Color(0xFF9C27B0)},
    {'id': 'spicy',       'label': '🌶️ Spicy',     'color': Color(0xFFE74C3C)},
    {'id': 'healthy',     'label': '🥗 Healthy',   'color': Color(0xFF8BC34A)},
    {'id': 'sweet',       'label': '🍮 Sweet',     'color': Color(0xFFFF69B4)},
    {'id': 'date',        'label': '💕 Date',      'color': Color(0xFFE91E63)},
  ];

  @override
  Widget build(BuildContext context) {
    // FIXED: was Colors.white54 — invisible on light theme
    final onSurface    = Theme.of(context).colorScheme.onSurface;
    final labelColor   = onSurface.withOpacity(0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Text(
                'Mood',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                  letterSpacing: 0.5,
                ),
              ),
              if (currentMood != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => onMoodChanged(null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFFF6B35).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentMood!,
                          style: const TextStyle(
                            color: Color(0xFFFF6B35),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.close_rounded,
                          color: Color(0xFFFF6B35),
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _moods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final mood     = _moods[i];
              final isActive = currentMood == mood['id'];
              final color    = mood['color'] as Color;
              return GestureDetector(
                onTap: () => onMoodChanged(
                    isActive ? null : mood['id'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? color
                        : color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? Colors.transparent
                          : color.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    mood['label'] as String,
                    style: TextStyle(
                      color: isActive ? Colors.white : color,
                      fontSize: 12,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}