import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:azimiam/screens/accueil_ecran.dart';
import 'package:azimiam/screens/progression_ecran.dart';
import 'package:azimiam/state/activites.dart';
import 'package:azimiam/state/catalogue.dart';
import 'package:azimiam/state/hydratation.dart';
import 'package:azimiam/state/journal.dart';
import 'package:azimiam/state/progression.dart';

/// Carte sommeil & FC au repos de l'accueil et suivi Progression
/// (v0.8.0). L'état est porté par [Activites] (déjà fourni partout) :
/// les tests injectent une instance pré-remplie, sans SQLite ni
/// Health Connect.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('fr_FR');
  });

  final maintenant = DateTime.now();
  final aujourdhui =
      DateTime(maintenant.year, maintenant.month, maintenant.day);

  Widget pompeAccueil(Activites activites) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Journal()),
        ChangeNotifierProvider(create: (_) => Progression()),
        ChangeNotifierProvider<Activites>.value(value: activites),
        ChangeNotifierProvider(create: (_) => Catalogue()),
        ChangeNotifierProvider(create: (_) => Hydratation()),
      ],
      child: const MaterialApp(home: AccueilEcran()),
    );
  }

  Widget pompeProgression(Activites activites) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Progression()),
        ChangeNotifierProvider(create: (_) => Hydratation()),
        ChangeNotifierProvider<Activites>.value(value: activites),
      ],
      child: const MaterialApp(home: ProgressionEcran()),
    );
  }

  testWidgets('la carte sommeil affiche la nuit dernière et la FC au repos',
      (tester) async {
    final activites = Activites()
      ..sommeil7 = {aujourdhui: 445}
      ..fcRepos7 = {aujourdhui: 58};
    await tester.pumpWidget(pompeAccueil(activites));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sommeilTitre')), findsOneWidget);
    expect(find.text('7 h 25'), findsOneWidget);
    expect(find.text('FC au repos : 58 bpm'), findsOneWidget);
  });

  testWidgets('la carte sommeil affiche la durée seule sans FC connue',
      (tester) async {
    final activites = Activites()..sommeil7 = {aujourdhui: 390};
    await tester.pumpWidget(pompeAccueil(activites));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sommeilTitre')), findsOneWidget);
    expect(find.text('6 h 30'), findsOneWidget);
    expect(find.textContaining('FC au repos'), findsNothing);
  });

  testWidgets('sans données santé, la carte sommeil disparaît de l\'accueil',
      (tester) async {
    final activites = Activites();
    await tester.pumpWidget(pompeAccueil(activites));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sommeilTitre')), findsNothing);
    expect(find.byKey(const Key('sommeilNuit')), findsNothing);
  });

  testWidgets('le suivi Progression liste les 7 dernières nuits',
      (tester) async {
    // La carte est en bas de l'écran : viewport agrandi pour la
    // construire (leçon v0.7.9).
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final activites = Activites()
      ..sommeil7 = {
        aujourdhui: 445,
        aujourdhui.subtract(const Duration(days: 1)): 480,
      }
      ..fcRepos7 = {aujourdhui: 58};
    await tester.pumpWidget(pompeProgression(activites));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sommeilSuiviTitre')), findsOneWidget);
    expect(find.text('7 h 25 · 58 bpm'), findsOneWidget);
    expect(find.text('8 h 00'), findsOneWidget);
    // Les 5 nuits plus anciennes sont inconnues : leurs lignes restent
    // présentes avec « — ».
    expect(find.text('—'), findsNWidgets(5));
  });

  testWidgets('sans données santé, le suivi sommeil disparaît de Progression',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final activites = Activites();
    await tester.pumpWidget(pompeProgression(activites));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sommeilSuiviTitre')), findsNothing);
  });
}
