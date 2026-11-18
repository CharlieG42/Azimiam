import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/progression.dart';
import '../services/service_base.dart';
import '../services/service_imc.dart';
import '../state/progression.dart';
import 'reglages_ecran.dart';

/// Écran Progression : IMC, suivi du poids (courbe + historique) et
/// analyse des apports journaliers (moyennes 7/30 jours, graphique 14 jours).
class ProgressionEcran extends StatelessWidget {
  const ProgressionEcran({super.key});

  @override
  Widget build(BuildContext context) {
    final progression = context.watch<Progression>();

    return Scaffold(
      appBar: AppBar(title: const Text('Progression & IMC')),
      body: progression.enChargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: progression.charger,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _CarteImc(progression: progression),
                  const SizedBox(height: 8),
                  _CartePoids(progression: progression),
                  const SizedBox(height: 8),
                  _CarteApports(progression: progression),
                  if (progression.erreur != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        progression.erreur!,
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.monitor_weight_outlined),
        label: const Text('Pesée du jour'),
        onPressed: () => _saisirPesee(context, progression),
      ),
    );
  }

  Future<void> _saisirPesee(
      BuildContext context, Progression progression) async {
    final controleur = TextEditingController(
      text: progression.dernier?.kg.toStringAsFixed(1) ?? '',
    );
    final kg = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pesée du jour'),
        content: TextField(
          controller: controleur,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Poids (kg)',
            suffixText: 'kg',
          ),
          onSubmitted: (v) => Navigator.pop(
              context, double.tryParse(v.replaceAll(',', '.'))),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controleur.text.replaceAll(',', '.')),
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controleur.dispose();
    if (kg != null && kg > 0) {
      await progression.ajouterPesee(kg, DateTime.now());
    }
  }
}

Color _couleurTranche(int indice) {
  if (indice <= 1) return Colors.blue.shade600;
  if (indice == 2) return Colors.green.shade700;
  if (indice == 3) return Colors.orange.shade800;
  return Colors.red.shade700;
}

/// Carte IMC : valeur, catégorie OMS, poids idéal et objectif de poids.
class _CarteImc extends StatelessWidget {
  final Progression progression;

  const _CarteImc({required this.progression});

