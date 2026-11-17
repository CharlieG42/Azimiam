import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/repas.dart';
import '../models/valeurs.dart';
import '../services/service_reglages.dart';
import '../state/journal.dart';
import 'ajout_repas_ecran.dart';
import 'reglages_ecran.dart';

/// Écran principal : résumé de la journée + liste des repas.
class AccueilEcran extends StatelessWidget {
  const AccueilEcran({super.key});

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<Journal>();
    final titreJour = DateFormat('EEEE d MMMM', 'fr_FR').format(journal.jour);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${titreJour[0].toUpperCase()}${titreJour.substring(1)}',
        ),
        actions: [
          IconButton(
            tooltip: 'Jour précédent',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => journal
                .changerJour(journal.jour.subtract(const Duration(days: 1))),
          ),
          IconButton(
            tooltip: 'Aujourd\'hui',
            icon: const Icon(Icons.today_outlined),
            onPressed: () => journal.changerJour(DateTime.now()),
          ),
          IconButton(
            tooltip: 'Jour suivant',
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                journal.changerJour(journal.jour.add(const Duration(days: 1))),
          ),
          IconButton(
            tooltip: 'Réglages',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReglagesEcran()),
            ),
          ),
        ],
      ),
      body: journal.enChargement
          ? const Center(child: CircularProgressIndicator())
          : _Contenu(journal: journal),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.restaurant_menu),
        label: const Text('Ajouter un repas'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AjoutRepasEcran()),
        ),
      ),
    );
  }
}

class _Contenu extends StatelessWidget {
  final Journal journal;

  const _Contenu({required this.journal});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => journal.changerJour(journal.jour),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _CarteResume(
            total: journal.total,
            reglages: journal.reglages,
          ),
          if (journal.erreur != null)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(journal.erreur!)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (journal.repas.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.restaurant_outlined,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'Aucun repas enregistré ce jour-là.\nTouchez « Ajouter un repas » pour photographier votre assiette.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            ...journal.repas.map(
              (repas) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CarteRepas(
                  repas: repas,
                  onSupprimer: () => journal.supprimer(repas.id!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CarteResume extends StatelessWidget {
  final ValeursNutritionnelles total;
  final Reglages reglages;

  const _CarteResume({required this.total, required this.reglages});

  @override
  Widget build(BuildContext context) {
    final ratio = reglages.objectifKcal > 0
        ? (total.kcal / reglages.objectifKcal).clamp(0.0, 1.0)
        : 0.0;
    final reste = reglages.objectifKcal - total.kcal;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${total.kcal.round()} kcal',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'sur ${reglages.objectifKcal.round()} kcal d\'objectif',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                if (reste > 0)
                  Text(
                    'reste ≈ ${reste.round()} kcal',
                    style: TextStyle(color: Colors.green.shade700),
                  )
                else
                  Text(
                    'objectif dépassé de ${(reste * -1).round()} kcal',
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Macro(
                  icone: Icons.egg_alt_outlined,
                  libelle: 'Protéines',
                  valeur: total.proteines,
                  objectif: reglages.objectifProt,
                  couleur: Colors.red.shade400,
                ),
                _Macro(
                  icone: Icons.bakery_dining_outlined,
                  libelle: 'Glucides',
                  valeur: total.glucides,
                  objectif: reglages.objectifGluc,
                  couleur: Colors.amber.shade700,
                ),
                _Macro(
                  icone: Icons.water_drop_outlined,
                  libelle: 'Lipides',
                  valeur: total.lipides,
                  objectif: reglages.objectifLip,
                  couleur: Colors.blue.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final double valeur;
  final double objectif;
  final Color couleur;

  const _Macro({
    required this.icone,
    required this.libelle,
    required this.valeur,
    required this.objectif,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icone, color: couleur, size: 20),
          const SizedBox(height: 2),
          Text(
            libelle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          Text(
            '${valeur.round()} / ${objectif.round()} g',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _CarteRepas extends StatelessWidget {
  final Repas repas;
  final VoidCallback onSupprimer;

  const _CarteRepas({required this.repas, required this.onSupprimer});

  @override
  Widget build(BuildContext context) {
    final heure = DateFormat('HH:mm').format(repas.prisLe);
    final resume = repas.lignes
        .map((l) => '${l.nom} (${l.grammes.round()} g)')
        .join(' · ');

    return Dismissible(
      key: ValueKey('repas-${repas.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onSupprimer(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: repas.photo != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(repas.photo!),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                )
              : CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: Text(
                    repas.type.substring(0, 1),
                    style: TextStyle(color: Colors.green.shade800),
                  ),
                ),
          title: Text('${repas.type} · $heure'),
          subtitle: Text(
            resume.isEmpty ? 'Repas vide' : resume,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            '${repas.total.kcal.round()} kcal',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
