import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profil.dart';
import '../services/service_base.dart';
import '../services/service_imc.dart';
import '../services/service_reglages.dart';
import '../state/journal.dart';
import '../state/progression.dart';

/// Réglages : clé API Mistral, modèle de vision, objectifs quotidiens.
class ReglagesEcran extends StatefulWidget {
  const ReglagesEcran({super.key});

  @override
  State<ReglagesEcran> createState() => _ReglagesEcranState();
}

class _ReglagesEcranState extends State<ReglagesEcran> {
  final _cleApiCtl = TextEditingController();
  final _baseUrlCtl = TextEditingController();
  final _modeleCtl = TextEditingController();
  final _kcalCtl = TextEditingController();
  final _protCtl = TextEditingController();
  final _glucCtl = TextEditingController();
  final _lipCtl = TextEditingController();
  final _tailleCtl = TextEditingController();
  final _ageCtl = TextEditingController();
  final _poidsCibleCtl = TextEditingController();

  String _sexe = 'f';
  String _activite = 'modere';
  String _objectif = 'maintien';

  bool _cleVisible = false;
  bool _initialise = false;
  String? _erreurChargement;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final reglages = await ServiceReglages.charger();
      if (!mounted) return;
      setState(() {
        _remplir(reglages);
        _erreurChargement = null;
        _initialise = true;
      });
    } catch (e) {
      // Même en cas d'erreur, le formulaire reste affiché (valeurs courantes)
      // avec une bannière : jamais d'écran gris bloquant.
      if (!mounted) return;
      setState(() {
        _erreurChargement = e.toString();
        _initialise = true;
      });
    }
  }

  void _remplir(Reglages reglages) {
    _cleApiCtl.text = reglages.cleApi;
    _baseUrlCtl.text = reglages.baseUrl;
    _modeleCtl.text = reglages.modele;
    _kcalCtl.text = reglages.objectifKcal.round().toString();
    _protCtl.text = reglages.objectifProt.round().toString();
    _glucCtl.text = reglages.objectifGluc.round().toString();
    _lipCtl.text = reglages.objectifLip.round().toString();
    _tailleCtl.text = reglages.profil.tailleCm?.toStringAsFixed(0) ?? '';
    _ageCtl.text = reglages.profil.age?.toString() ?? '';
    _poidsCibleCtl.text = reglages.profil.poidsCibleKg?.toStringAsFixed(1) ?? '';
    _sexe = reglages.profil.sexe;
    _activite = reglages.profil.activite;
    _objectif = reglages.profil.objectif;
  }

  Profil _profilCourant() => Profil(
        tailleCm: double.tryParse(_tailleCtl.text.replaceAll(',', '.')),
        age: int.tryParse(_ageCtl.text.trim()),
        sexe: _sexe,
        activite: _activite,
        objectif: _objectif,
        poidsCibleKg:
            double.tryParse(_poidsCibleCtl.text.replaceAll(',', '.')),
      );

  /// Calcule les objectifs quotidiens à partir du profil (métabolisme de
  /// base Mifflin-St Jeor x activité, ajusté selon l'objectif de poids)
  /// et de la dernière pesée connue.
  Future<void> _calculerAuto() async {
    final profil = _profilCourant();
    final poids =
        await ServiceBase.instance.dernierPoids() ?? profil.poidsCibleKg;
    if (!profil.complet || poids == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Renseignez d\'abord la taille et l\'âge, et saisissez une pesée '
              '(écran « Progression & IMC »).'),
        ),
      );
      return;
    }
    final objectifs = ServiceImc.objectifsAuto(profil, poids);
    setState(() {
      _kcalCtl.text = objectifs.kcal.round().toString();
      _protCtl.text = objectifs.proteines.round().toString();
      _glucCtl.text = objectifs.glucides.round().toString();
      _lipCtl.text = objectifs.lipides.round().toString();
    });
  }

  Future<void> _enregistrer() async {
    final reglages = Reglages(
      cleApi: _cleApiCtl.text.trim(),
      baseUrl: _baseUrlCtl.text.trim().isEmpty
          ? 'https://api.mistral.ai/v1'
          : _baseUrlCtl.text.trim(),
      modele: _modeleCtl.text.trim().isEmpty
          ? 'pixtral-12b-2409'
          : _modeleCtl.text.trim(),
      objectifKcal: double.tryParse(_kcalCtl.text) ?? 2000,
      objectifProt: double.tryParse(_protCtl.text) ?? 100,
      objectifGluc: double.tryParse(_glucCtl.text) ?? 220,
      objectifLip: double.tryParse(_lipCtl.text) ?? 70,
      profil: _profilCourant(),
    );
    await ServiceReglages.sauver(reglages);
    if (!mounted) return;
    // Rafraîchit les objectifs affichés sur l'accueil et le profil.
    await context.read<Journal>().charger();
    await context.read<Progression>().charger();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Réglages enregistrés')),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _cleApiCtl.dispose();
    _baseUrlCtl.dispose();
    _modeleCtl.dispose();
    _kcalCtl.dispose();
    _protCtl.dispose();
    _glucCtl.dispose();
    _lipCtl.dispose();
    _tailleCtl.dispose();
    _ageCtl.dispose();
    _poidsCibleCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: !_initialise
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ----- Erreur de chargement (le formulaire reste utilisable) -----
                  if (_erreurChargement != null)
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Réglages chargés avec les valeurs par défaut '
                                    '(lecture des préférences impossible : '
                                    '$_erreurChargement).',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                              onPressed: _charger,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ----- Couche IA -----
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Couche IA (vision)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Créez une clé API sur console.mistral.ai. '
                            'La photo du repas est envoyée au modèle ci-dessous '
                            'uniquement pour identifier les aliments ; les valeurs '
                            'nutritionnelles, elles, restent calculées localement '
                            'à partir de la base de l\'application.',
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _cleApiCtl,
                            obscureText: !_cleVisible,
                            decoration: InputDecoration(
                              labelText: 'Clé API',
                              suffixIcon: IconButton(
                                icon: Icon(_cleVisible
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () =>
                                    setState(() => _cleVisible = !_cleVisible),
                              ),
                            ),
                          ),
                          TextField(
                            controller: _modeleCtl,
                            decoration: const InputDecoration(
                                labelText: 'Modèle (ex. pixtral-12b-2409)'),
                          ),
                          TextField(
                            controller: _baseUrlCtl,
                            decoration: const InputDecoration(
                                labelText:
                                    'URL de base (endpoint OpenAI-compatible)'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ----- Profil & objectif de poids -----
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profil & objectif de poids',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Taille, âge et activité servent à calculer votre '
                            'IMC et vos objectifs automatiquement '
                            '(voir « Progression & IMC »).',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _tailleCtl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Taille (cm)'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _ageCtl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Âge (ans)'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text('Sexe',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700)),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                    value: 'f',
                                    label: Text('Femme'),
                                    icon: Icon(Icons.female)),
                                ButtonSegment(
                                    value: 'h',
                                    label: Text('Homme'),
                                    icon: Icon(Icons.male)),
                              ],
                              selected: {_sexe},
                              onSelectionChanged: (selection) => setState(
                                  () => _sexe = selection.first),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _activite,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Activité physique'),
                            items: [
                              for (final entree in Profil.activites.entries)
                                DropdownMenuItem(
                                    value: entree.key,
                                    child: Text(entree.value)),
                            ],
                            onChanged: (valeur) => setState(
                                () => _activite = valeur ?? 'modere'),
                          ),
                          const SizedBox(height: 10),
                          Text('Objectif de poids',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700)),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<String>(
                              segments: [
                                for (final entree in Profil.objectifs.entries)
                                  ButtonSegment(
                                      value: entree.key,
                                      label: Text(entree.value)),
                              ],
                              selected: {_objectif},
                              onSelectionChanged: (selection) => setState(
                                  () => _objectif = selection.first),
                            ),
                          ),
                          if (_objectif != 'maintien') ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: _poidsCibleCtl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Poids cible (kg)'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ----- Objectifs -----
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Objectifs quotidiens',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.auto_awesome_outlined),
                            label: const Text(
                                'Calculer automatiquement (métabolisme + objectif de poids)'),
                            onPressed: _calculerAuto,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _kcalCtl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Calories (kcal)'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _protCtl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Protéines (g)'),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _glucCtl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Glucides (g)'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _lipCtl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Lipides (g)'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Enregistrer'),
                    onPressed: _enregistrer,
                  ),
                ],
              ),
            ),
    );
  }
}
