import 'package:flutter_test/flutter_test.dart';
import 'package:azimiam/data/mini_base.dart';
import 'package:azimiam/services/service_nutrition.dart';

void main() {
  test('la base contient au moins 100 aliments', () {
    expect(BaseAliments.tous.length, greaterThanOrEqualTo(100));
  });

  test('tous les aliments ont un nom, des alias et des valeurs plausibles', () {
    for (final aliment in BaseAliments.tous) {
      expect(aliment.nom, isNotEmpty,
          reason: 'nom vide pour ${aliment.valeurs.kcal} kcal');
      expect(aliment.alias, isNotEmpty,
          reason: 'aucun alias pour « ${aliment.nom} »');
      expect(
          aliment.valeurs.kcal, allOf(greaterThanOrEqualTo(0), lessThan(950)),
          reason: 'kcal douteux pour « ${aliment.nom} »');
      expect(aliment.valeurs.proteines, greaterThanOrEqualTo(0));
      expect(aliment.valeurs.glucides, greaterThanOrEqualTo(0));
      expect(aliment.valeurs.lipides, greaterThanOrEqualTo(0));
      // Cohérence grossière : kcal ne peut pas être très en dessous de
      // 4·prot + 4·gluc + 9·lip (marge de 20 % pour les arrondis).
      final kcalTheoriqueMin = 0.8 *
          (4 * aliment.valeurs.proteines +
              4 * aliment.valeurs.glucides +
              9 * aliment.valeurs.lipides);
      if (kcalTheoriqueMin > 10) {
        expect(
          aliment.valeurs.kcal,
          greaterThan(kcalTheoriqueMin - 1),
          reason:
              '« ${aliment.nom} » : ${aliment.valeurs.kcal} kcal incohérent avec les macros',
        );
      }
    }
  });

  test('pas de doublon de nom normalisé', () {
    final vus = <String>{};
    for (final aliment in BaseAliments.tous) {
      final n = ServiceNutrition.normalise(aliment.nom);
      expect(vus.contains(n), isFalse,
          reason: '« ${aliment.nom} » est en doublon dans la base');
      vus.add(n);
    }
  });

  test('chaque aliment de la base se retrouve lui-même', () {
    for (final aliment in BaseAliments.tous) {
      expect(ServiceNutrition.retrouve(aliment.nom)?.nom, aliment.nom,
          reason: '« ${aliment.nom} » ne se retrouve pas dans la base');
    }
  });
}
