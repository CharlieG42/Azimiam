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
  /// [base] permet de chercher dans un catalogue enrichi (aliments
  /// personnalisés de l'utilisateur).
  static Aliment? retrouve(String nom, {List<Aliment>? base}) {
    final n = normalise(nom);
    if (n.isEmpty) return null;
    Aliment? meilleur;
    var meilleurScore = 0;
    for (final aliment in base ?? BaseAliments.tous) {
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

  /// Recherche du catalogue : contrairement à l'ancien `contains`, tous les
  /// MOTS de la requête doivent être trouvés (ordre libre) dans le nom ou
  /// un alias — « pommes terre » retrouve « Pommes de terre cuites »,
  /// « blanc poulet » retrouve « Poulet grillé » via son alias.
  ///
  /// Classement par pertinence : début de champ > début de mot > simple
  /// contenu ; bonus si le nom matche tous les mots. Ex æquo : ordre
  /// alphabétique.
  ///
  /// Texte vide : liste vide (l'écran affiche alors tout le catalogue).
  static List<Aliment> rechercher(String texte,
      {List<Aliment>? base, int limite = 200}) {
    final jetons = normalise(texte)
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList();
    if (jetons.isEmpty) return const [];
    final resultats = <MapEntry<int, Aliment>>[];
    for (final aliment in base ?? BaseAliments.tous) {
      final champs = <String>[aliment.nom, ...aliment.alias]
          .map(normalise)
          .where((c) => c.isNotEmpty)
          .toList();
      var score = 0;
      var tousPresents = true;
      for (final jeton in jetons) {
        var meilleur = 0;
        for (final champ in champs) {
          int s;
          if (champ.startsWith(jeton)) {
            s = 3;
          } else if (champ.contains(' $jeton')) {
            s = 2;
          } else if (champ.contains(jeton)) {
            s = 1;
          } else {
            s = 0;
          }
          if (s > meilleur) meilleur = s;
        }
        if (meilleur == 0) {
          tousPresents = false;
          break;
        }
        score += meilleur;
      }
      if (!tousPresents) continue;
      // Bonus : les mots tiennent dans un seul champ (nom OU alias) et
      // le nom les contient tous : plus pertinent qu'un alias dispersé.
      if (champs.any((c) => jetons.every((j) => c.contains(j)))) score += 2;
      if (jetons.every((j) => champs.first.contains(j))) score += 1;
      resultats.add(MapEntry(score, aliment));
    }
    resultats.sort((a, b) {
      final cmp = b.key.compareTo(a.key);
      if (cmp != 0) return cmp;
      return a.value.nom.compareTo(b.value.nom);
    });
    return resultats.take(limite).map((e) => e.value).toList();
  }

  /// Suggestions d'autocomplétion pour la saisie manuelle : recherche
  /// multi-mots sur le catalogue complet (base + aliments perso).
  static List<Aliment> suggestions(String texte,
      {List<Aliment>? base, int limite = 6}) {
    return rechercher(texte, base: base, limite: limite);
  }
}
