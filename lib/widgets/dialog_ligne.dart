import 'package:flutter/material.dart';

import '../models/repas.dart';
import '../models/valeurs.dart';

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
