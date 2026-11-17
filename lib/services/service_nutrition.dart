import '../data/mini_base.dart';

/// Recherche d'aliments dans la base locale et calculs associés.
class ServiceNutrition {
  static const Map<String, String> _accents = {
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'œ': 'oe',
    'æ': 'ae',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ñ': 'n',
  };

  /// Normalise un nom d'aliment : minuscules, sans accents, sans ponctuation,
  /// espaces simples. « Poulet grillé ! » -> « poulet grille ».
  static String normalise(String s) {
    var r = s.toLowerCase();
    _accents.forEach((k, v) => r = r.replaceAll(k, v));
    r = r.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    return r.split(RegExp(r'\s+')).where((m) => m.isNotEmpty).join(' ').trim();
  }

  /// Retrouve l'aliment de la base locale correspondant au mieux à [nom],
  /// ou null si rien ne colle. Gère le nom exact, un alias, ou un nom
  /// repris dans une phrase (« un morceau de poulet grillé »).
  static Aliment? retrouve(String nom) {
    final n = normalise(nom);
    if (n.isEmpty) return null;
    Aliment? meilleur;
    var meilleurScore = 0;
    for (final aliment in BaseAliments.tous) {
      for (final candidat in <String>[aliment.nom, ...aliment.alias]) {
        final c = normalise(candidat);
        if (c.isEmpty) continue;
        int score;
        if (c == n) {
          score = 1000 + c.length;
        } else if (n.contains(c)) {
          score = c.length;
        } else if (c.contains(n) && n.length >= 4) {
          score = n.length;
        } else {
          continue;
        }
        if (score > meilleurScore) {
          meilleurScore = score;
          meilleur = aliment;
        }
      }
    }
    return meilleur;
  }

  /// Suggestions d'autocomplétion pour la saisie manuelle.
  static List<Aliment> suggestions(String texte, {int limite = 6}) {
    final n = normalise(texte);
    if (n.isEmpty) return const [];
    return BaseAliments.tous
        .where((a) =>
            normalise(a.nom).contains(n) ||
            a.alias.any((al) => normalise(al).contains(n)))
        .take(limite)
        .toList();
  }
}
