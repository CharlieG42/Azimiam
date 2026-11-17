import 'package:flutter_test/flutter_test.dart';
import 'package:azimiam/models/profil.dart';
import 'package:azimiam/services/service_imc.dart';

void main() {
  group('imc', () {
    test('formule poids / taille² (taille en cm)', () {
      expect(ServiceImc.imc(80, 180), closeTo(24.69, 0.01));
      expect(ServiceImc.imc(72, 160), closeTo(28.125, 0.001));
    });
  });

  group('categorie (bornes OMS)', () {
    test('toutes les tranches', () {
      expect(ServiceImc.categorie(15).libelle, 'Dénutrition');
      expect(ServiceImc.categorie(17).libelle, 'Insuffisance pondérale');
      expect(ServiceImc.categorie(18.5).libelle, 'Corpulence normale');
      expect(ServiceImc.categorie(24.9).libelle, 'Corpulence normale');
      expect(ServiceImc.categorie(25).libelle, 'Surpoids');
      expect(ServiceImc.categorie(29.9).libelle, 'Surpoids');
      expect(ServiceImc.categorie(30).libelle, 'Obésité modérée');
      expect(ServiceImc.categorie(35).libelle, 'Obésité sévère');
      expect(ServiceImc.categorie(40).libelle, 'Obésité morbide');
    });
  });

  group('metabolismeBase (Mifflin-St Jeor)', () {
    test('homme : 10P + 6,25T - 5A + 5', () {
      expect(
        ServiceImc.metabolismeBase(
            sexe: 'h', age: 30, poidsKg: 80, tailleCm: 180),
        closeTo(1780, 0.5),
      );
    });

    test('femme : 10P + 6,25T - 5A - 161', () {
      expect(
        ServiceImc.metabolismeBase(
            sexe: 'f', age: 30, poidsKg: 80, tailleCm: 180),
        closeTo(1614, 0.5),
      );
    });
  });

  group('facteurActivite', () {
    test('croissant du sédentaire au très actif', () {
      expect(ServiceImc.facteurActivite('sedentaire'), 1.2);
      expect(ServiceImc.facteurActivite('leger'), 1.375);
      expect(ServiceImc.facteurActivite('modere'), 1.55);
      expect(ServiceImc.facteurActivite('actif'), 1.725);
      expect(ServiceImc.facteurActivite('tres_actif'), 1.9);
      expect(ServiceImc.facteurActivite('inconnu'), 1.2);
    });
  });

  group('tdee', () {
    test('métabolisme x facteur, 0 si profil incomplet', () {
      const profil = Profil(
          tailleCm: 180, age: 30, sexe: 'h', activite: 'modere');
      expect(ServiceImc.tdee(profil, 80), closeTo(1780 * 1.55, 0.5));
      expect(ServiceImc.tdee(const Profil(), 80), 0);
    });
  });

  group('caloriesCible', () {
    test('maintien = TDEE', () {
      expect(ServiceImc.caloriesCible(2500, 'maintien'), 2500);
    });

    test('perte = TDEE - 500, avec plancher 1200 (f) / 1500 (h)', () {
      expect(ServiceImc.caloriesCible(2500, 'perte', sexe: 'h'), 2000);
      expect(ServiceImc.caloriesCible(1600, 'perte', sexe: 'f'), 1200);
      expect(ServiceImc.caloriesCible(1600, 'perte', sexe: 'h'), 1500);
    });

    test('prise = TDEE + 300', () {
      expect(ServiceImc.caloriesCible(2500, 'prise'), 2800);
    });
  });

  group('poidsIdeal (Devine)', () {
    test('homme 180 cm', () {
      expect(ServiceImc.poidsIdeal(180, 'h'), closeTo(75.0, 0.5));
    });

    test('femme 165 cm', () {
      expect(ServiceImc.poidsIdeal(165, 'f'), closeTo(56.9, 0.5));
    });
  });

  group('objectifsAuto', () {
    const profil = Profil(
      tailleCm: 180,
      age: 30,
      sexe: 'h',
      activite: 'modere',
      objectif: 'perte',
      poidsCibleKg: 75,
    );

    test('kcal = TDEE - 500 (perte)', () {
      final o = ServiceImc.objectifsAuto(profil, 80);
      expect(o.kcal, closeTo(1780 * 1.55 - 500, 1));
    });

    test('protéines = 2 g/kg de poids cible, lipides = 30 % des kcal', () {
      final o = ServiceImc.objectifsAuto(profil, 80);
      expect(o.proteines, closeTo(150, 0.1));
      expect(o.lipides, closeTo(o.kcal * 0.30 / 9, 0.1));
    });

    test('les macros somment bien aux kcal (4P + 9L + 4G = kcal)', () {
      final o = ServiceImc.objectifsAuto(profil, 80);
      expect(4 * o.proteines + 9 * o.lipides + 4 * o.glucides,
          closeTo(o.kcal, 1));
      expect(o.glucides, greaterThanOrEqualTo(0));
    });
  });

  group('semainesEstimees', () {
    test('perte de 5 kg à -500 kcal/j ≈ 11 semaines (7700 kcal/kg)', () {
      const profil = Profil(
        tailleCm: 180,
        age: 30,
        sexe: 'h',
        activite: 'modere',
        objectif: 'perte',
        poidsCibleKg: 75,
      );
      expect(ServiceImc.semainesEstimees(profil, 80), 11);
    });

    test('maintien ou sans cible = 0', () {
      expect(ServiceImc.semainesEstimees(const Profil(objectif: 'maintien'), 80), 0);
      expect(ServiceImc.semainesEstimees(const Profil(objectif: 'perte'), 80), 0);
    });
  });
}
