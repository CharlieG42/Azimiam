import 'valeurs.dart';

/// Une pesée : poids corporel à une date donnée (une par jour au plus).
class Pesee {
  final int? id;
  final DateTime jour;
  final double kg;

  const Pesee({this.id, required this.jour, required this.kg});
}

/// Total nutritionnel d'une journée (agrégé sur tous les repas du jour).
class TotalJour {
  final DateTime jour;
  final ValeursNutritionnelles valeurs;

  const TotalJour(this.jour, this.valeurs);
}
