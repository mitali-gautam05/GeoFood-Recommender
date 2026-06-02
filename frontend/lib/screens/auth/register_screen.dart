// lib/screens/auth/register_screen.dart
// Phase 4: no UI changes — city was already collected and passed to
// ApiClient.register(). Now that ApiClient.register() accepts city
// and sends it to the backend, User.city is saved on registration.
// register_screen.dart is IDENTICAL to Phase 2 — nothing to change here.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/places_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../services/api_client.dart';
import '../../widgets/city_autocomplete_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl    = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _cityCtrl     = TextEditingController();

  String  _selectedCity = '';
  bool    _loading      = false;
  bool    _obscure      = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email    = _emailCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final city     = _selectedCity.isNotEmpty
        ? _selectedCity
        : _cityCtrl.text.trim();

    if (email.isEmpty || username.isEmpty ||
        password.isEmpty || city.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    if (username.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // 1. Register — city now persisted to backend User.city
      await ApiClient.register(
        email:    email,
        username: username,
        password: password,
        city:     city,     // ← sent to backend, stored in User.city
      );

      // 2. Auto-login — stores token in SharedPrefs
      await ApiClient.login(email: email, password: password);

      // 3. Persist profile locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', username);
      await prefs.setString('user_city', city);
      await prefs.setBool('onboarding_done', true);
      await ApiClient.saveUsername(username);

      if (!mounted) return;

      // 4. Wire providers
      final places = context.read<PlacesProvider>();
      places.setUser(name: username, city: city);
      places.setGamificationProvider(context.read<GamificationProvider>());

      // 5. GPS
      await places.fetchUserLocation();
      places.initLocationTracking();

      if (!mounted) return;

      // 6. Navigate — clear entire stack
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);

    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() {
        _error   = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title:           const Text('Create account'),
        backgroundColor: Colors.transparent,
        elevation:       0,
        foregroundColor: colorScheme.onSurface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Join GeoTaste',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                )),
              const SizedBox(height: 6),
              Text('Create your food explorer profile.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                )),

              const SizedBox(height: 32),

              // Error banner
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color:        colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!,
                    style: TextStyle(color: colorScheme.onErrorContainer)),
                ),
                const SizedBox(height: 20),
              ],

              // Email
              Text('Email', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller:   _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect:  false,
                decoration: InputDecoration(
                  hintText:   'you@example.com',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 20),

              // Username
              Text('Username', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller:  _usernameCtrl,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText:   'e.g. arjun_eats',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 20),

              // Password
              Text('Password', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller:  _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText:   'Min 6 characters',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 20),

              // City
              Text('Your city', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              CityAutocompleteField(
                hintText:   'e.g. Bhopal',
                controller: _cityCtrl,
                decoration: InputDecoration(
                  hintText:   'e.g. Bhopal',
                  prefixIcon: const Icon(
                      Icons.location_city_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onCitySelected: (city) =>
                    setState(() => _selectedCity = city),
              ),

              const SizedBox(height: 40),

              // Register button
              SizedBox(
                width:  double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create account',
                          style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 20),

              // Back to login
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Already have an account? ',
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.6))),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text('Sign in',
                        style: TextStyle(
                          color:      colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        )),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}