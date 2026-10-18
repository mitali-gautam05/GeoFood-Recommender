// lib/screens/home/mood_screen.dart
// THEME FIX:
//   Previously this screen used hardcoded colors (Color(0xFF0D1117),
//   Colors.white/white54/white38/white30/white70) — so it ALWAYS rendered
//   dark regardless of the app's light/dark theme toggle.
//   Fix: replaced every hardcoded color with Theme.of(context).colorScheme
//   values, so this screen now follows ThemeProvider like the rest of the app.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/places_provider.dart';

// ── Mood data ─────────────────────────────────────────────────
const List<Map<String, dynamic>> kMoods = [
  {
    'id':       'celebrating',
    'label':    'Celebrating 🎉',
    'subtitle': 'Something great happened!',
    'cuisines': 'Biryani • Kebab • Fine Dining',
    'gradient': [Color(0xFFFF6B35), Color(0xFFFF8E53)],
    'emoji':    '🎉',
  },
  {
    'id':       'comfort',
    'label':    'Need Comfort 🤗',
    'subtitle': 'Rough day, need a hug',
    'cuisines': 'Dal Rice • Khichdi • Soup',
    'gradient': [Color(0xFF4CAF50), Color(0xFF81C784)],
    'emoji':    '🤗',
  },
  {
    'id':       'adventurous',
    'label':    'Adventurous 🌍',
    'subtitle': 'Try something new!',
    'cuisines': 'Thai • Korean • Ethiopian',
    'gradient': [Color(0xFF9C27B0), Color(0xFFCE93D8)],
    'emoji':    '🌍',
  },
  {
    'id':       'date',
    'label':    'Date Night 💕',
    'subtitle': 'Make it special',
    'cuisines': 'Italian • Continental • Rooftop',
    'gradient': [Color(0xFFE91E63), Color(0xFFF48FB1)],
    'emoji':    '💕',
  },
  {
    'id':       'tired',
    'label':    'Tired & Lazy 😴',
    'subtitle': 'Quick and easy',
    'cuisines': 'Street Food • Fast Food • Thali',
    'gradient': [Color(0xFF607D8B), Color(0xFF90A4AE)],
    'emoji':    '😴',
  },
  {
    'id':       'spicy',
    'label':    'Spicy Mood 🌶️',
    'subtitle': 'Bring the heat!',
    'cuisines': 'Chettinad • Andhra • Schezwan',
    'gradient': [Color(0xFFE74C3C), Color(0xFFFF7043)],
    'emoji':    '🌶️',
  },
  {
    'id':       'healthy',
    'label':    'Feeling Healthy 🥗',
    'subtitle': 'Light and nutritious',
    'cuisines': 'Salad • Smoothies • Grain bowls',
    'gradient': [Color(0xFF8BC34A), Color(0xFFAED581)],
    'emoji':    '🥗',
  },
  {
    'id':       'sweet',
    'label':    'Sweet Craving 🍮',
    'subtitle': 'Dessert time!',
    'cuisines': 'Mithai • Cake • Ice Cream',
    'gradient': [Color(0xFFFF69B4), Color(0xFFFFB3D9)],
    'emoji':    '🍮',
  },
];

