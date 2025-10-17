import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

const _kaabaLat = 21.422487;
const _kaabaLon = 39.826206;

class QiblaDirection {
  static double computeBearing(double fromLat, double fromLon) {
    final lat1 = _deg2rad(fromLat);
    final lng1 = _deg2rad(fromLon);
    final lat2 = _deg2rad(_kaabaLat);
    final lng2 = _deg2rad(_kaabaLon);

    final d = lng2 - lng1;
    final y = math.sin(d) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
    math.sin(lat1) * math.cos(lat2) * math.cos(d);
    var d1 = math.atan2(y, x);
    return (_rad2deg(d1) + 360.0) % 360.0;
  }

  static double _deg2rad(double d) => d * math.pi / 180.0;
  static double _rad2deg(double r) => r * 180.0 / math.pi;
}

/// High-level widget that:
/// - Requests location permission & reads current position
/// - Reads device heading (compass). On web, asks for sensor permission on user gesture
/// - Renders a circular compass with Kaaba in the center and an arrow pointing to Qibla
class QiblaCompass extends StatefulWidget {
  const QiblaCompass({
    super.key,
    this.size = 280,
    this.kaabaImage,
    this.kaabaSize = 48,
    this.strokeColor,
    this.tickColor,
    this.arrowColor,
    this.textStyle,
    this.background,
    this.showCard = true,
    this.onLocateError,
    this.allowManualLocation = true,
    this.manualLatitude,
    this.manualLongitude,
    this.magneticDeclinationDeg,
    this.webSensorPromptBuilder,
  });

  /// Diameter of the compass canvas.
  final double size;

  /// Optional custom Kaaba image; otherwise uses assets/kaaba.png
  final ImageProvider? kaabaImage;
  final double kaabaSize;

  /// Styling
  final Color? strokeColor;
  final Color? tickColor;
  final Color? arrowColor;
  final TextStyle? textStyle;
  final Color? background;
  final bool showCard;

  /// Called when location request fails.
  final void Function(Object error)? onLocateError;

  /// If location permission denied, allow passing a manual lat/lon.
  final bool allowManualLocation;
  final double? manualLatitude;
  final double? manualLongitude;

  /// If you want to correct magnetic heading to true north, supply declination in degrees (+E, -W).
  final double? magneticDeclinationDeg;

  /// On web (iOS Safari), sensors require user gesture. Provide a custom prompt; or default shown.
  final Widget Function(VoidCallback requestPermission)? webSensorPromptBuilder;

  @override
  State<QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<QiblaCompass> {
  Position? _pos;
  StreamSubscription<CompassEvent?>? _headingSub;
  double? _headingDeg; // Magnetic heading (0..360; 0 = North)
  Object? _error;
  bool _webNeedsSensorPermission = false;
  bool _askedWebPermission = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _headingSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    // 1) Get location (or use manual)
    try {
      if (widget.manualLatitude != null && widget.manualLongitude != null) {
        _pos = Position(
          latitude: widget.manualLatitude!,
          longitude: widget.manualLongitude!,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      } else {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          final req = await Geolocator.requestPermission();
          if (req == LocationPermission.denied ||
              req == LocationPermission.deniedForever) {
            if (!mounted) return;
            if (widget.allowManualLocation) {
              // Leave _pos null; UI will show manual prompt
            } else {
              throw Exception('Location permission denied');
            }
          }
        }
        if (await Geolocator.isLocationServiceEnabled()) {
          _pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          );
        } else if (!widget.allowManualLocation) {
          throw Exception('Location services disabled');
        }
      }
    } catch (e) {
      _error = e;
      widget.onLocateError?.call(e);
    } finally {
      if (mounted) setState(() {});
    }

