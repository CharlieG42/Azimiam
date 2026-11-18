import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/repas.dart';
import '../models/valeurs.dart';
import '../services/service_plan.dart';
import '../services/service_reglages.dart';
import '../state/journal.dart';

/// Écran Plan nutritionnel : propose une journée type construite depuis la
/// mini-base locale et ajustée aux objectifs quotidiens. Le plan peut être
/// ajout au journal en un geste.
class PlanEcran extends StatefulWidget {
  const PlanEcran({super.key});

  @override
  State<PlanEcran> createState() => _PlanEcranState();
}

class _PlanEcranState extends State<PlanEcran> {
  Reglages? _reglages;
  List<RepasSuggere> _plan = [];
  DateTime _date = DateTime.now();
  bool _chargement = true;
  String? _erreur;

  static const Map<String, int> _heures = {
    'Petit-déjeuner': 8,
    'Déjeuner': 12,
    'Collation': 16,
    'Dîner': 20,
  };

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
        _reglages = reglages;
        _plan = _generer(reglages, _date);
        _erreur = null;
        _chargement = false;
      });
    } catch (e) {
      // Repli sur les objectifs par défaut : l'écran n'est jamais bloqué
      // sur un chargement infini.
      if (!mounted) return;
      setState(() {
        _reglages = const Reglages();
        _plan = _generer(const Reglages(), _date);
        _erreur = e.toString();
        _chargement = false;
      });
    }
  }

  List<RepasSuggere> _generer(Reglages reglages, DateTime date) =>
      ServicePlan.planDuJour(
        ValeursNutritionnelles(
          kcal: reglages.objectifKcal,
          proteines: reglages.objectifProt,
          glucides: reglages.objectifGluc,
          lipides: reglages.objectifLip,
        ),
        date: date,
      );

  void _changerJour(int jours) {
    setState(() {
      _date = _date.add(Duration(days: jours));
      _plan = _generer(_reglages!, _date);
    });
  }

  Future<void> _ajouterAuJournal() async {
    final journal = context.read<Journal>();
    for (final repas in _plan) {
      await journal.ajouter(Repas(
        prisLe: DateTime(
          _date.year,
          _date.month,
          _date.day,
          _heures[repas.type] ?? 12,
        ),
        type: repas.type,
        lignes: repas.lignes
            .map((l) => LigneRepas(
                  nom: l.nom,
                  grammes: l.grammes,
                  pour100: l.pour100,
                  source: 'plan',
                  reconnu: true,
                ))
            .toList(),
      ));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Plan du ${DateFormat('d MMMM', 'fr_FR').format(_date)} '
          'ajouté au journal (${_plan.length} repas).',
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final objectifs = _reglages == null
        ? null
        : ValeursNutritionnelles(
            kcal: _reglages!.objectifKcal,
            proteines: _reglages!.objectifProt,
            glucides: _reglages!.objectifGluc,
            lipides: _reglages!.objectifLip,
          );
    final total = ServicePlan.totalPlan(_plan);
    final titreDate =
        DateFormat('EEEE d MMMM', 'fr_FR').format(_date);

    return Scaffold(
      appBar: AppBar(title: const Text('Plan nutritionnel')),
      body: _chargement || objectifs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_erreur != null)
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Objectifs par défaut utilisés (erreur : $_erreur).',
                            ),
                          ),
                          TextButton(
                            onPressed: _charger,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_erreur != null) const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Jour précédent',
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => _changerJour(-1),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '${titreDate[0].toUpperCase()}'
                                '${titreDate.substring(1)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Objectif visé : ${objectifs.kcal.round()} kcal · '
                                'P ${objectifs.proteines.round()} g · '
                                'G ${objectifs.glucides.round()} g · '
                                'L ${objectifs.lipides.round()} g',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Jour suivant',
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => _changerJour(1),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final repas in _plan)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CarteRepasSuggere(repas: repas),
                  ),
                _CarteTotalPlan(total: total, objectifs: objectifs),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Ajouter ce plan au journal'),
                  onPressed: _plan.isEmpty ? null : _ajouterAuJournal,
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

/// Carte d'un repas proposé : lignes d'aliments + total du repas.
class _CarteRepasSuggere extends StatelessWidget {
  final RepasSuggere repas;

  const _CarteRepasSuggere({required this.repas});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(repas.type,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  '${repas.total.kcal.round()} kcal',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            for (final ligne in repas.lignes)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(ligne.nom)),
                    Text(
                      '${ligne.grammes.round()} g',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${ligne.valeurs.kcal.round()} kcal',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Carte récapitulative : totaux du plan vs objectifs, avec jauges.
class _CarteTotalPlan extends StatelessWidget {
  final ValeursNutritionnelles total;
  final ValeursNutritionnelles objectifs;

  const _CarteTotalPlan({required this.total, required this.objectifs});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total du plan : ${total.kcal.round()} kcal '
              'sur ${objectifs.kcal.round()} kcal visés',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _Jauge(
                libelle: 'Calories',
                valeur: total.kcal,
                objectif: objectifs.kcal,
                unite: 'kcal'),
            _Jauge(
                libelle: 'Protéines',
                valeur: total.proteines,
                objectif: objectifs.proteines,
                unite: 'g'),
            _Jauge(
                libelle: 'Glucides',
                valeur: total.glucides,
                objectif: objectifs.glucides,
                unite: 'g'),
            _Jauge(
                libelle: 'Lipides',
                valeur: total.lipides,
                objectif: objectifs.lipides,
                unite: 'g'),
          ],
        ),
      ),
    );
  }
}

class _Jauge extends StatelessWidget {
  final String libelle;
  final double valeur;
  final double objectif;
  final String unite;

  const _Jauge({
    required this.libelle,
    required this.valeur,
    required this.objectif,
    required this.unite,
  });

  @override
  Widget build(BuildContext context) {
    final ratio =
        objectif > 0 ? (valeur / objectif).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$libelle : ${valeur.round()} / ${objectif.round()} $unite',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }
}
