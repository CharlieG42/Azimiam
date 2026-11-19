import 'package:flutter_test/flutter_test.dart';
import 'package:azimiam/version.dart';

void main() {
  test('kVersionApp suit le format du pubspec : X.Y.Z(-prN)+build', () {
    expect(kVersionApp, matches(RegExp(r'^\d+\.\d+\.\d+(-pr\d+)?\+\d+$')));
  });
}
