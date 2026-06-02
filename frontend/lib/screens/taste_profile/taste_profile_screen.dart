import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/places_provider.dart';
import '../../utils/app_theme.dart';

class TasteProfileScreen extends StatelessWidget {
  const TasteProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlacesProvider>();
    final theme = Theme.of(context);
    final clicks = provider.cuisineClickMap;
    final total = clicks.values.fold(0, (a, b) => a + b);
    final sorted = clicks.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Coverage: unique cuisines clicked vs total unique in dataset (approx 20)
    final coverage = ((clicks.length / 20) * 100).clamp(0, 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taste Profile 📊'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Coverage card ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A2E45), Color(0xFF0D1B2A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CUISINE DISCOVERY',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '$coverage%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'of cuisines explored',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: coverage / 100,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryOrange),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  coverage < 30
                      ? '🌱 Just getting started — try something new!'
                      : coverage < 60
                          ? '🔥 Nice variety! Keep exploring.'
                          : '🏆 Foodie level: Expert!',
                  style: TextStyle(
                      color: AppTheme.primaryOrange.withOpacity(0.9),
                      fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Total taps ────────────────────────────────────────────────
          Row(
            children: [
              _MiniStat(
                  label: 'Total taps',
                  value: '$total',
                  icon: Icons.touch_app),
              const SizedBox(width: 12),
              _MiniStat(
                  label: 'Cuisines tried',
                  value: '${clicks.length}',
                  icon: Icons.restaurant_menu),
              const SizedBox(width: 12),
              _MiniStat(
                  label: 'Top cuisine',
                  value: sorted.isEmpty ? '—' : _shortName(sorted.first.key),
                  icon: Icons.star),
            ],
          ),

          const SizedBox(height: 24),

          // ── Bar chart ─────────────────────────────────────────────────
          if (sorted.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Text('📊', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text('No data yet',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Tap "Interested" on restaurants\nto build your taste profile.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              'YOUR CUISINE BREAKDOWN',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ...sorted.take(10).map((entry) {
              final pct = total == 0 ? 0.0 : entry.value / total;
              final color = _cuisineColor(entry.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(entry.key,
                              style: theme.textTheme.bodyMedium),
                        ),
                        Text(
                          '${entry.value} taps  •  ${(pct * 100).toInt()}%',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor:
                            color.withOpacity(0.12),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(color),
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 32),

          // ── Suggestion ────────────────────────────────────────────────
          if (sorted.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppTheme.primaryOrange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: AppTheme.primaryOrange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You love ${sorted.first.key}! Next time try something different — your ML model learns from every tap.',
                      style: const TextStyle(
                          color: AppTheme.primaryOrange,
                          fontSize: 13,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _shortName(String cuisine) {
    final words = cuisine.split(' ');
    return words.length > 1 ? words.first : cuisine;
  }

  Color _cuisineColor(String cuisine) {
    final colors = [
      AppTheme.primaryOrange,
      Colors.amber,
      Colors.green,
      Colors.blue,
      Colors.pinkAccent,
      Colors.teal,
      Colors.purple,
      Colors.cyan,
      Colors.deepOrange,
      Colors.indigo,
    ];
    return colors[cuisine.hashCode.abs() % colors.length];
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MiniStat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.primaryOrange;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            Text(label,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                    fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}