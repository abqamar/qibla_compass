import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A gentle guide for users to calibrate their compass.
/// Note: modern platforms don't expose a programmatic "calibrate" API.
/// We show best-practice motions and live heading feedback (host app can supply).
class QiblaCalibrationHelper extends StatefulWidget {
  const QiblaCalibrationHelper({
    super.key,
    this.title = 'Calibrate Compass',
    this.instructions,
  });

  final String title;
  final List<String>? instructions;

  @override
  State<QiblaCalibrationHelper> createState() => _QiblaCalibrationHelperState();
}

class _QiblaCalibrationHelperState extends State<QiblaCalibrationHelper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.instructions ??
        const [
          'Move your phone in a smooth “figure-8” motion.',
          'Rotate the device around all three axes.',
          'Keep away from magnets/metal surfaces.',
          'Ensure the case doesn’t contain magnets.',
        ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  painter: _FigureEightPainter(progress: _c.value),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...steps.map((s) => ListTile(
              dense: true,
              leading: const Icon(Icons.check_circle_outline),
              title: Text(s),
            )),
            const Spacer(),
            const Text(
              'Tip: Open the compass screen after calibration for best results.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _FigureEightPainter extends CustomPainter {
  _FigureEightPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.32;

    final path = Path();
    // Lemniscate (figure 8) parametric-ish
    for (int i = 0; i <= 360; i++) {
      final t = (i / 360.0) * 2 * math.pi;
      final x = r * math.sin(t);
      final y = r * math.sin(t) * math.cos(t);
      final p = Offset(c.dx + x, c.dy + y);
      if (i == 0) path.moveTo(p.dx, p.dy); else path.lineTo(p.dx, p.dy);
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.grey.shade500;
    canvas.drawPath(path, stroke);

    // animated dot
    final t = progress * 2 * math.pi;
    final x = r * math.sin(t);
    final y = r * math.sin(t) * math.cos(t);
    final dot = Offset(c.dx + x, c.dy + y);
    final fill = Paint()..color = Colors.blueAccent;
    canvas.drawCircle(dot, 8, fill);
  }

  @override
  bool shouldRepaint(covariant _FigureEightPainter oldDelegate) =>
      oldDelegate.progress != progress;
}