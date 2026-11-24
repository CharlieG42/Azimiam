import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:azimiam/data/mini_base.dart';
import 'package:azimiam/screens/ajout_repas_ecran.dart';
import 'package:azimiam/state/catalogue.dart';
import 'package:azimiam/state/journal.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('fr_FR');
  });

  Widget pompe() {
    // Catalogue pré-rempli avec la base embarquée, sans passer par la
    // base de données (pas de SQLite dans les tests widget).
    final catalogue = Catalogue()..tous = BaseAliments.tous;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Journal()),
        // L'écran d'ajout cherche dans le catalogue complet (base + perso).
        ChangeNotifierProvider<Catalogue>.value(value: catalogue),
      ],
      child: const MaterialApp(home: AjoutRepasEcran()),
    );
  }

  testWidgets('une suggestion de la base ajoute une ligne au repas',
      (tester) async {
    await tester.pumpWidget(pompe());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('champSaisieAliment')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.enterText(
        find.byKey(const Key('champSaisieAliment')), 'poulet');
    await tester.pumpAndSettle();
    expect(find.text('Poulet grillé'), findsOneWidget);

    await tester.tap(find.text('Poulet grillé'));
    await tester.pumpAndSettle();
    expect(find.text('Poulet grillé'), findsOneWidget);
    expect(find.textContaining('hors base, à vérifier'), findsNothing);
  });

  testWidgets('la saisie libre ajoute une ligne hors base', (tester) async {
    await tester.pumpWidget(pompe());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('champSaisieAliment')), 'Ma recette maison');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saisie libre (hors base)'));
    await tester.pumpAndSettle();

    expect(find.text('Ma recette maison'), findsOneWidget);
    expect(find.textContaining('hors base, à vérifier'), findsOneWidget);
  });

  testWidgets('saisie libre vide : avertissement, aucune ligne ajoutée',
      (tester) async {
    await tester.pumpWidget(pompe());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saisie libre (hors base)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('le bouton + de l\u2019AppBar atteint le panneau d\u2019ajout d\u2019aliment',
      (tester) async {
    await tester.pumpWidget(pompe());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    final champ = find.byKey(const Key('champSaisieAliment'));
    expect(champ, findsOneWidget);
    final textField = tester.widget<TextField>(champ);
    expect(textField.focusNode?.hasFocus, isTrue);
  });
}

