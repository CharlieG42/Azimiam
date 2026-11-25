import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:azimiam/models/repas.dart';
import 'package:azimiam/models/valeurs.dart';
import 'package:azimiam/screens/modifier_repas_ecran.dart';
import 'package:azimiam/state/journal.dart';

/// Tests de l'écran « Modifier le repas » : date et heure éditables (v0.6.2).
void main() {
  setUp(() async {
    await initializeDateFormatting('fr_FR');
  });

  Repas repasTest() => Repas(
        id: 1,
        prisLe: DateTime(2026, 11, 24, 19, 42),
        type: 'Dîner',
        lignes: [
          LigneRepas(
            nom: 'Lasagne',
            grammes: 300,
            pour100: const ValeursNutritionnelles(
              kcal: 130,
              proteines: 7,
              glucides: 12,
              lipides: 5,
            ),
          ),
        ],
      );

  Widget pompe(Repas repas) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Journal()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', 'FR')],
        home: ModifierRepasEcran(repas: repas),
      ),
    );
  }

  testWidgets('affiche la date et l\'heure du repas', (tester) async {
    await tester.pumpWidget(pompe(repasTest()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('boutonDateRepas')), findsOneWidget);
    expect(find.text('Mardi 24 novembre 2026'), findsOneWidget);
    expect(find.byKey(const Key('boutonHeureRepas')), findsOneWidget);
    expect(find.text('19:42'), findsOneWidget);
  });

  testWidgets('la date du repas se change via le calendrier', (tester) async {
    await tester.pumpWidget(pompe(repasTest()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boutonDateRepas')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // Choix du 25 du mois affiché, puis validation : le repas du mardi
    // devient un repas du mercredi.
    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.text('Mercredi 25 novembre 2026'), findsOneWidget);
    // L'heure est conservée.
    expect(find.text('19:42'), findsOneWidget);
  });

  testWidgets('l\'heure du repas se change ; annulation = inchangée',
      (tester) async {
    await tester.pumpWidget(pompe(repasTest()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boutonHeureRepas')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.text('19:42'), findsOneWidget);
  });
}
