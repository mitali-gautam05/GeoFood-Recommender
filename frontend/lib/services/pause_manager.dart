import 'dart:async';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PauseManager — ONE job: track whether notifications are paused,
// and auto-unpause after 60 minutes.
//
// WHY a separate class for this?
//   The pause logic has 3 pieces: a bool flag, a Timer, and a DateTime.
//   If you put these inside PlacesProvider, it becomes messy — the provider
//   already has 20+ fields. Separating it means:
//     - Easy to unit test pause logic independently
//     - Easy to change pause duration without touching the provider
//     - Clear mental model: "PauseManager handles pause, nothing else"
//
// This is called the Single Responsibility Principle — each class does
// exactly one thing. This is what separates junior from senior engineers.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class PauseManager {

  bool      _isPaused = false;
  Timer?    _timer;
  DateTime? _pausedAt;

  // ── Getters ────────────────────────────────────────────────────────────

  // PlacesProvider reads this before every notification attempt
  bool get isPaused => _isPaused;

  // UI can display "Resumes in 43 min" using this
  int get minutesRemaining {
    if (!_isPaused || _pausedAt == null) return 0;
    final elapsed = DateTime.now().difference(_pausedAt!).inMinutes;
    // .clamp(0, 60) prevents negative numbers if timer already fired
    return (60 - elapsed).clamp(0, 60);
  }

  // ── Callbacks ──────────────────────────────────────────────────────────
  // PlacesProvider sets this so it knows when the pause expires.
  // Pattern: callback instead of import so there's no circular dependency.

  void Function()? onResumed;

  // ── pause ──────────────────────────────────────────────────────────────
  // Call when user taps "Not hungry now".
  // Default duration is 60 minutes — matches your existing API behaviour.

  void pause({Duration duration = const Duration(minutes: 60)}) {
    _isPaused = true;
    _pausedAt = DateTime.now();

    // Cancel any previous timer before starting a new one.
    // This handles the case where user taps "Not hungry" multiple times:
    // the 60-min clock resets each time, not stacks.
    _timer?.cancel();

    _timer = Timer(duration, _resume);
  }

  // ── resume ─────────────────────────────────────────────────────────────
  // Call if user manually re-enables notifications from settings,
  // or when the 60-min timer fires automatically.

  void resume() {
    _timer?.cancel();
    _resume();
  }

  // Private — shared by both the timer callback and public resume()
  void _resume() {
    _isPaused = false;
    _pausedAt = null;
    _timer    = null;
    onResumed?.call(); // notify PlacesProvider so it can check for restaurants now
  }

  // ── dispose ────────────────────────────────────────────────────────────
  // IMPORTANT: always cancel the timer in dispose() or it will fire
  // AFTER the provider is destroyed → null pointer crash.

  void dispose() {
    _timer?.cancel();
  }
}