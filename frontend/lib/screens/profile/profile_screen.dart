// lib/screens/profile/profile_screen.dart
// Phase 4 fix:
//   _signOut now calls ApiClient.clearToken() so the JWT is removed
//   from SharedPrefs on logout. Without this, SplashScreen's token check
//   would log the user back in automatically after signing out.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/places_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../widgets/city_autocomplete_field.dart';
import '../../services/api_client.dart';   // ← Phase 4: needed for clearToken()

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _resetPreferences(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset preferences?'),
        content: const Text(
            'This clears your click history. Name and city stay the same.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<PlacesProvider>().resetClickHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences reset!')),
        );
      }
    }
  }

  void _showChangeCitySheet(BuildContext context, PlacesProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change city', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            CityAutocompleteField(
              initialValue: provider.currentCity,
              decoration: InputDecoration(
                hintText: 'Search for a city…',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onCitySelected: (city) async {
                Navigator.pop(ctx);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_city', city);
                if (context.mounted) {
                  context.read<PlacesProvider>().setCity(city);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text("You'll go back to the login screen."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      // 1. Clear JWT token — Phase 4 fix
      //    Without this SplashScreen re-logs the user in automatically
      await ApiClient.clearToken();

      // 2. Clear all SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!context.mounted) return;

      // 3. Reset PlacesProvider in-memory state
      context.read<PlacesProvider>().setUser(name: '', city: '');

      // 4. Reset GamificationProvider in-memory state
      await context.read<GamificationProvider>().init();

      if (!context.mounted) return;

      // 5. Clear nav stack — Back button can't return to dashboard
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider    = context.watch<PlacesProvider>();
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    provider.userName.isNotEmpty
                        ? provider.userName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize:   36,
                      fontWeight: FontWeight.w700,
                      color:      colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  provider.userName.isEmpty ? 'Guest' : provider.userName,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          _InfoCard(
            icon:  Icons.location_city_outlined,
            label: 'City',
            value: provider.currentCity.isEmpty ? '—' : provider.currentCity,
            trailing: TextButton(
              onPressed: () => _showChangeCitySheet(context, provider),
              child: const Text('Change'),
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon:  Icons.touch_app_outlined,
            label: 'Places tapped',
            value: '${provider.clickCount}',
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon:  Icons.psychology_outlined,
            label: 'ML signals active',
            value: provider.clickCount >= 5
                ? 'Personalisation on 🟢'
                : 'Needs ${5 - provider.clickCount} more taps',
          ),

          const SizedBox(height: 36),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding:         const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon:     const Icon(Icons.refresh),
            label:    const Text('Reset click preferences'),
            onPressed: () => _resetPreferences(context),
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: () => _signOut(context),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Widget?  trailing;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.5))),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}