    // 2) Subscribe heading (compass)
    // On web + iOS Safari, we might need a user gesture to enable sensors; we’ll detect a null stream and show prompt.
    try {
      _headingSub = FlutterCompass.events?.listen((event) {
        final raw = event?.heading; // degrees from magnetic north; 0..360, or null
        if (raw == null) {
          if (kIsWeb && !_askedWebPermission) {
            setState(() => _webNeedsSensorPermission = true);
          }
          return;
        }
        var h = raw;
        // Optional: apply declination to convert magnetic => true
        if (widget.magneticDeclinationDeg != null) {
          h = (h + widget.magneticDeclinationDeg!) % 360;
          if (h < 0) h += 360;
        }
        setState(() => _headingDeg = h);
      });
    } catch (_) {
      // Ignore; heading remains null => fallback UI
    }
  }

  Future<void> _requestWebSensorPermission() async {
    // We can’t programmatically call DeviceOrientationEvent.requestPermission()
    // from here (needs JS + direct user gesture). But flutter_compass internally
    // tries again after permission; so we flip a flag to encourage user to interact.
    _askedWebPermission = true;
    setState(() => _webNeedsSensorPermission = false);
    // Tip: Place this widget in a button handler on web to re-create heading subscription if needed.
    _headingSub?.cancel();
    _headingSub = FlutterCompass.events?.listen((event) {
      final raw = event?.heading;
      if (raw == null) return;
      var h = raw;
      if (widget.magneticDeclinationDeg != null) {
        h = (h + widget.magneticDeclinationDeg!) % 360;
        if (h < 0) h += 360;
      }
      setState(() => _headingDeg = h);
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    return widget.showCard
        ? Card(
      color: widget.background ?? Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(padding: const EdgeInsets.all(16), child: body),
    )
        : body;
  }

  Widget _buildBody(BuildContext context) {
    final size = widget.size;
    final strokeColor =
        widget.strokeColor ?? Theme.of(context).colorScheme.outline;
    final tickColor = widget.tickColor ?? strokeColor.withOpacity(0.6);
    final arrowColor = widget.arrowColor ?? Theme.of(context).colorScheme.primary;
    final textStyle = widget.textStyle ??
        Theme.of(context).textTheme.bodySmall!.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        );

    final position = _pos;
    final heading = _headingDeg; // may be null

    // Messages / prompts
    if (_error != null && !widget.allowManualLocation) {
      return _errorTile('Location error: $_error');
    }
    if (position == null && widget.allowManualLocation &&
        widget.manualLatitude == null) {
      return _manualLocationPrompt(context);
    }
    if (kIsWeb && _webNeedsSensorPermission) {
      return (widget.webSensorPromptBuilder?.call(_requestWebSensorPermission)) ??
          _defaultWebSensorPrompt(context);
    }

    // Compute Qibla bearing
    double? qiblaBearingDeg;
    if (position != null) {
      qiblaBearingDeg =
          QiblaDirection.computeBearing(position.latitude, position.longitude);
    }

    // Angle to rotate the ARROW: positive is clockwise in Flutter’s Transform.rotate (radians)
    // If we have heading (north-up device), arrow rotation = (qibla - heading)
    // If no heading, show a north-up static dial and rotate arrow to qibla (relative to top).
    final arrowAngleRad = (qiblaBearingDeg != null
        ? ((qiblaBearingDeg - (heading ?? 0)) * math.pi / 180)
        : 0.0) %
        (2 * math.pi);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Dial
              CustomPaint(
                size: Size.square(size),
                painter: _DialPainter(
                  strokeColor: strokeColor,
                  tickColor: tickColor,
                  labelStyle: textStyle,
                ),
              ),

              // Arrow (rotates)
              Transform.rotate(
                angle: arrowAngleRad,
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _ArrowPainter(color: arrowColor),
                ),
              ),

              // Kaaba in the center
              _KaabaCenter(
                size: widget.kaabaSize,
                image: widget.kaabaImage,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (position != null)
          Text(
            'Qibla: ${qiblaBearingDeg!.toStringAsFixed(0)}°  '
                '${heading != null ? ' | Heading: ${heading.toStringAsFixed(0)}°' : ''}',
            style: textStyle,
          )
        else
          Text('Provide location to compute Qibla', style: textStyle),
        if (heading == null)
          Text('Compass not available — showing North-up view', style: textStyle),
      ],
    );
  }

  Widget _manualLocationPrompt(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.my_location_outlined, size: 36),
        const SizedBox(height: 8),
        const Text(
          'Allow location to compute Qibla, or pass manual coordinates.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            try {
              final req = await Geolocator.requestPermission();
              if (req == LocationPermission.denied ||
                  req == LocationPermission.deniedForever) return;
              _pos = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.medium);
              setState(() {});
            } catch (e) {
              _error = e;
              widget.onLocateError?.call(e);
              setState(() {});
            }
          },
          child: const Text('Enable Location'),
        ),
      ],
    );
  }

  Widget _defaultWebSensorPrompt(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.screen_rotation_alt, size: 36),
        const SizedBox(height: 8),
        const Text(
          'Enable motion sensors to rotate the compass on web.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _requestWebSensorPermission,
          child: const Text('Enable Sensors'),
        ),
      ],
    );
  }

  Widget _errorTile(String msg) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error_outline),
      const SizedBox(width: 8),
      Flexible(child: Text(msg)),
    ],
  );
}

