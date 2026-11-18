import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/journal.dart';
import 'reglages_ecran.dart';

/// Écran Plan nutritionnel : fixe les OBJECTIFS GLOBAUX de la journée
/// (calories, protéines, glucides, lipides) et affiche la progression réelle
/// du jour (réalisé / objectif / reste) — sans imposer de plats précis.
class PlanEcran extends StatelessWidget {
  const PlanEcran({super.key});

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<Journal>();
    final reglages = journal.reglages;
    final total = journal.total;
    final titre = DateFormat('EEE d MMM', 'fr_FR').format(journal.jour);

    final lignes = <_LigneObjectif>[
      _LigneObjectif(
        icone: Icons.local_fire_department_outlined,
        libelle: 'Calories',
        unite: 'kcal',
        objectif: reglages.objectifKcal,
        valeur: total.kcal,
        couleur: Colors.orange.shade700,
      ),
      _LigneObjectif(
        icone: Icons.egg_alt_outlined,
        libelle: 'Protéines',
        unite: 'g',
        objectif: reglages.objectifProt,
        valeur: total.proteines,
        couleur: Colors.red.shade400,
      ),
      _LigneObjectif(
        icone: Icons.bakery_dining_outlined,
        libelle: 'Glucides',
        unite: 'g',
        objectif: reglages.objectifGluc,
        valeur: total.glucides,
        couleur: Colors.amber.shade700,
      ),
      _LigneObjectif(
        icone: Icons.water_drop_outlined,
        libelle: 'Lipides',
        unite: 'g',
        objectif: reglages.objectifLip,
        valeur: total.lipides,
        couleur: Colors.blue.shade400,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Plan nutritionnel')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Objectifs globaux — $titre',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Des cibles globales pour la journée, sans aucun plat '
                    'imposé : enregistrez vos repas librement dans le journal.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Divider(height: 20),
                  for (final ligne in lignes) ...[
                    _WidgetLigneObjectif(ligne: ligne),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Modifier les objectifs (Réglages)'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ReglagesEcran()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneObjectif {
  final IconData icone;
  final String libelle;
  final String unite;
  final double objectif;
  final double valeur;
  final Color couleur;

  const _LigneObjectif({
    required this.icone,
    required this.libelle,
    required this.unite,
    required this.objectif,
    required this.valeur,
    required this.couleur,
  });
}

class _WidgetLigneObjectif extends StatelessWidget {
  final _LigneObjectif ligne;

  const _WidgetLigneObjectif({required this.ligne});

  @override
  Widget build(BuildContext context) {
    final ratio = ligne.objectif > 0
        ? (ligne.valeur / ligne.objectif).clamp(0.0, 1.0)
        : 0.0;
    final reste = ligne.objectif - ligne.valeur;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(ligne.icone, color: ligne.couleur, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ligne.libelle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${ligne.valeur.round()} / ${ligne.objectif.round()} ${ligne.unite}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: ligne.couleur,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          reste > 0
              ? 'reste ≈ ${reste.round()} ${ligne.unite}'
              : 'objectif atteint (+${reste.abs().round()} ${ligne.unite})',
          style: TextStyle(
            fontSize: 12,
            color: reste > 0 ? Colors.green.shade700 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
