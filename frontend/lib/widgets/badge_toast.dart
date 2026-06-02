// lib/widgets/badge_toast.dart
//
// Usage — wrap any screen's build() with BadgeToastListener:
//
//   return BadgeToastListener(
//     child: Scaffold(...),
//   );
//
// It watches GamificationProvider.lastUnlockedBadgeId and shows a SnackBar
// automatically whenever a new badge unlocks.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gamification_provider.dart';
import '../models/badge_definitions.dart';

class BadgeToastListener extends StatefulWidget {
  final Widget child;
  const BadgeToastListener({super.key, required this.child});

  @override
  State<BadgeToastListener> createState() => _BadgeToastListenerState();
}

class _BadgeToastListenerState extends State<BadgeToastListener> {
  String? _lastShownId;

  @override
  Widget build(BuildContext context) {
    // Listen without rebuilding the whole tree
    return Consumer<GamificationProvider>(
      builder: (context, gami, child) {
        final newId = gami.lastUnlockedBadgeId;
        if (newId != null && newId != _lastShownId) {
          _lastShownId = newId;
          // Schedule after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showBadgeSnackBar(context, newId, gami);
          });
        }
        return child!;
      },
      child: widget.child,
    );
  }

  void _showBadgeSnackBar(
    BuildContext context,
    String badgeId,
    GamificationProvider gami,
  ) {
    final badge = kBadgeById[badgeId];
    if (badge == null) return;
    gami.clearLastUnlockedBadge();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Badge unlocked!',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    badge.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    badge.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}