/// Guards against a double-tap firing the same action twice in one gesture.
///
/// Found via a real crash: tapping a nav row twice before its push animation
/// starts sends the same route to GoRouter twice, which throws
/// (`!keyReservation.contains(key)` in `navigator.dart`) because both pushes
/// resolve to the same page key. A single app-wide cooldown, applied once in
/// [NexusCard], [NexusListRow], and [NexusButton], covers every tap-driven
/// navigation without editing each call site.
class TapDebounce {
  TapDebounce._();

  static DateTime? _lastTap;
  static const _cooldown = Duration(milliseconds: 500);

  static bool ready() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _cooldown) {
      return false;
    }
    _lastTap = now;
    return true;
  }
}
