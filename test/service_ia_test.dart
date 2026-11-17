import 'package:flutter_test/flutter_test.dart';
import 'package:azimiam/services/service_ia.dart';

void main() {
  group('ServiceIa.parseJsonItems', () {
    test('tableau JSON pur', () {
      final r = ServiceIa.parseJsonItems(
          '[{"nom": "Poulet grillé", "grammes": 150, "confiance": 0.8}]');
      expect(r.length, 1);
      expect(r[0].nom, 'Poulet grillé');
      expect(r[0].grammes, 150);
      expect(r[0].confiance, 0.8);
    });

    test('JSON dans des fences markdown', () {
      final r = ServiceIa.parseJsonItems(
          '```json\n[{"nom": "Riz", "grammes": 200, "confiance": 0.7}]\n```');
      expect(r.length, 1);
      expect(r[0].nom, 'Riz');
      expect(r[0].grammes, 200);
    });

    test('texte autour du JSON', () {
      final r = ServiceIa.parseJsonItems(
          'Voici mon analyse :\n[{"nom": "Pomme", "grammes": 150, "confiance": 0.9}]\nBonne journée !');
      expect(r.length, 1);
      expect(r[0].nom, 'Pomme');
    });

    test('objet avec liste embarquée', () {
      final r = ServiceIa.parseJsonItems(
          '{"aliments": [{"nom": "Riz", "grammes": 200, "confiance": 0.5}]}');
      expect(r.length, 1);
      expect(r[0].nom, 'Riz');
    });

    test('objet aliment unique sans tableau', () {
      final r = ServiceIa.parseJsonItems('{"nom": "Banane", "grammes": 118}');
      expect(r.length, 1);
      expect(r[0].nom, 'Banane');
      expect(r[0].grammes, 118);
    });

    test('variantes de noms de champs', () {
      final r = ServiceIa.parseJsonItems(
          '[{"food": "Banana", "quantity_g": 118, "confidence": 0.6}]');
      expect(r.length, 1);
      expect(r[0].nom, 'Banana');
      expect(r[0].grammes, 118);
      expect(r[0].confiance, 0.6);
    });

    test('grammes en chaîne avec unité et virgule décimale', () {
      final r = ServiceIa.parseJsonItems(
          '[{"nom": "Pain", "grammes": "40 g"}, {"nom": "Yaourt", "quantite": "125,5"}]');
      expect(r.length, 2);
      expect(r[0].grammes, 40);
      expect(r[1].grammes, 125.5);
    });

    test('ignore les entrées invalides', () {
      final r = ServiceIa.parseJsonItems(
          '[{"nom": "", "grammes": 10}, {"nom": "X", "grammes": 0}, {"grammes": 50}, 42]');
      expect(r, isEmpty);
    });

    test('confiance bornée entre 0 et 1', () {
      final r = ServiceIa.parseJsonItems(
          '[{"nom": "Pizza", "grammes": 300, "confiance": 1.7}, {"nom": "Frites", "grammes": 100, "confiance": -0.2}]');
      expect(r[0].confiance, 1.0);
      expect(r[1].confiance, 0.0);
    });

    test('lève FormatException si aucun JSON', () {
      expect(() => ServiceIa.parseJsonItems('Je ne vois aucune nourriture.'),
          throwsFormatException);
    });
  });
}
