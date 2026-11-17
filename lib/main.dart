import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/accueil_ecran.dart';
import 'state/journal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
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
      supportedLocales: const [Locale('fr', 'FR')],
      home: ChangeNotifierProvider(
        create: (_) => Journal()..charger(),
        child: const AccueilEcran(),
      ),
    );
  }
}
