import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/activite.dart';
import '../services/service_base.dart';
import '../services/service_sante.dart';

/// État de l'écran Activités : déclarations sportives et totaux.
///
/// v0.7.0 : porte aussi les compteurs pas/étages du jour et l'import
/// automatique des séances depuis Health Connect (ex. montre Garmin).
class Activites extends ChangeNotifier {
  final ServiceBase _base = ServiceBase.instance;

  /// Source santé injectable (simulée dans les tests, Health Connect
  /// en production par défaut).
  final SourceSante? source;

  /// Activités, de la plus récente à la plus ancienne.
  List<ActiviteSport> liste = [];

  bool enChargement = false;
  String? erreur;

  /// Compteurs pas/étages du jour courant, lus dans Health Connect
  /// (null si indisponibles : pas d'autorisation, pas de données…).
  CompteursJour? compteursJour;

  /// Message discret d'information sur le dernier import (ex. « 2 séance(s)
  /// importée(s) depuis Health Connect ») ; null quand rien à signaler.
  String? infoImport;

  Activites({SourceSante? sourceSante})
      : source = sourceSante ?? SourceSanteHealth();

  /// Rafraîchit les compteurs pas/étages du jour depuis la source santé.
  /// Silencieux : sans autorisation ni données, rien ne s'affiche.
  Future<void> rafraichirCompteurs() async {
    if (source == null) return;
    final compte = await source!.compteursJour(DateTime.now());
    if (compte != compteursJour) {
      compteursJour = compte;
      notifyListeners();
    }
  }

  /// Import automatique des séances récentes, appelé au démarrage de
  /// l'application. Ne demande rien : sans autorisation Health Connect
  /// accordée, il ne fait rien, et une erreur ne remonte jamais.
  Future<void> importAuto({SourceSante? sourceSante, int jours = 30}) async {
    try {
      await importerDepuisSante(sourceSante ?? source,
          jours: jours, silencieux: true);
    } catch (_) {
      // L'import automatique ne remonte jamais d'erreur à l'utilisateur.
    }
  }

  /// Importe les séances des [jours] derniers jours depuis la source
  /// santé, sans créer de doublon (dédoublonnage par clé externe).
  ///
  /// [silencieux] : true au démarrage (aucun message en cas d'absence de
  /// nouvelles séances), false quand l'utilisateur demande l'import.
  Future<void> importerDepuisSante(SourceSante? sourceSante,
      {int jours = 30, bool silencieux = false}) async {
    final source = sourceSante ?? this.source;
    if (source == null) return;
    try {
      // Sans autorisation accordée, l'import s'arrête : silencieux au
      // démarrage, message explicite sur demande explicite.
      final autorise = await source.demanderAutorisation();
      if (!autorise) {
        if (!silencieux) {
          infoImport =
              'Import impossible : autorisez Health Connect pour Azimiam';
          notifyListeners();
        }
        return;
      }
      final fin = DateTime.now();
      final debut = fin.subtract(Duration(days: jours));
      final candidates = await source.seancesEntre(debut, fin);
      final connues = await _base.clesExternesActivites();
      final nouvelles = seancesNouvelles(candidates, connues);
      for (final seance in nouvelles) {
        await _base.enregistrerActivite(enActivite(seance));
      }
      if (nouvelles.isNotEmpty) {
        infoImport =
            '${nouvelles.length} séance(s) importée(s) depuis Health Connect';
        await charger();
      } else if (!silencieux) {
        infoImport = 'Aucune nouvelle séance à importer';
        notifyListeners();
      }
      await rafraichirCompteurs();
    } catch (e) {
      if (!silencieux) {
        erreur = e.toString();
        notifyListeners();
      }
    }
  }

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

  /// Calories sportives dépensées le [jour] demandé (v0.7.2) : somme des
  /// séances de ce jour civil. Créditée au budget calorique de l'accueil
  /// (objectif augmenté d'autant le jour affiché).
  double depenseJour(DateTime jour) {
    double total = 0;
    for (final a in liste) {
      if (a.moment.year == jour.year &&
          a.moment.month == jour.month &&
          a.moment.day == jour.day) {
        total += a.kcal;
      }
    }
    return total;
  }

  /// Dépense à créditer au budget du [jour] affiché (v0.7.3) : le plus
  /// élevé des calories actives du jour courant (Health Connect, déjà
  /// mesurées par la montre) et des kcal des séances de ce jour.
  ///
  /// Les calories actives incluent déjà celles des séances : prendre le
  /// max évite de compter deux fois la même sortie, et les séances (kcal
  /// montre ou estimation MET) prennent le relais si Health Connect est
  /// muet ou pour un jour passé feuilleté (compteurs lus au jour courant).
  double depenseBudget(DateTime jour) {
    final kcalSeances = depenseJour(jour);
    final compteurs = compteursJour;
    if (compteurs == null) return kcalSeances;
    final maintenant = DateTime.now();
    if (jour.year != maintenant.year ||
        jour.month != maintenant.month ||
        jour.day != maintenant.day) {
      return kcalSeances;
    }
    return math.max(kcalSeances, compteurs.kcalActives);
  }

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
