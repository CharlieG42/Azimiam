import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:azimiam/models/activite.dart';
import 'package:azimiam/screens/accueil_ecran.dart';
import 'package:azimiam/screens/activites_ecran.dart';
import 'package:azimiam/services/service_sante.dart';
import 'package:azimiam/state/activites.dart';
import 'package:azimiam/state/hydratation.dart';
import 'package:azimiam/state/journal.dart';
import 'package:azimiam/state/progression.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('fr_FR');
  });

  ActiviteSport seance(
    DateTime moment,
    String type,
    double duree,
    double? km,
    double? dplus,
    int kcal,
  ) =>
      ActiviteSport(
        moment: moment,
        type: type,
        dureeMin: duree,
        distanceKm: km,
        deniveleM: dplus,
        kcal: kcal.toDouble(),
      );

  Widget hote(Activites activites, {Widget? enfant}) => MultiProvider(
        providers: [
          ChangeNotifierProvider<Journal>.value(value: Journal()),
          ChangeNotifierProvider<Progression>.value(value: Progression()),
          ChangeNotifierProvider<Activites>.value(value: activites),
          // v0.7.9 : l'accueil (pompé par un test) lit l'hydratation.
          ChangeNotifierProvider<Hydratation>.value(value: Hydratation()),
        ],
        child: MaterialApp(home: enfant ?? const ActivitesEcran()),
      );

  testWidgets('historique vide : message explicite', (tester) async {
    await tester.pumpWidget(hote(Activites()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucune activité déclarée'), findsOneWidget);
    expect(find.text('Déclarer une activité'), findsOneWidget);
  });

  testWidgets('résumé 7 jours + séances groupées par jour', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final maintenant = DateTime.now();
    final activites = Activites();
    activites.liste = [
      seance(maintenant.subtract(const Duration(hours: 3)), 'marche',
          45, 10.2, 150, 234),
      seance(maintenant.subtract(const Duration(days: 1)), 'course',
          60, 12, 250, 880),
      // Hors fenêtre 7 jours : présente dans l'historique, pas dans le
      // résumé de semaine.
      seance(maintenant.subtract(const Duration(days: 30)), 'course',
          60, 8, null, 900),
    ];

    await tester.pumpWidget(hote(activites));
    await tester.pumpAndSettle();

    // Résumé : les deux séances récentes, pas l'ancienne.
    expect(find.text('1114 kcal'), findsOneWidget);
    expect(find.text('2 séances · 1 h 45 · 22.2 km'), findsOneWidget);

    // Les trois séances sont dans l'historique, avec leurs calories.
    expect(find.text('Marche'), findsOneWidget);
    expect(find.text('234 kcal'), findsOneWidget);
    expect(find.text('880 kcal'), findsOneWidget);
    expect(find.text('900 kcal'), findsOneWidget);
    // Détail de la marche : durée, distance, dénivelé.
    expect(find.text('45 min · 10.2 km · D+ 150 m'), findsOneWidget);
  });

  testWidgets('déclarer : calories calculées en direct depuis la saisie',
      (tester) async {
    final activites = Activites();
    await tester.pumpWidget(hote(activites));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Déclarer une activité'));
    await tester.pumpAndSettle();

    // Type par défaut = Marche (premier du catalogue), avec distance et
    // dénivelé proposés.
    expect(find.text('Distance (km, optionnel)'), findsOneWidget);
    expect(find.text('Dénivelé positif (m, optionnel)'), findsOneWidget);

    // Aucune pesée dans le profil de test : estimation sur 70 kg.
    expect(find.textContaining('estimé sur 70 kg'), findsOneWidget);

    // Durée saisie -> calories recalculées (3,5 x 70 x 0,5 h = 122,5).
    await tester.enterText(find.byType(TextField).at(0), '30');
    await tester.pump();
    expect(find.text('123'), findsOneWidget);
  });

  testWidgets('déclarer : type sans distance ni dénivelé, saisie manuelle'
      ' puis retour au calcul', (tester) async {
    final activites = Activites();
    await tester.pumpWidget(hote(activites));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Déclarer une activité'));
    await tester.pumpAndSettle();

    // Changer de type : Natation (pas de distance, pas de dénivelé).
    await tester.tap(find.byKey(const Key('dropdownTypeActivite')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Natation').last);
    await tester.tap(find.text('Natation').last);
    await tester.pumpAndSettle();
    expect(find.text('Distance (km, optionnel)'), findsNothing);
    expect(find.text('Dénivelé positif (m, optionnel)'), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), '30');
    await tester.pump();
    // 7 x 70 x 0,5 = 245.
    expect(find.text('245'), findsOneWidget);

    // Saisie manuelle : fige la valeur et masque l'aperçu de calcul.
    await tester.enterText(
        find.widgetWithText(TextField, 'Calories dépensées (kcal)'), '999');
    await tester.pump();
    expect(find.text('999'), findsOneWidget);
    expect(find.textContaining('estimé sur 70 kg'), findsNothing);

    // « Calcul automatique » : retour à la valeur calculée.
    await tester.tap(find.text('Calcul automatique'));
    await tester.pump();
    expect(find.text('245'), findsOneWidget);
    expect(find.textContaining('estimé sur 70 kg'), findsOneWidget);
  });

  testWidgets('le tiroir de l\'accueil ouvre l\'écran Activités',
      (tester) async {
    await tester.pumpWidget(hote(Activites(), enfant: const AccueilEcran()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    // Le corps de l'accueil a aussi un chip « Activités » : viser
    // l'entrée du tiroir précisément.
    await tester.tap(find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Activités'),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucune activité déclarée'), findsOneWidget);
  });

  testWidgets('badge montre pour les séances importées depuis Garmin '
      '(v0.7.0)', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final maintenant = DateTime.now();
    final activites = Activites();
    activites.liste = [
      // Séance importée depuis la montre Garmin : badge montre.
      ActiviteSport(
        moment: maintenant.subtract(const Duration(hours: 2)),
        type: 'course',
        dureeMin: 45,
        distanceKm: 8,
        kcal: 520,
        cleExterne: 'uuid-hc-1',
        source: 'com.garmin.android.apps.connectmobile',
      ),
      // Séance importée d'une autre source : badge Health Connect.
      ActiviteSport(
        moment: maintenant.subtract(const Duration(days: 1)),
        type: 'marche',
        dureeMin: 30,
        kcal: 160,
        cleExterne: 'uuid-hc-2',
        source: 'com.autre.app.sport',
      ),
      // Saisie manuelle : aucun badge.
      seance(maintenant.subtract(const Duration(days: 2)), 'velo', 60, 20, 300,
          250),
    ];
    activites.infoImport = '2 séances importées depuis Health Connect';

    await tester.pumpWidget(hote(activites));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.watch_outlined), findsOneWidget);
    expect(find.byIcon(Icons.health_and_safety_outlined), findsOneWidget);
    expect(
        find.textContaining('séances importées depuis Health Connect'),
        findsOneWidget);
  });

  testWidgets('le tirer-à-rafraîchir relance l\'import Santé Connect (v0.7.7)',
      (tester) async {
    // Source simulée qui refuse l'autorisation : le tirer-à-rafraîchir
    // doit déclencher l'import et en afficher le résultat explicite.
    final activites = Activites(sourceSante: _SourceSanteRefus());
    await tester.pumpWidget(hote(activites));
    await tester.pumpAndSettle();

    // Rien à importer tant que la liste n'a pas été tirée.
    expect(find.textContaining('Import impossible'), findsNothing);

    await tester.fling(
        find.byType(ListView), const Offset(0, 400), 1000.0);
    await tester.pumpAndSettle();
    expect(find.textContaining('Import impossible'), findsOneWidget);
  });
}

/// Fausse source santé qui refuse l'autorisation Health Connect :
/// permet de vérifier en test widget que le tirer-à-rafraîchir de
/// l'écran Activités relance bien l'import (v0.7.7) sans toucher
/// à Health Connect ni à la base.
class _SourceSanteRefus implements SourceSante {
  @override
  Future<bool> demanderAutorisation() async => false;

  @override
  Future<List<SeanceSante>> seancesEntre(DateTime debut, DateTime fin) =>
      Future.value(const []);

  @override
  Future<List<PeseeSante>> peseesEntre(DateTime debut, DateTime fin) =>
      Future.value(const []);

  @override
  Future<List<SeanceSommeil>> sommeilEntre(DateTime debut, DateTime fin) =>
      Future.value(const []);

  @override
  Future<List<MesureFc>> fcReposEntre(DateTime debut, DateTime fin) =>
      Future.value(const []);

  @override
  Future<int?> fcMinEntre(DateTime debut, DateTime fin) async => null;

  @override
  Future<CompteursJour?> compteursJour(DateTime jour) async => null;
}
