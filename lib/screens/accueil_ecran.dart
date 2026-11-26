import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/repas.dart';
import '../models/valeurs.dart';
import '../services/service_reglages.dart';
import '../services/service_sante.dart';
import '../state/activites.dart';
import '../state/journal.dart';
import 'a_propos_ecran.dart';
import 'activites_ecran.dart';
import 'ajout_repas_ecran.dart';
import 'modifier_repas_ecran.dart';
import 'plan_ecran.dart';
import 'progression_ecran.dart';
import 'reglages_ecran.dart';

/// Icône du groupe de repas sur l'accueil.
IconData _iconeType(String type) {
  switch (type) {
    case 'Petit-déjeuner':
      return Icons.emoji_food_beverage_outlined;
    case 'Déjeuner':
      return Icons.lunch_dining_outlined;
    case 'Collation':
      return Icons.icecream_outlined;
    case 'Dîner':
      return Icons.dinner_dining_outlined;
  }
  return Icons.restaurant_outlined;
}

/// Sous-total calorique des repas d'un type donné, pour l'en-tête du groupe.
double _sousTotal(Journal journal, String type) => journal.repas
    .where((r) => r.type == type)
    .fold(0.0, (acc, repas) => acc + repas.total.kcal);

/// v0.7.0 : vrai si les deux instants tombent le même jour civil.
bool _memeJour(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Écran principal : résumé de la journée + liste des repas.
class AccueilEcran extends StatelessWidget {
  const AccueilEcran({super.key});

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<Journal>();
    // Format court (« mar. 18 nov. ») pour ne pas couper la date dans la barre.
    final titreJour = DateFormat('EEE d MMM', 'fr_FR').format(journal.jour);

    return Scaffold(
      // Menu explicite : le bouton ☰ ouvre toujours le tiroir, sans dépendre
      // de l'inférence automatique de l'AppBar (fragile selon les appareils).
      drawerEnableOpenDragGesture: true,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Azimiam',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu_outlined),
              title: const Text('Journal'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('Progression & IMC'),
              onTap: () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.push(
                  MaterialPageRoute(builder: (_) => const ProgressionEcran()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_run),
              title: const Text('Activités'),
              onTap: () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.push(
                  MaterialPageRoute(builder: (_) => const ActivitesEcran()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Plan nutritionnel'),
              onTap: () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.push(
                  MaterialPageRoute(builder: (_) => const PlanEcran()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('À propos'),
              onTap: () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.push(
                  MaterialPageRoute(builder: (_) => const AProposEcran()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Réglages'),
              onTap: () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.push(
                  MaterialPageRoute(builder: (_) => const ReglagesEcran()),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(
          '${titreJour[0].toUpperCase()}${titreJour.substring(1)}',
          style: const TextStyle(fontSize: 17),
          overflow: TextOverflow.ellipsis,
        ),
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Jour précédent',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => journal
                .changerJour(journal.jour.subtract(const Duration(days: 1))),
          ),
          IconButton(
            tooltip: 'Jour suivant',
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                journal.changerJour(journal.jour.add(const Duration(days: 1))),
          ),
          // Le menu ⋮ a été retiré (v0.6.4) : ses entrées doublonnaient le
          // tiroir ☰. Seule l'action « Aujourd'hui » méritait un accès
          // direct, elle devient un bouton à part entière.
          IconButton(
            tooltip: 'Aujourd\u2019hui',
            icon: const Icon(Icons.today),
            onPressed: () => journal.changerJour(DateTime.now()),
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
          // Le repas est daté de la journée AFFICHÉE (hier inclus), pas de
          // « maintenant » : sinon le dîner d'hier se retrouvait daté du
          // jour où on le saisit.
          MaterialPageRoute(
              builder: (_) => AjoutRepasEcran(jour: journal.jour)),
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
    // Activités écoutées une seule fois : compteurs pas/étages du jour
    // courant et dépense sportive du jour affiché (v0.7.2).
    final activites = context.watch<Activites>();
    return RefreshIndicator(
      onRefresh: () => journal.changerJour(journal.jour),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _CarteResume(
            total: journal.total,
            reglages: journal.reglages,
            // Compteurs pas/étages : affichés seulement pour la journée
            // en cours (pas de sens sur une date passée feuilletée).
            sante: _memeJour(journal.jour, DateTime.now())
                ? activites.compteursJour
                : null,
            // Dépense sportive du jour affiché, créditée au budget
            // calorique (v0.7.2) : kcal des séances de ce jour-là.
            depense: activites.depenseJour(journal.jour),
          ),
          const SizedBox(height: 8),
          // Bouton d'ajout toujours visible (au-delà du bouton flottant),
          // pour que l'ajout d'un repas reste accessible à tout moment.
          FilledButton.icon(
            key: const Key('boutonAjouterRepas'),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Ajouter un repas'),
            onPressed: () => Navigator.push(
              context,
              // Idem bouton flottant : la journée affichée est transmise.
              MaterialPageRoute(
                  builder: (_) => AjoutRepasEcran(jour: journal.jour)),
            ),
          ),
          const SizedBox(height: 8),
          // Raccourcis visibles vers les vues de suivi et de plan.
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.insights_outlined, size: 18),
                label: const Text('Progression & IMC'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProgressionEcran()),
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.directions_run, size: 18),
                label: const Text('Activités'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ActivitesEcran()),
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Plan nutritionnel'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlanEcran()),
                ),
              ),
            ],
          ),
          // ----- Repas fréquents (favoris) -----
          if (journal.favoris.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Repas fréquents',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    for (final favori in journal.favoris.take(5))
                      Dismissible(
                        key: ValueKey('favori-${favori.id}'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) =>
                            journal.supprimerFavori(favori.id!),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading:
                              const Icon(Icons.star, color: Colors.amber),
                          title: Text(favori.nom),
                          subtitle: Text(
                            '${favori.type} · ${favori.total.kcal.round()} kcal',
                          ),
                          trailing: const Icon(Icons.playlist_add),
                          onTap: () async {
                            await journal.recreerFavori(favori);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      "« ${favori.nom} » recrée aujourd'hui."),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
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
          else ...[
            // ----- Repas du jour, groupés par type -----
            for (final type in typesRepas)
              if (journal.repas.any((r) => r.type == type)) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                  child: Row(
                    children: [
                      Icon(_iconeType(type), size: 18,
                          color: Colors.green.shade800),
                      const SizedBox(width: 6),
                      Text(
                        type,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${_sousTotal(journal, type).round()} kcal'
                          '${type != 'Dîner' ? '' : ''}',
                          style:
                              TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                ...journal.repas
                    .where((r) => r.type == type)
                    .map(
                      (repas) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CarteRepas(
                          repas: repas,
                          estFavori: journal.estFavori(repas),
                          onModifier: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ModifierRepasEcran(repas: repas),
                            ),
                          ),
                          onSupprimer: () => journal.supprimer(repas.id!),
                          onBasculerFavori: () =>
                              _basculerFavori(context, journal, repas),
                        ),
                      ),
                    ),
              ],
            // Repas dont le type sortirait de la liste (données anciennes).
            for (final repas in journal.repas
                .where((r) => !typesRepas.contains(r.type)))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CarteRepas(
                  repas: repas,
                  estFavori: journal.estFavori(repas),
                  onModifier: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ModifierRepasEcran(repas: repas),
                    ),
                  ),
                  onSupprimer: () => journal.supprimer(repas.id!),
                  onBasculerFavori: () =>
                      _basculerFavori(context, journal, repas),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CarteResume extends StatelessWidget {
  final ValeursNutritionnelles total;
  final Reglages reglages;

  /// Compteurs pas/étages du jour (null : pas de source santé disponible).
  final CompteursJour? sante;

  /// Calories dépensées en sport le jour affiché (0 : aucune séance).
  /// Créditées au budget calorique : objectif du jour augmenté d'autant.
  final double depense;

  const _CarteResume(
      {required this.total,
      required this.reglages,
      this.sante,
      this.depense = 0});

  @override
  Widget build(BuildContext context) {
    // Budget du jour : objectif + dépense sportive (v0.7.2). Le sport
    // du jour augmente le plafond, le dépassement se juge contre lui.
    final budget = reglages.objectifKcal + depense;
    final ratio = budget > 0
        ? (total.kcal / budget).clamp(0.0, 1.0)
        : 0.0;
    final reste = budget - total.kcal;

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
                      depense > 0
                          ? 'sur ${budget.round()} kcal (objectif + sport)'
                          : 'sur ${reglages.objectifKcal.round()} kcal d\'objectif',
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
            // Compteurs pas/étages du jour, lus depuis Health Connect
            // (ex. montre Garmin) : ligne discrète, seulement si l'un
            // des deux est non nul.
            if (sante != null && (sante!.pas > 0 || sante!.etages > 0)) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.directions_walk,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${formatEntier(sante!.pas)} pas',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.stairs, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${formatEntier(sante!.etages)} étages',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            // Dépense sportive du jour affiché (v0.7.2), créditée au
            // budget ci-dessus : ligne discrète avec flamme, seulement
            // s'il y a eu du sport ce jour-là.
            if (depense > 0) ...[
              Row(
                children: [
                  Icon(Icons.local_fire_department_outlined,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'dépense sportive : ${depense.round()} kcal',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
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
  final bool estFavori;
  final VoidCallback onModifier;
  final VoidCallback onSupprimer;
  final VoidCallback onBasculerFavori;

  const _CarteRepas({
    required this.repas,
    required this.estFavori,
    required this.onModifier,
    required this.onSupprimer,
    required this.onBasculerFavori,
  });

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
          leading: _vignette(repas),
          title: Text('${repas.type} · $heure'),
          subtitle: Text(
            resume.isEmpty ? 'Repas vide' : resume,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${repas.total.kcal.round()} kcal',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                tooltip: 'Modifier le repas',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onModifier,
              ),
              IconButton(
                tooltip: estFavori
                    ? 'Retirer des favoris'
                    : 'Ajouter aux favoris',
                icon: Icon(
                  estFavori ? Icons.star : Icons.star_border,
                  color: estFavori ? Colors.amber.shade700 : Colors.grey,
                ),
                onPressed: onBasculerFavori,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vignette du repas : photo si lisible, sinon avatar avec la première
  /// lettre du type (pas de carré gris quand le fichier image est absent).
  static Widget _vignette(Repas repas) {
    final avatar = CircleAvatar(
      backgroundColor: Colors.green.shade50,
      child: Text(
        repas.type.substring(0, 1),
        style: TextStyle(color: Colors.green.shade800),
      ),
    );
    final photo = repas.photo;
    if (photo == null) return avatar;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(photo),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => avatar,
      ),
    );
  }
}

/// Bascule le favori d'un repas : retire si déjà favori, sinon demande un
/// nom et enregistre le snapshot des lignes.
Future<void> _basculerFavori(
    BuildContext context, Journal journal, Repas repas) async {
  if (journal.estFavori(repas)) {
    await journal.retirerFavori(repas);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retiré des favoris.')),
      );
    }
    return;
  }
  final controleur = TextEditingController(text: repas.type);
  final nom = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ajouter aux favoris'),
      content: TextField(
        controller: controleur,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nom du favori'),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controleur.text.trim()),
          child: const Text('Ajouter'),
        ),
      ],
    ),
  );
  controleur.dispose();
  if (nom != null && nom.isNotEmpty) {
    await journal.ajouterFavori(repas, nom);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« $nom » ajouté aux favoris.')),
      );
    }
  }
}
