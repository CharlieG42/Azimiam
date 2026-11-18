import 'package:flutter/foundation.dart';

import '../models/favori.dart';
import '../models/repas.dart';
import '../models/valeurs.dart';
import '../services/service_base.dart';
import '../services/service_reglages.dart';

/// État du journal : journée affichée, repas enregistrés, favoris, réglages.
class Journal extends ChangeNotifier {
  final ServiceBase _base = ServiceBase.instance;

  DateTime jour = DateTime.now();
  List<Repas> repas = [];
  List<FavoriRepas> favoris = [];
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
      favoris = await _base.tousLesFavoris();
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

  // ------------------------------------------------------------ Favoris

  /// Vrai si un favori a la même empreinte (type + lignes) que [repas].
  bool estFavori(Repas repas) =>
      favoris.any((f) => f.empreinte == empreinteRepas(repas));

  /// Ajoute [repas] aux favoris sous le nom [nom] (copie des lignes).
  Future<void> ajouterFavori(Repas repas, String nom) async {
    await _base.ajouterFavori(FavoriRepas(
      nom: nom,
      type: repas.type,
      creeLe: DateTime.now(),
      lignes: _copieLignes(repas.lignes),
    ));
    await charger();
  }

  /// Retire le favori d'empreinte identique à [repas], s'il existe.
  Future<void> retirerFavori(Repas repas) async {
    final existant = favoris
        .where((f) => f.empreinte == empreinteRepas(repas))
        .toList();
    for (final f in existant) {
      if (f.id != null) await _base.supprimerFavori(f.id!);
    }
    await charger();
  }

  Future<void> supprimerFavori(int id) async {
    await _base.supprimerFavori(id);
    await charger();
  }

  /// Recrée aujourd'hui un repas à partir d'un favori.
  Future<void> recreerFavori(FavoriRepas favori) async {
    await ajouter(Repas(
      prisLe: DateTime.now(),
      type: favori.type,
      lignes: _copieLignes(favori.lignes),
    ));
  }

  static List<LigneRepas> _copieLignes(List<LigneRepas> lignes) => lignes
      .map((l) => LigneRepas(
            nom: l.nom,
            grammes: l.grammes,
            pour100: l.pour100,
            source: l.source,
            reconnu: l.reconnu,
          ))
      .toList();
}
