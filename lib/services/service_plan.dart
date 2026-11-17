import '../models/repas.dart';
import '../models/valeurs.dart';
import 'service_nutrition.dart';

/// Ligne d'un plan : un aliment de la base locale + une quantité ajustée.
class LigneSuggeree {
  final String nom;
  final double grammes;
  final ValeursNutritionnelles pour100;

  const LigneSuggeree({
    required this.nom,
    required this.grammes,
    required this.pour100,
  });

  ValeursNutritionnelles get valeurs => pour100.pour(grammes);
}

/// Repas proposé pour un type de la journée.
class RepasSuggere {
  final String type;
  final List<LigneSuggeree> lignes;

  const RepasSuggere({required this.type, required this.lignes});

  ValeursNutritionnelles get total =>
      lignes.fold(ValeursNutritionnelles.vide, (acc, l) => acc.ajouter(l.valeurs));
}

/// Génération d'un plan nutritionnel pour une journée, à partir des
/// objectifs quotidiens et de la mini-base locale.
///
/// Chaque type de repas a plusieurs variantes (gabarits) ; la variante
/// retenue dépend du jour de l'année (rotation déterministe, le plan
/// change donc de jour en jour). Les quantités de chaque gabarit sont
/// ensuite mises à l'échelle pour coller à la part calorique du repas.
///
/// Pur Dart : testable unitairement.
class ServicePlan {
  /// Répartition des apports caloriques sur la journée.
  static const Map<String, double> repartition = {
    'Petit-déjeuner': 0.25,
    'Déjeuner': 0.35,
    'Collation': 0.10,
    'Dîner': 0.30,
  };

  /// Gabarits par type de repas : liste de variantes, chaque variante étant
  /// une liste de (nom d'aliment de la base, grammes de référence).
  static final Map<String, List<List<(String, double)>>> modeles = {
    'Petit-déjeuner': [
      [('Muesli', 60), ('Lait demi-écrémé', 250), ('Banane', 120)],
      [('Œuf cuit', 100), ('Pain de mie', 60), ('Orange', 150)],
      [('Fromage blanc', 200), ('Muesli', 40), ('Fraises', 120)],
    ],
    'Déjeuner': [
      [('Poulet grillé', 120), ('Riz blanc cuit', 150), ('Huile d\'olive', 10), ('Brocoli cuit', 150)],
      [('Steak haché 5 %', 120), ('Pâtes cuites', 160), ('Huile d\'olive', 5), ('Tomate', 100)],
      [('Thon en boîte à l\'eau', 100), ('Semoule cuite', 180), ('Huile d\'olive', 5), ('Carottes crues', 100)],
      [('Lentilles cuites', 200), ('Riz blanc cuit', 100), ('Huile d\'olive', 5)],
    ],
    'Collation': [
      [('Yaourt nature', 150), ('Pomme', 150)],
      [('Amandes', 25), ('Orange', 150)],
      [('Fromage blanc', 150), ('Banane', 100)],
    ],
    'Dîner': [
      [('Saumon cuit', 120), ('Pommes de terre cuites', 200), ('Huile d\'olive', 5), ('Épinards cuits', 100)],
      [('Filet de porc', 130), ('Quinoa cuit', 150), ('Huile d\'olive', 5), ('Courgette cuite', 150)],
      [('Cabillaud', 150), ('Riz blanc cuit', 120), ('Huile d\'olive', 5), ('Poivron', 100)],
      [('Tofu', 150), ('Pâtes cuites', 120), ('Huile d\'olive', 5), ('Champignons de Paris', 100)],
    ],
  };

  /// Plan complet d'une journée pour les [objectifs] donnés.
  /// [date] fixe la variante retenue (aujourd'hui par défaut).
  static List<RepasSuggere> planDuJour(
    ValeursNutritionnelles objectifs, {
    DateTime? date,
  }) {
    final datePlan = date ?? DateTime.now();
    final debutAnnee = DateTime(datePlan.year, 1, 1);
    final numeroJour = datePlan.difference(debutAnnee).inDays;

    final repas = <RepasSuggere>[];
    for (final type in typesRepas) {
      final part = repartition[type] ?? 0.25;
      final kcalCible = objectifs.kcal * part;
      final variantes = modeles[type] ?? const [];
      if (variantes.isEmpty) continue;
      final modele = variantes[numeroJour % variantes.length];

      final lignesBase = <LigneSuggeree>[];
      var kcalBase = 0.0;
      for (final (nom, grammes) in modele) {
        final aliment = ServiceNutrition.retrouve(nom);
        if (aliment == null) continue;
        final ligne = LigneSuggeree(
          nom: aliment.nom,
          grammes: grammes,
          pour100: aliment.valeurs,
        );
        lignesBase.add(ligne);
        kcalBase += ligne.valeurs.kcal;
      }
      if (lignesBase.isEmpty || kcalBase <= 0) continue;

      var facteur = kcalCible / kcalBase;
      if (facteur < 0.4) facteur = 0.4;
      if (facteur > 2.5) facteur = 2.5;

      final lignes = lignesBase
          .map((l) => LigneSuggeree(
                nom: l.nom,
                grammes: ((l.grammes * facteur / 5).round() * 5)
                    .clamp(5, 500)
                    .toDouble(),
                pour100: l.pour100,
              ))
          .toList();
      repas.add(RepasSuggere(type: type, lignes: lignes));
    }
    return repas;
  }

  /// Total nutritionnel d'un plan complet.
  static ValeursNutritionnelles totalPlan(List<RepasSuggere> plan) => plan
      .fold(ValeursNutritionnelles.vide, (acc, r) => acc.ajouter(r.total));
}
