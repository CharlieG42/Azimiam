import 'package:flutter/foundation.dart';

import '../models/repas.dart';
import '../models/valeurs.dart';
import '../services/service_base.dart';
import '../services/service_reglages.dart';

/// État du journal : journée affichée, repas enregistrés, réglages.
class Journal extends ChangeNotifier {
  final ServiceBase _base = ServiceBase.instance;

  DateTime jour = DateTime.now();
  List<Repas> repas = [];
  Reglages reglages = const Reglages();
  bool enChargement = false;
  String? erreur;

  /// Total nutritionnel de la journée affichée.
  ValeursNutritionnelles get total => repas.fold(
        ValeursNutritionnelles.vide,
        (acc, repas) => acc.ajouter(repas.total),
      );

  Future<void> charger() async {
    enChargement = true;
    erreur = null;
    notifyListeners();
    try {
      reglages = await ServiceReglages.charger();
      repas = await _base.repasDuJour(jour);
    } catch (e) {
      erreur = e.toString();
    }
    enChargement = false;
    notifyListeners();
  }

  Future<void> changerJour(DateTime nouveauJour) async {
    jour = nouveauJour;
    await charger();
  }

  Future<void> ajouter(Repas repas) async {
    await _base.enregistrer(repas);
    await charger();
  }

  Future<void> supprimer(int idRepas) async {
    await _base.supprimer(idRepas);
    await charger();
  }
}
