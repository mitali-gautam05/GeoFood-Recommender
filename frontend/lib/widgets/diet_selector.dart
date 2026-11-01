// lib/widgets/diet_selector.dart
//
// DietSelector : a small setting (Any / Pure Veg / Non-veg).
//                - DietSelector()              -> full card (Explore screen)
//                - DietSelector(compact: true) -> thin bar only (Discover screen)
//                Default is "Any" — nothing is filtered unless the user picks.
//                The choice is saved (SharedPreferences) by PlacesProvider.
// DietDot      : the little veg / non-veg mark for restaurant cards.
//                Shows nothing for 'mixed' (unknown) places on purpose.
//
// NOTE: WidgetState / WidgetStateProperty need Flutter 3.22+. On an older
// Flutter, rename them to MaterialState / MaterialStateProperty.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/places_provider.dart';
import '../utils/app_theme.dart';

class DietSelector extends StatelessWidget {
  /// true  -> only the segmented bar, no card / title / helper text / margin
  ///          (used on Discover, which already has its own padding)
  /// false -> full card with title and helper text (used on Explore)
  final bool compact;

  const DietSelector({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlacesProvider>();
    final cs = Theme.of(context).colorScheme;
    final current = provider.diet ?? 'any';

    final control = SegmentedButton<String>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 'any', label: Text('Any')),
        ButtonSegment(value: 'veg', label: Text('Pure Veg')),
        ButtonSegment(value: 'nonveg', label: Text('Non-veg')),
      ],
      selected: {current},
      onSelectionChanged: (s) {
        final v = s.first;
        context.read<PlacesProvider>().setDiet(v == 'any' ? null : v);
      },
      style: ButtonStyle(
        visualDensity: compact ? VisualDensity.compact : null,
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppTheme.primaryOrange.withOpacity(0.18)
              : Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppTheme.primaryOrange
              : cs.onSurface.withOpacity(0.7);
        }),
      ),
    );

    // Discover: just the bar
    if (compact) {
      return SizedBox(width: double.infinity, child: control);
    }

    // Explore: full card
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Food preference',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: control),
          const SizedBox(height: 10),
          Text(
            current == 'veg'
                ? 'Showing only places confirmed vegetarian. Expect fewer results.'
                : current == 'nonveg'
                    ? 'Hiding pure-veg places.'
                    : 'Showing everything.',
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class DietDot extends StatelessWidget {
  final String diet; // 'veg' | 'nonveg' | 'mixed'
  const DietDot({super.key, required this.diet});

  @override
  Widget build(BuildContext context) {
    if (diet != 'veg' && diet != 'nonveg') return const SizedBox.shrink();

    final color =
        diet == 'veg' ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Tooltip(
      message: diet == 'veg' ? 'Pure veg' : 'Serves non-veg',
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}