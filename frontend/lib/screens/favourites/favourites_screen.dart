import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/favourites_provider.dart';
import '../../providers/places_provider.dart';
import '../home/widgets/place_card.dart';
import '../home/restaurant_detail_page.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favProvider = context.watch<FavouritesProvider>();
    final placesProvider = context.read<PlacesProvider>();
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
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: favs.length,
              itemBuilder: (_, i) {
                final place = favs[i];
                return Dismissible(
                  key: Key(place.name),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.redAccent,
                    child: const Icon(Icons.delete_outline,
                        color: Colors.white, size: 28),
                  ),
                  onDismissed: (_) => favProvider.remove(place.name),
                  child: GestureDetector(
                    onTap: () =>
                        RestaurantDetailPage.show(context, place, i + 1),
                    child: PlaceCard(
                      place:    place,
                      rank:     i + 1,
                      username: placesProvider.userName,
                      onFeedback: (action) {
                        if (action == 'interested') {
                          placesProvider.recordClick(
                              placesProvider.userName, place.cuisine);
                        } else if (action == 'not_hungry') {
                          placesProvider.setNotHungry();
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}