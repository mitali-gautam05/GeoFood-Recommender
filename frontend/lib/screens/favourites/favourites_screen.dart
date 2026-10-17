// lib/screens/favourites/favourites_screen.dart
//
// CHANGES:
//   - Saved restaurants are shown in the same responsive BOX grid as the
//     dashboard (1 to 4 columns depending on width).
//   - Each box has a "Remove" button instead of Interested / Not for me /
//     Not hungry (which made no sense on an already-saved restaurant), and
//     no #rank badge.
//   - Tap on a box opens RestaurantDetailPage (handled inside PlaceCard).
//   - Removing shows a snackbar with UNDO.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/favourites_provider.dart';
import '../home/widgets/place_card.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favProvider = context.watch<FavouritesProvider>();
    final favs = favProvider.favourites;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favourites ⭐'),
        centerTitle: false,
      ),
      body: favs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 16),
                  Text('No favourites yet',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Interested" on any restaurant\nto save it here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 14.0;
                  final available = constraints.maxWidth;
                  final cols = (available / 340).floor().clamp(1, 4);
                  final cardWidth = (available - spacing * (cols - 1)) / cols;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: List.generate(favs.length, (i) {
                      final place = favs[i];
                      return SizedBox(
                        width: cardWidth,
                        child: PlaceCard(
                          // key by name so a removed card doesn't hand its
                          // state to the next one
                          key: ValueKey(place.name),
                          place: place,
                          rank: i + 1,
                          showRank: false,
                          username: '',
                          onRemove: () {
                            favProvider.remove(place.name);
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.hideCurrentSnackBar();
                            // Newer Flutter keeps a SnackBar that has an action
                            // on screen until dismissed, ignoring `duration`.
                            // So we close it ourselves after 3 seconds.
                            final controller = messenger.showSnackBar(
                              SnackBar(
                                content:
                                    Text('Removed ${place.name} from favourites'),
                                duration: const Duration(seconds: 3),
                                action: SnackBarAction(
                                  label: 'UNDO',
                                  onPressed: () => favProvider.add(place),
                                ),
                              ),
                            );
                            Future.delayed(const Duration(seconds: 3), () {
                              controller.close();
                            });
                          },
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
    );
  }
}