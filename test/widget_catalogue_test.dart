import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:azimiam/data/mini_base.dart';
import 'package:azimiam/models/valeurs.dart';
import 'package:azimiam/screens/catalogue_ecran.dart';
import 'package:azimiam/state/catalogue.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('fr_FR');
  });

  Catalogue catalogueAvecPerso() {
    final catalogue = Catalogue();
    catalogue.perso = [
      Aliment(
        'Gâteau de mamie',
        ['gateau mamie'],
        const ValeursNutritionnelles(
            kcal: 320, proteines: 5, glucides: 45, lipides: 12),
        perso: true,
        id: 7,
      ),
    ];
    catalogue.tous = [...BaseAliments.tous, ...catalogue.perso];
    return catalogue;
  }

  Widget hote(Catalogue catalogue) => ChangeNotifierProvider<Catalogue>.value(
        value: catalogue,
        child: const MaterialApp(home: CatalogueEcran()),
      );

  testWidgets('le catalogue affiche base + aliments perso, avec compteur',
      (tester) async {
    tester.view.physicalSize = const Size(800, 10000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final catalogue = catalogueAvecPerso();
    await tester.pumpWidget(hote(catalogue));
    await tester.pumpAndSettle();

    // Titre avec le nombre total (120 base + 1 perso).
    expect(find.text('Catalogue d\'aliments (121)'), findsOneWidget);

    // L'aliment perso est là, marqué « Perso » (viewport très haut pour
    // forcer la liste paresseuse à tout construire).
    expect(find.text('Gâteau de mamie'), findsOneWidget);
    expect(find.textContaining('Perso'), findsWidgets);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets('recherche multi-mots dans le catalogue complet', (tester) async {
    await tester.pumpWidget(hote(catalogueAvecPerso()));
    await tester.pumpAndSettle();

    // Mots non contigus : ce que signalait Charlie.
    await tester.enterText(
        find.byKey(const Key('champRechercheCatalogue')), 'pommes terre');
    await tester.pumpAndSettle();
    expect(find.text('Pommes de terre cuites'), findsOneWidget);
    expect(find.text('Poulet grillé'), findsNothing);

    // L'aliment perso se retrouve aussi par son alias.
    await tester.enterText(
        find.byKey(const Key('champRechercheCatalogue')), 'gateau mamie');
    await tester.pumpAndSettle();
    expect(find.text('Gâteau de mamie'), findsOneWidget);
  });

  testWidgets('le bouton + ouvre la fiche de création d\'un aliment',
      (tester) async {
    await tester.pumpWidget(hote(catalogueAvecPerso()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fabAjouterAliment')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialogNouvelAliment')), findsOneWidget);
    expect(find.byKey(const Key('champNomAliment')), findsOneWidget);

    // Validation sans rien saisir : message d'erreur, pas d'ajout.
    await tester.tap(find.byKey(const Key('boutonEnregistrerAliment')));
    await tester.pump();
    expect(find.textContaining('Nom et calories / 100 g sont requis'),
        findsOneWidget);
    // Le dialogue reste ouvert.
    expect(find.byKey(const Key('dialogNouvelAliment')), findsOneWidget);
  });
}
