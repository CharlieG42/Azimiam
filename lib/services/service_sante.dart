import 'package:health/health.dart';

import '../models/activite.dart';
import 'service_activites.dart';

/// Compteurs quotidiens relevés dans Health Connect (v0.7.0).
class CompteursJour {
  /// Pas de la journée.
  final int pas;

  /// Étages (volées d'escaliers) gravis dans la journée.
  final int etages;

  const CompteursJour({required this.pas, required this.etages});
}

/// Une séance sportive relevée dans une source santé (Health Connect),
/// telle que journalisée par la montre (ex. Garmin Connect).
class SeanceSante {
  /// Identifiant stable de l'enregistrement Health Connect (uuid) :
  /// sert à ne pas réimporter une séance déjà enregistrée.
  final String? cleExterne;

  /// Origine du point (nom du paquet, ex. com.garmin.android.apps.connectmobile).
  final String? source;

  /// Début de la séance.
  final DateTime moment;

  /// Durée en minutes.
  final double dureeMin;

  /// Distance en kilomètres (null si non renseignée).
  final double? distanceKm;

  /// Calories déclarées par la source en kcal (null si absente ou
  /// exprimée dans une autre unité).
  final double? kcal;

  /// Nom du type de séance côté Health Connect (ex. RUNNING).
  final String? typeNom;

  const SeanceSante({
    this.cleExterne,
    this.source,
    required this.moment,
    required this.dureeMin,
    this.distanceKm,
    this.kcal,
    this.typeNom,
  });
}

/// Source de données santé : autorisation, séances et compteurs.
///
/// Abstraite pour être simulable dans les tests : seule l'implémentation
/// réelle [SourceSanteHealth] parle à Health Connect.
abstract class SourceSante {
  /// Demande l'autorisation de lire les types utiles.
  /// Renvoie false (et jamais d'exception) si refus ou plateforme absente.
  Future<bool> demanderAutorisation();

  /// Séances commençant entre [debut] et [fin]. Liste vide si rien/erreur.
  Future<List<SeanceSante>> seancesEntre(DateTime debut, DateTime fin);

  /// Compteurs (pas, étages) de la journée [jour]. null si indisponible.
  Future<CompteursJour?> compteursJour(DateTime jour);
}

/// Traduit un type de séance Health Connect (ex. le nom de
/// [WorkoutHealthValue.workoutActivityType]) en clé du catalogue Azimiam.
///
/// Les types non mappés deviennent « autre » : la séance est conservée
/// plutôt que perdue, et l'utilisateur peut la retoucher.
String cleAzimiamPour(String? typeNom) {
  switch (typeNom) {
    case 'RUNNING':
    case 'RUNNING_MACHINE': // ergomètre de course, géré comme course
      return 'course';
    case 'WALKING':
      return 'marche';
    case 'HIKING':
      return 'rando';
    case 'BIKING':
    case 'MOUNTAIN_BIKING':
      return 'velo';
    case 'SWIMMING':
    case 'SWIMMING_OPEN_WATER':
      return 'natation';
    case 'YOGA':
      return 'yoga';
    case 'HIGH_INTENSITY_INTERVAL_TRAINING':
      return 'hiit';
    case 'TRADITIONAL_STRENGTH_TRAINING':
    case 'STRENGTH_TRAINING':
      return 'musculation';
    case 'ROWING':
      return 'aviron';
    case 'TENNIS':
    case 'BADMINTON':
      return 'tennis';
    case 'SOCCER':
    case 'FOOTBALL':
    case 'BASKETBALL':
    case 'HANDBALL':
    case 'RUGBY':
    case 'VOLLEYBALL':
      return 'collectif';
    case 'DOWNHILL_SKIING':
    case 'SKIING':
    case 'SNOWBOARDING':
      return 'ski';
    default:
      return 'autre';
  }
}

/// Filtre les séances candidates dont la clé externe est déjà connue.
///
/// Une séance sans clé (vide ou null) est écartée : impossible de garantir
/// qu'elle ne serait pas importée en double à chaque lancement.
List<SeanceSante> seancesNouvelles(
    List<SeanceSante> candidates, Set<String> connues) {
  final vues = <String>{...connues};
  final nouvelles = <SeanceSante>[];
  for (final seance in candidates) {
    final cle = seance.cleExterne;
    if (cle == null || cle.isEmpty) continue;
    if (vues.contains(cle)) continue;
    vues.add(cle);
    nouvelles.add(seance);
  }
  return nouvelles;
}

