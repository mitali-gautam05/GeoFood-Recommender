// lib/screens/home/mood_screen.dart
// FIXES:
//   Line 145: PlacesProvider isn't a type
//   Reason: import was written as:
//     import package:frontend/lib/providers/places_provider.dart;
//   That is INVALID Dart syntax — missing quotes around the path.
//   Also the path itself was wrong (lib/ is not included in package imports).
//   Fix: replaced with correct relative import.
//   Also removed: import 'dart:math' — was imported but never used.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/places_provider.dart'; // ← FIXED (was broken syntax)

// ── Mood data ─────────────────────────────────────────────────
const List<Map<String, dynamic>> kMoods = [
  {
    'id':       'celebrating',
    'label':    'Celebrating 🎉',
    'subtitle': 'Something great happened!',
    'cuisines': 'Biryani • Kebab • Fine Dining',
    'gradient': [Color(0xFFFF6B35), Color(0xFFFF8E53)],
    'emoji':    '🎉',
    'bg':       Color(0xFF1A0F00),
  },
  {
    'id':       'comfort',
    'label':    'Need Comfort 🤗',
    'subtitle': 'Rough day, need a hug',
    'cuisines': 'Dal Rice • Khichdi • Soup',
    'gradient': [Color(0xFF4CAF50), Color(0xFF81C784)],
    'emoji':    '🤗',
    'bg':       Color(0xFF001A00),
  },
  {
    'id':       'adventurous',
    'label':    'Adventurous 🌍',
    'subtitle': 'Try something new!',
    'cuisines': 'Thai • Korean • Ethiopian',
    'gradient': [Color(0xFF9C27B0), Color(0xFFCE93D8)],
    'emoji':    '🌍',
    'bg':       Color(0xFF0F001A),
  },
  {
    'id':       'date',
    'label':    'Date Night 💕',
    'subtitle': 'Make it special',
    'cuisines': 'Italian • Continental • Rooftop',
    'gradient': [Color(0xFFE91E63), Color(0xFFF48FB1)],
    'emoji':    '💕',
    'bg':       Color(0xFF1A0010),
  },
  {
    'id':       'tired',
    'label':    'Tired & Lazy 😴',
    'subtitle': 'Quick and easy',
    'cuisines': 'Street Food • Fast Food • Thali',
    'gradient': [Color(0xFF607D8B), Color(0xFF90A4AE)],
    'emoji':    '😴',
    'bg':       Color(0xFF0A0E12),
  },
  {
    'id':       'spicy',
    'label':    'Spicy Mood 🌶️',
    'subtitle': 'Bring the heat!',
    'cuisines': 'Chettinad • Andhra • Schezwan',
    'gradient': [Color(0xFFE74C3C), Color(0xFFFF7043)],
    'emoji':    '🌶️',
    'bg':       Color(0xFF1A0000),
  },
  {
    'id':       'healthy',
    'label':    'Feeling Healthy 🥗',
    'subtitle': 'Light and nutritious',
    'cuisines': 'Salad • Smoothies • Grain bowls',
    'gradient': [Color(0xFF8BC34A), Color(0xFFAED581)],
    'emoji':    '🥗',
    'bg':       Color(0xFF0A1500),
  },
  {
    'id':       'sweet',
    'label':    'Sweet Craving 🍮',
    'subtitle': 'Dessert time!',
    'cuisines': 'Mithai • Cake • Ice Cream',
    'gradient': [Color(0xFFFF69B4), Color(0xFFFFB3D9)],
    'emoji':    '🍮',
    'bg':       Color(0xFF1A0015),
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

    // FIX line 145: PlacesProvider now found via correct import above
    final provider = context.read<PlacesProvider>();
    await provider.fetchRecommendationsWithMood(
      username: provider.userName,
      mood:     id,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
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
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                    padding:     EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Spacer(),
                  const Text('MOOD SELECTOR',
                    style: TextStyle(
                      color: Colors.white30, fontSize: 11,
                      letterSpacing: 3, fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Heading
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 6),
              child: Text(
                'How are you\nfeeling right now?',
                style: TextStyle(
                  color: Colors.white, fontSize: 28,
                  fontWeight: FontWeight.w800, height: 1.2,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                "We'll find food that matches your vibe",
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),

            // Mood grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:   2,
                  childAspectRatio: 7,
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
                child: const Center(
                  child: Text(
                    'Skip — just show me restaurants',
                    style: TextStyle(
                      color: Colors.white30, fontSize: 13,
                      decoration:      TextDecoration.underline,
                      decorationColor: Colors.white30,
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
    final colors   = widget.mood['gradient'] as List<Color>;
    final isActive = widget.isActive;

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
              gradient: isActive
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                      colors: colors,
                    )
                  : LinearGradient(
                      colors: [
                        colors[0].withOpacity(0.12),
                        colors[1].withOpacity(0.06),
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
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white70,
                          fontSize: 13, fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.mood['cuisines'] as String,
                        style: TextStyle(
                          color: isActive
                              ? Colors.white70
                              : Colors.white.withOpacity(0.3),
                          fontSize: 10,
                        ),
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