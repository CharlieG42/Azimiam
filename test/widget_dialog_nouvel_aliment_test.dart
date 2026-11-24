import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:azimiam/widgets/dialog_nouvel_aliment.dart';

void main() {
  Widget pompe(DialogNouvelAliment dialogue) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showDialog<AlimentCree>(
                context: context,
                builder: (_) => dialogue,
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('enregistre et renvoie la fiche créée', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    AlimentCree? cree;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                cree = await showDialog<AlimentCree>(
                  context: context,
                  builder: (_) => DialogNouvelAliment(
                    onValide: (nom, alias, valeurs) async {
                      expect(alias, ['chevre chaud']);
                      expect(valeurs.kcal, 265);
                      return null; // succès
                    },
                  ),
                );
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dialogNouvelAliment')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('champNomAliment')), 'Chèvre chaud');
    await tester.enterText(
        find.widgetWithText(TextField, 'Alias de recherche (optionnel)'),
        'chevre chaud');
    await tester.enterText(
        find.widgetWithText(TextField, 'Calories / 100 g *'), '265');
    await tester.pump();

    await tester.tap(find.byKey(const Key('boutonEnregistrerAliment')));
    await tester.pumpAndSettle();

    // Le dialogue s'est refermé et a renvoyé la fiche créée.
    expect(find.byKey(const Key('dialogNouvelAliment')), findsNothing);
    expect(cree, isNotNull);
    expect(cree!.nom, 'Chèvre chaud');
    expect(cree!.alias, ['chevre chaud']);
    expect(cree!.valeurs.kcal, 265);
  });

  testWidgets('erreur (doublon) : snackbar et dialogue reste ouvert',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(pompe(DialogNouvelAliment(
      onValide: (nom, alias, valeurs) async =>
          '« $nom » est déjà dans le catalogue.',
    )));

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('champNomAliment')), 'Poulet grillé');
    await tester.enterText(
        find.widgetWithText(TextField, 'Calories / 100 g *'), '165');
    await tester.pump();
    await tester.tap(find.byKey(const Key('boutonEnregistrerAliment')));
    await tester.pump();

    // L'erreur s'affiche et le dialogue RESTE ouvert : l'utilisateur
    // conserve sa saisie pour corriger.
    expect(find.textContaining('est déjà dans le catalogue'), findsOneWidget);
    expect(find.byKey(const Key('dialogNouvelAliment')), findsOneWidget);
  });

  testWidgets('nomInitial pré-remplit le champ nom', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(pompe(DialogNouvelAliment(
      nomInitial: 'Fromage fort',
      onValide: (nom, alias, valeurs) async => null,
    )));

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    final champ =
        tester.widget<TextField>(find.byKey(const Key('champNomAliment')));
    expect(champ.controller?.text, 'Fromage fort');
  });
}
