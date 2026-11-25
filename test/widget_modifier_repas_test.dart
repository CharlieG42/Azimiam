import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:azimiam/models/repas.dart';
import 'package:azimiam/models/valeurs.dart';
import 'package:azimiam/screens/modifier_repas_ecran.dart';
import 'package:azimiam/state/journal.dart';

/// Tests de l'écran « Modifier le repas » : date éditable (v0.6.3 —
/// l'heure ne l'est pas : les étiquettes de repas suffisent).
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

  testWidgets('affiche la date du repas', (tester) async {
    await tester.pumpWidget(pompe(repasTest()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('boutonDateRepas')), findsOneWidget);
    expect(find.text('Mardi 24 novembre 2026'), findsOneWidget);
    // Pas de sélecteur d'heure : les étiquettes de repas suffisent.
    expect(find.byKey(const Key('boutonHeureRepas')), findsNothing);
  });

  testWidgets('la date du repas se change via le calendrier', (tester) async {
    await tester.pumpWidget(pompe(repasTest()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boutonDateRepas')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // Choix du 25 du mois affiché, puis validation : le repas du mardi
    // devient un repas du mercredi. L'heure enregistrée est conservée.
    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.text('Mercredi 25 novembre 2026'), findsOneWidget);
  });
}
