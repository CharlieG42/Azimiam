/// Une activité sportive déclarée : type, durée, distance et dénivelé
/// éventuels, et calories dépensées (calculées ou saisies à la main).
class ActiviteSport {
  final int? id;

  /// Date et heure de l'activité.
  final DateTime moment;

  /// Clé du catalogue de types (voir `services/service_activites.dart`).
  final String type;

  /// Durée en minutes.
  final double dureeMin;

  /// Distance en kilomètres (null si non applicable / non renseignée).
  final double? distanceKm;

  /// Dénivelé positif en mètres (null si non applicable / non renseigné).
  final double? deniveleM;

  /// Calories dépensées (kcal).
  final double kcal;

  /// Clé externe (uuid Health Connect) si la séance vient d'une source
  /// santé, null pour une saisie manuelle. Sert à ne pas la réimporter.
  final String? cleExterne;

  /// Origine de la séance (nom du paquet, ex. com.garmin…) si importée,
  /// null pour une saisie manuelle. Affichée comme badge « montre ».
  final String? source;

  /// Vrai si la séance a été importée depuis une source santé externe.
  bool get importee => cleExterne != null && cleExterne!.isNotEmpty;

  const ActiviteSport({
    this.id,
    required this.moment,
    required this.type,
    required this.dureeMin,
    this.distanceKm,
    this.deniveleM,
    required this.kcal,
    this.cleExterne,
    this.source,
  });
}
