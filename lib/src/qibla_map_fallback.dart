import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:qibla_compass/qibla_compass.dart';

/// A simple map fallback that shows user's position and a great-circle line
/// pointing to Kaaba; also draws a bearing arrow overlay.
/// Works on iOS/Android/Web without API keys (OSM tiles).
class QiblaMapFallback extends StatelessWidget {
  const QiblaMapFallback({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 320,
    this.zoom = 12.0,
    this.showLineToKaaba = true,
    this.kaabaMarkerColor,
  });

  final double latitude;
  final double longitude;
  final double height;
  final double zoom;
  final bool showLineToKaaba;
  final Color? kaabaMarkerColor;

  static const _kaaba = latlng.LatLng(21.422487, 39.826206);

  @override
  Widget build(BuildContext context) {
    final user = latlng.LatLng(latitude, longitude);
    final bearing = QiblaDirection.computeBearing(latitude, longitude);
    final map = FlutterMap(
      options: MapOptions(
        initialCenter: user,
        initialZoom: zoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'qibla_compass',
        ),
        PolylineLayer<String>(
          polylines: showLineToKaaba
              ? <Polyline<String>>[
            Polyline<String>(
              points: [user, _kaaba],
              strokeWidth: 3,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              hitValue: 'qibla-line', // any non-null String works
            ),
          ]
              : const <Polyline<String>>[],
        ),
        MarkerLayer(markers: [
          Marker(
            point: user,
            width: 28,
            height: 28,
            child: const _Dot(color: Colors.blue),
          ),
          Marker(
            point: _kaaba,
            width: 28,
            height: 28,
            child: _KaabaMarker(color: kaabaMarkerColor),
          ),
        ]),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: height, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: map)),
        const SizedBox(height: 8),
        Text('Qibla bearing: ${bearing.toStringAsFixed(1)}°'),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
    ),
  );
}

class _KaabaMarker extends StatelessWidget {
  const _KaabaMarker({this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: (color ?? Colors.brown.shade700),
      shape: BoxShape.rectangle,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Colors.black, width: 1.5),
    ),
    child: const Center(
      child: Icon(Icons.crop_square, size: 14, color: Colors.white),
    ),
  );
}
