import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// NotificationService — ONE job: show and manage push notifications.
//
// Uses the Singleton pattern because flutter_local_notifications requires
// exactly one plugin instance across the entire app lifetime.
// If you created two instances, Android would register two channels and
// you'd get duplicate notifications.
//
// HOW SINGLETONS WORK IN DART:
//   The first time someone writes NotificationService(), Dart runs _internal()
//   and stores the result in _instance. Every call after that returns the
//   SAME object — never creates a new one. So it's always one instance.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();

  // Fixed notification ID for restaurant alerts.
  // Showing the same ID again REPLACES the old notification — not stacks it.
  // This means user always sees only the latest restaurant, not 50 old ones.
  static const int _restaurantId = 42;

  // ── Callbacks ──────────────────────────────────────────────────────────
  // PlacesProvider sets these after construction so that when a notification
  // action is tapped, the provider can react (pause, navigate).
  // This pattern avoids circular imports between NotificationService and
  // PlacesProvider — neither imports the other.

  void Function()?        onNotHungryTapped;
  void Function(String?)? onViewRestaurantTapped;

  // ── init ───────────────────────────────────────────────────────────────
  // Call once in main() BEFORE runApp().
  // This registers the notification channel with Android so notifications
  // can appear. If you skip this, no notifications will ever show.

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',  // app icon shown in notification bar
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,   // show the iOS "allow notifications?" popup
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      // This callback fires when the user taps the notification (or its buttons)
      // while the app is already open (foreground).
      onDidReceiveNotificationResponse: _handleTap,
    );
  }

  // ── showRestaurantNotification ─────────────────────────────────────────
  // The main method PlacesProvider calls whenever it finds a nearby restaurant.

  Future<void> showRestaurantNotification({
    required String restaurantName,
    required double distanceKm,
    required String cuisine,
    required String restaurantId,
  }) async {
    // Format "1.2km away" or "450m away" depending on distance
    final distanceText = distanceKm < 1
        ? '${(distanceKm * 1000).round()}m away'
        : '${distanceKm.toStringAsFixed(1)}km away';

    final androidDetails = AndroidNotificationDetails(
      'restaurant_nearby',          // channel ID — must be unique per notification type
      'Nearby Restaurants',         // channel name (shown in Android Settings)
      channelDescription: 'Alerts you when a great restaurant is close by',
      importance: Importance.high,  // HIGH = pops up on screen (heads-up notification)
      priority:   Priority.high,    // needed alongside importance for heads-up
      playSound:  true,
      // Action buttons that appear inside the notification without opening the app
      actions: const [
        AndroidNotificationAction(
          'not_hungry',           // action ID — checked in _handleTap
          'Not hungry now',       // button label user sees
          cancelNotification: true, // tapping this auto-dismisses the notification
        ),
        AndroidNotificationAction(
          'view_restaurant',
          'Show me',
          cancelNotification: true,
        ),
      ],
    );

    await _plugin.show(
      _restaurantId,                  // same ID every time = replaces old notif
      restaurantName,                 // big bold title: "Chirag Biryani Hub"
      '$cuisine · $distanceText',    // subtitle: "North Indian · 1.2km away"
      NotificationDetails(android: androidDetails),
      payload: restaurantId,          // passed to _handleTap so we know WHICH restaurant
    );
  }

  // ── cancelRestaurantNotification ────────────────────────────────────────
  // Call this when user opens the RestaurantDetailPage so the notification
  // doesn't linger in the tray after they've already seen the restaurant.

  Future<void> cancelRestaurantNotification() async {
    await _plugin.cancel(_restaurantId);
  }

  // ── _handleTap ─────────────────────────────────────────────────────────
  // Private — fires automatically when notification or action button is tapped.
  // Routes to the correct callback based on which button was pressed.

  void _handleTap(NotificationResponse response) {
    final action       = response.actionId;   // 'not_hungry' | 'view_restaurant' | null
    final restaurantId = response.payload;    // what we passed as restaurantId above

    if (action == 'not_hungry') {
      onNotHungryTapped?.call();
    } else {
      // Either "Show me" button OR user tapped the notification body itself
      onViewRestaurantTapped?.call(restaurantId);
    }
  }
}