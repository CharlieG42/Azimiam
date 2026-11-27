import 'package:flutter/foundation.dart';

import '../services/service_base.dart';

/// État du suivi d'hydratation (v0.7.9) : eau bue aujourd'hui et
/// historique des 7 derniers jours, alimenté par les boutons de la
/// carte d'hydratation de l'accueil.
class Hydratation extends ChangeNotifier {
  final ServiceBase _base = ServiceBase.instance;

  /// Eau bue aujourd'hui, en millilitres.
  int mlJour = 0;

  /// Eau bue par jour des 7 derniers jours (clé = jour civil à minuit,
  /// valeur en mL ; jours sans saisie absents de la carte).
  Map<DateTime, int> derniers7 = {};

  /// Recharge aujourd'hui et les 7 derniers jours. Silencieux en cas
  /// d'erreur (base indisponible en tests widget) : l'hydratation ne
  /// doit jamais bloquer l'écran d'accueil.
  Future<void> charger() async {
    try {
      mlJour = await _base.eauJour(DateTime.now());
      derniers7 = await _base.historiqueEau(7);
    } catch (_) {
      // Base indisponible : on garde les valeurs déjà chargées.
    }
    notifyListeners();
  }

  /// Ajuste l'eau d'aujourd'hui de [ml] millilitres (négatif permis pour
  /// corriger une erreur de saisie) puis recharge l'état.
  Future<void> ajuster(int ml) async {
    try {
      await _base.ajusterEau(DateTime.now(), ml);
      await charger();
    } catch (_) {
      // Base indisponible (tests) : l'affichage ne change pas.
    }
  }
}
