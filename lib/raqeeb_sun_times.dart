import 'dart:math' as math;

/// Computes approximate solar sunrise/sunset using date + coordinates.
/// No network request or pre-entered seasonal tables are needed.
class RaqeebSunTimes {
  static const double _zenith = 90.833;

  static double _rad(double degrees) => degrees * math.pi / 180;
  static double _deg(double radians) => radians * 180 / math.pi;

  static ({DateTime sunrise, DateTime sunset}) forDate(
    DateTime date, {
    required double latitude,
    required double longitude,
  }) {
    final yearStart = DateTime.utc(date.year, 1, 1);
    final day = DateTime.utc(date.year, date.month, date.day)
            .difference(yearStart).inDays + 1;

    DateTime event(bool sunrise) {
      final longHour = longitude / 15;
      final t = day + ((sunrise ? 6 : 18) - longHour) / 24;
      final anomaly = 0.9856 * t - 3.289;
      final solarLong = (anomaly +
              1.916 * math.sin(_rad(anomaly)) +
              0.020 * math.sin(2 * _rad(anomaly)) +
              282.634) % 360;
      var ascension = (_deg(math.atan(0.91764 * math.tan(_rad(solarLong)))) + 360) % 360;
      ascension = (ascension +
              (solarLong / 90).floor() * 90 -
              (ascension / 90).floor() * 90) / 15;
      final sinDecl = 0.39782 * math.sin(_rad(solarLong));
      final cosDecl = math.cos(math.asin(sinDecl));
      final cosHour = (math.cos(_rad(_zenith)) -
              sinDecl * math.sin(_rad(latitude))) /
          (cosDecl * math.cos(_rad(latitude)));

      // In polar regions sunrise/sunset may not occur on some dates.
      // Caller can fall back to device theme if desired.
      if (cosHour < -1 || cosHour > 1) {
        throw StateError('No sunrise/sunset on this date at this location');
      }
      final hour = sunrise
          ? (360 - _deg(math.acos(cosHour))) / 15
          : _deg(math.acos(cosHour)) / 15;
      final localMean = hour + ascension - (0.06571 * t) - 6.622;
      final utcHours = (localMean - longHour + 24) % 24;
      return DateTime.utc(date.year, date.month, date.day)
          .add(Duration(milliseconds: (utcHours * 3600000).round()))
          .toLocal();
    }

    return (sunrise: event(true), sunset: event(false));
  }

  static bool isNight(DateTime now, {
    required double latitude,
    required double longitude,
  }) {
    final times = forDate(now, latitude: latitude, longitude: longitude);
    return now.isBefore(times.sunrise) || !now.isBefore(times.sunset);
  }
}
