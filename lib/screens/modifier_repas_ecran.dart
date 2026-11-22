import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/repas.dart';
import '../models/valeurs.dart';
import '../state/journal.dart';
import '../widgets/carte_ligne.dart';
import '../widgets/dialog_ligne.dart';

/// Modification d'un repas déjà enregistré : type, lignes d'aliments
/// (quantité, valeurs, suppression). La date/heure et la photo ne changent
/// pas ; l'écran enregistre en base et l'accueil se rafraîchit tout seul.
class ModifierRepasEcran extends StatefulWidget {
  final Repas repas;

  const ModifierRepasEcran({super.key, required this.repas});

  @override
  State<ModifierRepasEcran> createState() => _ModifierRepasEcranState();
}

class _ModifierRepasEcranState extends State<ModifierRepasEcran> {
  late String _type;
  late final List<LigneRepas> _lignes;

  @override
  void initState() {
    super.initState();
    _type = widget.repas.type;
    // Copies profondes : on ne modifie la base qu'au moment d'enregistrer.
    _lignes = widget.repas.lignes
        .map((l) => LigneRepas(
              nom: l.nom,
              grammes: l.grammes,
              pour100: l.pour100,
              source: l.source,
              reconnu: l.reconnu,
            ))
        .toList();
  }

  Future<void> _editerLigne(int index) async {
    final modifiee = await editerLigneDialog(context, _lignes[index]);
    if (modifiee && mounted) setState(() {});
  }

  Future<void> _enregistrer() async {
    final journal = context.read<Journal>();
    await journal.modifier(Repas(
      id: widget.repas.id,
      prisLe: widget.repas.prisLe,
      type: _type,
      photo: widget.repas.photo,
      lignes: _lignes,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final total = _lignes.fold(
      ValeursNutritionnelles.vide,
      (acc, ligne) => acc.ajouter(ligne.valeurs),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le repas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ----- Type de repas -----
            Wrap(
              spacing: 8,
              children: [
                for (final type in typesRepas)
                  ChoiceChip(
                    label: Text(type),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ----- Lignes d'aliments -----
            if (_lignes.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Ce repas est vide : il ne comptera plus dans les totaux.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              for (var i = 0; i < _lignes.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CarteLigne(
                    ligne: _lignes[i],
                    onGrammesModifies: (g) =>
                        setState(() => _lignes[i].grammes = g),
                    onEditer: () => _editerLigne(i),
                    onSupprimer: () =>
                        setState(() => _lignes.removeAt(i)),
                  ),
                ),
            const SizedBox(height: 8),

            // ----- Total -----
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '${total.kcal.round()} kcal',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Protéines ${total.proteines.round()} g · '
                      'Glucides ${total.glucides.round()} g · '
                      'Lipides ${total.lipides.round()} g',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Enregistrer les modifications'),
              onPressed: _enregistrer,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
