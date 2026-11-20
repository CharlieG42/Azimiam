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
}
