import 'package:flutter/material.dart';

import '../models/activite.dart';

/// Un type d'activité sportive : clé, libellé, icône, MET de référence
/// (Compendium of Physical Activities, valeurs approchées) et champs
/// applicables (distance, dénivelé, ajustement du MET par la vitesse).
class TypeActivite {
  final String cle;
  final String libelle;
  final IconData icone;

  /// MET de base (intensité modérée du type).
  final double met;

  /// Vrai si une distance (km) peut être renseignée.
  final bool avecDistance;

  /// Vrai si un dénivelé positif (m) peut être renseigné.
  final bool avecDenivele;

  const TypeActivite(
    this.cle,
    this.libelle,
    this.icone, {
    required this.met,
    this.avecDistance = false,
    this.avecDenivele = false,
  });
}

/// Calcul des calories dépensées par une activité sportive.
///
/// Pur Dart (aucun accès plateforme) : testable unitairement.
///
/// Formule de base : kcal = MET x poids (kg) x durée (h).
/// Pour la course et le vélo, le MET est ajusté à la vitesse réelle
/// (distance / durée) quand elle est connue. Le dénivelé positif ajoute
/// le travail mécanique de montée : poids x m x g / 4,184 kJ/kcal avec
/// un rendement musculaire d'environ 25 % (soit ~9,4 kcal par tonne-mètre).
class ServiceActivites {
  /// Catalogue des types d'activité, par ordre d'affichage.
  static const List<TypeActivite> types = [
    TypeActivite('marche', 'Marche', Icons.directions_walk,
        met: 3.5, avecDistance: true, avecDenivele: true),
    TypeActivite('marche_rapide', 'Marche rapide', Icons.directions_walk,
        met: 5.0, avecDistance: true, avecDenivele: true),
    TypeActivite('rando', 'Randonnée', Icons.hiking,
        met: 6.0, avecDistance: true, avecDenivele: true),
    TypeActivite('course', 'Course à pied', Icons.directions_run,
        met: 9.8, avecDistance: true, avecDenivele: true),
    TypeActivite('trail', 'Trail', Icons.terrain,
        met: 9.0, avecDistance: true, avecDenivele: true),
    TypeActivite('velo', 'Vélo', Icons.directions_bike,
        met: 8.0, avecDistance: true, avecDenivele: true),
    TypeActivite('vtt', 'VTT', Icons.pedal_bike,
        met: 8.5, avecDistance: true, avecDenivele: true),
    TypeActivite('natation', 'Natation', Icons.pool, met: 7.0),
    TypeActivite('musculation', 'Musculation', Icons.fitness_center,
        met: 5.0),
    TypeActivite('hiit', 'HIIT / Cardio', Icons.local_fire_department,
        met: 8.0),
    TypeActivite(
        'yoga', 'Yoga / Pilates', Icons.self_improvement, met: 3.0),
    TypeActivite('aviron', 'Aviron', Icons.rowing, met: 7.0),
    TypeActivite(
        'tennis', 'Tennis / Badminton', Icons.sports_tennis, met: 7.5),
    TypeActivite(
        'collectif', 'Sport collectif', Icons.sports_soccer, met: 8.0),
    TypeActivite('ski', 'Ski', Icons.ac_unit,
        met: 7.0, avecDistance: true),
    TypeActivite('autre', 'Autre', Icons.more_horiz, met: 4.0),
  ];

  /// Type du catalogue par sa clé, ou null si inconnu.
  static TypeActivite? typeParCle(String cle) {
    for (final t in types) {
      if (t.cle == cle) return t;
    }
    return null;
  }

  /// Libellé affichable d'un type (clé brute si inconnue).
  static String libelle(String cle) => typeParCle(cle)?.libelle ?? cle;

  /// Icône affichable d'un type (générique si inconnue).
  static IconData icone(String cle) =>
      typeParCle(cle)?.icone ?? Icons.more_horiz;

  /// MET ajusté à la vitesse (km/h) pour les types avec table de vitesse.
  /// Les autres types gardent leur MET de base.
  static double metVitesse(String cle, double kmh) {
    if (kmh <= 0) return typeParCle(cle)?.met ?? 0;
    switch (cle) {
      // Compendium : 8 km/h = 8,3 ; 9,7 = 9,8 ; 11,3 = 11 ; 12,9 = 11,8 ;
      // 14,5 = 12,8 ; 16 = 14,5.
      case 'course':
        if (kmh <= 5) return 6.0;
        if (kmh <= 7) return 7.0;
        if (kmh <= 8) return 8.3;
        if (kmh <= 9.7) return 9.8;
        if (kmh <= 11.3) return 11.0;
        if (kmh <= 12.9) return 11.8;
        if (kmh <= 14.5) return 12.8;
        if (kmh <= 16) return 14.5;
        return 16.0;
      // Compendium : 10-16 km/h = 6,8 ; 16-19 = 8 ; 20-25 = 10 ; 25-30 = 12.
      case 'velo':
      case 'vtt':
        if (kmh <= 16) return 6.8;
        if (kmh <= 19) return 8.0;
        if (kmh <= 25) return 10.0;
        if (kmh <= 30) return 12.0;
        return 14.0;
      // Marche : allure ordinaire 3,5 ; soutenue 5,6 km/h = 4,3 ; rapide
      // 6,4 km/h = 5 ; très rapide = 6.
      case 'marche':
      case 'marche_rapide':
        if (kmh < 5.5) return 3.5;
        if (kmh < 6.0) return 4.3;
        if (kmh < 6.5) return 5.0;
        return 6.0;
      default:
        return typeParCle(cle)?.met ?? 0;
    }
  }

  /// Calories dépensées pour une activité, arrondies à la kcal.
  ///
  /// - [poidsKg] : poids de référence (dernière pesée). null = estimation
  ///   sur 70 kg ;
  /// - [distanceKm] : si renseignée avec la durée, le MET est ajusté à la
  ///   vitesse pour les types concernés ;
  /// - [deniveleM] : dénivelé positif, ajoute le travail de montée.
  ///
  /// Renvoie 0 si le type est inconnu, la durée invalide ou l'activité
  /// trop courte (< 1 minute).
  static double calories({
    required String type,
    required double dureeMin,
    double? poidsKg,
    double? distanceKm,
    double? deniveleM,
  }) {
    final t = typeParCle(type);
    if (t == null || dureeMin <= 0 || dureeMin.isNaN) return 0;
    final poids = (poidsKg != null && poidsKg > 0) ? poidsKg : 70.0;
    final heures = dureeMin / 60;
    var met = t.met;
    if (distanceKm != null && distanceKm > 0) {
      met = metVitesse(type, distanceKm / heures);
      if (met == 0) return 0;
    }
    var kcal = met * poids * heures;
    if (deniveleM != null && deniveleM > 0) {
      // Poids (kg) x altitude (m) x g (m/s²) -> joules ; / 4184 -> kcal
      // alimentaires ; / 0,25 -> rendement musculaire d'environ 25 %.
      kcal += poids * deniveleM * 9.81 / 4184 / 0.25;
    }
    return kcal.roundToDouble();
  }

  /// Calories recalculées d'une activité enregistrée, par exemple quand
  /// le poids de référence a changé. Renvoie la valeur stockée si le type
  /// est inconnu.
  static double recalcul(ActiviteSport a, double? poidsKg) =>
      calories(
        type: a.type,
        dureeMin: a.dureeMin,
        poidsKg: poidsKg,
        distanceKm: a.distanceKm,
        deniveleM: a.deniveleM,
      );
}
