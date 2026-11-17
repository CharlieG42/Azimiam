import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/repas.dart';
import '../models/valeurs.dart';

/// Base de données locale (SQLite) : repas et lignes d'aliments.
class ServiceBase {
  static final ServiceBase instance = ServiceBase._();
  ServiceBase._();

  Database? _base;

  Future<Database> get base async => _base ??= await _ouvrir();

  Future<Database> _ouvrir() async {
    final dossier = await getApplicationDocumentsDirectory();
    return openDatabase(
      p.join(dossier.path, 'azimiam.db'),
      version: 1,
      onCreate: (db, version) async {
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
      },
    );
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

  /// Tous les repas d'une journée, par ordre chronologique.
  Future<List<Repas>> repasDuJour(DateTime jour) async {
    final db = await base;
    final lignesRepas = await db.query(
      'repas',
      where: 'pris_le LIKE ?',
      whereArgs: ['${cleJour(jour)}%'],
      orderBy: 'pris_le',
    );

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
}
