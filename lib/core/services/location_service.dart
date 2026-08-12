import 'package:geolocator/geolocator.dart';

/// A single location fix, plus whether the platform believes it was faked.
///
/// [isMocked] comes straight from Android's `Position.isMocked` (set when the
/// fix came from a mock-location provider — i.e. a GPS spoofing app). It is
/// reported to the server rather than acted on locally, because a modified
/// client could always lie; the server decides what to do with it.
typedef GeoFix = ({double lat, double lng, bool isMocked});

/// Thin wrapper over geolocator for the attendance geo-fence.
///
/// The fence only needs "roughly where is this phone" — a single fix with a
/// short staleness window is plenty. Returns null on any failure (permission
/// denied, sensors off, timeout) so callers can degrade instead of crash.
class LocationService {
  static const _timeout = Duration(seconds: 10);

  static Future<bool> hasPermission() async {
    return Geolocator.isLocationServiceEnabled().then(
      (enabled) async => enabled && await Geolocator.checkPermission() != LocationPermission.denied,
    );
  }

  /// Ensures permission is granted, then returns the best fix we can get in
  /// [_timeout]. Null when the user denied permission or the device can't
  /// produce a fix.
  static Future<GeoFix?> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _timeout,
        ),
      );
      if (pos.latitude == 0 && pos.longitude == 0) return null;
      return (lat: pos.latitude, lng: pos.longitude, isMocked: pos.isMocked);
    } catch (_) {
      return null;
    }
  }
}