/// Renders the Kaaba image in the center.
class _KaabaCenter extends StatelessWidget {
  const _KaabaCenter({required this.size, this.image});
  final double size;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final img = image ?? const AssetImage('assets/kaaba.png');
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            spreadRadius: 1,
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Image(image: img, fit: BoxFit.contain),
    );
  }
}

/// Paints a simple circular dial with N/E/S/W labels and minute ticks.
class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.strokeColor,
    required this.tickColor,
    required this.labelStyle,
  });

  final Color strokeColor;
  final Color tickColor;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = strokeColor;
    canvas.drawCircle(c, r - 1.5, ring);

    // Ticks
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = tickColor;

    for (int i = 0; i < 360; i += 6) {
      final isMajor = i % 30 == 0;
      final len = isMajor ? 14.0 : 8.0;
      final a = i * math.pi / 180.0;
      final p1 = Offset(
        c.dx + (r - 6) * math.sin(a),
        c.dy - (r - 6) * math.cos(a),
      );
      final p2 = Offset(
        c.dx + (r - 6 - len) * math.sin(a),
        c.dy - (r - 6 - len) * math.cos(a),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Labels N/E/S/W
    final labels = {
      'N': 0.0,
      'E': 90.0,
      'S': 180.0,
      'W': 270.0,
    };
    labels.forEach((t, deg) {
      final a = deg * math.pi / 180.0;
      final off = Offset(
        c.dx + (r - 34) * math.sin(a),
        c.dy - (r - 34) * math.cos(a),
      );
      final tp = TextPainter(
        text: TextSpan(text: t, style: labelStyle.copyWith(fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, off - Offset(tp.width / 2, tp.height / 2));
    });
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor ||
          oldDelegate.tickColor != tickColor ||
          oldDelegate.labelStyle != labelStyle;
}

/// Paints a pointer arrow that points up (0°). We rotate this in the widget.
class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final path = Path();

    // Arrow body pointing up (north). Dimensions are relative to radius.
    final shaftWidth = r * 0.06;
    final shaftLen = r * 0.55;
    final headLen = r * 0.22;
    final headWidth = r * 0.18;

    // Shaft
    path.addRRect(RRect.fromRectXY(
      Rect.fromCenter(center: Offset(c.dx, c.dy - shaftLen / 2), width: shaftWidth, height: shaftLen),
      shaftWidth * 0.5, shaftWidth * 0.5,
    ));

    // Head (triangle)
    final tip = Offset(c.dx, c.dy - shaftLen - headLen);
    path.moveTo(tip.dx, tip.dy);
    path.lineTo(c.dx - headWidth / 2, c.dy - shaftLen);
    path.lineTo(c.dx + headWidth / 2, c.dy - shaftLen);
    path.close();

    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) => oldDelegate.color != color;
}
