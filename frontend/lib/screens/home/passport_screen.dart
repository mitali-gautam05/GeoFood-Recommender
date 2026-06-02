// lib/screens/home/passport_screen.dart
// Phase 3 additions (UI is IDENTICAL — only data wiring changed):
//   1. initState calls ApiClient.getPassport() and merges server
//      counts with local cuisineClickMap — so progress survives logout.
//   2. _serverCounts overlay merged on top of local counts in build().
//   No visual changes — same grid, same animations, same filter row.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/places_provider.dart';
import '../../../services/api_client.dart';

// ── All 22 cuisines (unchanged) ───────────────────────────────
const List<Map<String, dynamic>> kAllCuisines = [
  {'id': 'north indian',  'name': 'North Indian',  'emoji': '🍛', 'color': Color(0xFFFF6B35), 'light': Color(0xFFFFF0EB)},
  {'id': 'south indian',  'name': 'South Indian',  'emoji': '🥘', 'color': Color(0xFF2ECC71), 'light': Color(0xFFE8F8EF)},
  {'id': 'chinese',       'name': 'Chinese',        'emoji': '🍜', 'color': Color(0xFFE74C3C), 'light': Color(0xFFFDE8E7)},
  {'id': 'mughlai',       'name': 'Mughlai',        'emoji': '🍖', 'color': Color(0xFF8E44AD), 'light': Color(0xFFF3E8FA)},
  {'id': 'street food',   'name': 'Street Food',    'emoji': '🌮', 'color': Color(0xFFF39C12), 'light': Color(0xFFFEF6E4)},
  {'id': 'biryani',       'name': 'Biryani',        'emoji': '🍚', 'color': Color(0xFFE67E22), 'light': Color(0xFFFEF0E6)},
  {'id': 'pizza',         'name': 'Pizza',          'emoji': '🍕', 'color': Color(0xFFE74C3C), 'light': Color(0xFFFDE8E7)},
  {'id': 'burger',        'name': 'Burger',         'emoji': '🍔', 'color': Color(0xFFD35400), 'light': Color(0xFFFCECE3)},
  {'id': 'desserts',      'name': 'Desserts',       'emoji': '🍮', 'color': Color(0xFFFF69B4), 'light': Color(0xFFFFF0F7)},
  {'id': 'cafe',          'name': 'Café',           'emoji': '☕', 'color': Color(0xFF795548), 'light': Color(0xFFF0EBE8)},
  {'id': 'rajasthani',    'name': 'Rajasthani',     'emoji': '🥗', 'color': Color(0xFFFF8C00), 'light': Color(0xFFFFF4E3)},
  {'id': 'gujarati',      'name': 'Gujarati',       'emoji': '🧆', 'color': Color(0xFF27AE60), 'light': Color(0xFFE8F7EE)},
  {'id': 'punjabi',       'name': 'Punjabi',        'emoji': '🥙', 'color': Color(0xFFFF5722), 'light': Color(0xFFFFF0ED)},
  {'id': 'bengali',       'name': 'Bengali',        'emoji': '🐟', 'color': Color(0xFF2196F3), 'light': Color(0xFFE3F2FD)},
  {'id': 'kerala',        'name': 'Kerala',         'emoji': '🥥', 'color': Color(0xFF4CAF50), 'light': Color(0xFFE8F5E9)},
  {'id': 'thai',          'name': 'Thai',           'emoji': '🍲', 'color': Color(0xFFFF6F00), 'light': Color(0xFFFFF3E0)},
  {'id': 'continental',   'name': 'Continental',    'emoji': '🥩', 'color': Color(0xFF607D8B), 'light': Color(0xFFECEFF1)},
  {'id': 'italian',       'name': 'Italian',        'emoji': '🍝', 'color': Color(0xFF009688), 'light': Color(0xFFE0F2F1)},
  {'id': 'kebab',         'name': 'Kebab',          'emoji': '🍢', 'color': Color(0xFF9C27B0), 'light': Color(0xFFF3E5F5)},
  {'id': 'healthy',       'name': 'Healthy',        'emoji': '🥗', 'color': Color(0xFF8BC34A), 'light': Color(0xFFF1F8E9)},
  {'id': 'seafood',       'name': 'Seafood',        'emoji': '🦞', 'color': Color(0xFF0288D1), 'light': Color(0xFFE1F5FE)},
  {'id': 'fast food',     'name': 'Fast Food',      'emoji': '🍟', 'color': Color(0xFFFFC107), 'light': Color(0xFFFFFDE7)},
];

String _rarity(String id) {
  const rare     = ['bengali', 'kerala', 'thai', 'italian', 'seafood', 'rajasthani'];
  const uncommon = ['mughlai', 'continental', 'gujarati', 'healthy'];
  if (rare.contains(id))     return 'RARE';
  if (uncommon.contains(id)) return 'UNCOMMON';
  return 'COMMON';
}

