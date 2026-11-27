import 'package:azimiam/models/activite.dart';
import 'package:azimiam/services/service_sante.dart';
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

  test('minutesSportJour additionne les durées du jour demandé (v0.7.9)', () {
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
    // Sert à majorer l'objectif d'hydratation : 70 min ce jour-là.
    expect(activites.minutesSportJour(DateTime(2026, 11, 26)), 70);
    expect(activites.minutesSportJour(DateTime(2026, 11, 24)), 60);
    expect(activites.minutesSportJour(DateTime(2026, 11, 20)), 0);
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

  test('depenseBudget retient le max calories actives / séances (v0.7.3)',
      () {
    final aujourdHui = DateTime.now();
    final a8 = DateTime(aujourdHui.year, aujourdHui.month, aujourdHui.day, 8);
    // Calories actives plus élevées que les séances : elles sont retenues.
    final activesForte = Activites()
      ..liste = [
        ActiviteSport(
            moment: a8, type: 'course', dureeMin: 40, kcal: 430),
      ]
      ..compteursJour = CompteursJour(pas: 8432, etages: 12, kcalActives: 700);
    expect(activesForte.depenseBudget(a8), 700);
    // Séances plus élevées que les calories actives : retenues.
    final seancesForte = Activites()
      ..liste = [
        ActiviteSport(
            moment: a8, type: 'course', dureeMin: 40, kcal: 820),
      ]
      ..compteursJour = CompteursJour(pas: 2100, etages: 1, kcalActives: 210);
    expect(seancesForte.depenseBudget(a8), 820);
  });

  test('depenseBudget sans compteurs retombe sur les séances (v0.7.3)', () {
    final aujourdHui = DateTime.now();
    final a8 = DateTime(aujourdHui.year, aujourdHui.month, aujourdHui.day, 8);
    final activites = Activites()
      ..liste = [
        ActiviteSport(
            moment: a8, type: 'course', dureeMin: 45, kcal: 520),
      ];
    expect(activites.depenseBudget(a8), 520);
  });

  test('depenseBudget ignore les calories actives sur un jour passé (v0.7.3)',
      () {
    final hier = DateTime.now().subtract(const Duration(days: 1));
    final activites = Activites()
      ..liste = [
        ActiviteSport(
            moment: DateTime(hier.year, hier.month, hier.day, 9),
            type: 'velo',
            dureeMin: 60,
            kcal: 400),
      ]
      // Compteurs du jour courant : illisibles sur la journée d'hier.
      ..compteursJour = CompteursJour(pas: 8432, etages: 12, kcalActives: 900);
    expect(activites.depenseBudget(DateTime(hier.year, hier.month, hier.day)),
        400);
  });
}
