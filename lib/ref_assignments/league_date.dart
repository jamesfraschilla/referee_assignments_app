import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const int _leagueDayCutoffHour = 3;

bool _tzInitialized = false;
tz.Location? _easternLocation;

DateTime currentLeagueDate() {
  try {
    _ensureTimezoneInitialized();
    final location = _easternLocation ??= tz.getLocation('America/New_York');
    var easternNow = tz.TZDateTime.now(location);
    if (easternNow.hour < _leagueDayCutoffHour) {
      easternNow = easternNow.subtract(const Duration(days: 1));
    }
    return DateTime(easternNow.year, easternNow.month, easternNow.day);
  } catch (e) {
    debugPrint('Failed to compute league date: $e');
    final fallbackNow = DateTime.now();
    final adjustedNow = fallbackNow.hour < _leagueDayCutoffHour
        ? fallbackNow.subtract(const Duration(days: 1))
        : fallbackNow;
    return DateTime(adjustedNow.year, adjustedNow.month, adjustedNow.day);
  }
}

void _ensureTimezoneInitialized() {
  if (_tzInitialized) return;
  try {
    tz.initializeTimeZones();
  } catch (_) {
    // Ignore duplicate initialization; fallback remains available.
  } finally {
    _tzInitialized = true;
  }
}
