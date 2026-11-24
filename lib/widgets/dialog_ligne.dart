import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/repas.dart';
import '../models/valeurs.dart';
import '../state/catalogue.dart';
import 'dialog_nouvel_aliment.dart';

String _fmt(double d) =>
    d == d.roundToDouble() ? d.round().toString() : d.toStringAsFixed(1);

/// Ouvre la boîte de dialogue d'édition complète d'une ligne d'aliment
/// (nom, quantité, valeurs pour 100 g). Modifie [ligne] en place si
/// l'utilisateur valide, et renvoie vrai dans ce cas.
///
/// Partagée entre l'écran d'ajout et l'écran de modification d'un repas :
/// une seule implémentation pour garantir le même comportement.
Future<bool> editerLigneDialog(BuildContext context, LigneRepas ligne) async {
  final nomCtl = TextEditingController(text: ligne.nom);
  final grammesCtl = TextEditingController(text: _fmt(ligne.grammes));
  final kcalCtl = TextEditingController(text: _fmt(ligne.pour100.kcal));
  final protCtl = TextEditingController(text: _fmt(ligne.pour100.proteines));
  final glucCtl = TextEditingController(text: _fmt(ligne.pour100.glucides));
  final lipCtl = TextEditingController(text: _fmt(ligne.pour100.lipides));

  final valide = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Modifier la ligne'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomCtl,
              decoration: const InputDecoration(labelText: 'Aliment'),
            ),
            TextField(
              controller: grammesCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantité (g)'),
            ),
            TextField(
              controller: kcalCtl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Calories / 100 g'),
            ),
            TextField(
              controller: protCtl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Protéines / 100 g'),
            ),
            TextField(
              controller: glucCtl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Glucides / 100 g'),
            ),
            TextField(
              controller: lipCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Lipides / 100 g'),
            ),
            if (!ligne.reconnu) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('boutonCreerCatalogue'),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Créer cet aliment dans le catalogue'),
                onPressed: () async {
                  // Fiche de création pré-remplie avec le nom de la ligne :
                  // une fois créé, l'aliment alimentera aussi le
                  // rapprochement IA des prochaines analyses.
                  final cree = await showDialog<AlimentCree>(
                    context: context,
                    builder: (context) => DialogNouvelAliment(
                      nomInitial: nomCtl.text.trim().isNotEmpty
                          ? nomCtl.text.trim()
                          : ligne.nom,
                      onValide: (nom, alias, valeurs) => context
                          .read<Catalogue>()
                          .ajouter(nom: nom, alias: alias, valeurs: valeurs),
                    ),
                  );
                  if (cree != null) {
                    // Reprise des valeurs dans la fiche de la ligne :
                    // l'utilisateur garde la main (Valider pour appliquer).
                    nomCtl.text = cree.nom;
                    kcalCtl.text = _fmt(cree.valeurs.kcal);
                    protCtl.text = _fmt(cree.valeurs.proteines);
                    glucCtl.text = _fmt(cree.valeurs.glucides);
                    lipCtl.text = _fmt(cree.valeurs.lipides);
                  }
                },
              ),
              const SizedBox(height: 4),
              const Text(
                'Aliment hors base : créez-le une fois, toutes les '
                'prochaines analyses le reconnaîtront.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Valider'),
        ),
      ],
    ),
  );

  if (valide == true) {
    ligne.nom = nomCtl.text.trim().isEmpty ? ligne.nom : nomCtl.text.trim();
    ligne.grammes = double.tryParse(grammesCtl.text.replaceAll(',', '.')) ??
        ligne.grammes;
    ligne.pour100 = ValeursNutritionnelles(
      kcal: double.tryParse(kcalCtl.text.replaceAll(',', '.')) ??
          ligne.pour100.kcal,
      proteines: double.tryParse(protCtl.text.replaceAll(',', '.')) ??
          ligne.pour100.proteines,
      glucides: double.tryParse(glucCtl.text.replaceAll(',', '.')) ??
          ligne.pour100.glucides,
      lipides: double.tryParse(lipCtl.text.replaceAll(',', '.')) ??
          ligne.pour100.lipides,
    );
    ligne.reconnu = true;
  }
  nomCtl.dispose();
  grammesCtl.dispose();
  kcalCtl.dispose();
  protCtl.dispose();
  glucCtl.dispose();
  lipCtl.dispose();
  return valide == true;
}
