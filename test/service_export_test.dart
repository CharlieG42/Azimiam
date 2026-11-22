import 'package:flutter_test/flutter_test.dart';
import 'package:azimiam/models/activite.dart';
import 'package:azimiam/models/progression.dart';
import 'package:azimiam/models/repas.dart';
import 'package:azimiam/models/valeurs.dart';
import 'package:azimiam/services/service_export.dart';

void main() {
  final repas = Repas(
    prisLe: DateTime(2026, 11, 18, 12, 30),
    type: 'Déjeuner',
    lignes: [
      LigneRepas(
        nom: 'Poulet grillé',
        grammes: 150,
        pour100: const ValeursNutritionnelles(
            kcal: 165, proteines: 31, glucides: 0, lipides: 3.6),
      ),
      LigneRepas(
        nom: 'Aliment "inventé"',
        grammes: 100,
        pour100: ValeursNutritionnelles.vide,
        source: 'manuel',
        reconnu: false,
      ),
    ],
  );
  final pesee = Pesee(jour: DateTime(2026, 11, 18), kg: 78.5);

  test('en-tête présent', () {
    final csv = ServiceExport.toCsv(repas: [repas], pesees: [pesee]);
    expect(csv.split('\n').first,
        'section;date;type;aliment;grammes;kcal;proteines;glucides;'
        'lipides;poids_kg;duree_min;distance_km;denivele_m');
  });

  test('une ligne par aliment + une ligne par pesée', () {
    final csv = ServiceExport.toCsv(repas: [repas], pesees: [pesee]);
    final lignes = csv.trim().split('\n');
    expect(lignes.length, 1 + 2 + 1); // en-tête + 2 aliments + 1 pesée
    expect(lignes[1], startsWith('pesee;2026-11-18;'));
    expect(lignes[1], endsWith(';78.5;;;'));
    expect(lignes[2],
        'repas;2026-11-18 12:30;"Déjeuner";"Poulet grillé";150.0;247.5;46.5;0.0;5.4;;;;');
    // échappement des guillemets dans le nom
    expect(lignes[3], contains('"Aliment ""inventé"""'));
  });

  test('une ligne par activité sportive déclarée', () {
    final activites = [
      ActiviteSport(
        moment: DateTime(2026, 11, 22, 8, 30),
        type: 'course',
        dureeMin: 45,
        distanceKm: 10.2,
        deniveleM: 120,
        kcal: 787,
      ),
      ActiviteSport(
        moment: DateTime(2026, 11, 21, 18, 0),
        type: 'yoga',
        dureeMin: 60,
        kcal: 210,
      ),
    ];
    final csv = ServiceExport.toCsv(
        repas: [repas], pesees: [pesee], activites: activites);
    final lignes = csv.trim().split('\n');
    expect(lignes.length, 1 + 1 + 2 + 2); // en-tête + pesée + 2 activités + 2 aliments

    // Champs : kcal en 6e colonne, durée/distance/dénivelé en 11-13e.
    expect(lignes[2],
        'activite;2026-11-22 08:30;"course";;;787.0;;;;;45.0;10.2;120.0');
    // Distance et dénivelé absents : cellules vides.
    expect(lignes[3],
        'activite;2026-11-21 18:00;"yoga";;;210.0;;;;;60.0;;');
  });

  test('export vide = en-tête seul', () {
    final csv = ServiceExport.toCsv(repas: [], pesees: []);
    expect(csv.trim().split('\n').length, 1);
  });
}
