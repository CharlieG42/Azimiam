import 'package:flutter_test/flutter_test.dart';
import 'package:azimiam/models/valeurs.dart';
import 'package:azimiam/services/service_nutrition.dart';

void main() {
  group('normalise', () {
    test('minuscules, accents et ponctuation', () {
      expect(ServiceNutrition.normalise('Poulet grillé !'), 'poulet grille');
      expect(ServiceNutrition.normalise('  Café   au lait '), 'cafe au lait');
      expect(ServiceNutrition.normalise('Œufs (2)'), 'oeufs 2');
    });
  });

  group('retrouve', () {
    test('nom exact', () {
      final a = ServiceNutrition.retrouve('Poulet grillé');
      expect(a, isNotNull);
      expect(a!.nom, 'Poulet grillé');
    });

    test('alias', () {
      final a = ServiceNutrition.retrouve('jambon');
      expect(a, isNotNull);
      expect(a!.nom, 'Jambon blanc');
    });

    test('nom noyé dans une phrase', () {
      final a = ServiceNutrition.retrouve('un morceau de poulet grillé');
      expect(a, isNotNull);
      expect(a!.nom, 'Poulet grillé');
    });

    test('recherche floue sur nom partiel', () {
      final a = ServiceNutrition.retrouve('saumonette');
      expect(a, isNotNull);
      expect(a!.nom, 'Saumon cuit');
    });

    test('sans correspondance renvoie null', () {
      expect(ServiceNutrition.retrouve('zoiglberg'), isNull);
      expect(ServiceNutrition.retrouve(''), isNull);
    });

    test('score : le plus long alias gagne', () {
      // « steak de thon » doit tomber sur Thon frais, pas « Steak de bœuf »
      // (candidats de même longueur : le premier trouvé avec un score
      // strictement supérieur l'emporte, égalité = premier rencontré).
      final a = ServiceNutrition.retrouve('thon');
      expect(a!.nom, 'Thon frais');
    });
  });

  group('suggestions', () {
    test('retourne au plus 6 résultats', () {
      expect(ServiceNutrition.suggestions(' ').length, 0);
      final s = ServiceNutrition.suggestions('pa');
      expect(s.length, lessThanOrEqualTo(6));
      expect(s.map((a) => a.nom), contains('Pâtes cuites'));
    });
  });

  group('ValeursNutritionnelles', () {
    test('mise à l\'échelle pour une quantité', () {
      const base = ValeursNutritionnelles(
          kcal: 165, proteines: 31, glucides: 0, lipides: 3.6);
      final portion = base.pour(150);
      expect(portion.kcal, closeTo(247.5, 0.01));
      expect(portion.proteines, closeTo(46.5, 0.01));
      expect(portion.lipides, closeTo(5.4, 0.01));
    });

    test('somme neutre et addition', () {
      final total = ValeursNutritionnelles.vide
          .ajouter(const ValeursNutritionnelles(
              kcal: 10, proteines: 1, glucides: 2, lipides: 0.5))
          .ajouter(const ValeursNutritionnelles(
              kcal: 20, proteines: 2, glucides: 4, lipides: 1));
      expect(total.kcal, 30);
      expect(total.proteines, 3);
      expect(total.glucides, 6);
      expect(total.lipides, 1.5);
    });
  });
}
