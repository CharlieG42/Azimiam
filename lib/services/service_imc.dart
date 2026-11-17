import '../models/profil.dart';

/// Une tranche d'IMC (classification OMS) avec sa borne inférieure.
class TrancheImc {
  final double min;
  final String libelle;
  const TrancheImc(this.min, this.libelle);
}

/// Objectifs nutritionnels calculés automatiquement.
class ObjectifsAuto {
  final double kcal;
  final double proteines;
  final double glucides;
  final double lipides;

  const ObjectifsAuto({
    required this.kcal,
    required this.proteines,
    required this.glucides,
    required this.lipides,
  });
}

/// Calculs liés au profil : IMC, métabolisme de base (Mifflin-St Jeor),
/// dépense énergétique (TDEE), poids idéal (Devine) et objectifs
/// caloriques/macros automatiques.
///
/// Pur Dart (aucun accès plateforme) : testable unitairement.
class ServiceImc {
  /// Tranches OMS, de la plus basse à la plus haute.
  static const List<TrancheImc> tranches = [
    TrancheImc(0, 'Dénutrition'),
    TrancheImc(16.5, 'Insuffisance pondérale'),
    TrancheImc(18.5, 'Corpulence normale'),
    TrancheImc(25, 'Surpoids'),
    TrancheImc(30, 'Obésité modérée'),
    TrancheImc(35, 'Obésité sévère'),
    TrancheImc(40, 'Obésité morbide'),
  ];

  /// IMC = poids (kg) / taille² (m). [tailleCm] en centimètres.
  static double imc(double poidsKg, double tailleCm) {
    final tailleM = tailleCm / 100;
    return poidsKg / (tailleM * tailleM);
  }

  /// Tranche OMS correspondant à une valeur d'IMC.
  static TrancheImc categorie(double valeur) {
    var resultat = tranches.first;
    for (final tranche in tranches) {
      if (valeur >= tranche.min) resultat = tranche;
    }
    return resultat;
  }

  /// Métabolisme de base (Mifflin-St Jeor), en kcal/jour.
  static double metabolismeBase({
    required String sexe,
    required int age,
    required double poidsKg,
    required double tailleCm,
  }) {
    final base = 10 * poidsKg + 6.25 * tailleCm - 5 * age;
    return sexe == 'h' ? base + 5 : base - 161;
  }

  /// Multiplicateur d'activité appliqué au métabolisme de base.
  static double facteurActivite(String activite) {
    switch (activite) {
      case 'leger':
        return 1.375;
      case 'modere':
        return 1.55;
      case 'actif':
        return 1.725;
      case 'tres_actif':
        return 1.9;
      case 'sedentaire':
      default:
        return 1.2;
    }
  }

  /// Dépense énergétique totale journalière (TDEE), en kcal.
  /// Renvoie 0 si le profil est incomplet.
  static double tdee(Profil profil, double poidsKg) {
    if (!profil.complet) return 0;
    final mb = metabolismeBase(
      sexe: profil.sexe,
      age: profil.age!,
      poidsKg: poidsKg,
      tailleCm: profil.tailleCm!,
    );
    return mb * facteurActivite(profil.activite);
  }

  /// Objectif calorique journalier selon l'objectif de poids :
  /// maintien = TDEE, perte = TDEE - 500 kcal (avec plancher de sécurité
  /// 1 200 kcal pour une femme, 1 500 kcal pour un homme), prise = TDEE + 300.
  static double caloriesCible(double tdeeValeur, String objectif,
      {String sexe = 'h'}) {
    switch (objectif) {
      case 'perte':
        final plancher = sexe == 'f' ? 1200.0 : 1500.0;
        final valeur = tdeeValeur - 500;
        return valeur < plancher ? plancher : valeur;
      case 'prise':
        return tdeeValeur + 300;
      case 'maintien':
      default:
        return tdeeValeur;
    }
  }

  /// Poids idéal selon la formule de Devine (approximation usuelle).
  static double poidsIdeal(double tailleCm, String sexe) {
    final pouces = tailleCm / 2.54;
    final base = sexe == 'h' ? 50 : 45.5;
    return base + 2.3 * (pouces - 60);
  }

  /// Objectifs complets (kcal + macros) calculés automatiquement.
  ///
  /// - protéines : 2 g/kg de poids de référence (poids cible si objectif
  ///   perte/prise avec cible, sinon poids actuel) ;
  /// - lipides : 30 % des kcal ;
  /// - glucides : le reste des kcal, à défaut 0.
  static ObjectifsAuto objectifsAuto(Profil profil, double poidsKg) {
    final depense = tdee(profil, poidsKg);
    final kcal = caloriesCible(depense, profil.objectif, sexe: profil.sexe);
    final poidsReference =
        (profil.objectif != 'maintien' && profil.poidsCibleKg != null && profil.poidsCibleKg! > 0)
            ? profil.poidsCibleKg!
            : poidsKg;
    final proteines = 2.0 * poidsReference;
    final lipides = kcal * 0.30 / 9;
    var glucides = (kcal - 4 * proteines - 9 * lipides) / 4;
    if (glucides < 0) glucides = 0;
    return ObjectifsAuto(
      kcal: kcal,
      proteines: proteines,
      glucides: glucides,
      lipides: lipides,
    );
  }

  /// Nombre de semaines estimé pour atteindre le poids cible
  /// (1 kg de masse grasse ≈ 7 700 kcal). 0 si pas de cible atteignable.
  static int semainesEstimees(Profil profil, double poidsActuel) {
    if (profil.objectif == 'maintien' || profil.poidsCibleKg == null) {
      return 0;
    }
    final delta = (profil.poidsCibleKg! - poidsActuel).abs();
    if (delta < 0.1 || !profil.complet) return 0;
    final depense = tdee(profil, poidsActuel);
    final cible = caloriesCible(depense, profil.objectif, sexe: profil.sexe);
    final ecart = (depense - cible).abs();
    if (ecart < 50) return 0;
    // delta kg x 7700 kcal/kg / ecart kcal/j / 7 j : calcul ordonné pour
    // garder les valeurs entières exactes en virgule flottante.
    return (delta * 7700 / ecart / 7).ceil();
  }
}
