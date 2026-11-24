import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/mini_base.dart';
import '../models/activite.dart';
import '../models/favori.dart';
import '../models/progression.dart';
import '../models/repas.dart';
import '../models/valeurs.dart';
import 'service_export.dart';

/// Base de données locale (SQLite) : repas, lignes d'aliments et pesées.
class ServiceBase {
  static final ServiceBase instance = ServiceBase._();
  ServiceBase._();

  Database? _base;

  Future<Database> get base async => _base ??= await _ouvrir();

  Future<Database> _ouvrir() async {
    final dossier = await getApplicationDocumentsDirectory();
    return openDatabase(
      p.join(dossier.path, 'azimiam.db'),
      version: 5,
      onCreate: (db, version) async {
        await _creerTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS poids(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              jour TEXT NOT NULL UNIQUE,
              kg REAL NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS favoris(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nom TEXT NOT NULL,
              type TEXT NOT NULL,
              cree_le TEXT NOT NULL,
              lignes TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS activites(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              moment TEXT NOT NULL,
              type TEXT NOT NULL,
              duree_min REAL NOT NULL,
              distance_km REAL,
              denivele_m REAL,
              kcal REAL NOT NULL
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS aliments_perso(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nom TEXT NOT NULL,
              alias TEXT NOT NULL DEFAULT '[]',
              kcal100 REAL NOT NULL,
              prot100 REAL NOT NULL,
              gluc100 REAL NOT NULL,
              lip100 REAL NOT NULL,
              cree_le TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  Future<void> _creerTables(Database db) async {
    await db.execute('''
      CREATE TABLE repas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pris_le TEXT NOT NULL,
        type TEXT NOT NULL,
        photo TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE lignes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        repas_id INTEGER NOT NULL,
        nom TEXT NOT NULL,
        grammes REAL NOT NULL,
        kcal100 REAL NOT NULL,
        prot100 REAL NOT NULL,
        gluc100 REAL NOT NULL,
        lip100 REAL NOT NULL,
        source TEXT NOT NULL DEFAULT 'manuel'
      )
    ''');
    await db.execute('''
      CREATE TABLE poids(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jour TEXT NOT NULL UNIQUE,
        kg REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE favoris(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        type TEXT NOT NULL,
        cree_le TEXT NOT NULL,
        lignes TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE activites(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        moment TEXT NOT NULL,
        type TEXT NOT NULL,
        duree_min REAL NOT NULL,
        distance_km REAL,
        denivele_m REAL,
        kcal REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE aliments_perso(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        alias TEXT NOT NULL DEFAULT '[]',
        kcal100 REAL NOT NULL,
        prot100 REAL NOT NULL,
        gluc100 REAL NOT NULL,
        lip100 REAL NOT NULL,
        cree_le TEXT NOT NULL
      )
    ''');
  }

  /// « 2026-11-17 »
  static String cleJour(DateTime d) =>
      '${d.year}-${deux(d.month)}-${deux(d.day)}';

  /// « 2026-11-17 12:30 »
  static String cleInstant(DateTime d) =>
      '${cleJour(d)} ${deux(d.hour)}:${deux(d.minute)}';

  static String deux(int n) => n.toString().padLeft(2, '0');

  /// Enregistre un repas complet et renvoie son id.
  Future<int> enregistrer(Repas repas) async {
    final db = await base;
    final id = await db.insert('repas', {
      'pris_le': cleInstant(repas.prisLe),
      'type': repas.type,
      'photo': repas.photo,
    });
    for (final ligne in repas.lignes) {
      await db.insert('lignes', {
        'repas_id': id,
        'nom': ligne.nom,
        'grammes': ligne.grammes,
        'kcal100': ligne.pour100.kcal,
        'prot100': ligne.pour100.proteines,
        'gluc100': ligne.pour100.glucides,
        'lip100': ligne.pour100.lipides,
        'source': ligne.source,
      });
    }
    return id;
  }

  /// Met à jour un repas existant (type + lignes). L'heure et la photo ne
  /// changent pas : les lignes sont simplement remplacées.
  Future<void> majRepas(Repas repas) async {
    final db = await base;
    final id = repas.id;
    if (id == null) return;
    await db.update(
      'repas',
      {'type': repas.type},
      where: 'id = ?',
      whereArgs: [id],
    );
    await db.delete('lignes', where: 'repas_id = ?', whereArgs: [id]);
    for (final ligne in repas.lignes) {
      await db.insert('lignes', {
        'repas_id': id,
        'nom': ligne.nom,
        'grammes': ligne.grammes,
        'kcal100': ligne.pour100.kcal,
        'prot100': ligne.pour100.proteines,
        'gluc100': ligne.pour100.glucides,
        'lip100': ligne.pour100.lipides,
        'source': ligne.source,
      });
    }
  }

  /// Tous les repas d'une journée, par ordre chronologique.
  Future<List<Repas>> repasDuJour(DateTime jour) async {
    final db = await base;
    final lignesRepas = await db.query(
      'repas',
      where: 'pris_le LIKE ?',
      whereArgs: ['${cleJour(jour)}%'],
      orderBy: 'pris_le',
    );
    return _chargerRepas(db, lignesRepas);
  }

  /// Tous les repas enregistrés (tous jours), pour l'export CSV.
  Future<List<Repas>> tousLesRepas() async {
    final db = await base;
    final lignesRepas = await db.query('repas', orderBy: 'pris_le');
    return _chargerRepas(db, lignesRepas);
  }

  Future<List<Repas>> _chargerRepas(
    Database db,
    List<Map<String, Object?>> lignesRepas,
  ) async {
    final resultats = <Repas>[];
    for (final ligne in lignesRepas) {
      final items = await db.query(
        'lignes',
        where: 'repas_id = ?',
        whereArgs: [ligne['id']],
      );
      resultats.add(Repas(
        id: ligne['id'] as int,
        prisLe: DateTime.parse(ligne['pris_le'] as String),
        type: ligne['type'] as String,
        photo: ligne['photo'] as String?,
        lignes: items
            .map(
              (i) => LigneRepas(
                nom: i['nom'] as String,
                grammes: (i['grammes'] as num).toDouble(),
                pour100: ValeursNutritionnelles(
                  kcal: (i['kcal100'] as num).toDouble(),
                  proteines: (i['prot100'] as num).toDouble(),
                  glucides: (i['gluc100'] as num).toDouble(),
                  lipides: (i['lip100'] as num).toDouble(),
                ),
                source: (i['source'] as String?) ?? 'manuel',
              ),
            )
            .toList(),
      ));
    }
    return resultats;
  }

  Future<void> supprimer(int idRepas) async {
    final db = await base;
    await db.delete('lignes', where: 'repas_id = ?', whereArgs: [idRepas]);
    await db.delete('repas', where: 'id = ?', whereArgs: [idRepas]);
  }

  // ------------------------------------------------------------- Pesées

  /// Enregistre (ou remplace) la pesée d'un jour. Renvoie l'id de la ligne.
  Future<int> ajouterPesee(DateTime jour, double kg) async {
    final db = await base;
    return db.insert(
      'poids',
      {'jour': cleJour(jour), 'kg': kg},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Toutes les pesées, de la plus récente à la plus ancienne.
  Future<List<Pesee>> historiquePesees() async {
    final db = await base;
    final lignes = await db.query('poids', orderBy: 'jour DESC, id DESC');
    return lignes
        .map((l) => Pesee(
              id: l['id'] as int,
              jour: DateTime.parse(l['jour'] as String),
              kg: (l['kg'] as num).toDouble(),
            ))
        .toList();
  }

  /// Poids de la pesée la plus récente, ou null s'il n'y en a aucune.
  Future<double?> dernierPoids() async {
    final db = await base;
    final lignes =
        await db.query('poids', orderBy: 'jour DESC, id DESC', limit: 1);
    if (lignes.isEmpty) return null;
    return (lignes.first['kg'] as num).toDouble();
  }

  Future<void> supprimerPesee(int id) async {
    final db = await base;
    await db.delete('poids', where: 'id = ?', whereArgs: [id]);
  }

  // --------------------------------------------------- Totaux journaliers

  /// Totaux nutritionnels par jour entre [depuis] et [jusqu] (inclus),
  /// triés par jour croissant. Un jour sans repas n'apparaît pas.
  Future<List<TotalJour>> totauxParJour(DateTime depuis, DateTime jusqu) async {
    final db = await base;
    final lignes = await db.rawQuery('''
      SELECT substr(r.pris_le, 1, 10) AS jour,
        SUM(l.kcal100 * l.grammes / 100) AS kcal,
        SUM(l.prot100 * l.grammes / 100) AS prot,
        SUM(l.gluc100 * l.grammes / 100) AS gluc,
        SUM(l.lip100 * l.grammes / 100) AS lip
      FROM repas r JOIN lignes l ON l.repas_id = r.id
      WHERE substr(r.pris_le, 1, 10) BETWEEN ? AND ?
      GROUP BY jour
      ORDER BY jour
    ''', [cleJour(depuis), cleJour(jusqu)]);
    return lignes
        .map((l) => TotalJour(
              DateTime.parse(l['jour'] as String),
              ValeursNutritionnelles(
                kcal: (l['kcal'] as num?)?.toDouble() ?? 0,
                proteines: (l['prot'] as num?)?.toDouble() ?? 0,
                glucides: (l['gluc'] as num?)?.toDouble() ?? 0,
                lipides: (l['lip'] as num?)?.toDouble() ?? 0,
              ),
            ))
        .toList();
  }

  // ----------------------------------------------------------- Activités

  /// Enregistre une activité sportive et renvoie son id.
  Future<int> enregistrerActivite(ActiviteSport activite) async {
    final db = await base;
    return db.insert('activites', {
      'moment': cleInstant(activite.moment),
      'type': activite.type,
      'duree_min': activite.dureeMin,
      'distance_km': activite.distanceKm,
      'denivele_m': activite.deniveleM,
      'kcal': activite.kcal,
    });
  }

  /// Toutes les activités, de la plus récente à la plus ancienne.
  Future<List<ActiviteSport>> listeActivites() async {
    final db = await base;
    final lignes =
        await db.query('activites', orderBy: 'moment DESC, id DESC');
    return lignes
        .map((l) => ActiviteSport(
              id: l['id'] as int,
              moment: DateTime.parse(l['moment'] as String),
              type: l['type'] as String,
              dureeMin: (l['duree_min'] as num).toDouble(),
              distanceKm: (l['distance_km'] as num?)?.toDouble(),
              deniveleM: (l['denivele_m'] as num?)?.toDouble(),
              kcal: (l['kcal'] as num).toDouble(),
            ))
        .toList();
  }

  Future<void> supprimerActivite(int id) async {
    final db = await base;
    await db.delete('activites', where: 'id = ?', whereArgs: [id]);
  }

  /// Toutes les activités (tous jours), pour l'export CSV.
  Future<List<ActiviteSport>> toutesLesActivites() => listeActivites();

  // ------------------------------------------------- Aliments perso

  /// Enregistre un aliment personnalisé (ajouté au catalogue par
  /// l'utilisateur). Renvoie l'id de la ligne.
  Future<int> ajouterAlimentPerso(Aliment aliment) async {
    final db = await base;
    return db.insert('aliments_perso', {
      'nom': aliment.nom,
      'alias': jsonEncode(aliment.alias),
      'kcal100': aliment.valeurs.kcal,
      'prot100': aliment.valeurs.proteines,
      'gluc100': aliment.valeurs.glucides,
      'lip100': aliment.valeurs.lipides,
      'cree_le': cleInstant(DateTime.now()),
    });
  }

  /// Tous les aliments personnalisés, du plus récent au plus ancien.
  Future<List<Aliment>> listeAlimentsPerso() async {
    final db = await base;
    final lignes = await db.query('aliments_perso',
        orderBy: 'cree_le DESC, id DESC');
    return lignes
        .map((l) => Aliment(
              l['nom'] as String,
              (jsonDecode(l['alias'] as String) as List)
                  .map((a) => a.toString())
                  .toList(),
              ValeursNutritionnelles(
                kcal: (l['kcal100'] as num).toDouble(),
                proteines: (l['prot100'] as num).toDouble(),
                glucides: (l['gluc100'] as num).toDouble(),
                lipides: (l['lip100'] as num).toDouble(),
              ),
              perso: true,
              id: l['id'] as int,
            ))
        .toList();
  }

  /// Renvoie l'aliment perso portant ce nom (normalisé), ou null.
  Future<Aliment?> alimentPersoParNom(String nom) async {
    final tous = await listeAlimentsPerso();
    final cible = nom.trim().toLowerCase();
    for (final a in tous) {
      if (a.nom.trim().toLowerCase() == cible) return a;
    }
    return null;
  }

  Future<void> supprimerAlimentPerso(int id) async {
    final db = await base;
    await db.delete('aliments_perso', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------ Favoris

  /// Enregistre un favori (snapshot JSON des lignes). Renvoie l'id.
  Future<int> ajouterFavori(FavoriRepas favori) async {
    final db = await base;
    return db.insert('favoris', {
      'nom': favori.nom,
      'type': favori.type,
      'cree_le': cleInstant(favori.creeLe),
      'lignes': FavoriRepas.lignesToJson(favori.lignes),
    });
  }

  /// Tous les favoris, du plus récent au plus ancien.
  Future<List<FavoriRepas>> tousLesFavoris() async {
    final db = await base;
    final rows = await db.query('favoris', orderBy: 'cree_le DESC, id DESC');
    return rows
        .map((r) => FavoriRepas(
              id: r['id'] as int,
              nom: r['nom'] as String,
              type: r['type'] as String,
              creeLe: DateTime.parse(r['cree_le'] as String),
              lignes: FavoriRepas.lignesFromJson(r['lignes'] as String),
            ))
        .toList();
  }

  Future<void> supprimerFavori(int id) async {
    final db = await base;
    await db.delete('favoris', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------- Export

  /// Exporte journal + pesées en CSV dans le dossier Téléchargements
  /// (repli : documents de l'app). Renvoie le chemin du fichier créé.
  Future<String> exporterCsv() async {
    final csv = ServiceExport.toCsv(
      repas: await tousLesRepas(),
      pesees: await historiquePesees(),
      activites: await toutesLesActivites(),
    );
    final telechargements = await getDownloadsDirectory();
    final racine = telechargements?.path ??
        (await getApplicationDocumentsDirectory()).path;
    final fichier = File(
        p.join(racine, 'Azimiam', 'export_${cleJour(DateTime.now())}.csv'));
    await fichier.create(recursive: true);
    await fichier.writeAsString(csv);
    return fichier.path;
  }
}
