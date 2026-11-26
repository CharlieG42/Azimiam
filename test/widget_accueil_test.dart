import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:azimiam/models/activite.dart';
import 'package:azimiam/models/repas.dart';
import 'package:azimiam/models/valeurs.dart';
import 'package:azimiam/screens/a_propos_ecran.dart';
import 'package:azimiam/screens/accueil_ecran.dart';
import 'package:azimiam/screens/ajout_repas_ecran.dart';
import 'package:azimiam/services/service_sante.dart';
import 'package:azimiam/state/activites.dart';
import 'package:azimiam/state/catalogue.dart';
import 'package:azimiam/state/journal.dart';
import 'package:azimiam/state/progression.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('fr_FR');
  });

  Widget pompe() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Journal()),
        ChangeNotifierProvider(create: (_) => Progression()),
        // v0.7.0 : la carte résumé lit les compteurs pas/étages.
        ChangeNotifierProvider(create: (_) => Activites()),
        // L'écran d'ajout poussé depuis l'accueil cherche dans le catalogue.
        ChangeNotifierProvider(create: (_) => Catalogue()),
      ],
      child: const MaterialApp(home: AccueilEcran()),
    );
  }

  testWidgets('le bouton menu ouvre le tiroir et navigue vers À propos',
      (tester) async {
    await tester.pumpWidget(pompe());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    final tiroir = find.byType(Drawer);
    expect(find.descendant(of: tiroir, matching: find.text('Journal')),
        findsOneWidget);
    expect(
        find.descendant(of: tiroir, matching: find.text('Progression & IMC')),
        findsOneWidget);
    expect(
        find.descendant(of: tiroir, matching: find.text('Plan nutritionnel')),
        findsOneWidget);
    expect(find.descendant(of: tiroir, matching: find.text('À propos')),
        findsOneWidget);
    expect(find.descendant(of: tiroir, matching: find.text('Réglages')),
        findsOneWidget);

    await tester.tap(
        find.descendant(of: tiroir, matching: find.text('À propos')));
    await tester.pumpAndSettle();
    expect(find.byType(AProposEcran), findsOneWidget);
  });

  testWidgets('le bouton d\u00e9j\u00e0 visible ouvre l\u2019\u00e9cran d\u2019ajout de repas',
      (tester) async {
    await tester.pumpWidget(pompe());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('boutonAjouterRepas')), findsOneWidget);
    await tester.tap(find.byKey(const Key('boutonAjouterRepas')));
    await tester.pumpAndSettle();
    expect(find.byType(AjoutRepasEcran), findsOneWidget);
    expect(find.byKey(const Key('champSaisieAliment')), findsOneWidget);
  });

  testWidgets('le bouton flottant ouvre l\u2019\u00e9cran d\u2019ajout de repas',
      (tester) async {
    await tester.pumpWidget(pompe());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajouter un repas').first);
    await tester.pumpAndSettle();
    expect(find.byType(AjoutRepasEcran), findsOneWidget);
  });

  testWidgets(
      'l\u2019ajout depuis une journ\u00e9e pass\u00e9e propose cette journ\u00e9e (v0.6.2)',
      (tester) async {
    // L'accueil affiche hier : le repas doit être DATÉ d'hier, pas
    // d'aujourd'hui (retour du bug v0.6.1 sur la date des repas).
    final journal = Journal()..jour = DateTime(2026, 11, 24);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<Journal>.value(value: journal),
        ChangeNotifierProvider(create: (_) => Progression()),
        ChangeNotifierProvider(create: (_) => Activites()),
        ChangeNotifierProvider(create: (_) => Catalogue()),
      ],
      child: const MaterialApp(home: AccueilEcran()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boutonAjouterRepas')));
    await tester.pumpAndSettle();
    expect(find.byType(AjoutRepasEcran), findsOneWidget);
    expect(find.text('Mardi 24 novembre'), findsOneWidget);
  });

  testWidgets('le bouton Aujourd\u2019hui recentre sur la journée en cours '
      '(v0.6.4)', (tester) async {
    final journal = Journal()..jour = DateTime(2026, 11, 24);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<Journal>.value(value: journal),
        ChangeNotifierProvider(create: (_) => Progression()),
        ChangeNotifierProvider(create: (_) => Activites()),
        ChangeNotifierProvider(create: (_) => Catalogue()),
      ],
      child: const MaterialApp(home: AccueilEcran()),
    ));
    await tester.pumpAndSettle();

    // Le popup ⋮ a disparu au profit d\u2019un bouton direct.
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byIcon(Icons.today), findsOneWidget);

    await tester.tap(find.byIcon(Icons.today));
    // Pas de pumpAndSettle ici : charger() affiche un spinner pendant que
    // SQLite échoue en silence (MissingPluginException attendue en test).
    // L'affectation de journal.jour est synchrone, elle est déjà effective.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final maintenant = DateTime.now();
    expect(journal.jour.year, maintenant.year);
    expect(journal.jour.month, maintenant.month);
    expect(journal.jour.day, maintenant.day);
  });

  testWidgets('compteurs pas/étages du jour affichés quand Health Connect '
      'les fournit (v0.7.0)', (tester) async {
    // Pas de journal fourni : un Journal() par défaut affiche Aujourd'hui,
    // donc la carte résumé lit Activites.compteursJour.
    final activites = Activites()
      ..compteursJour = CompteursJour(pas: 8432, etages: 12);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Journal()),
        ChangeNotifierProvider(create: (_) => Progression()),
        ChangeNotifierProvider<Activites>.value(value: activites),
        ChangeNotifierProvider(create: (_) => Catalogue()),
      ],
      child: const MaterialApp(home: AccueilEcran()),
    ));
    await tester.pump();

    expect(find.text('8 432 pas'), findsOneWidget);
    expect(find.text('12 étages'), findsOneWidget);
    expect(find.byIcon(Icons.stairs), findsOneWidget);
  });

  testWidgets('dépense sportive du jour créditée au budget calorique '
      '(v0.7.2)', (tester) async {
    final maintenant = DateTime.now();
    final activites = Activites()
      ..liste = [
        ActiviteSport(
          moment: maintenant.subtract(const Duration(hours: 1)),
          type: 'course',
          dureeMin: 45,
          kcal: 520,
        ),
        // Séance d'un autre jour : ne doit pas compter dans le budget du jour.
        ActiviteSport(
          moment: maintenant.subtract(const Duration(days: 2)),
          type: 'velo',
          dureeMin: 60,
          kcal: 400,
        ),
      ];
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Journal()),
        ChangeNotifierProvider(create: (_) => Progression()),
        ChangeNotifierProvider<Activites>.value(value: activites),
        ChangeNotifierProvider(create: (_) => Catalogue()),
      ],
      child: const MaterialApp(home: AccueilEcran()),
    ));
    await tester.pump();

    expect(find.textContaining('dépense sportive : 520 kcal'), findsOneWidget);
    expect(
        find.byIcon(Icons.local_fire_department_outlined), findsOneWidget);
    // Le sous-titre signale le budget ajusté, pas l'objectif seul.
    expect(find.textContaining('objectif + sport'), findsOneWidget);
  });

  testWidgets('pas de ligne dépense sans séance le jour affiché (v0.7.2)',
      (tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Journal()),
        ChangeNotifierProvider(create: (_) => Progression()),
        ChangeNotifierProvider(create: (_) => Activites()),
        ChangeNotifierProvider(create: (_) => Catalogue()),
      ],
      child: const MaterialApp(home: AccueilEcran()),
    ));
    await tester.pump();

    expect(find.textContaining('dépense sportive'), findsNothing);
    expect(find.textContaining('objectif + sport'), findsNothing);
  });

  testWidgets('calories actives du jour créditées sans séance (v0.7.3)',
      (tester) async {
    // Pas de séance, mais Health Connect fournit les calories actives
    // du jour (montre) : elles créditent le budget comme le ferait du sport.
    final activites = Activites()
      ..compteursJour = CompteursJour(pas: 8432, etages: 12, kcalActives: 210);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Journal()),
        ChangeNotifierProvider(create: (_) => Progression()),
        ChangeNotifierProvider<Activites>.value(value: activites),
        ChangeNotifierProvider(create: (_) => Catalogue()),
      ],
      child: const MaterialApp(home: AccueilEcran()),
    ));
    await tester.pump();

    expect(find.textContaining('dépense sportive : 210 kcal'), findsOneWidget);
    expect(
        find.byIcon(Icons.local_fire_department_outlined), findsOneWidget);
    expect(find.textContaining('objectif + sport'), findsOneWidget);
  });

  testWidgets('le type de repas n\'est pas répété dans les cartes (v0.7.4)',
      (tester) async {
    // L'en-tête du groupe affiche déjà le type : la carte ne doit
    // plus le répéter, seulement l'heure du repas.
    final journal = Journal()
      ..repas = [
        Repas(
          prisLe: DateTime(2026, 11, 26, 13, 18),
          type: 'Déjeuner',
          lignes: [
            LigneRepas(
              nom: 'Filet de porc',
              grammes: 250,
              pour100: ValeursNutritionnelles(
                  kcal: 160, proteines: 5, glucides: 10, lipides: 2),
            ),
          ],
        ),
      ];
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<Journal>.value(value: journal),
        ChangeNotifierProvider(create: (_) => Progression()),
        ChangeNotifierProvider(create: (_) => Activites()),
        ChangeNotifierProvider(create: (_) => Catalogue()),
      ],
      child: const MaterialApp(home: AccueilEcran()),
    ));
    await tester.pump();

    expect(find.text('Déjeuner'), findsOneWidget);
    expect(find.textContaining('Déjeuner ·'), findsNothing);
    expect(find.text('13:18'), findsOneWidget);
  });
}
