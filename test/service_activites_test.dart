import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:azimiam/services/service_activites.dart';

void main() {
  group('catalogue des types', () {
    test('clés uniques, libellés remplis, MET positifs', () {
      final cles = <String>{};
      for (final t in ServiceActivites.types) {
        expect(cles.contains(t.cle), isFalse,
            reason: 'clé en double : ${t.cle}');
        cles.add(t.cle);
        expect(t.libelle, isNotEmpty);
        expect(t.met, greaterThan(0));
      }
    });

    test('typeParCle : trouvé puis inconnu', () {
      expect(ServiceActivites.typeParCle('marche')?.met, 3.5);
      expect(ServiceActivites.typeParCle('inconnu'), isNull);
    });

    test('libellé et icône de repli pour une clé inconnue', () {
      expect(ServiceActivites.libelle('marche'), 'Marche');
      expect(ServiceActivites.libelle('zap'), 'zap');
      expect(ServiceActivites.icone('zap'), Icons.more_horiz);
    });
  });

  group('calories de base (MET x poids x durée)', () {
    test('marche 60 min, 80 kg : MET 3,5', () {
      expect(
        ServiceActivites.calories(
            type: 'marche', dureeMin: 60, poidsKg: 80),
        280,
      );
    });

    test('arrondi à la kcal : marche 45 min, 70 kg', () {
      expect(
        ServiceActivites.calories(
            type: 'marche', dureeMin: 45, poidsKg: 70),
        184, // 3,5 x 70 x 0,75 = 183,75
      );
    });

    test('sans pesée : estimation sur 70 kg', () {
      expect(
        ServiceActivites.calories(type: 'marche', dureeMin: 60),
        245, // 3,5 x 70
      );
    });

    test('durée invalide ou type inconnu : 0', () {
      expect(
        ServiceActivites.calories(type: 'marche', dureeMin: 0, poidsKg: 80),
        0,
      );
      expect(
        ServiceActivites.calories(type: 'inconnu', dureeMin: 60, poidsKg: 80),
        0,
      );
    });
  });

  group('MET ajusté à la vitesse', () {
    test('course 10 km/h (10 km en 60 min), 80 kg : MET 11', () {
      expect(
        ServiceActivites.calories(
            type: 'course',
            dureeMin: 60,
            poidsKg: 80,
            distanceKm: 10),
        880, // 11 x 80 x 1
      );
    });

    test('course 12 km/h (10 km en 50 min), 80 kg : MET 11,8', () {
      expect(
        ServiceActivites.calories(
            type: 'course',
            dureeMin: 50,
            poidsKg: 80,
            distanceKm: 10),
        787, // 11,8 x 80 x 50/60 = 786,7
      );
    });

    test('vélo 20 km/h, 75 kg : MET 10', () {
      expect(
        ServiceActivites.calories(
            type: 'velo',
            dureeMin: 60,
            poidsKg: 75,
            distanceKm: 20),
        750,
      );
    });

    test('marche rapide 6 km/h, 70 kg : MET 5', () {
      expect(
        ServiceActivites.calories(
            type: 'marche_rapide',
            dureeMin: 60,
            poidsKg: 70,
            distanceKm: 6),
        350,
      );
    });

    test('type sans table de vitesse : MET de base, distance ignorée', () {
      // La natation n'a pas de table : 7 x 70 x 1, whatever la distance.
      expect(
        ServiceActivites.calories(
            type: 'natation',
            dureeMin: 60,
            poidsKg: 70,
            distanceKm: 2),
        490,
      );
    });
  });

  group('dénivelé positif', () {
    test('rando 60 min 80 kg + 500 m : base 480 + montée ~375', () {
      expect(
        ServiceActivites.calories(
            type: 'rando',
            dureeMin: 60,
            poidsKg: 80,
            deniveleM: 500),
        855, // 6 x 80 = 480 ; + 80 x 500 x 9,81 / 4184 / 0,25 = 375,05
      );
    });

    test('dénivelé absent ou négatif : pas de bonus', () {
      expect(
        ServiceActivites.calories(
            type: 'rando',
            dureeMin: 60,
            poidsKg: 80,
            deniveleM: -100),
        480,
      );
    });
  });
}
