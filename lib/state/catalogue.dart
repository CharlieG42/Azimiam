import 'package:flutter/foundation.dart';

import '../data/mini_base.dart';
import '../models/valeurs.dart';
import '../services/service_base.dart';
import '../services/service_nutrition.dart';

/// État du catalogue d'aliments : base embarquée (~110 aliments) + les
/// aliments ajoutés par l'utilisateur (table `aliments_perso`), fondus en
/// une seule liste triée, utilisée par la recherche de l'écran d'ajout,
/// le catalogue complet et le rapprochement IA.
class Catalogue extends ChangeNotifier {
  final ServiceBase _base = ServiceBase.instance;

  /// Catalogue complet (base + perso), trié par nom.
  List<Aliment> tous = [];

  /// Aliments ajoutés par l'utilisateur (sous-ensemble de [tous]).
  List<Aliment> perso = [];

  bool enChargement = false;
  String? erreur;

  Future<void> charger() async {
    enChargement = true;
    erreur = null;
    notifyListeners();
    try {
      perso = await _base.listeAlimentsPerso();
      tous = [...BaseAliments.tous, ...perso]..sort(
          (a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()),
        );
    } catch (e) {
      erreur = e.toString();
    }
    enChargement = false;
    notifyListeners();
  }

  /// Ajoute un aliment au catalogue. Renvoie null si tout s'est bien
  /// passé, sinon un message d'erreur lisible (doublon, nom vide…).
  Future<String?> ajouter({
    required String nom,
    required List<String> alias,
    required ValeursNutritionnelles valeurs,
  }) async {
    final nomNet = nom.trim();
    if (nomNet.isEmpty) return 'Donnez un nom à l\'aliment.';
    if (valeurs.kcal <= 0) {
      return 'Les calories pour 100 g doivent être supérieures à 0.';
    }
    // Doublon : base ou perso, même nom normalisé.
    for (final existant in tous) {
      if (ServiceNutrition.normalise(existant.nom) ==
          ServiceNutrition.normalise(nomNet)) {
        return '« $nomNet » est déjà dans le catalogue.';
      }
    }
    final nettoyes = alias
        .map((a) => a.trim())
        .where((a) =>
            a.isNotEmpty &&
            ServiceNutrition.normalise(a) !=
                ServiceNutrition.normalise(nomNet))
        .toList();
    await _base.ajouterAlimentPerso(Aliment(nomNet, nettoyes, valeurs));
    await charger();
    return null;
  }

  /// Supprime un aliment personnalisé (jamais un aliment de la base).
  Future<void> supprimer(Aliment aliment) async {
    if (!aliment.perso || aliment.id == null) return;
    await _base.supprimerAlimentPerso(aliment.id!);
    await charger();
  }
}
