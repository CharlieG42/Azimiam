import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:azimiam/main.dart';

/// Régression : l'app déclarait "supportedLocales: [Locale('fr', 'FR')]"
/// sans les délégués de localisation, ce qui renvoyait "null" depuis
/// "MaterialLocalizations.of()" et plantait en release tous les widgets
/// qui en dépendent (TextField de l'écran d'ajout, tiroir de l'accueil…).
/// Les autres tests widget construisent leur propre MaterialApp (localisé
/// en anglais par défaut), ils ne couvraient donc pas ce cas : ici on
/// pompe la vraie application, telle que lancée sur appareil.
///
/// NB : pas de "pumpAndSettle" ici. En test, les plugins natifs
/// (sqflite, path_provider) ne répondent jamais : le chargement initial
/// ne se termine pas et le spinner de l'accueil tourne indéfiniment.
/// Sur appareil réel, les plugins répondent et tout se stabilise.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('fr_FR');
  });

  // Pompes bornées : suffisent aux délégués de localisation (données
  // fr chargées en mémoire, sans passer par un plugin natif).
  Future<void> pomper(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
      'l\'application réelle fournit MaterialLocalizations pour le français',
      (tester) async {
    await tester.pumpWidget(const AzimiamApp());
    await pomper(tester);

    expect(find.byType(MaterialApp), findsOneWidget);

    // Le cœur du bug : la locale fr doit être résolue, pas renvoyer null
    // (c'est ce null qui provoquait le crash « Null check operator »).
    final contexte = tester.element(find.byType(Scaffold).first);
    final localisations = MaterialLocalizations.of(contexte);
    expect(localisations, isNotNull);
    expect(Localizations.localeOf(contexte), equals(const Locale('fr', 'FR')));
  });

  testWidgets(
      'l\'écran d\'ajout de repas s\'ouvre depuis l\'accueil sans crash',
      (tester) async {
    // ErrorWidget par défaut : en cas d'échec de build d'un sous-arbre,
    // le test doit échouer sur l'exception d'origine, pas sur un rendu.
    final ancien = ErrorWidget.builder;
    addTearDown(() => ErrorWidget.builder = ancien);

    await tester.pumpWidget(const AzimiamApp());
    await pomper(tester);

    await tester.tap(find.text('Ajouter un repas'));
    await pomper(tester);

    // Avant le correctif, ce TextField levait « Null check operator used
    // on a null value » dans _TextFieldState._getEffectiveDecoration.
    expect(find.byKey(const Key('champSaisieAliment')), findsOneWidget);
  });
}
