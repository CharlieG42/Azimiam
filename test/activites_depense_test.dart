import 'package:azimiam/models/activite.dart';
import 'package:azimiam/state/activites.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('depenseJour additionne les séances du jour demandé (v0.7.2)', () {
    final activites = Activites()
      ..liste = [
        ActiviteSport(
            moment: DateTime(2026, 11, 26, 8),
            type: 'course',
            dureeMin: 40,
            kcal: 430),
        ActiviteSport(
            moment: DateTime(2026, 11, 26, 19),
            type: 'marche',
            dureeMin: 30,
            kcal: 160),
        ActiviteSport(
            moment: DateTime(2026, 11, 24, 18),
            type: 'velo',
            dureeMin: 60,
            kcal: 400),
      ];
    expect(activites.depenseJour(DateTime(2026, 11, 26)), 590);
  });

  test('depenseJour vaut 0 sans séance ce jour-là (v0.7.2)', () {
    final activites = Activites()
      ..liste = [
        ActiviteSport(
            moment: DateTime(2026, 11, 25, 9),
            type: 'course',
            dureeMin: 40,
            kcal: 430),
      ];
    expect(activites.depenseJour(DateTime(2026, 11, 26)), 0);
  });

  test('depenseJour avec liste vide (v0.7.2)', () {
    final activites = Activites();
    expect(activites.depenseJour(DateTime(2026, 11, 26)), 0);
  });
}
