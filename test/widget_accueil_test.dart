import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:azimiam/screens/a_propos_ecran.dart';
import 'package:azimiam/screens/accueil_ecran.dart';
import 'package:azimiam/screens/plan_ecran.dart';
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

  testWidgets('le menu ⋮ ouvre le plan nutritionnel', (tester) async {
    await tester.pumpWidget(pompe());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan nutritionnel').last);
    await tester.pumpAndSettle();
    expect(find.byType(PlanEcran), findsOneWidget);
  });
}
