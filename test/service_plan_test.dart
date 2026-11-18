import 'package:flutter_test/flutter_test.dart';
import 'package:azimiam/models/repas.dart';
import 'package:azimiam/models/valeurs.dart';
import 'package:azimiam/services/service_nutrition.dart';
import 'package:azimiam/services/service_plan.dart';

void main() {
  const objectifs = ValeursNutritionnelles(
    kcal: 2000,
    proteines: 100,
    glucides: 220,
    lipides: 70,
  );

  test('le plan couvre les 4 types de repas, dans l\'ordre de la journée', () {
    final plan = ServicePlan.planDuJour(objectifs, date: DateTime(2026, 11, 17));
    expect(plan.map((r) => r.type), typesRepas);
  });

  test('chaque ligne provient de la base locale, avec une quantité minimale', () {
    final plan = ServicePlan.planDuJour(objectifs, date: DateTime(2026, 11, 17));
    for (final repas in plan) {
      expect(repas.lignes, isNotEmpty, reason: 'repas ${repas.type} vide');
      for (final ligne in repas.lignes) {
        expect(ServiceNutrition.retrouve(ligne.nom)?.nom, ligne.nom,
            reason: '« ${ligne.nom} » ne vient pas de la base');
        expect(ligne.grammes, greaterThanOrEqualTo(5));
        expect(ligne.valeurs.kcal, greaterThan(0));
      }
    }
  });

  test('le total du jour approche l\'objectif calorique (± 25 %) sur un mois', () {
    for (var jour = 1; jour <= 28; jour++) {
      final plan = ServicePlan.planDuJour(objectifs, date: DateTime(2026, 11, jour));
      final total = ServicePlan.totalPlan(plan);
      expect(total.kcal, greaterThan(objectifs.kcal * 0.75),
          reason: 'jour $jour : ${total.kcal} kcal');
      expect(total.kcal, lessThan(objectifs.kcal * 1.25),
          reason: 'jour $jour : ${total.kcal} kcal');
    }
  });

  test('le plan est déterministe pour une même date', () {
    final a = ServicePlan.planDuJour(objectifs, date: DateTime(2026, 11, 17));
    final b = ServicePlan.planDuJour(objectifs, date: DateTime(2026, 11, 17));
    expect(a.map((r) => r.total.kcal), b.map((r) => r.total.kcal));
    expect(
      a.map((r) => r.lignes.map((l) => l.nom).join('|')).toList(),
      b.map((r) => r.lignes.map((l) => l.nom).join('|')).toList(),
    );
  });

  test('les variantes tournent selon le jour (plusieurs menus sur un mois)', () {
    final noms = <String>{};
    for (var jour = 1; jour <= 28; jour++) {
      for (final r in ServicePlan.planDuJour(objectifs, date: DateTime(2026, 11, jour))) {
        noms.addAll(r.lignes.map((l) => l.nom));
      }
    }
    expect(noms.length, greaterThan(10));
  });

  test('répartition des repas : chaque repas a une part de l\'objectif', () {
    final plan = ServicePlan.planDuJour(objectifs, date: DateTime(2026, 11, 17));
    for (final repas in plan) {
      final part = ServicePlan.repartition[repas.type]!;
      expect(repas.total.kcal, closeTo(objectifs.kcal * part, objectifs.kcal * part * 0.25));
    }
  });
}
