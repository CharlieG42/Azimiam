import 'package:flutter_test/flutter_test.dart';
import 'package:azimiam/models/favori.dart';
import 'package:azimiam/models/repas.dart';
import 'package:azimiam/models/valeurs.dart';

void main() {
  final ligneA = LigneRepas(
    nom: 'Poulet grillé',
    grammes: 150,
    pour100: const ValeursNutritionnelles(
        kcal: 165, proteines: 31, glucides: 0, lipides: 3.6),
    source: 'ia',
    reconnu: true,
  );
  final ligneB = LigneRepas(
    nom: 'Riz blanc cuit',
    grammes: 120,
    pour100:
        const ValeursNutritionnelles(kcal: 130, proteines: 2.7, glucides: 28, lipides: 0.3),
    source: 'base',
  );

  group('sérialisation JSON des lignes', () {
    test('aller-retour fidèle', () {
      final json = FavoriRepas.lignesToJson([ligneA, ligneB]);
      final retour = FavoriRepas.lignesFromJson(json);
      expect(retour.length, 2);
      expect(retour[0].nom, 'Poulet grillé');
      expect(retour[0].grammes, 150);
      expect(retour[0].pour100.kcal, 165);
      expect(retour[0].pour100.proteines, 31);
      expect(retour[0].source, 'ia');
      expect(retour[0].reconnu, isTrue);
      expect(retour[1].nom, 'Riz blanc cuit');
      expect(retour[1].reconnu, isTrue); // défaut
    });

    test('valeurs nulles gérées (saisie libre)', () {
      const ligne = LigneRepas(
        nom: 'Aliment inventé',
        grammes: 100,
        pour100: ValeursNutritionnelles.vide,
        source: 'manuel',
        reconnu: false,
      );
      final retour = FavoriRepas.lignesFromJson(FavoriRepas.lignesToJson([ligne]));
      expect(retour.single.nom, 'Aliment inventé');
      expect(retour.single.reconnu, isFalse);
      expect(retour.single.pour100.kcal, 0);
    });
  });

  group('empreinte (comparaison repas <-> favori)', () {
    final repas = Repas(
      prisLe: DateTime(2026, 11, 18, 12, 30),
      type: 'Déjeuner',
      lignes: [ligneB, ligneA], // ordre différent
    );

    test('même contenu = même empreinte (ordre des lignes indifférent)', () {
      expect(empreinteRepas(repas), FavoriRepas.empreinteLignes('Déjeuner', [ligneA, ligneB]));
    });

    test('grammes différents = empreinte différente', () {
      final autre = Repas(
        prisLe: repas.prisLe,
        type: 'Déjeuner',
        lignes: [ligneA, LigneRepas(nom: ligneB.nom, grammes: 200, pour100: ligneB.pour100)],
      );
      expect(empreinteRepas(autre), isNot(empreinteRepas(repas)));
    });

    test('type différent = empreinte différente', () {
      final autre = Repas(prisLe: repas.prisLe, type: 'Dîner', lignes: repas.lignes);
      expect(empreinteRepas(autre), isNot(empreinteRepas(repas)));
    });
  });

  group('total du favori', () {
    test('somme des lignes', () {
      final favori = FavoriRepas(
        nom: 'Déj perso',
        type: 'Petit-déjeuner',
        creeLe: DateTime(2026, 11, 18),
        lignes: [ligneA, ligneB],
      );
      // 150 g poulet = 247.5 kcal ; 120 g riz = 156 kcal
      expect(favori.total.kcal, closeTo(403.5, 0.01));
    });
  });
}
