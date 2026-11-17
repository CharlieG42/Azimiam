import 'package:shared_preferences/shared_preferences.dart';

/// Réglages de l'application (clé API, objectifs quotidiens).
class Reglages {
  final String cleApi;
  final String baseUrl;
  final String modele;
  final double objectifKcal;
  final double objectifProt;
  final double objectifGluc;
  final double objectifLip;

  const Reglages({
    this.cleApi = '',
    this.baseUrl = 'https://api.mistral.ai/v1',
    this.modele = 'pixtral-12b-2409',
    this.objectifKcal = 2000,
    this.objectifProt = 100,
    this.objectifGluc = 220,
    this.objectifLip = 70,
  });

  bool get iaDisponible => cleApi.isNotEmpty;
}

class ServiceReglages {
  static Future<Reglages> charger() async {
    final prefs = await SharedPreferences.getInstance();
    return Reglages(
      cleApi: prefs.getString('cleApi') ?? '',
      baseUrl: prefs.getString('baseUrl') ?? 'https://api.mistral.ai/v1',
      modele: prefs.getString('modele') ?? 'pixtral-12b-2409',
      objectifKcal: prefs.getDouble('objectifKcal') ?? 2000,
      objectifProt: prefs.getDouble('objectifProt') ?? 100,
      objectifGluc: prefs.getDouble('objectifGluc') ?? 220,
      objectifLip: prefs.getDouble('objectifLip') ?? 70,
    );
  }

  static Future<void> sauver(Reglages reglages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cleApi', reglages.cleApi);
    await prefs.setString('baseUrl', reglages.baseUrl);
    await prefs.setString('modele', reglages.modele);
    await prefs.setDouble('objectifKcal', reglages.objectifKcal);
    await prefs.setDouble('objectifProt', reglages.objectifProt);
    await prefs.setDouble('objectifGluc', reglages.objectifGluc);
    await prefs.setDouble('objectifLip', reglages.objectifLip);
  }
}
