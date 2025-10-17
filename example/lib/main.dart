import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qibla_compass/qibla_compass.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DemoApp());
}

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});
  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  Position? _pos;

  @override
  void initState() {
    super.initState();
    _getPos();
  }

  Future<void> _getPos() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      perm = await Geolocator.requestPermission();
    }
    if (!await Geolocator.isLocationServiceEnabled()) return;
    try {
      final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      setState(() => _pos = p);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qibla Compass Demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1565C0)),
      home: Scaffold(
        appBar: AppBar(title: const Text('Qibla Compass')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Compass', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            QiblaCompass(
              size: 300,
              webSensorPromptBuilder: (request) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Tap to enable motion sensors on web'),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: request, child: const Text('Enable')),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Map Fallback', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_pos != null)
              QiblaMapFallback(
                latitude: _pos!.latitude,
                longitude: _pos!.longitude,
                height: 220,
              )
            else
              const Text('Location not available yet.'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QiblaCalibrationHelper()),
              ),
              child: const Text('Open Calibration Helper'),
            ),
          ],
        ),
      ),
    );
  }
}