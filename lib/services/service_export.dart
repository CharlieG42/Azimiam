import '../models/progression.dart';
import '../models/repas.dart';

/// Export CSV du journal et des pesées (séparateur ';', décimales avec '.').
///
/// Pur Dart (testable) : la fonction [toCsv] ne touche ni au disque ni au
/// réseau ; l'écriture du fichier est faite côté `ServiceBase.exporterCsv`.
class ServiceExport {
  static String _deux(int n) => n.toString().padLeft(2, '0');

  static String _jour(DateTime d) =>
      '${d.year}-${_deux(d.month)}-${_deux(d.day)}';

  static String _instant(DateTime d) =>
      '${_jour(d)} ${_deux(d.hour)}:${_deux(d.minute)}';

  static String _num(double v) => v.toStringAsFixed(1);

  /// Échappe une cellule texte (guillemets doublés, cellule entre "").
  static String _ech(String s) => '"${s.replaceAll('"', '""')}"';

  /// Construit le CSV complet : une ligne par aliment de repas, plus une
  /// ligne par pesée (colonne `poids_kg`).
  static String toCsv({
    required List<Repas> repas,
    required List<Pesee> pesees,
  }) {
    final b = StringBuffer();
    b.writeln(
        'section;date;type;aliment;grammes;kcal;proteines;glucides;lipides;poids_kg');
    for (final p in pesees) {
      b.writeln(
          'pesee;${_jour(p.jour)};;;;;;;;${_num(p.kg)}');
    }
    for (final r in repas) {
      for (final l in r.lignes) {
        final v = l.valeurs;
        b.writeln(
          'repas;${_instant(r.prisLe)};${_ech(r.type)};${_ech(l.nom)};'
          '${_num(l.grammes)};${_num(v.kcal)};${_num(v.proteines)};'
          '${_num(v.glucides)};${_num(v.lipides)};',
        );
      }
    }
    return b.toString();
  }
}