/// Calories d'une séance importée : celles de la source si elle en fournit,
/// sinon estimation MET du catalogue Azimiam sur 70 kg.
double caloriesSeance(SeanceSante seance) {
  final kcal = seance.kcal;
  if (kcal != null && kcal > 0) return kcal;
  return ServiceActivites.calories(
    type: cleAzimiamPour(seance.typeNom),
    dureeMin: seance.dureeMin,
    distanceKm: seance.distanceKm,
  );
}

/// Convertit une séance santé en [ActiviteSport] enregistrable en base.
ActiviteSport enActivite(SeanceSante seance) => ActiviteSport(
      moment: seance.moment,
      type: cleAzimiamPour(seance.typeNom),
      dureeMin: seance.dureeMin,
      distanceKm: seance.distanceKm,
      kcal: caloriesSeance(seance),
      cleExterne: seance.cleExterne,
      source: seance.source,
    );

/// 8432 -> « 8 432 » : séparateur de milliers à la française.
String formatEntier(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');

/// Implémentation réelle de [SourceSante] au-dessus du plugin health.
///
/// Toute erreur (Health Connect absent, autorisation refusée, Android
/// trop ancien, pas de données…) est avalée : l'import santé ne doit
/// JAMAIS empêcher l'application de démarrer ou de fonctionner.
class SourceSanteHealth implements SourceSante {
  final Health _sante = Health();

  static const List<HealthDataType> _typesLus = [
    HealthDataType.STEPS,
    HealthDataType.FLIGHTS_CLIMBED,
    HealthDataType.WORKOUT,
  ];

  @override
  Future<bool> demanderAutorisation() async {
    try {
      return await _sante.requestAuthorization(_typesLus);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<SeanceSante>> seancesEntre(DateTime debut, DateTime fin) async {
    try {
      final points = await _sante.getHealthDataFromTypes(
        startTime: debut,
        endTime: fin,
        types: const [HealthDataType.WORKOUT],
      );
      final seances = <SeanceSante>[];
      for (final point in points) {
        final valeur = point.value;
        if (valeur is! WorkoutHealthValue) continue;
        // uuid est typé non nullable dans l'API du plugin : le cast
        // évite le warning analyze (bloquant en CI) sans perdre la
        // défense à l'exécution contre une valeur null de la plateforme.
        final cleExterne = point.uuid as String?;
        if (cleExterne == null || cleExterne.isEmpty) continue;
        // Les calories ne sont reprises que si la source les exprime
        // en kilocalories (kcal) : toute autre unité est ignorée et
        // l'estimation MET Azimiam prendra le relais.
        double? kcal;
        final brut = valeur.totalEnergyBurned;
        final unite = valeur.totalEnergyBurnedUnit;
        if (brut != null &&
            (unite == null || unite == HealthDataUnit.KILOCALORIE)) {
          kcal = (brut as num).toDouble();
        }
        // Health Connect renvoie la distance en mètres.
        double? distanceKm;
        final distanceM = valeur.totalDistance;
        if (distanceM != null && (distanceM as num) > 0) {
          distanceKm = (distanceM as num).toDouble() / 1000.0;
        }
        seances.add(SeanceSante(
          cleExterne: cleExterne,
          source: point.sourceName,
          moment: point.dateFrom,
          dureeMin: point.dateTo.difference(point.dateFrom).inMinutes
              .toDouble(),
          distanceKm: distanceKm,
          kcal: kcal,
          typeNom: valeur.workoutActivityType.name,
        ));
      }
      return seances;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<CompteursJour?> compteursJour(DateTime jour) async {
    try {
      final debut = DateTime(jour.year, jour.month, jour.day);
      final fin = DateTime(jour.year, jour.month, jour.day, 23, 59, 59);
      int? pas;
      try {
        pas = await _sante.getTotalStepsInInterval(debut, fin);
      } catch (_) {
        pas = null;
      }
      int etages = 0;
      try {
        final points = await _sante.getHealthDataFromTypes(
          startTime: debut,
          endTime: fin,
          types: const [HealthDataType.FLIGHTS_CLIMBED],
        );
        for (final point in points) {
          final valeur = point.value;
          if (valeur is NumericHealthValue) {
            etages += valeur.numericValue.toInt();
          }
        }
      } catch (_) {
        // Pas d'étages dispo : on renvoie quand même les pas si présents.
      }
      if (pas == null && etages == 0) return null;
      return CompteursJour(pas: pas ?? 0, etages: etages);
    } catch (_) {
      return null;
    }
  }
}