  @override
  Widget build(BuildContext context) {
    final profil = progression.reglages.profil;
    final pesee = progression.dernier;
    final poids = pesee?.kg;
    final taille = profil.tailleCm;
    final valeurImc =
        (poids != null && taille != null && taille > 0) ? ServiceImc.imc(poids, taille) : null;
    final tranche =
        valeurImc != null ? ServiceImc.categorie(valeurImc) : null;
    final indice = tranche != null ? ServiceImc.tranches.indexOf(tranche) : -1;

    final avecObjectif = profil.objectif != 'maintien' &&
        profil.poidsCibleKg != null &&
        poids != null;
    double? fraction;
    int semaines = 0;
    ObjectifsAuto? auto;
    if (avecObjectif && progression.pesees.isNotEmpty) {
      final cible = profil.poidsCibleKg!;
      final depart = progression.pesees.last.kg; // la plus ancienne
      if ((depart - cible).abs() > 0.01) {
        fraction =
            ((depart - poids) / (depart - cible)).clamp(0.0, 1.0).toDouble();
      }
      if (profil.complet) {
        semaines = ServiceImc.semainesEstimees(profil, poids);
        auto = ServiceImc.objectifsAuto(profil, poids);
      }
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Indice de masse corporelle',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (valeurImc != null && tranche != null) ...[
              Row(
                children: [
                  Text(
                    valeurImc.toStringAsFixed(1),
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Chip(
                    label: Text(tranche.libelle),
                    backgroundColor: _couleurTranche(indice).withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: _couleurTranche(indice),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Poids ${poids!.toStringAsFixed(1)} kg'
                '${taille != null ? ' · taille ${taille.toStringAsFixed(0)} cm' : ''}'
                '${pesee != null ? ' · pesée du ${DateFormat('d MMM', 'fr_FR').format(pesee.jour)}' : ''}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              if (taille != null && taille > 0)
                Text(
                  'Poids idéal (formule de Devine) : '
                  '${ServiceImc.poidsIdeal(taille, profil.sexe).toStringAsFixed(1)} kg',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
            ] else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Renseignez votre taille dans les réglages et faites une '
                    'pesée pour calculer votre IMC.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Compléter mon profil'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReglagesEcran()),
                    ),
                  ),
                ],
              ),
            if (avecObjectif) ...[
              const Divider(height: 24),
              Builder(
                builder: (context) {
                  final cible = profil.poidsCibleKg!;
                  final restant = (cible - poids).abs();
                  final sens = profil.objectif == 'perte' ? 'à perdre' : 'à prendre';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Objectif : ${cible.toStringAsFixed(1)} kg — '
                        'encore ${restant.toStringAsFixed(1)} kg $sens',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (fraction != null) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(fraction * 100).round()} % du chemin parcouru'
                          '${semaines > 0 ? ' · ≈ $semaines sem.' : ''}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                      if (auto != null)
                        Text(
                          'Objectif calculé : ${auto.kcal.round()} kcal/j '
                          '(P ${auto.proteines.round()} g · G ${auto.glucides.round()} g · '
                          'L ${auto.lipides.round()} g)',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Carte poids : courbe d'évolution + historique des pesées supprimables.
class _CartePoids extends StatelessWidget {
  final Progression progression;

  const _CartePoids({required this.progression});

  @override
  Widget build(BuildContext context) {
    // psees : de la plus récente à la plus ancienne -> on inverse pour le graphe
    final chrono = progression.pesees.reversed.toList();
    final deltas = <int, double>{};
    final progres = <int, bool>{};
    final cible = progression.reglages.profil.poidsCibleKg;
    for (var i = 1; i < chrono.length; i++) {
      final id = chrono[i].id;
      if (id == null) continue;
      deltas[id] = chrono[i].kg - chrono[i - 1].kg;
      if (cible != null) {
        final avant = (chrono[i - 1].kg - cible).abs();
        final apres = (chrono[i].kg - cible).abs();
        progres[id] = apres < avant;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Poids', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (chrono.isEmpty)
              Text(
                'Aucune pesée. Touchez « Pesée du jour » pour commencer le suivi.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else ...[
              SizedBox(
                height: 150,
                child: CustomPaint(
                  painter: _CourbePainter(chrono),
                  child: Container(),
                ),
              ),
              const Divider(height: 16),
              for (final pesee in progression.pesees)
                Dismissible(
                  key: ValueKey('pesee-${pesee.id}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => progression.supprimerPesee(pesee.id!),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.monitor_weight_outlined),
                    title: Text('${pesee.kg.toStringAsFixed(1)} kg'),
                    subtitle: Text(
                      DateFormat('EEEE d MMMM', 'fr_FR').format(pesee.jour),
                    ),
                    trailing: pesee.id != null && deltas.containsKey(pesee.id)
                        ? Text(
                            '${deltas[pesee.id]! >= 0 ? '+' : ''}'
                            '${deltas[pesee.id]!.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              color: cible == null
                                  ? Colors.grey.shade600
                                  : progres[pesee.id] == true
                                      ? Colors.green.shade700
                                      : Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Carte apports : moyennes 7/30 jours + graphique des 14 derniers jours.
class _CarteApports extends StatelessWidget {
  final Progression progression;

  const _CarteApports({required this.progression});

  static double _moyenne(List<TotalJour> totaux, int jours) {
    final maintenant = DateTime.now();
    final aujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final limite = aujourdhui.subtract(Duration(days: jours - 1));
    final filtres = totaux.where((t) => !t.jour.isBefore(limite)).toList();
    if (filtres.isEmpty) return 0;
    return filtres.map((t) => t.valeurs.kcal).reduce((a, b) => a + b) /
        filtres.length;
  }

  @override
  Widget build(BuildContext context) {
    final objectif = progression.reglages.objectifKcal;
    final moy7 = _moyenne(progression.totaux, 7);
    final moy30 = _moyenne(progression.totaux, 30);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apports journaliers',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Moyenne 7 j\n${moy7.round()} kcal',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Moyenne 30 j\n${moy30.round()} kcal',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Objectif\n${objectif.round()} kcal',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: _GraphiqueBarres(
                totaux: progression.totaux,
                objectif: objectif,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Calories des 14 derniers jours (barres) vs objectif (ligne rouge).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Courbe du poids dans le temps (ordre chronologique croissant).
class _CourbePainter extends CustomPainter {
  final List<Pesee> pesees;

  _CourbePainter(this.pesees);

  @override
  void paint(Canvas canvas, Size size) {
    if (pesees.isEmpty) return;
    final poids = pesees.map((p) => p.kg).toList();
    var min = poids.reduce((a, b) => a < b ? a : b);
    var max = poids.reduce((a, b) => a > b ? a : b);
    if (max - min < 1) {
      min -= 0.5;
      max += 0.5;
    }
    const marge = 10.0;
    double x(int i) => pesees.length == 1
        ? size.width / 2
        : marge + (size.width - 2 * marge) * i / (pesees.length - 1);
    double y(double kg) => size.height - marge -
        (size.height - 2 * marge) * (kg - min) / (max - min);

    if (pesees.length >= 2) {
      final chemin = Path()..moveTo(x(0), y(poids[0]));
      for (var i = 1; i < pesees.length; i++) {
        chemin.lineTo(x(i), y(poids[i]));
      }
      canvas.drawPath(
        chemin,
        Paint()
          ..color = Colors.green.shade700
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
    final point = Paint()..color = Colors.green.shade900;
    for (var i = 0; i < pesees.length; i++) {
      canvas.drawCircle(Offset(x(i), y(poids[i])), 3.5, point);
    }

    final style = TextStyle(fontSize: 10, color: Colors.grey.shade600);
    final haut = TextPainter(
      text: TextSpan(text: '${max.toStringAsFixed(1)} kg', style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    haut.paint(canvas, Offset(marge, 0));
    final bas = TextPainter(
      text: TextSpan(text: '${min.toStringAsFixed(1)} kg', style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    bas.paint(canvas, Offset(marge, size.height - bas.height));
  }

  @override
  bool shouldRepaint(covariant _CourbePainter old) => old.pesees != pesees;
}

/// Barres des calories journalières + ligne d'objectif.
class _GraphiqueBarres extends StatelessWidget {
  final List<TotalJour> totaux;
  final double objectif;

  const _GraphiqueBarres({required this.totaux, required this.objectif});

  @override
  Widget build(BuildContext context) {
    final maintenant = DateTime.now();
    final aujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final parJour = {
      for (final t in totaux) ServiceBase.cleJour(t.jour): t.valeurs.kcal
    };
    final valeurs = List.generate(
      14,
      (i) =>
          parJour[ServiceBase.cleJour(aujourdhui.subtract(Duration(days: 13 - i)))] ?? 0,
    );
    return CustomPaint(
      painter: _BarresPainter(valeurs, objectif),
      child: Container(),
    );
  }
}

class _BarresPainter extends CustomPainter {
  final List<double> valeurs;
  final double objectif;

  _BarresPainter(this.valeurs, this.objectif);

  @override
  void paint(Canvas canvas, Size size) {
    var max = valeurs.fold(0.0, (a, b) => a > b ? a : b);
    if (objectif > max) max = objectif;
    if (max <= 0) max = 1;
    max *= 1.1;

    final n = valeurs.length;
    final largeur = size.width / n;
    final barre = Paint()..color = Colors.green.shade400;
    for (var i = 0; i < n; i++) {
      final hauteur = size.height * valeurs[i] / max;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            largeur * i + (largeur - largeur * 0.7) / 2,
            size.height - hauteur,
            largeur * 0.7,
            hauteur,
          ),
          const Radius.circular(3),
        ),
        barre,
      );
    }

    final yObjectif = size.height - size.height * objectif / max;
    canvas.drawLine(
      Offset(0, yObjectif),
      Offset(size.width, yObjectif),
      Paint()
        ..color = Colors.red.shade400
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _BarresPainter old) =>
      old.valeurs != valeurs || old.objectif != objectif;
}