// ════════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════════
class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen>
    with TickerProviderStateMixin {

  String? _selected;
  late List<AnimationController> _cardControllers;
  late List<Animation<double>>   _cardAnims;

  @override
  void initState() {
    super.initState();
    _cardControllers = List.generate(
      kMoods.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _cardAnims = _cardControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOutCubic))
        .toList();

    for (var i = 0; i < kMoods.length; i++) {
      Future.delayed(Duration(milliseconds: 80 * i), () {
        if (mounted) _cardControllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _cardControllers) { c.dispose(); }
    super.dispose();
  }

  void _onMoodSelected(String id) async {
    setState(() => _selected = id);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final provider = context.read<PlacesProvider>();
    await provider.fetchRecommendationsWithMood(
      username: provider.userName,
      mood:     id,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // ── Pull colors from the active theme instead of hardcoding them ──
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: scheme.onSurface.withOpacity(0.54)),
                    onPressed: () => Navigator.pop(context),
                    padding:     EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Spacer(),
                  Text('MOOD SELECTOR',
                    style: TextStyle(
                      color: scheme.onSurface.withOpacity(0.3),
                      fontSize: 11,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Heading
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
              child: Text(
                'How are you\nfeeling right now?',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                "We'll find food that matches your vibe",
                style: TextStyle(
                  color: scheme.onSurface.withOpacity(0.38),
                  fontSize: 14,
                ),
              ),
            ),

            // Mood grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:   2,
                  // was 7 — too flat for 2 lines of text + emoji, caused
                  // a few px of bottom overflow once the real (Nunito)
                  // font metrics applied. 5.4 gives enough breathing room.
                  childAspectRatio: 5.4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing:  12,
                ),
                itemCount:    kMoods.length,
                itemBuilder:  (context, i) {
                  final mood     = kMoods[i];
                  final isActive = _selected == mood['id'];
                  return AnimatedBuilder(
                    animation: _cardAnims[i],
                    builder: (context, _) => Transform.translate(
                      offset: Offset(0, 30 * (1 - _cardAnims[i].value)),
                      child: Opacity(
                        opacity: _cardAnims[i].value,
                        child: _MoodCard(
                          mood:     mood,
                          isActive: isActive,
                          onTap:    () => _onMoodSelected(mood['id'] as String),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Skip
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Center(
                  child: Text(
                    'Skip — just show me restaurants',
                    style: TextStyle(
                      color: scheme.onSurface.withOpacity(0.3),
                      fontSize: 13,
                      decoration:      TextDecoration.underline,
                      decorationColor: scheme.onSurface.withOpacity(0.3),
                    ),
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

// ── Mood card ─────────────────────────────────────────────────
class _MoodCard extends StatefulWidget {
  final Map<String, dynamic> mood;
  final bool         isActive;
  final VoidCallback onTap;
  const _MoodCard({
    required this.mood,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_MoodCard> createState() => _MoodCardState();
}

class _MoodCardState extends State<_MoodCard>
    with SingleTickerProviderStateMixin {

  late AnimationController _pressCtrl;
  late Animation<double>   _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pressAnim = Tween(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final scheme   = Theme.of(context).colorScheme;
    final colors   = widget.mood['gradient'] as List<Color>;
    final isActive = widget.isActive;

    // Text/label colors now derive from the theme instead of a fixed
    // white/white70 — so they stay readable in BOTH light and dark mode.
    final labelColor = isActive
        ? Colors.white // active card always has a saturated gradient bg
        : scheme.onSurface.withOpacity(0.85);
    final subLabelColor = isActive
        ? Colors.white70
        : scheme.onSurface.withOpacity(0.5);

    return GestureDetector(
      onTapDown:   (_) => _pressCtrl.forward(),
      onTapUp:     (_) { _pressCtrl.reverse(); widget.onTap(); },
      onTapCancel: ()  => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _pressAnim,
        builder: (context, _) => Transform.scale(
          scale: _pressAnim.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              // Inactive card: theme surface tinted with the mood's accent
              // color, instead of always compositing over a black page.
              color: isActive ? null : scheme.surfaceContainerHighest.withOpacity(0.4),
              gradient: isActive
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                      colors: colors,
                    )
                  : LinearGradient(
                      colors: [
                        colors[0].withOpacity(0.14),
                        colors[1].withOpacity(0.07),
                      ],
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isActive ? colors[0] : colors[0].withOpacity(0.3),
                width: isActive ? 2 : 1,
              ),
              boxShadow: isActive
                  ? [BoxShadow(
                      color:      colors[0].withOpacity(0.35),
                      blurRadius: 20,
                      offset:     const Offset(0, 6),
                    )]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:  MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.mood['emoji'] as String,
                      style: const TextStyle(fontSize: 26)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.mood['label'] as String,
                        // explicit `height` pins the line-height so it
                        // doesn't shift a few px once Nunito (vs the
                        // fallback font) actually loads and applies.
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.mood['cuisines'] as String,
                        style: TextStyle(
                          color: subLabelColor,
                          fontSize: 10,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}