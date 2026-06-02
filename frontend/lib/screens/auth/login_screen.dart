// lib/screens/auth/login_screen.dart
// Hotfix: city now read from /me response (Phase 4 User.city column).
// Was hardcoded to 'delhi' — now uses server value, falls back to
// local SharedPrefs city, then 'delhi' only as last resort.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/places_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../services/api_client.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool    _loading = false;
  bool    _obscure = true;
  String? _error;

  static String get _baseUrl => kIsWeb
      ? 'http://localhost:8000/api/v1'
      : 'http://10.0.2.2:8000/api/v1';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email and password');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // 1. Login — ApiClient stores token in SharedPrefs
      await ApiClient.login(email: email, password: password);

      // 2. Fetch profile from /me
      final token    = await ApiClient.getToken();
      final prefs    = await SharedPreferences.getInstance();

      // Fallbacks: use existing saved city if available, else 'delhi'
      String username = email.split('@').first;
      String city     = prefs.getString('user_city') ?? 'delhi';

      if (token != null) {
        try {
          final meRes = await http.get(
            Uri.parse('$_baseUrl/auth/me'),
            headers: {'Authorization': 'Bearer $token'},
          ).timeout(const Duration(seconds: 8));

          if (meRes.statusCode == 200) {
            final me = jsonDecode(meRes.body) as Map<String, dynamic>;
            // Read username from server
            username = me['username'] as String? ?? username;
            // Read city from server — Phase 4 fix (was hardcoded 'delhi')
            final serverCity = me['city'] as String? ?? '';
            if (serverCity.isNotEmpty) city = serverCity;
          }
        } catch (_) {
          // Network issue — proceed with fallback values
        }
      }

      // 3. Persist to SharedPrefs
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

      // 6. Navigate — removes login from back stack
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              Text('GeoTaste',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                )),
              const SizedBox(height: 6),
              Text('Discover restaurants made for you.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                )),

              const SizedBox(height: 48),

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

              Text('Password', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller:  _passwordCtrl,
                obscureText: _obscure,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText:   '••••••••',
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

              const SizedBox(height: 40),

              SizedBox(
                width:  double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Sign in',
                          style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Don't have an account? ",
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.6))),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      ),
                      child: Text('Register',
                        style: TextStyle(
                          color:      colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        )),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}