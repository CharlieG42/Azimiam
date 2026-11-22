import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:azimiam/models/repas.dart';
import 'package:azimiam/models/valeurs.dart';
import 'package:azimiam/services/service_ia.dart';
import 'package:azimiam/widgets/carte_ligne.dart';

void main() {
  testWidgets(
      'la quantité affichée se resynchronise quand la ligne est modifiée ailleurs',
      (tester) async {
    // Régression v0.4.0 : TextField initialValue + clé inchangée => l'écran
    // affichait encore 100 g après édition de la ligne à 250 g (photo du
    // bug « Thé à la menthe »).
    final ligne = LigneRepas(
      nom: 'Thé à la menthe',
      grammes: 100,
      pour100: ValeursNutritionnelles(
          kcal: 5, proteines: 0, glucides: 1, lipides: 0),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            CarteLigne(
              ligne: ligne,
              onGrammesModifies: (g) => ligne.grammes = g,
              onEditer: () {},
              onSupprimer: () {},
            ),
            TextButton(
              onPressed: () {
                // Simule la validation de la boîte de dialogue d'édition.
                ligne.grammes = 250;
                (tester.state(find.byType(CarteLigne)) as dynamic)
                    .setState(() {});
              },
              child: const Text('simuler édition'),
            ),
          ],
        ),
      ),
    ));

    expect(find.text('100'), findsOneWidget);
    await tester.tap(find.text('simuler édition'));
    await tester.pump();
    expect(find.text('250'), findsOneWidget);
    expect(find.text('100'), findsNothing);
  });

  test('les erreurs réseau donnent un message clair, pas un errno', () {
    const exception =
        'ClientException with SocketException: Failed host lookup: '
        '\'api.mistral.ai\' (OS Error: No address associated with hostname, '
        'errno = 7)';

    final message = ServiceIa.messageErreur(exception);
    expect(message, contains('Pas de connexion'));
    expect(message, contains('n\'est pas un problème de modèle'));
    expect(message, isNot(contains('errno')));
    expect(message, contains('api.mistral.ai'));
  });

  test('les erreurs non réseau restent lisibles', () {
    final message = ServiceIa.messageErreur(
        const FormatException('Tableau JSON invalide'));
    expect(message, contains('Analyse IA échouée'));
    expect(message, contains('Tableau JSON invalide'));
  });
}
