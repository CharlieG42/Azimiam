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

  /// Minutes de sommeil par jour de réveil sur les 7 derniers jours
  /// (v0.8.0) : la nuit de mardi à mercredi compte pour mercredi.
  /// Seuls les jours connus sont présents.
  Map<DateTime, int> sommeil7 = {};

  /// FC au repos par jour civil sur les 7 derniers jours (v0.8.0),
  /// en bpm. Seuls les jours connus sont présents.
  Map<DateTime, int> fcRepos7 = {};

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
      // Poids de référence pour l'estimation MET des séances sans
      // calories fournies par la montre (v0.7.5) : dernière pesée.
      double? poidsReference;
      try {
        poidsReference = await _base.dernierPoids();
      } catch (_) {
        poidsReference = null;
      }
      for (final seance in nouvelles) {
        await _base
            .enregistrerActivite(enActivite(seance, poidsKg: poidsReference));
      }
      if (nouvelles.isNotEmpty) {
        infoImport =
            '${nouvelles.length} séance(s) importée(s) depuis Health Connect';
        await charger();
      } else if (!silencieux) {
        infoImport = 'Aucune nouvelle séance à importer';
        notifyListeners();
      }
      // Pesées de Santé Connect (v0.7.5) : ne remplissent que les jours
      // sans pesée — une saisie manuelle n'est jamais écrasée. L'échec
      // de l'import du poids ne remonte jamais.
      try {
        final pesees = await source.peseesEntre(debut, fin);
        final aImporter = peseesAImporter(
          poidsParJour(pesees),
          (await _base.historiquePesees())
              .map((p) => DateTime(p.jour.year, p.jour.month, p.jour.day))
              .toSet(),
        );
        for (final e in aImporter.entries) {
          await _base.ajouterPesee(e.key, e.value);
        }
        if (aImporter.isNotEmpty) {
          infoImport = (infoImport == null || infoImport!.isEmpty)
              ? '${aImporter.length} pesée(s) santé ajoutée(s)'
              : '${infoImport!} ; ${aImporter.length} pesée(s) santé ajoutée(s)';
          notifyListeners();
        }
      } catch (_) {
        // L'import du poids ne doit jamais bloquer ni alerter.
      }
      // Sommeil et FC au repos de Santé Connect (v0.8.0) : nuits
      // attribuées au jour du réveil, FC au repos quotidienne (repli :
      // FC minimale du jour courant relevée dans les mesures
      // ponctuelles, pour limiter le volume lu — une source qui ne
      // publie pas de FC au repos reste ainsi exploitable). L'échec
      // ne remonte jamais.
      try {
        final sommeil = await source.sommeilEntre(debut, fin);
        final nuits = minutesSommeilParJour(sommeil);
        for (final e in nuits.entries) {
          await _base.majSommeilMinutes(e.key, e.value);
        }
        final fc = fcReposParJour(await source.fcReposEntre(debut, fin));
        final maintenant = DateTime.now();
        final aujourdhui =
            DateTime(maintenant.year, maintenant.month, maintenant.day);
        if (!fc.containsKey(aujourdhui)) {
          final mini = await source.fcMinEntre(aujourdhui, maintenant);
          if (mini != null) fc[aujourdhui] = mini;
        }
        for (final e in fc.entries) {
          await _base.majFcRepos(e.key, e.value);
        }
        if (nuits.isNotEmpty || fc.isNotEmpty) {
          sommeil7 = await _base.historiqueSommeil(7);
          fcRepos7 = await _base.historiqueFcRepos(7);
          notifyListeners();
        }
      } catch (_) {
        // L'import du sommeil ne doit jamais bloquer ni alerter.
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
      // v0.8.0 : suivi du sommeil et de la FC au repos (7 derniers
      // jours). Silencieux : la base peut être indisponible en tests.
      try {
        sommeil7 = await _base.historiqueSommeil(7);
        fcRepos7 = await _base.historiqueFcRepos(7);
      } catch (_) {
        // Base indisponible : suivi du sommeil vide, rien ne bloque.
      }
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

  /// Minutes de sport le [jour] demandé (v0.7.9) : somme des durées des
  /// séances de ce jour civil. Sert à majorer l'objectif d'hydratation
  /// (500 mL par heure d'effort).
  double minutesSportJour(DateTime jour) {
    double total = 0;
    for (final a in liste) {
      if (a.moment.year == jour.year &&
          a.moment.month == jour.month &&
          a.moment.day == jour.day) {
        total += a.dureeMin;
      }
    }
    return total;
  }

  /// Minutes de sommeil de la nuit attribuée au [jour] — le jour du
  /// réveil (v0.8.0) ; null si aucune nuit connue.
  int? sommeilJour(DateTime jour) =>
      sommeil7[DateTime(jour.year, jour.month, jour.day)];

  /// FC au repos du [jour], en bpm (v0.8.0) ; null si inconnue.
  int? fcReposJour(DateTime jour) =>
      fcRepos7[DateTime(jour.year, jour.month, jour.day)];

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
