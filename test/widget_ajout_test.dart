import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:azimiam/data/mini_base.dart';
import 'package:azimiam/models/valeurs.dart';
import 'package:azimiam/screens/ajout_repas_ecran.dart';
import 'package:azimiam/state/catalogue.dart';
import 'package:azimiam/state/journal.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('fr_FR');
  });

  Widget pompe({DateTime? jour, Catalogue? catalogue}) {
    // Catalogue pré-rempli avec la base embarquée, sans passer par la
    // base de données (pas de SQLite dans les tests widget). Un
    // catalogue injecté (v0.8.2) permet de capturer les ajouts
    // automatiques des lignes hors base.
    final cata = catalogue ?? (Catalogue()..tous = BaseAliments.tous);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Journal()),
        // L'écran d'ajout cherche dans le catalogue complet (base + perso).
        ChangeNotifierProvider<Catalogue>.value(value: cata),
      ],
      // Localisations comme dans la vraie app : le sélecteur de date
      // (showDatePicker) en dépend.
      child: MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', 'FR')],
        home: AjoutRepasEcran(jour: jour),
      ),
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

  testWidgets(
      'ligne hors base renseignée : l’aliment entre automatiquement au catalogue (v0.8.2)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final capture = _CatalogueCapture();
    await tester.pumpWidget(pompe(catalogue: capture));
    await tester.pumpAndSettle();

    // Une ligne hors base (saisie libre).
    await tester.enterText(
        find.byKey(const Key('champSaisieAliment')), 'Ma recette maison');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saisie libre (hors base)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('hors base, à vérifier'), findsOneWidget);

    // Toucher la ligne ouvre la fiche d’édition : plus de bouton de
    // création (v0.8.2), la validation suffit.
    await tester.tap(find.text('Ma recette maison'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('boutonCreerCatalogue')), findsNothing);

    // On renseigne les calories de la ligne, puis on valide.
    await tester.enterText(
        find.widgetWithText(TextField, 'Calories / 100 g'), '150');
    await tester.pump();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    // La ligne est reconnue et l’aliment est entré au catalogue avec
    // les valeurs saisies.
    expect(find.textContaining('hors base, à vérifier'), findsNothing);
    expect(capture.ajoutes.length, 1);
    expect(capture.ajoutes.first.nom, 'Ma recette maison');
    expect(capture.ajoutes.first.valeurs.kcal, 150);
    expect(
        find.text('« Ma recette maison » ajouté au catalogue'),
        findsOneWidget);
  });

  testWidgets(
      'une ligne de la base ne crée rien au catalogue (v0.8.2)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final capture = _CatalogueCapture();
    await tester.pumpWidget(pompe(catalogue: capture));
    await tester.pumpAndSettle();

    // Ligne ajoutée depuis la base : elle y est déjà.
    await tester.enterText(
        find.byKey(const Key('champSaisieAliment')), 'poulet');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poulet grillé'));
    await tester.pumpAndSettle();

    // Éditer ses valeurs ne doit pas créer de doublon.
    await tester.tap(find.text('Poulet grillé'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Calories / 100 g'), '200');
    await tester.pump();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(capture.ajoutes.length, 0);
    expect(find.textContaining('ajouté au catalogue'), findsNothing);
  });

  testWidgets(
      'la journée transmise (ex. veille) s\'affiche et sera celle du repas '
      '(v0.6.2)', (tester) async {
    await tester.pumpWidget(pompe(jour: DateTime(2026, 11, 24)));
    await tester.pumpAndSettle();

    // La puce de journée montre le jour demandé, pas « aujourd'hui ».
    expect(find.byKey(const Key('boutonJourRepas')), findsOneWidget);
    expect(find.text('Mardi 24 novembre'), findsOneWidget);
  });

  testWidgets('la journée du repas se change via le calendrier (v0.6.2)',
      (tester) async {
    await tester.pumpWidget(pompe(jour: DateTime(2026, 11, 24)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boutonJourRepas')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // Choix du 25 du mois affiché, puis validation.
    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.text('Mercredi 25 novembre'), findsOneWidget);
  });
}

/// Catalogue simulé (v0.8.2) : capture les ajouts au lieu d’écrire
/// dans SQLite (indisponible en test widget), pour vérifier l’entrée
/// automatique des lignes hors base au catalogue.
class _CatalogueCapture extends Catalogue {
  final ajoutes = <_AlimentAjoute>[];

  @override
  Future<String?> ajouter({
    required String nom,
    required List<String> alias,
    required ValeursNutritionnelles valeurs,
  }) async {
    ajoutes.add(_AlimentAjoute(nom, valeurs));
    return null;
  }
}

class _AlimentAjoute {
  final String nom;
  final ValeursNutritionnelles valeurs;
  _AlimentAjoute(this.nom, this.valeurs);
}
