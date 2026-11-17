/// Profil utilisateur : morphologie, activité physique et objectif de poids.
///
/// Sert au calcul de l'IMC, du métabolisme de base et des objectifs
/// caloriques automatiques (voir `services/service_imc.dart`).
class Profil {
  /// Taille en cm (null = non renseignée).
  final double? tailleCm;

  /// Âge en années (null = non renseigné).
  final int? age;

  /// Sexe : 'h' ou 'f'.
  final String sexe;

  /// Niveau d'activité : une clé de [activites].
  final String activite;

  /// Objectif de poids : une clé de [objectifs].
  final String objectif;

  /// Poids cible en kg (null = pas de cible, ex. maintien).
  final double? poidsCibleKg;

  const Profil({
    this.tailleCm,
    this.age,
    this.sexe = 'f',
    this.activite = 'modere',
    this.objectif = 'maintien',
    this.poidsCibleKg,
  });

  /// Niveaux d'activité reconnus, avec libellé affiché.
  static const Map<String, String> activites = {
    'sedentaire': 'Sédentaire',
    'leger': 'Légèrement actif',
    'modere': 'Activité modérée',
    'actif': 'Actif',
    'tres_actif': 'Très actif',
  };

  /// Objectifs de poids reconnus, avec libellé affiché.
  static const Map<String, String> objectifs = {
    'maintien': 'Maintien',
    'perte': 'Perte',
    'prise': 'Prise',
  };

  /// Vrai si taille et âge sont renseignés (calculs possibles).
  bool get complet => tailleCm != null && tailleCm! > 0 && age != null;
}
