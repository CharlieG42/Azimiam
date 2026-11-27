import 'package:flutter_test/flutter_test.dart';

import 'package:azimiam/services/service_hydratation.dart';

void main() {
  test('objectifEau : 30 mL par kg, sans sport (v0.7.9)', () {
    expect(objectifEau(poidsKg: 80), 2400);
  });

  test('objectifEau : majoré de 500 mL par heure de sport (v0.7.9)', () {
    expect(objectifEau(poidsKg: 80, minutesSport: 60), 2900);
    expect(objectifEau(poidsKg: 80, minutesSport: 90), 3150);
  });

  test('objectifEau : plancher 1 500 mL (v0.7.9)', () {
    // 40 kg donneraient 1 200 mL : le plancher s'applique.
    expect(objectifEau(poidsKg: 40), 1500);
  });

  test('objectifEau : repli 2 000 mL sans poids connu (v0.7.9)', () {
    expect(objectifEau(), 2000);
    expect(objectifEau(poidsKg: 0), 2000);
  });

  test('objectifEau : arrondi au multiple de 50 mL (v0.7.9)', () {
    // 71 kg -> 2 130 mL -> 2 150 mL.
    expect(objectifEau(poidsKg: 71), 2150);
  });

  test('objectifEau : plafond 5 000 mL (v0.7.9)', () {
    expect(objectifEau(poidsKg: 200, minutesSport: 300), 5000);
  });
}
