import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/service_reglages.dart';
import '../state/journal.dart';

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

  bool _cleVisible = false;
  bool _initialise = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final reglages = await ServiceReglages.charger();
    if (!mounted) return;
    setState(() {
      _cleApiCtl.text = reglages.cleApi;
      _baseUrlCtl.text = reglages.baseUrl;
      _modeleCtl.text = reglages.modele;
      _kcalCtl.text = reglages.objectifKcal.round().toString();
      _protCtl.text = reglages.objectifProt.round().toString();
      _glucCtl.text = reglages.objectifGluc.round().toString();
      _lipCtl.text = reglages.objectifLip.round().toString();
      _initialise = true;
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
    );
    await ServiceReglages.sauver(reglages);
    if (!mounted) return;
    // Rafraîchit les objectifs affichés sur l'accueil.
    await context.read<Journal>().charger();
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
