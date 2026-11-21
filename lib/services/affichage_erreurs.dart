import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Affichage des erreurs de construction des widgets.
///
/// Par défaut, en mode release, Flutter remplace un sous-arbre qui plante par
/// une boîte grise muette : impossible de savoir ce qui a échoué sur un
/// appareil réel. On affiche plutôt l'erreur réelle, lisible, pour pouvoir la
/// diagnostiquer à partir d'une simple capture d'écran.
class AffichageErreurs {
  static void installer() {
    ErrorWidget.builder = erreurLisible;
  }

  static Widget erreurLisible(FlutterErrorDetails details) {
    debugPrint('Erreur de construction d\u2019un widget : ${details.exception}');
    debugPrint('Pile d\u2019appels :\n${details.stack}');
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Erreur d\u2019affichage',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text('${details.exception}'),
            const SizedBox(height: 12),
            // Pile d'appels compacte : les cadres du haut désignent le
            // fichier et la ligne exacts du crash dans le code de l'app.
            Text(
              framesPertinents(details).join('\n'),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Prenez une capture d\u2019écran de ce message pour le signaler.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  /// Cadres de pile qui pointent dans le code applicatif (package:azimiam)
  /// ou dans les widgets de lib/ du SDK, les plus profonds d'abord. Compact
  /// (3 cadres max) : le panneau doit tenir dans des zones parfois étroites.
  static List<String> framesPertinents(FlutterErrorDetails details) {
    final pile = details.stack?.toString().split('\n') ?? const <String>[];
    final frames = <String>[];
    var gardeFou = 0;
    for (var ligne in pile) {
      if (gardeFou >= 24) break;
      gardeFou++;
      final compacte = ligne.trim();
      if (compacte.isEmpty) continue;
      if (compacte.contains('package:azimiam') ||
          compacte.contains('package:flutter/src/')) {
        frames.add(compacte.length > 70 ? '${compacte.substring(0, 70)}…' : compacte);
        if (frames.length >= 3) break;
      }
    }
    if (frames.isEmpty) return const <String>['Pile d\u2019appels indisponible.'];
    return frames;
  }
}
