import 'dart:convert';

import 'repas.dart';
import 'valeurs.dart';

/// Un repas favori : snapshot des lignes, recréable en un appui.
class FavoriRepas {
  final int? id;
  final String nom;
  final String type;
  final DateTime creeLe;
  final List<LigneRepas> lignes;

  const FavoriRepas({
    this.id,
    required this.nom,
    required this.type,
    required this.creeLe,
    required this.lignes,
  });

  /// Total nutritionnel du favori.
  ValeursNutritionnelles get total => lignes.fold(
      ValeursNutritionnelles.vide, (acc, l) => acc.ajouter(l.valeurs));

  /// Empreinte de comparaison : deux repas sont "le même favori" s'ils ont
  /// le même type et les mêmes lignes (nom + grammes).
  String get empreinte => empreinteLignes(type, lignes);

  static String empreinteLignes(String type, List<LigneRepas> lignes) {
    final parts = lignes
        .map((l) => '${l.nom}|${l.grammes.toStringAsFixed(1)}')
        .toList()
      ..sort();
    return '$type|${parts.join(';')}';
  }

  // ------------------------------------------------- Sérialisation JSON

  static String lignesToJson(List<LigneRepas> lignes) =>
      jsonEncode(lignes.map(ligneToJson).toList());

  static List<LigneRepas> lignesFromJson(String texte) =>
      (jsonDecode(texte) as List<dynamic>)
          .map((e) => ligneFromJson(e as Map<String, dynamic>))
          .toList();

  static Map<String, dynamic> ligneToJson(LigneRepas l) => {
        'nom': l.nom,
        'grammes': l.grammes,
        'kcal100': l.pour100.kcal,
        'prot100': l.pour100.proteines,
        'gluc100': l.pour100.glucides,
        'lip100': l.pour100.lipides,
        'source': l.source,
        'reconnu': l.reconnu,
      };

  static LigneRepas ligneFromJson(Map<String, dynamic> j) => LigneRepas(
        nom: j['nom'] as String,
        grammes: (j['grammes'] as num).toDouble(),
        pour100: ValeursNutritionnelles(
          kcal: (j['kcal100'] as num).toDouble(),
          proteines: (j['prot100'] as num).toDouble(),
          glucides: (j['gluc100'] as num).toDouble(),
          lipides: (j['lip100'] as num).toDouble(),
        ),
        source: (j['source'] as String?) ?? 'manuel',
        reconnu: (j['reconnu'] as bool?) ?? true,
      );
}

/// Empreinte d'un repas du journal (pour savoir s'il est déjà en favori).
String empreinteRepas(Repas repas) =>
    FavoriRepas.empreinteLignes(repas.type, repas.lignes);
