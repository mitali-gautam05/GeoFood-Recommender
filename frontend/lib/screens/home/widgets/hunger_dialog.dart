import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/places_provider.dart';
import '../../../services/api_client.dart';

Future<void> showHungerDialog(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _HungerSheet(),
  );
}

class _HungerSheet extends StatelessWidget {
  const _HungerSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 28),
          const Text('🍽️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),

          Text(
            'Hungry right now?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "We'll show you the best spots to eat.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.55),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 36),

          Row(
            children: [
              // Not yet
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final provider = context.read<PlacesProvider>();
                    Navigator.pop(context);
                    // Use ApiClient.setNotHungry (the actual method name)
                    try {
                      await ApiClient.setNotHungry(provider.userName);
                    } catch (_) {}
                    if (context.mounted) {
                      provider.setNotHungry();
                    }
                  },
                  child: const Text('Not yet'),
                ),
              ),
              const SizedBox(width: 14),

              // Yes, hungry!
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final provider = context.read<PlacesProvider>();
                    Navigator.pop(context);
                    provider.fetchRecommendations(
                      username: provider.userName,
                    );
                  },
                  child: const Text(
                    'Yes, show me food! 🔥',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}