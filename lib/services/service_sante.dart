import 'package:health/health.dart';

import '../models/activite.dart';
import 'service_activites.dart';

/// Compteurs quotidiens relevés dans Health Connect (v0.7.0 ; calories
/// actives ajoutées en v0.7.3).
class CompteursJour {
  /// Pas de la journée.
  final int pas;

  /// Étages (volées d'escaliers) gravis dans la journée.
  final int etages;

  /// Calories actives de la journée (kcal, ex. 210) : énergie brûlée au-delà
  /// du métabolisme de base, mesurée par la montre. Inclut déjà les séances.
  final double kcalActives;

  const CompteursJour(
      {required this.pas, required this.etages, this.kcalActives = 0});
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

/// Une pesée relevée dans une source santé (Health Connect), telle que
/// journalisée par la montre ou la balance (v0.7.5).
class PeseeSante {
  /// Date et heure de la mesure.
  final DateTime moment;

  /// Poids mesuré, en kilogrammes.
  final double kg;

  const PeseeSante({required this.moment, required this.kg});
}

/// Une nuit de sommeil relevée dans une source santé (Health Connect),
/// telle que journalisée par la montre (v0.8.0) : début et fin de la
/// session de sommeil (la durée s'en déduit).
class SeanceSommeil {
  /// Coucher (début de la session de sommeil).
  final DateTime debut;

  /// Réveil (fin de la session de sommeil).
  final DateTime fin;

  const SeanceSommeil({required this.debut, required this.fin});
}

/// Une mesure de fréquence cardiaque relevée dans une source santé
/// (v0.8.0) — au repos (Health Connect publie en général une valeur
/// quotidienne) ou ponctuelle.
class MesureFc {
  /// Date et heure de la mesure.
  final DateTime moment;

  /// Fréquence cardiaque, en battements par minute.
  final int bpm;

  const MesureFc({required this.moment, required this.bpm});
}

/// Détail d'effort relevé dans une source santé sur une fenêtre
/// donnée (v0.8.1) : pas et fréquence cardiaque pendant l'effort,
/// pour l'écran de détail d'une séance.
class EffortSante {
  /// Pas relevés pendant la fenêtre (null si indisponible).
  final int? pas;

  /// FC minimale relevée pendant la fenêtre (bpm, null si aucune).
  final int? fcMin;

  /// FC moyenne de la fenêtre (bpm, null si aucune mesure).
  final int? fcMoy;

  /// FC maximale relevée pendant la fenêtre (bpm, null si aucune).
  final int? fcMax;

  const EffortSante({this.pas, this.fcMin, this.fcMoy, this.fcMax});
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

  /// Pesées relevées entre [debut] et [fin] (v0.7.5).
  /// Liste vide si rien/erreur.
  Future<List<PeseeSante>> peseesEntre(DateTime debut, DateTime fin);

  /// Nuits de sommeil chevauchant [debut] et [fin] (v0.8.0).
  /// Liste vide si rien/erreur.
  Future<List<SeanceSommeil>> sommeilEntre(DateTime debut, DateTime fin);

  /// Mesures de FC au repos relevées entre [debut] et [fin] (v0.8.0).
  /// Liste vide si rien/erreur.
  Future<List<MesureFc>> fcReposEntre(DateTime debut, DateTime fin);

  /// FC minimale relevée entre [debut] et [fin] dans les mesures
  /// ponctuelles (v0.8.0) : repli quand la source ne publie pas de FC
  /// au repos. null si indisponible.
  Future<int?> fcMinEntre(DateTime debut, DateTime fin);

