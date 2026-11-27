import 'package:flutter_test/flutter_test.dart';

import 'package:azimiam/services/service_sante.dart';

/// Fonctions pures du suivi du sommeil et de la FC au repos (v0.8.0).
void main() {
  group('minutesSommeilParJour (v0.8.0)', () {
    test('une nuit est attribuée au jour du réveil', () {
      // Nuit de mardi 22 h à mercredi 6 h 30 : elle compte pour
      // mercredi (jour du réveil), 8 h 30 de sommeil.
      final parJour = minutesSommeilParJour([
        SeanceSommeil(
          debut: DateTime(2026, 11, 24, 22),
          fin: DateTime(2026, 11, 25, 6, 30),
        ),
      ]);
      expect(parJour, {DateTime(2026, 11, 25): 8 * 60 + 30});
    });

    test('sieste et nuit finies des jours différents ne se mélangent pas',
        () {
      // Sieste du 25 (13 h - 14 h 30) puis nuit du 25 au 26 : la
      // sieste compte pour le 25, la nuit pour le 26.
      final parJour = minutesSommeilParJour([
        SeanceSommeil(
          debut: DateTime(2026, 11, 25, 13),
          fin: DateTime(2026, 11, 25, 14, 30),
        ),
        SeanceSommeil(
          debut: DateTime(2026, 11, 25, 22),
          fin: DateTime(2026, 11, 26, 6),
        ),
      ]);
      expect(parJour, {
        DateTime(2026, 11, 25): 90,
        DateTime(2026, 11, 26): 480,
      });
    });

    test('deux courtes sessions finies le même jour s\'additionnent', () {
      final parJour = minutesSommeilParJour([
        SeanceSommeil(
          debut: DateTime(2026, 11, 25, 13),
          fin: DateTime(2026, 11, 25, 13, 30),
        ),
        SeanceSommeil(
          debut: DateTime(2026, 11, 25, 15),
          fin: DateTime(2026, 11, 25, 15, 20),
        ),
      ]);
      expect(parJour, {DateTime(2026, 11, 25): 50});
    });

    test('une session de plus de 24 h (donnée aberrante) est ignorée', () {
      final parJour = minutesSommeilParJour([
        SeanceSommeil(
          debut: DateTime(2026, 11, 24, 22),
          fin: DateTime(2026, 11, 26, 23),
        ),
      ]);
      expect(parJour, isEmpty);
    });

    test('une session vide ou négative est ignorée', () {
      final moment = DateTime(2026, 11, 25, 6, 30);
      final parJour = minutesSommeilParJour([
        SeanceSommeil(debut: moment, fin: moment),
        SeanceSommeil(debut: moment, fin: moment.subtract(
            const Duration(minutes: 10))),
      ]);
      expect(parJour, isEmpty);
    });
  });

  group('fcReposParJour (v0.8.0)', () {
    test('la dernière mesure du jour est retenue', () {
      final parJour = fcReposParJour([
        MesureFc(moment: DateTime(2026, 11, 25, 8), bpm: 57),
        MesureFc(moment: DateTime(2026, 11, 25, 20), bpm: 59),
      ]);
      expect(parJour, {DateTime(2026, 11, 25): 59});
    });

    test('les mesures de jours différents coexistent', () {
      final parJour = fcReposParJour([
        MesureFc(moment: DateTime(2026, 11, 24, 9), bpm: 61),
        MesureFc(moment: DateTime(2026, 11, 25, 8), bpm: 58),
      ]);
      expect(parJour, {
        DateTime(2026, 11, 24): 61,
        DateTime(2026, 11, 25): 58,
      });
    });

    test('les mesures hors bornes évidentes sont ignorées', () {
      final parJour = fcReposParJour([
        MesureFc(moment: DateTime(2026, 11, 25, 8), bpm: 25),
        MesureFc(moment: DateTime(2026, 11, 25, 9), bpm: 230),
      ]);
      expect(parJour, isEmpty);
    });
  });

  group('formatDuree (v0.8.0)', () {
    test('445 -> « 7 h 25 »', () {
      expect(formatDuree(445), '7 h 25');
    });

    test('60 -> « 1 h 00 »', () {
      expect(formatDuree(60), '1 h 00');
    });

    test('45 -> « 0 h 45 »', () {
      expect(formatDuree(45), '0 h 45');
    });

    test('480 -> « 8 h 00 »', () {
      expect(formatDuree(480), '8 h 00');
    });
  });
}
