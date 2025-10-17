# qibla_compass

A simple, accurate, and beautiful **Qibla compass** for Flutter (iOS/Android/Web) with:

- Kaaba image in the center and an arrow that points to Qibla
- Optional **map-based fallback** (OpenStreetMap via `flutter_map`)
- **Calibration helper** screen

## Install

```yaml
dependencies:
  qibla_compass: ^0.1.0
```

## Quick start
```dart
import 'package:qibla_compass/qibla_compass.dart';

QiblaCompass(
  size: 320,
  // magneticDeclinationDeg: +2.0, // optional correction
)
```

### Map fallback:

```dart
QiblaMapFallback(latitude: 25.2048, longitude: 55.2708);
```

### Calibration helper:

```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const QiblaCalibrationHelper(),
));
```

### Permissions
- Android: ACCESS_FINE_LOCATION
- iOS: NSLocationWhenInUseUsageDescription
- Web: iOS Safari needs a user gesture to enable motion sensors; the widget shows a prompt.

### Why magnetic declination?

Phone compasses report magnetic heading. We compute true Qibla bearing. For perfect alignment, supply local declination (±°). You can hardcode by city or integrate a geomagnetic model later.