  /// Détail d'effort (pas, FC min/moy/max) relevé entre [debut] et
  /// [fin] (v0.8.1), pour l'écran de détail d'une séance. null si
  /// indisponible.
  Future<EffortSante?> effortEntre(DateTime debut, DateTime fin);

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

/// Poids par jour civil (v0.7.5) : parmi les pesées d'une source santé,
/// la dernière mesure de chaque journée (une montre peut en écrire
/// plusieurs, ex. avant/après entraînement).
Map<DateTime, double> poidsParJour(List<PeseeSante> pesees) {
  final parJour = <DateTime, double>{};
  final dernierMoment = <DateTime, DateTime>{};
  for (final p in pesees) {
    final jour = DateTime(p.moment.year, p.moment.month, p.moment.day);
    final deja = dernierMoment[jour];
    if (deja == null || p.moment.isAfter(deja)) {
      dernierMoment[jour] = p.moment;
      parJour[jour] = p.kg;
    }
  }
  return parJour;
}

/// Pesées à importer (v0.7.5) : retire de [parJour] les jours déjà
/// présents dans l'historique Azimiam — une pesée saisie ou corrigée à
/// la main n'est jamais écrasée par celle de la montre.
Map<DateTime, double> peseesAImporter(
    Map<DateTime, double> parJour, Set<DateTime> joursConnus) {
  return Map.fromEntries(parJour.entries
      .where((e) => !joursConnus.contains(e.key))
      .toList());
}

/// Minutes de sommeil par jour de réveil (v0.8.0) : chaque session est
/// attribuée au jour civil où elle se termine — la nuit de mardi à
/// mercredi compte pour mercredi. Plusieurs sessions terminées le
/// même jour (ex. sieste puis nuit) s'additionnent ; une session
/// vide ou de plus de 24 h (donnée aberrante) est ignorée.
Map<DateTime, int> minutesSommeilParJour(List<SeanceSommeil> seances) {
  final parJour = <DateTime, int>{};
  for (final seance in seances) {
    final minutes = seance.fin.difference(seance.debut).inMinutes;
    if (minutes <= 0 || minutes > 24 * 60) continue;
    final jour =
        DateTime(seance.fin.year, seance.fin.month, seance.fin.day);
    parJour[jour] = (parJour[jour] ?? 0) + minutes;
  }
  return parJour;
}

/// FC au repos par jour civil (v0.8.0) : la dernière mesure de la
/// journée (Health Connect publie en général une valeur quotidienne).
/// Les mesures hors bornes évidentes (25 ou 230 bpm) sont ignorées.
Map<DateTime, int> fcReposParJour(List<MesureFc> mesures) {
  final parJour = <DateTime, int>{};
  final dernierMoment = <DateTime, DateTime>{};
  for (final m in mesures) {
    if (m.bpm < 30 || m.bpm > 220) continue;
    final jour = DateTime(m.moment.year, m.moment.month, m.moment.day);
    final deja = dernierMoment[jour];
    if (deja == null || m.moment.isAfter(deja)) {
      dernierMoment[jour] = m.moment;
      parJour[jour] = m.bpm;
    }
  }
  return parJour;
}

/// 445 -> « 7 h 25 » (v0.8.0) : durée de sommeil lisible.
String formatDuree(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '$h h ${m.toString().padLeft(2, '0')}';
}

/// Calories d'une séance importée : celles de la source si elle en fournit,
/// sinon estimation MET du catalogue Azimiam — sur [poidsKg] quand le poids
/// est connu (dernière pesée), sinon 70 kg (v0.7.5).
double caloriesSeance(SeanceSante seance, {double? poidsKg}) {
  final kcal = seance.kcal;
  if (kcal != null && kcal > 0) return kcal;
  return ServiceActivites.calories(
    type: cleAzimiamPour(seance.typeNom),
    dureeMin: seance.dureeMin,
    distanceKm: seance.distanceKm,
    poidsKg: poidsKg,
  );
}

/// Convertit une séance santé en [ActiviteSport] enregistrable en base.
/// [poidsKg] : poids de référence pour l'estimation MET (v0.7.5).
ActiviteSport enActivite(SeanceSante seance, {double? poidsKg}) =>
    ActiviteSport(
      moment: seance.moment,
      type: cleAzimiamPour(seance.typeNom),
      dureeMin: seance.dureeMin,
      distanceKm: seance.distanceKm,
      kcal: caloriesSeance(seance, poidsKg: poidsKg),
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
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WEIGHT,
    // v0.7.8 : le plugin enrichit chaque séance WORKOUT lue avec les
    // DistanceRecord / TotalCaloriesBurnedRecord / StepsRecord de sa
    // fenêtre. Sans autorisation DISTANCE et TOTAL_CALORIES_BURNED, la
    // lecture d'une séance lève une SecurityException côté plateforme :
    // la liste revient vide et aucune séance n'est jamais importée,
    // même présente dans Health Connect.
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.TOTAL_CALORIES_BURNED,
    // v0.8.0 : sommeil (nuits attribuées au jour du réveil) et
    // fréquence cardiaque (FC au repos publiée par la source, repli
    // sur la FC minimale des mesures ponctuelles du jour).
    HealthDataType.SLEEP_SESSION,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE,
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
  Future<List<PeseeSante>> peseesEntre(DateTime debut, DateTime fin) async {
    try {
      final points = await _sante.getHealthDataFromTypes(
        startTime: debut,
        endTime: fin,
        types: const [HealthDataType.WEIGHT],
      );
      final pesees = <PeseeSante>[];
      for (final point in points) {
        final valeur = point.value;
        if (valeur is! NumericHealthValue) continue;
        final kg = valeur.numericValue.toDouble();
        // Garde-fou : un poids hors limites évidentes est ignoré.
        if (kg < 20 || kg > 400) continue;
        pesees.add(PeseeSante(moment: point.dateFrom, kg: kg));
      }
      return pesees;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<SeanceSommeil>> sommeilEntre(DateTime debut, DateTime fin) async {
    try {
      final points = await _sante.getHealthDataFromTypes(
        startTime: debut,
        endTime: fin,
        types: const [HealthDataType.SLEEP_SESSION],
      );
      final seances = <SeanceSommeil>[];
      for (final point in points) {
        // Le plugin renvoie une session de sommeil sous forme
        // d'intervalle (valeur = minutes de l'intervalle) : la durée
        // se déduit du début et de la fin, plus fiables.
        if (point.dateTo.isAfter(point.dateFrom)) {
          seances.add(
              SeanceSommeil(debut: point.dateFrom, fin: point.dateTo));
        }
      }
      return seances;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<MesureFc>> fcReposEntre(DateTime debut, DateTime fin) async {
    try {
      final points = await _sante.getHealthDataFromTypes(
        startTime: debut,
        endTime: fin,
        types: const [HealthDataType.RESTING_HEART_RATE],
      );
      final mesures = <MesureFc>[];
      for (final point in points) {
        final valeur = point.value;
        if (valeur is! NumericHealthValue) continue;
        final bpm = valeur.numericValue.round();
        // Garde-fou : une FC hors limites évidentes est ignorée.
        if (bpm < 30 || bpm > 220) continue;
        mesures.add(MesureFc(moment: point.dateFrom, bpm: bpm));
      }
      return mesures;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<int?> fcMinEntre(DateTime debut, DateTime fin) async {
    try {
      final points = await _sante.getHealthDataFromTypes(
        startTime: debut,
        endTime: fin,
        types: const [HealthDataType.HEART_RATE],
      );
      int? mini;
      for (final point in points) {
        final valeur = point.value;
        if (valeur is! NumericHealthValue) continue;
        final bpm = valeur.numericValue.round();
        if (bpm < 30 || bpm > 220) continue;
        if (mini == null || bpm < mini) mini = bpm;
      }
      return mini;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<EffortSante?> effortEntre(DateTime debut, DateTime fin) async {
    if (!fin.isAfter(debut)) return null;
    // Pas de la fenêtre (le plugin fournit un total d'intervalle).
    int? pas;
    try {
      pas = await _sante.getTotalStepsInInterval(debut, fin);
    } catch (_) {
      pas = null;
    }
    // FC min / moyenne / max des mesures ponctuelles de la fenêtre.
    int? fcMin;
    int? fcMax;
    double somme = 0;
    int nb = 0;
    try {
      final points = await _sante.getHealthDataFromTypes(
        startTime: debut,
        endTime: fin,
        types: const [HealthDataType.HEART_RATE],
      );
      for (final point in points) {
        final valeur = point.value;
        if (valeur is! NumericHealthValue) continue;
        final bpm = valeur.numericValue.round();
        // Garde-fou : une FC hors limites évidentes est ignorée.
        if (bpm < 30 || bpm > 220) continue;
        if (fcMin == null || bpm < fcMin) fcMin = bpm;
        if (fcMax == null || bpm > fcMax) fcMax = bpm;
        somme += bpm;
        nb++;
      }
    } catch (_) {
      // Pas de FC disponible sur la fenêtre : on garde les pas.
    }
    if (pas == null && nb == 0) return null;
    return EffortSante(
      pas: pas,
      fcMin: fcMin,
      fcMoy: nb > 0 ? (somme / nb).round() : null,
      fcMax: fcMax,
    );
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
      // Calories actives du jour (v0.7.3) : Health Connect les fournit par
      // petits segments (ex. un par heure côté Garmin) — on les additionne.
      double kcalActives = 0;
      try {
        final points = await _sante.getHealthDataFromTypes(
          startTime: debut,
          endTime: fin,
          types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
        );
        for (final point in points) {
          final valeur = point.value;
          if (valeur is NumericHealthValue) {
            kcalActives += valeur.numericValue.toDouble();
          }
        }
      } catch (_) {
        // Pas de calories actives dispo : les séances prennent le relais.
      }
      if (pas == null && etages == 0 && kcalActives == 0) return null;
      return CompteursJour(
          pas: pas ?? 0, etages: etages, kcalActives: kcalActives);
    } catch (_) {
      return null;
    }
  }
}
