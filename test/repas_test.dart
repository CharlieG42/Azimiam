import 'package:flutter_test/flutter_test.dart';

import 'package:azimiam/models/repas.dart';
import 'package:azimiam/models/valeurs.dart';

void main() {
  test('dateSeule ramène le jour à minuit', () {
    final d = DateTime(2026, 11, 24, 19, 42, 33);
    expect(dateSeule(d), DateTime(2026, 11, 24));
  });

  test('instantPour(null) renvoie l\'instant présent', () {
    final avant = DateTime.now();
    final resultat = instantPour(null);
    final apres = DateTime.now();
    expect(
        resultat.isAfter(avant.subtract(const Duration(seconds: 1))), isTrue);
    expect(resultat.isBefore(apres.add(const Duration(seconds: 1))), isTrue);
  });

  test('instantPour garde le jour demandé, à l\'heure présente', () {
    // L'heure de la journée reçue est ignorée : seule la date compte,
    // l'heure vient de « maintenant ».
    final jour = DateTime(2026, 11, 24, 8, 0);
    final resultat = instantPour(jour);
    expect(dateSeule(resultat), DateTime(2026, 11, 24));

    final maintenant = DateTime.now();
    final secondesResultat =
        resultat.hour * 3600 + resultat.minute * 60 + resultat.second;
    final secondesMaintenant = maintenant.hour * 3600 +
        maintenant.minute * 60 +
        maintenant.second;
    // Tolérance de 3 s : le test s'exécute en un clin d'œil.
    expect((secondesResultat - secondesMaintenant).abs() <= 3, isTrue);
  });

  test('un repas totalise les valeurs de ses lignes', () {
    final repas = Repas(
      prisLe: DateTime(2026, 11, 24, 19, 42),
      type: 'Dîner',
      lignes: [
        LigneRepas(
          nom: 'Lasagne',
          grammes: 200,
          pour100: const ValeursNutritionnelles(
            kcal: 130,
            proteines: 7,
            glucides: 12,
            lipides: 5,
          ),
        ),
      ],
    );
    expect(repas.total.kcal, closeTo(260, 0.01));
  });
}
