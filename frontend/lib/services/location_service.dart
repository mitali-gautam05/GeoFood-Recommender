import 'dart:async';
import 'package:geolocator/geolocator.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LocationService — ONE job: give a real-time GPS stream to anyone who needs it.
//
// WHY a separate class?
//   PlacesProvider already had fetchUserLocation() for a one-time GPS check.
//   That method is still there and still works for the initial API call.
//   THIS class handles the continuous background stream — a totally different
//   concern. Keeping them separate means: if geolocator ever gets replaced,
//   you change this one file, not 3 files.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class LocationService {

  // StreamController is like a pipe.
  // We push Position objects into one end (_controller.add),
  // and PlacesProvider listens at the other end (positionStream.listen).
  // ".broadcast()" = multiple listeners allowed simultaneously.
  final _controller = StreamController<Position>.broadcast();

  // Public stream — PlacesProvider subscribes to this
  Stream<Position> get positionStream => _controller.stream;

  // We store the geolocator subscription so we can cancel it in dispose()
  StreamSubscription<Position>? _sub;

  // ── startTracking ──────────────────────────────────────────────────────
  // Call this once from PlacesProvider.initLocationTracking()
  // It handles all permission logic internally so the provider doesn't
  // need to know anything about geolocator.

  Future<void> startTracking() async {
    // Step 1: Is GPS hardware turned on at all?
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return; // GPS off — silently stop, no crash

    // Step 2: Does the app have permission to use GPS?
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      // Not asked yet — show the system dialog now
      perm = await Geolocator.requestPermission();
    }
    // If user said "never ask again" or still denied, stop silently
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;

    // Step 3: Create the stream settings.
    // distanceFilter: 500 means geolocator will ONLY fire a new position
    // if the user has physically moved at least 500 metres since the last one.
    // This is the key battery-saving setting. Without it, you'd get
    // updates every second and drain the battery in hours.
    const settings = LocationSettings(
      accuracy:       LocationAccuracy.high,  // best GPS fix
      distanceFilter: 500,                    // metres — change to 200 for denser cities
    );

    // Step 4: Subscribe to geolocator and forward every position into our stream
    _sub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (pos)  => _controller.add(pos),  // forward position to our listeners
          onError: (_)  => {},             // swallow errors — never crash background
        );
  }

  // ── stopTracking ───────────────────────────────────────────────────────
  // Call this when user signs out or turns off notifications in settings

  void stopTracking() {
    _sub?.cancel();
    _sub = null;
  }

  // ── distanceKm ─────────────────────────────────────────────────────────
  // Static helper: calculate distance in km between two GPS points.
  // "static" means you call it without creating a LocationService instance:
  //   LocationService.distanceKm(lat1, lng1, lat2, lng2)
  //
  // This is the same haversine formula your backend uses in recommender.py,
  // but now available in Flutter so we can show "1.2km away" in the banner.

  static double distanceKm(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    // Geolocator.distanceBetween returns metres — divide by 1000 for km
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  // ── dispose ────────────────────────────────────────────────────────────
  // Always call this in PlacesProvider.dispose() to prevent memory leaks.
  // A memory leak here = GPS keeps running even after app closes = battery drain.

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}