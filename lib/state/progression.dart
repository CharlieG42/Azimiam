import 'package:flutter/foundation.dart';

import '../models/progression.dart';
import '../services/service_base.dart';
import '../services/service_reglages.dart';

/// État de l'écran Progression : pesées, totaux journaliers, réglages.
class Progression extends ChangeNotifier {
  final ServiceBase _base = ServiceBase.instance;

  /// Pesées, de la plus récente à la plus ancienne.
  List<Pesee> pesees = [];

  /// Totaux nutritionnels des 90 derniers jours (jours avec repas uniquement).
  List<TotalJour> totaux = [];

  Reglages reglages = const Reglages();
  bool enChargement = false;
  String? erreur;

  /// Pesée la plus récente, ou null.
  Pesee? get dernier => pesees.isEmpty ? null : pesees.first;

  Future<void> charger() async {
    enChargement = true;
    erreur = null;
    notifyListeners();
    try {
      reglages = await ServiceReglages.charger();
      pesees = await _base.historiquePesees();
      final maintenant = DateTime.now();
      totaux = await _base.totauxParJour(
        maintenant.subtract(const Duration(days: 90)),
        maintenant,
      );
    } catch (e) {
      erreur = e.toString();
    }
    enChargement = false;
    notifyListeners();
  }

  /// Enregistre la pesée du jour (remplace celle du même jour si existe).
  Future<void> ajouterPesee(double kg, DateTime jour) async {
    await _base.ajouterPesee(jour, kg);
    await charger();
  }

  Future<void> supprimerPesee(int id) async {
    await _base.supprimerPesee(id);
    await charger();
  }
}
