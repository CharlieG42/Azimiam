import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/accueil_ecran.dart';
import 'services/affichage_erreurs.dart';
import 'state/journal.dart';
import 'state/progression.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  // En mode release, Flutter remplace par défaut un sous-arbre qui plante
  // par une boîte grise muette : impossible de savoir ce qui a échoué.
  // On affiche plutôt l'erreur réelle pour diagnostiquer sur appareil réel.
  AffichageErreurs.installer();
  runApp(const AzimiamApp());
}

class AzimiamApp extends StatelessWidget {
  const AzimiamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Azimiam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
      ),
      // Sans ces délégués, \`supportedLocales\` limité au français fait
      // échouer MaterialLocalizations.of() (null) et plante en release
      // tous les widgets Material qui en dépendent : TextField, Drawer…
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR')],
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => Journal()..charger()),
          ChangeNotifierProvider(create: (_) => Progression()..charger()),
        ],
        child: const AccueilEcran(),
      ),
    );
  }
}