Color _rarityColor(String rarity) {
  switch (rarity) {
    case 'RARE':     return const Color(0xFF9C27B0);
    case 'UNCOMMON': return const Color(0xFFFF8C00);
    default:         return const Color(0xFF607D8B);
  }
}

// ════════════════════════════════════════════════════════════
// PASSPORT SCREEN
// ════════════════════════════════════════════════════════════
class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen>
    with TickerProviderStateMixin {

  late AnimationController _headerController;
  late Animation<double>   _headerAnim;
  String? _justStamped;
  int _filterIndex = 0;

  // ── Phase 3: server counts merged with local ──────────────
  Map<String, int> _serverCounts = {};
  bool _serverLoaded = false;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _headerAnim = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );
    // Phase 3: fetch server-side passport on open
    _loadServerPassport();
  }

  // ── Phase 3: load server passport and merge with local ────
  Future<void> _loadServerPassport() async {
    final username = context.read<PlacesProvider>().userName;
    if (username.isEmpty) {
      setState(() => _serverLoaded = true);
      return;
    }
    final serverCounts = await ApiClient.getPassport(username);
    if (mounted) {
      setState(() {
        _serverCounts  = serverCounts;
        _serverLoaded  = true;
      });
    }
  }

  // ── Merge local + server counts (take max of each) ────────
  Map<String, int> _mergedCounts(Map<String, int> local) {
    final merged = Map<String, int>.from(local);
    for (final entry in _serverCounts.entries) {
      final existing = merged[entry.key] ?? 0;
      if (entry.value > existing) merged[entry.key] = entry.value;
    }
    return merged;
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filteredCuisines(Map<String, int> seen) {
    switch (_filterIndex) {
      case 1:
        return kAllCuisines.where((c) => seen.containsKey(c['id'])).toList();
      case 2:
        return kAllCuisines.where((c) => !seen.containsKey(c['id'])).toList();
      case 3:
        return kAllCuisines.where((c) => _rarity(c['id']) == 'RARE').toList();
      default:
        return kAllCuisines;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlacesProvider>();
    // Phase 3: merge local + server so progress is never lost
    final seen     = _mergedCounts(provider.cuisineClickMap);
    final total    = kAllCuisines.length;
    final unlocked = kAllCuisines.where((c) => seen.containsKey(c['id'])).length;
    final pct      = (unlocked / total * 100).round();
    final filtered = _filteredCuisines(seen);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: CustomScrollView(
        slivers: [

          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: const Color(0xFF0D1117),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'FOOD PASSPORT',
              style: TextStyle(
                color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.w700, letterSpacing: 3,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _PassportHeader(
                unlocked: unlocked,
                total:    total,
                pct:      pct,
                anim:     _headerAnim,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _StatsStrip(seen: seen, unlocked: unlocked, total: total),
          ),

          SliverToBoxAdapter(
            child: _FilterRow(
              selected:  _filterIndex,
              onChanged: (i) => setState(() => _filterIndex = i),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final cuisine = filtered[i];
                  final id      = cuisine['id'] as String;
                  final clicks  = seen[id] ?? 0;
                  final isNew   = _justStamped == id;

                  return _CuisineCard(
                    cuisine:    cuisine,
                    clicks:     clicks,
                    isUnlocked: clicks > 0,
                    isNew:      isNew,
                    onStamped: () {
                      setState(() => _justStamped = id);
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) setState(() => _justStamped = null);
                      });
                    },
                  );
                },
                childCount: filtered.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:   3,
                childAspectRatio: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing:  10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── All sub-widgets below are IDENTICAL to original ───────────

class _PassportHeader extends StatelessWidget {
  final int unlocked, total, pct;
  final Animation<double> anim;
  const _PassportHeader({
    required this.unlocked, required this.total,
    required this.pct, required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1A1F2E), Color(0xFF0D1117)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _BgPainter())),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                child: Opacity(
                  opacity: anim.value.clamp(0.0, 1.0),
                  child: Row(
                    children: [
                      Container(
                        width: 64, height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withOpacity(0.4),
                              blurRadius: 16, offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🍽️', style: TextStyle(fontSize: 26)),
                            SizedBox(height: 4),
                            Text('GT', style: TextStyle(
                              color: Colors.white, fontSize: 10,
                              fontWeight: FontWeight.w800, letterSpacing: 2,
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$unlocked / $total cuisines explored',
                              style: const TextStyle(
                                color: Colors.white, fontSize: 16,
                                fontWeight: FontWeight.w700,
                              )),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: unlocked / total * anim.value,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFFFF6B35)),
                                minHeight: 7,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text('$pct% of your food journey complete',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  final Map<String, int> seen;
  final int unlocked, total;
  const _StatsStrip({required this.seen, required this.unlocked, required this.total});

  int get pct => (unlocked / total * 100).round();

  @override
  Widget build(BuildContext context) {
    final totalVisits = seen.values.fold(0, (a, b) => a + b);
    final rareCount   = kAllCuisines
        .where((c) => _rarity(c['id']) == 'RARE' && seen.containsKey(c['id']))
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          _Stat('$unlocked',    'Cuisines\nUnlocked', const Color(0xFFFF6B35)),
          _vDivider(),
          _Stat('$totalVisits', 'Total\nVisits',      const Color(0xFF2ECC71)),
          _vDivider(),
          _Stat('$rareCount',   'Rare\nFinds',        const Color(0xFF9C27B0)),
          _vDivider(),
          _Stat(unlocked >= total ? '🏆' : '$pct%',
                'Passport\nFilled',                   const Color(0xFFF39C12)),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
    width: 1, height: 38,
    color: Colors.white.withOpacity(0.08),
  );
}

class _Stat extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _Stat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: TextStyle(
          color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white38, fontSize: 10, height: 1.4)),
      ],
    ),
  );
}

class _FilterRow extends StatelessWidget {
  final int selected;
  final Function(int) onChanged;
  const _FilterRow({required this.selected, required this.onChanged});
  static const _labels = ['All', 'Unlocked', 'Locked', 'Rare'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = selected == i;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFFF6B35) : const Color(0xFF161B27),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? Colors.transparent : Colors.white12),
              ),
              child: Text(_labels[i],
                style: TextStyle(
                  color:      active ? Colors.white : Colors.white54,
                  fontSize:   13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                )),
            ),
          );
        },
      ),
    );
  }
}

