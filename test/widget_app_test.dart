import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:azimiam/main.dart';

/// Régression : l'app déclarait \`supportedLocales: [Locale('fr', 'FR')]\`
/// sans les délégués de localisation, ce qui renvoyait \`null\` depuis
/// \`MaterialLocalizations.of()\` et plantait en release tous les widgets
/// qui en dépendent (TextField de l'écran d'ajout, tiroir de l'accueil…).
/// Les autres tests widget construisent leur propre MaterialApp en
/// anglais, ils ne couvraient donc pas ce cas : ici on pompe la vraie
/// application, telle que lancée sur appareil.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('fr_FR');
  });

  testWidgets(
      'l\'application réelle fournit MaterialLocalizations pour le français',
      (tester) async {
    await tester.pumpWidget(const AzimiamApp());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);

    // Le cœur du bug : la locale fr doit être résolue, pas renvoyer null.
    final contexte = tester.element(find.byType(Scaffold).first);
    expect(MaterialLocalizations.of(contexte), isNotNull);
    expect(
      Localizations.maybeLocaleOf(contexte),
      anyOf(isNull, equals(const Locale('fr', 'FR'))),
    );
  });

  testWidgets(
      'l\'écran d\'ajout de repas s\'ouvre depuis l\'accueil sans crash',
      (tester) async {
    // ErrorWidget par défaut : en cas d'échec de build, le test doit
    // échouer sur l'exception d'origine plutôt que sur un rendu d'erreur.
    final ancien = ErrorWidget.builder;
    addTearDown(() => ErrorWidget.builder = ancien);

    await tester.pumpWidget(const AzimiamApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajouter un repas'));
    await tester.pumpAndSettle();

    // Avant le correctif, ce TextField levait « Null check operator used
    // on a null value » dans _TextFieldState._getEffectiveDecoration.
    expect(find.byKey(const Key('champSaisieAliment')), findsOneWidget);
  });
}
