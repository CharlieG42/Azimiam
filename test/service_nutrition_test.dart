import 'package:flutter_test/flutter_test.dart';
import 'package:azimiam/data/mini_base.dart';
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

    test('multi-mots : « blanc poulet » suggère le poulet', () {
      final s = ServiceNutrition.suggestions('blanc poulet');
      expect(s, isNotEmpty);
      expect(s.first.nom, 'Poulet grillé');
    });
  });

  group('recherche multi-mots (v0.6.0)', () {
    test('« pommes terre » (mots non contigus) retrouve les pommes de terre',
        () {
      final resultats = ServiceNutrition.rechercher('pommes terre');
      expect(resultats, isNotEmpty);
      expect(resultats.any((a) => a.nom.contains('Pommes de terre')), isTrue);
    });

    test('accent + ordre des mots : « TERRE pommes » marche aussi', () {
      final resultats = ServiceNutrition.rechercher('TERRE pommes');
      expect(resultats.any((a) => a.nom.contains('Pommes de terre')), isTrue);
    });

    test('pertinence : le nom exact sort avant les alias', () {
      final resultats = ServiceNutrition.rechercher('poulet');
      expect(resultats.first.nom, 'Poulet grillé');
    });

    test('un mot absent élimine l\'aliment', () {
      final resultats = ServiceNutrition.rechercher('poulet pizza');
      expect(resultats.every((a) => a.nom != 'Poulet grillé'), isTrue);
    });

    test('texte vide : liste vide', () {
      expect(ServiceNutrition.rechercher(''), isEmpty);
      expect(ServiceNutrition.rechercher('   '), isEmpty);
    });

    test('base personnalisée injectée : les aliments perso sont cherchés',
        () {
      final perso = [
        Aliment('Gâteau maison de mamie', ['gateau mamie'],
            const ValeursNutritionnelles(
                kcal: 320, proteines: 5, glucides: 45, lipides: 12),
            perso: true,
            id: 1),
      ];
      final resultats =
          ServiceNutrition.rechercher('gateau mamie', base: perso);
      expect(resultats, isNotEmpty);
      expect(resultats.first.nom, 'Gâteau maison de mamie');
      // Ce mot ne matche rien dans une base vide.
      expect(
        ServiceNutrition.rechercher('gateau mamie', base: const []),
        isEmpty,
      );
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
