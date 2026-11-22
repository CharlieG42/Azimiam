import 'package:flutter/foundation.dart';

import '../models/activite.dart';
import '../services/service_base.dart';

/// État de l'écran Activités : déclarations sportives et totaux.
class Activites extends ChangeNotifier {
  final ServiceBase _base = ServiceBase.instance;

  /// Activités, de la plus récente à la plus ancienne.
  List<ActiviteSport> liste = [];

  bool enChargement = false;
  String? erreur;

  Future<void> charger() async {
    enChargement = true;
    erreur = null;
    notifyListeners();
    try {
      liste = await _base.listeActivites();
    } catch (e) {
      erreur = e.toString();
    }
    enChargement = false;
    notifyListeners();
  }

  /// Enregistre une nouvelle activité déclarée.
  Future<void> ajouter(ActiviteSport activite) async {
    await _base.enregistrerActivite(activite);
    await charger();
  }

  /// Supprime une activité (déjà retirée de l'interface par le swipe).
  Future<void> supprimer(int id) async {
    await _base.supprimerActivite(id);
    await charger();
  }

  /// Activités des 7 derniers jours (borne : même heure qu'aujourd'hui).
  List<ActiviteSport> get derniers7Jours {
    final limite = DateTime.now().subtract(const Duration(days: 7));
    return liste.where((a) => a.moment.isAfter(limite)).toList();
  }

  /// Calories sportives dépensées sur les 7 derniers jours.
  double get kcal7Jours =>
      derniers7Jours.fold(0.0, (acc, a) => acc + a.kcal);

  /// Activités groupées par jour, du plus récent au plus ancien.
  ///
  /// Chaque élément : date du jour + activités de ce jour (ordre inverse
  /// chronologique, comme stockées).
  List<MapEntry<DateTime, List<ActiviteSport>>> get parJour {
    final groupes = <String, MapEntry<DateTime, List<ActiviteSport>>>{};
    for (final a in liste) {
      final cle = ServiceBase.cleJour(a.moment);
      final groupe = groupes.putIfAbsent(
          cle, () => MapEntry(DateTime(a.moment.year, a.moment.month, a.moment.day), <ActiviteSport>[]));
      groupe.value.add(a);
    }
    // Conserver l'ordre de la liste (moment décroissant) pour les groupes.
    return groupes.values.toList();
  }
}
