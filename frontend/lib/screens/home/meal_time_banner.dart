import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// Shows a contextual banner based on current time of day.
/// Tap the suggestion chip to auto-fill the query.
class MealTimeBanner extends StatelessWidget {
  final ValueChanged<String> onSuggestionTap;

  const MealTimeBanner({super.key, required this.onSuggestionTap});

  static _MealTime _getMealTime() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) {
      return _MealTime(
        label: 'Good morning! 🌅',
        sub: 'Breakfast time',
        suggestions: ['idli', 'poha', 'paratha', 'dosa'],
        color: const Color(0xFFFF9B71),
        icon: '☀️',
      );
    } else if (hour >= 11 && hour < 15) {
      return _MealTime(
        label: 'Lunch hour 🍛',
        sub: 'What\'s for lunch?',
        suggestions: ['biryani', 'thali', 'north indian', 'south indian'],
        color: AppTheme.primaryOrange,
        icon: '🍛',
      );
    } else if (hour >= 15 && hour < 18) {
      return _MealTime(
        label: 'Snack time ☕',
        sub: 'Evening cravings',
        suggestions: ['chaat', 'momos', 'pizza', 'burger'],
        color: const Color(0xFF9B59B6),
        icon: '☕',
      );
    } else if (hour >= 18 && hour < 23) {
      return _MealTime(
        label: 'Dinner time 🌙',
        sub: 'End the day well',
        suggestions: ['chinese', 'mughlai', 'kebab', 'paneer'],
        color: const Color(0xFF2980B9),
        icon: '🌙',
      );
    } else {
      return _MealTime(
        label: 'Late night 🦉',
        sub: 'Night owl craving?',
        suggestions: ['pizza', 'rolls', 'noodles'],
        color: const Color(0xFF2C3E50),
        icon: '🦉',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = _getMealTime();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: meal.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: meal.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(meal.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.label,
                    style: TextStyle(
                      color: meal.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    meal.sub,
                    style: TextStyle(
                      color: meal.color.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: meal.suggestions.map((s) {
              return GestureDetector(
                onTap: () => onSuggestionTap(s),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: meal.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: meal.color.withOpacity(0.4)),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      color: meal.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MealTime {
  final String label;
  final String sub;
  final List<String> suggestions;
  final Color color;
  final String icon;
  const _MealTime({
    required this.label,
    required this.sub,
    required this.suggestions,
    required this.color,
    required this.icon,
  });
}