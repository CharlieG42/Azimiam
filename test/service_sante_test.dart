import 'package:flutter_test/flutter_test.dart';

import 'package:azimiam/models/activite.dart';
import 'package:azimiam/services/service_sante.dart';

void main() {
  test('cleAzimiamPour types Garmin usuels -> clés du catalogue Azimiam',
      () {
    expect(cleAzimiamPour('RUNNING'), 'course');
    expect(cleAzimiamPour('WALKING'), 'marche');
    expect(cleAzimiamPour('HIKING'), 'rando');
    expect(cleAzimiamPour('BIKING'), 'velo');
    expect(cleAzimiamPour('SWIMMING'), 'natation');
    expect(cleAzimiamPour('YOGA'), 'yoga');
    expect(cleAzimiamPour('HIGH_INTENSITY_INTERVAL_TRAINING'), 'hiit');
    expect(cleAzimiamPour('TRADITIONAL_STRENGTH_TRAINING'), 'musculation');
    expect(cleAzimiamPour('ROWING'), 'aviron');
    expect(cleAzimiamPour('TENNIS'), 'tennis');
    expect(cleAzimiamPour('SOCCER'), 'collectif');
    expect(cleAzimiamPour('DOWNHILL_SKIING'), 'ski');
  });

  test('cleAzimiamPour type inconnu -> autre', () {
    expect(cleAzimiamPour('ARM_WRESTLING'), 'autre');
    expect(cleAzimiamPour(null), 'autre');
    expect(cleAzimiamPour(''), 'autre');
  });

  test('seancesNouvelles exclut les séances déjà importées', () {
    final a = SeanceSante(
      cleExterne: 'uuid-a',
      moment: DateTime(2026, 11, 25, 8),
      dureeMin: 45,
    );
    final b = SeanceSante(
      cleExterne: 'uuid-b',
      moment: DateTime(2026, 11, 24, 18),
      dureeMin: 60,
    );
    // « uuid-a » est déjà en base : seule « uuid-b » est nouvelle.
    final nouvelles =
        seancesNouvelles([a, b], const {'uuid-a'}).map((s) => s.cleExterne);
    expect(nouvelles, ['uuid-b']);
  });

  test('seancesNouvelles ignore les séances sans clé externe '
      '(jamais dédoublonnables)', () {
    final avecCle = SeanceSante(
      cleExterne: 'uuid-ok',
      moment: DateTime(2026, 11, 25, 8),
      dureeMin: 30,
    );
    final sansCle = SeanceSante(
      moment: DateTime(2026, 11, 24, 18),
      dureeMin: 30,
    );
    final cleVide = SeanceSante(
      cleExterne: '',
      moment: DateTime(2026, 11, 23, 18),
      dureeMin: 30,
    );
    final nouvelles = seancesNouvelles([avecCle, sansCle, cleVide], const {});
    expect(nouvelles.map((s) => s.cleExterne), ['uuid-ok']);
    // Un doublon de clé DANS le lot candidat est aussi écarté.
    final doublon = SeanceSante(
      cleExterne: 'uuid-ok',
      moment: DateTime(2026, 11, 22, 18),
      dureeMin: 30,
    );
    expect(seancesNouvelles([avecCle, doublon], const {}).length, 1);
  });

  test('enActivite conserve les calories, la clé et la source de Garmin',
      () {
    final seance = SeanceSante(
      cleExterne: 'uuid-garmin-1',
      source: 'com.garmin.android.apps.connectmobile',
      moment: DateTime(2026, 11, 25, 8),
      dureeMin: 45,
      distanceKm: 8,
      kcal: 520,
      typeNom: 'RUNNING',
    );
    final activite = enActivite(seance);
    expect(activite, isA<ActiviteSport>());
    expect(activite.type, 'course');
    expect(activite.kcal, 520);
    expect(activite.cleExterne, 'uuid-garmin-1');
    expect(activite.source, 'com.garmin.android.apps.connectmobile');
    expect(activite.distanceKm, 8);
    expect(activite.importee, isTrue);
  });

  test('enActivite calories estimées par le calcul MET quand la source '
      'n’en fournit pas (WALKING 60 min -> 3,5 x 70 kg x 1 h = 245)', () {
    final seance = SeanceSante(
      cleExterne: 'uuid-hc-2',
      source: 'com.autre.app.sport',
      moment: DateTime(2026, 11, 25, 9),
      dureeMin: 60,
      typeNom: 'WALKING',
    );
    final activite = enActivite(seance);
    expect(activite.type, 'marche');
    expect(activite.kcal, 245);
  });

  test('enActivite estime les calories sur le poids de référence connu '
      '(v0.7.5, WALKING 60 min -> 3,5 x 85 kg x 1 h, arrondi à 298)', () {
    final seance = SeanceSante(
      cleExterne: 'uuid-hc-3',
      source: 'com.autre.app.sport',
      moment: DateTime(2026, 11, 26, 9),
      dureeMin: 60,
      typeNom: 'WALKING',
    );
    final activite = enActivite(seance, poidsKg: 85);
    expect(activite.kcal, 298);
    // Sans poids connu, on retombe sur la référence 70 kg.
    expect(enActivite(seance).kcal, 245);
    // Les calories de la source priment toujours sur l'estimation.
    expect(caloriesSeance(seance, poidsKg: 85), 298);
  });

  test('poidsParJour garde la dernière mesure de chaque jour (v0.7.5)',
      () {
    final pesees = [
      PeseeSante(
          moment: DateTime(2026, 11, 26, 7, 30), kg: 82.4),
      PeseeSante(
          moment: DateTime(2026, 11, 26, 19, 10), kg: 81.8),
      PeseeSante(
          moment: DateTime(2026, 11, 25, 8), kg: 82.9),
    ];
    final parJour = poidsParJour(pesees);
    expect(parJour.length, 2);
    expect(parJour[DateTime(2026, 11, 26)], 81.8);
    expect(parJour[DateTime(2026, 11, 25)], 82.9);
    expect(poidsParJour(const []), isEmpty);
  });

  test('peseesAImporter écarte les jours déjà pesés dans Azimiam (v0.7.5)',
      () {
    final parJour = {
      DateTime(2026, 11, 26): 81.8,
      DateTime(2026, 11, 25): 82.9,
      DateTime(2026, 11, 24): 83.2,
    };
    // Le 25 est déjà saisi (même à la main, autre valeur) : il ne doit
    // jamais être écrasé par la montre.
    final aImporter =
        peseesAImporter(parJour, {DateTime(2026, 11, 25)});
    expect(aImporter.keys, containsAll([DateTime(2026, 11, 26), DateTime(2026, 11, 24)]));
    expect(aImporter.containsKey(DateTime(2026, 11, 25)), isFalse);
  });

  test('formatEntier séparateur de milliers', () {
    expect(formatEntier(8432), '8 432');
    expect(formatEntier(0), '0');
    expect(formatEntier(999), '999');
    expect(formatEntier(1234), '1 234');
    expect(formatEntier(1234567), '1 234 567');
  });
}
