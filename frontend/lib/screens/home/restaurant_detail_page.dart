import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/place_model.dart';
import '../../../utils/app_theme.dart';
import '../../../providers/places_provider.dart';
import '../../../providers/favourites_provider.dart';

class RestaurantDetailPage extends StatelessWidget {
  final PlaceModel place;
  final int rank;

  const RestaurantDetailPage({
    super.key,
    required this.place,
    required this.rank,
  });

  static void show(BuildContext context, PlaceModel place, int rank) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            RestaurantDetailPage(place: place, rank: rank),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = AppTheme.scoreColor(place.score);
    final favProvider = context.watch<FavouritesProvider>();
    final isFav = favProvider.isFavourite(place.name);
    final placesProvider = context.read<PlacesProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF1A2E45),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.redAccent : Colors.white,
                ),
                onPressed: () {
                  if (isFav) {
                    favProvider.remove(place.name);
                  } else {
                    favProvider.add(place);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isFav ? 'Removed from favourites' : 'Added to favourites ⭐',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A2E45), Color(0xFF0D1B2A)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.primaryOrange, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '#$rank',
                          style: const TextStyle(
                            color: AppTheme.primaryOrange,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          place.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Quick stats row ───────────────────────────────────
                  Row(
                    children: [
                      _StatCard(
                          icon: Icons.star,
                          value: '${place.rating}',
                          label: 'Rating',
                          color: Colors.amber),
                      const SizedBox(width: 12),
                      _StatCard(
                          icon: Icons.currency_rupee,
                          value: '₹${place.price}',
                          label: 'Avg price',
                          color: Colors.green),
                      const SizedBox(width: 12),
                      _StatCard(
                          icon: Icons.analytics_outlined,
                          value: place.scorePercent,
                          label: 'Match',
                          color: scoreColor),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Cuisine + city ────────────────────────────────────
                  _Section(
                    title: 'DETAILS',
                    child: Column(
                      children: [
                        _DetailRow(
                            icon: Icons.restaurant_menu,
                            label: 'Cuisine',
                            value: place.cuisine),
                        _DetailRow(
                            icon: Icons.location_city,
                            label: 'City',
                            value: place.city.toUpperCase()),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Why recommended ───────────────────────────────────
                  _Section(
                    title: 'WHY WE PICKED THIS',
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.primaryOrange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline,
                              color: AppTheme.primaryOrange, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              place.whyRecommended,
                              style: const TextStyle(
                                color: AppTheme.primaryOrange,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Score breakdown ───────────────────────────────────
                  _Section(
                    title: 'SCORE BREAKDOWN',
                    child: Column(
                      children: [
                        _SignalBar(label: 'Cuisine Match', value: place.simScore, weight: '30%', icon: Icons.restaurant_menu, color: AppTheme.primaryOrange),
                        _SignalBar(label: 'Rating Quality', value: place.ratingScore, weight: '20%', icon: Icons.star_outline, color: Colors.amber),
                        _SignalBar(label: 'Popularity', value: place.popularityNorm, weight: '15%', icon: Icons.trending_up, color: Colors.green),
                        _SignalBar(label: 'Budget Fit', value: place.budgetScore, weight: '15%', icon: Icons.currency_rupee, color: const Color(0xFF2ECC71)),
                        _SignalBar(label: 'Your Preference', value: place.prefScore, weight: '10%', icon: Icons.favorite_outline, color: Colors.pinkAccent),
                        _SignalBar(label: 'Time Context', value: place.timeBoost, weight: '5%', icon: Icons.access_time, color: const Color(0xFF3498DB)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Feedback buttons ──────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _FeedbackBtn(
                          label: '😋 Interested',
                          color: Colors.green,
                          onTap: () async {
                            await placesProvider.recordClick(
                              placesProvider.userName,
                              place.cuisine,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Noted! 😋')),
                              );
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FeedbackBtn(
                          label: '👎 Skip',
                          color: Colors.redAccent,
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SignalBar extends StatelessWidget {
  final String label;
  final double value;
  final String weight;
  final IconData icon;
  final Color color;
  const _SignalBar({required this.label, required this.value, required this.weight, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13))),
          Expanded(
            child: Stack(
              children: [
                Container(height: 8, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 36, child: Text('$pct%', textAlign: TextAlign.right, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
          SizedBox(width: 32, child: Text(weight, textAlign: TextAlign.right, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10))),
        ],
      ),
    );
  }
}

class _FeedbackBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _FeedbackBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(14),
          color: color.withOpacity(0.08),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }
}