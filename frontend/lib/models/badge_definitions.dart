// lib/models/badge_definitions.dart

class BadgeDefinition {
  final String id;
  final String emoji;
  final String title;
  final String description;   // shown on badge shelf
  final String unlockHint;    // shown while locked

  const BadgeDefinition({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.unlockHint,
  });
}

// ── All badge definitions ──────────────────────────────────────────────────────
//
// Unlock logic lives in GamificationProvider.checkBadges().
// Each id here is the key checked there — keep them in sync.

const List<BadgeDefinition> kAllBadges = [
  // ── Explorer badges ──────────────────────────────────────────────────────────
  BadgeDefinition(
    id:          'first_tap',
    emoji:       '👆',
    title:       'First bite',
    description: 'Tapped your first restaurant.',
    unlockHint:  'Tap any restaurant card.',
  ),
  BadgeDefinition(
    id:          'explorer_5',
    emoji:       '🧭',
    title:       'Explorer',
    description: 'Tried 5 different cuisines.',
    unlockHint:  'Explore 5 different cuisine types.',
  ),
  BadgeDefinition(
    id:          'explorer_10',
    emoji:       '🗺️',
    title:       'World traveller',
    description: 'Tried 10 different cuisines.',
    unlockHint:  'Explore 10 different cuisine types.',
  ),

  // ── Cuisine specialist badges ────────────────────────────────────────────────
  BadgeDefinition(
    id:          'biryani_boss',
    emoji:       '🍚',
    title:       'Biryani boss',
    description: 'Tapped 10 biryani restaurants.',
    unlockHint:  'Tap 10 biryani places.',
  ),
  BadgeDefinition(
    id:          'street_foodie',
    emoji:       '🌮',
    title:       'Street foodie',
    description: 'Tapped 8 street food spots.',
    unlockHint:  'Tap 8 street food places.',
  ),
  BadgeDefinition(
    id:          'chai_lover',
    emoji:       '☕',
    title:       'Chai lover',
    description: 'Tapped 5 beverage or cafe places.',
    unlockHint:  'Tap 5 cafe or beverage spots.',
  ),

  // ── Time-based badges ────────────────────────────────────────────────────────
  BadgeDefinition(
    id:          'night_owl',
    emoji:       '🦉',
    title:       'Night owl',
    description: 'Explored restaurants after 10 PM.',
    unlockHint:  'Open the app after 10 PM.',
  ),
  BadgeDefinition(
    id:          'early_bird',
    emoji:       '🌅',
    title:       'Early bird',
    description: 'Discovered breakfast spots before 8 AM.',
    unlockHint:  'Open the app before 8 AM.',
  ),

  // ── Streak badges ────────────────────────────────────────────────────────────
  BadgeDefinition(
    id:          'streak_3',
    emoji:       '🔥',
    title:       'On a roll',
    description: 'Kept a 3-day streak.',
    unlockHint:  'Open the app 3 days in a row.',
  ),
  BadgeDefinition(
    id:          'streak_7',
    emoji:       '🏆',
    title:       'Unstoppable',
    description: 'Kept a 7-day streak.',
    unlockHint:  'Open the app 7 days in a row.',
  ),
  BadgeDefinition(
    id:          'streak_30',
    emoji:       '💎',
    title:       'Diamond palate',
    description: '30-day streak. You are GeoTaste.',
    unlockHint:  'Open the app 30 days in a row.',
  ),

  // ── XP milestones ────────────────────────────────────────────────────────────
  BadgeDefinition(
    id:          'xp_100',
    emoji:       '⭐',
    title:       'Rising star',
    description: 'Earned 100 XP.',
    unlockHint:  'Earn 100 XP by exploring.',
  ),
  BadgeDefinition(
    id:          'xp_500',
    emoji:       '🌟',
    title:       'Taste legend',
    description: 'Earned 500 XP.',
    unlockHint:  'Earn 500 XP.',
  ),

  // ── Notification badges ──────────────────────────────────────────────────────
  BadgeDefinition(
    id:          'nearby_visited',
    emoji:       '📍',
    title:       'Serendipity',
    description: 'Visited a restaurant from a nearby notification.',
    unlockHint:  'Tap "Show me" on a nearby notification.',
  ),
];

// Convenience lookup
final Map<String, BadgeDefinition> kBadgeById = {
  for (final b in kAllBadges) b.id: b,
};