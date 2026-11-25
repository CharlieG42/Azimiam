import 'valeurs.dart';

/// Types de repas disponibles, dans l'ordre d'une journée.
const List<String> typesRepas = [
  'Petit-déjeuner',
  'Déjeuner',
  'Collation',
  'Dîner',
];

/// Une ligne d'aliment dans un repas, ex. « Poulet grillé, 150 g ».
///
/// [pour100] contient les valeurs pour 100 g ; les valeurs réelles se
/// calculent via [valeurs]. La ligne est mutable : l'utilisateur la corrige
/// après l'analyse IA (quantité, nom, valeurs).
class LigneRepas {
  String nom;
  double grammes;
  ValeursNutritionnelles pour100;

  /// Origine de la ligne : 'ia' (photo), 'base' (mini-base), 'manuel'.
  String source;

  /// Vrai si l'aliment a été reconnu dans la base locale (valeurs fiables).
  bool reconnu;

  LigneRepas({
    required this.nom,
    required this.grammes,
    required this.pour100,
    this.source = 'manuel',
    this.reconnu = true,
  });

  /// Valeurs nutritionnelles réelles pour la quantité saisie.
  ValeursNutritionnelles get valeurs => pour100.pour(grammes);
}

/// Un repas complet : type, date/heure, photo éventuelle et lignes d'aliments.
class Repas {
  final int? id;
  final DateTime prisLe;
  final String type;
  final String? photo;
  final List<LigneRepas> lignes;

  Repas({
    this.id,
    required this.prisLe,
    required this.type,
    this.photo,
    List<LigneRepas>? lignes,
  }) : lignes = lignes ?? [];

  /// Total nutritionnel du repas.
  ValeursNutritionnelles get total => lignes.fold(
      ValeursNutritionnelles.vide, (acc, l) => acc.ajouter(l.valeurs));
}

/// Le jour d'[instant], à minuit : sert de clé de journée, indépendamment
/// de l'heure.
DateTime dateSeule(DateTime instant) =>
    DateTime(instant.year, instant.month, instant.day);

/// Le jour demandé, à l'heure qu'il est au moment de l'appel.
///
/// Utilisé pour enregistrer un repas sur la journée AFFICHÉE (qui peut
/// être passée ou future) tout en gardant une heure plausible, plutôt que
/// de dater le repas « maintenant » quoi qu'il arrive. Si [jour] est null,
/// renvoie simplement l'instant présent.
DateTime instantPour(DateTime? jour) {
  final maintenant = DateTime.now();
  if (jour == null) return maintenant;
  return DateTime(
    jour.year,
    jour.month,
    jour.day,
    maintenant.hour,
    maintenant.minute,
    maintenant.second,
  );
}
