import 'package:flutter_test/flutter_test.dart';

import 'package:qibla_compass/qibla_compass.dart';

void main() {
  test('bearing sanity checks', () {
    // Dubai ~ 258°
    final dubai = QiblaDirection.computeBearing(25.2048, 55.2708);
    expect(dubai, inInclusiveRange(250, 265));

    // London ~ 119°
    final london = QiblaDirection.computeBearing(51.5074, -0.1278);
    expect(london, inInclusiveRange(110, 130));

    // Jakarta ~ 295°
    final jakarta = QiblaDirection.computeBearing(-6.2088, 106.8456);
    expect(jakarta, inInclusiveRange(285, 305));
  });
}

Matcher inInclusiveRange(num a, num b) =>
    predicate<num>((v) => v >= a && v <= b, 'in range [$a,$b]');