class _CuisineCard extends StatefulWidget {
  final Map<String, dynamic> cuisine;
  final int        clicks;
  final bool       isUnlocked;
  final bool       isNew;
  final VoidCallback onStamped;

  const _CuisineCard({
    required this.cuisine, required this.clicks,
    required this.isUnlocked, required this.isNew,
    required this.onStamped,
  });

  @override
  State<_CuisineCard> createState() => _CuisineCardState();
}

class _CuisineCardState extends State<_CuisineCard>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double>   _scale;
  late Animation<double>   _stampOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _scale = Tween(begin: 0.93, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _stampOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.4)),
    );
    if (widget.isUnlocked) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_CuisineCard old) {
    super.didUpdateWidget(old);
    if (widget.isNew && !old.isNew) _ctrl.forward(from: 0);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c      = widget.cuisine;
    final color  = c['color']  as Color;
    final light  = c['light']  as Color;
    final rarity = _rarity(c['id'] as String);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Transform.scale(
        scale: widget.isNew ? _scale.value : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isUnlocked ? light : const Color(0xFF161B27),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isUnlocked
                  ? color.withOpacity(0.4)
                  : Colors.white.withOpacity(0.06),
              width: widget.isUnlocked ? 1.5 : 1,
            ),
            boxShadow: widget.isUnlocked
                ? [BoxShadow(
                    color: color.withOpacity(0.18),
                    blurRadius: 10, offset: const Offset(0, 3))]
                : null,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: widget.isUnlocked
                            ? color.withOpacity(0.15)
                            : Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: widget.isUnlocked
                            ? Text(c['emoji'] as String,
                                style: const TextStyle(fontSize: 24))
                            : const Icon(Icons.lock_outline_rounded,
                                color: Colors.white24, size: 20),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(c['name'] as String,
                      textAlign: TextAlign.center, maxLines: 2,
                      style: TextStyle(
                        color: widget.isUnlocked
                            ? const Color(0xFF1A1A1A)
                            : Colors.white30,
                        fontSize: 11, fontWeight: FontWeight.w600,
                        height: 1.3,
                      )),
                    if (widget.isUnlocked && widget.clicks > 0) ...[
                      const SizedBox(height: 4),
                      Text('${widget.clicks}× visited',
                        style: TextStyle(
                          color: color, fontSize: 10,
                          fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
              if (rarity != 'COMMON')
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: _rarityColor(rarity).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(rarity[0],
                      style: TextStyle(
                        color: _rarityColor(rarity),
                        fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ),
              if (widget.isNew)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) => Opacity(
                      opacity: (1 - _stampOpacity.value).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Transform.scale(
                            scale: (2.0 - _scale.value).clamp(1.0, 2.0),
                            child: const Text('✅',
                                style: TextStyle(fontSize: 30)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1
      ..style       = PaintingStyle.stroke;
    for (var i = 0; i < 8; i++) {
      canvas.drawCircle(
          Offset(size.width * 0.15, size.height * 0.3), 40.0 + i * 26, paint);
    }
    for (var i = 0; i < 6; i++) {
      canvas.drawCircle(
          Offset(size.width * 0.9, size.height * 0.85), 30.0 + i * 20, paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}