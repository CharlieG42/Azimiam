import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:azimiam/data/mini_base.dart';
import 'package:azimiam/screens/accueil_ecran.dart';
import 'package:azimiam/screens/catalogue_ecran.dart';
import 'package:azimiam/screens/modifier_repas_ecran.dart';
import 'package:azimiam/screens/reglages_ecran.dart';
import 'package:azimiam/models/repas.dart';
import 'package:azimiam/models/valeurs.dart';
import 'package:azimiam/state/activites.dart';
import 'package:azimiam/state/catalogue.dart';
import 'package:azimiam/state/journal.dart';
import 'package:azimiam/state/progression.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('fr_FR');
  });

  LigneRepas ligne(String nom, int kcal) => LigneRepas(
        nom: nom,
        grammes: 100,
        pour100: ValeursNutritionnelles(
            kcal: kcal.toDouble(), proteines: 5, glucides: 10, lipides: 2),
      );

  testWidgets('les repas sont groupés par type avec sous-totaux',
      (tester) async {
    // Viewport haut : la liste est bâtie paresseusement (SliverList), les
    // groupes du bas ne sont instanciés que s'ils entrent dans l'écran.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final journal = Journal();
    journal.repas = [
      Repas(
        prisLe: DateTime(2026, 11, 22, 8),
        type: 'Petit-déjeuner',
        lignes: [ligne('Pain', 250)],
      ),
      Repas(
        prisLe: DateTime(2026, 11, 22, 13),
        type: 'Déjeuner',
        lignes: [ligne('Poulet grillé', 165)],
      ),
      Repas(
        prisLe: DateTime(2026, 11, 22, 9),
        type: 'Petit-déjeuner',
        lignes: [ligne('Thé', 5)],
      ),
    ];

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: journal),
        ChangeNotifierProvider(create: (_) => Progression()),
        // v0.7.0 : l'accueil lit les compteurs pas/étages d'Activites.
        ChangeNotifierProvider(create: (_) => Activites()),
      ],
      child: const MaterialApp(home: AccueilEcran()),
    ));
    await tester.pumpAndSettle();

    // En-têtes des groupes présents, dans l'ordre d'une journée.
    expect(find.text('Petit-déjeuner'), findsWidgets);
    expect(find.text('Déjeuner'), findsWidgets);
    expect(find.textContaining('255 kcal'), findsOneWidget);

    // L'icône de modification est présente sur chaque carte repas.
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(3));
  });

  testWidgets('le bouton modifier ouvre l\'écran de modification du repas',
      (tester) async {
    final journal = Journal();
    journal.repas = [
      Repas(
        prisLe: DateTime(2026, 11, 22, 13),
        type: 'Déjeuner',
        lignes: [ligne('Poulet grillé', 165)],
      ),
    ];

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: journal),
        ChangeNotifierProvider(create: (_) => Progression()),
        // v0.7.0 : l'accueil lit les compteurs pas/étages d'Activites.
        ChangeNotifierProvider(create: (_) => Activites()),
      ],
      child: const MaterialApp(home: AccueilEcran()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    expect(find.byType(ModifierRepasEcran), findsOneWidget);
    expect(find.text('Poulet grillé'), findsOneWidget);
    expect(find.text('Enregistrer les modifications'), findsOneWidget);

    // Changer de type et vérifier le total recalculé s'affiche.
    await tester.tap(find.text('Collation'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('le catalogue recherche et renvoie l\'aliment choisi',
      (tester) async {
    // Le catalogue est poussé comme une vraie route : son « pop avec
    // résultat » doit refermer l'écran (impossible depuis la route racine).
    await tester.pumpWidget(MultiProvider(
      providers: [
        // Le catalogue cherche dans le provider (base + aliments perso).
        // Pré-rempli avec la base embarquée, sans SQLite dans les tests.
        ChangeNotifierProvider<Catalogue>.value(
          value: Catalogue()..tous = BaseAliments.tous,
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CatalogueEcran(),
                  ),
                ),
                child: const Text('ouvrir catalogue'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ouvrir catalogue'));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogueEcran), findsOneWidget);

    // Recherche insensible aux accents : « cotelette » → « Côtelette d'agneau ».
    await tester.enterText(
        find.byKey(const Key('champRechercheCatalogue')), 'cotelette');
    await tester.pumpAndSettle();
    expect(find.textContaining('Côtelette'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('champRechercheCatalogue')), 'pomme de terre');
    await tester.pumpAndSettle();
    // L'alias « pomme de terre » retrouve la fiche « Pommes de terre cuites ».
    expect(find.text('Pommes de terre cuites'), findsOneWidget);

    // Multi-mots : « pommes terre » (mots non contigus) retrouve aussi la
    // fiche — le cœur de la v0.6.0.
    await tester.enterText(
        find.byKey(const Key('champRechercheCatalogue')), 'pommes terre');
    await tester.pumpAndSettle();
    expect(find.text('Pommes de terre cuites'), findsOneWidget);

    await tester.tap(find.text('Pommes de terre cuites'));
    await tester.pumpAndSettle();
    // L'aliment est pop-é : le catalogue est fermé.
    expect(find.byType(CatalogueEcran), findsNothing);
  });

  testWidgets('réglages : le modèle d\'analyse photo est un menu déroulant',
      (tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Journal()),
        ChangeNotifierProvider(create: (_) => Progression()),
      ],
      child: const MaterialApp(home: ReglagesEcran()),
    ));
    await tester.pumpAndSettle();

    // Le dropdown remplace l'ancien champ texte libre.
    expect(find.byKey(const Key('dropdownModeleIa')), findsOneWidget);
    expect(find.textContaining('Pixtral 12B'), findsOneWidget);
    // Saisie manuelle cachée tant qu'un modèle connu est choisi.
    expect(find.textContaining('Identifiant du modèle'), findsNothing);

    // « Autre modèle » fait apparaître le champ de saisie libre.
    await tester.tap(find.byKey(const Key('dropdownModeleIa')));
    await tester.pumpAndSettle();
    final itemAutre = find.text('Autre modèle (saisie manuelle)').last;
    await tester.ensureVisible(itemAutre);
    await tester.pumpAndSettle();
    await tester.tap(itemAutre);
    await tester.pumpAndSettle();
    expect(find.textContaining('Identifiant du modèle'), findsOneWidget);
  });
}
