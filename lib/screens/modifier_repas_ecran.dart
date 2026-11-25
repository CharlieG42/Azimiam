import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/repas.dart';
import '../models/valeurs.dart';
import '../state/journal.dart';
import '../widgets/carte_ligne.dart';
import '../widgets/dialog_ligne.dart';

/// Modification d'un repas déjà enregistré : type, date et heure, lignes
/// d'aliments (quantité, valeurs, suppression). La photo ne change pas ;
/// l'écran enregistre en base et l'accueil se rafraîchit tout seul.
class ModifierRepasEcran extends StatefulWidget {
  final Repas repas;

  const ModifierRepasEcran({super.key, required this.repas});

  @override
  State<ModifierRepasEcran> createState() => _ModifierRepasEcranState();
}

class _ModifierRepasEcranState extends State<ModifierRepasEcran> {
  late String _type;
  late DateTime _prisLe;
  late final List<LigneRepas> _lignes;

  @override
  void initState() {
    super.initState();
    _type = widget.repas.type;
    _prisLe = widget.repas.prisLe;
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

  /// Libellé de la date du repas, ex. « Mardi 24 novembre 2026 ».
  String _libelleDate() {
    final brut = DateFormat('EEEE d MMMM y', 'fr_FR').format(_prisLe);
    return brut[0].toUpperCase() + brut.substring(1);
  }

  Future<void> _changerDate() async {
    final aujourdHui = dateSeule(DateTime.now());
    // Le repas peut être attribué à demain (repas saisi un peu en avance),
    // pas au-delà ; et jamais avant l'an 2000.
    final derniere =
        _prisLe.isAfter(aujourdHui) ? _prisLe : aujourdHui.add(const Duration(days: 1));
    final choisi = await showDatePicker(
      context: context,
      initialDate: _prisLe,
      firstDate: DateTime(2000),
      lastDate: derniere,
      helpText: 'Nouvelle date du repas',
    );
    if (choisi == null || !mounted) return;
    setState(() => _prisLe = DateTime(
          choisi.year,
          choisi.month,
          choisi.day,
          _prisLe.hour,
          _prisLe.minute,
        ));
  }

  Future<void> _changerHeure() async {
    final choisi = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_prisLe),
      helpText: 'Nouvelle heure du repas',
    );
    if (choisi == null || !mounted) return;
    setState(() => _prisLe = DateTime(
          _prisLe.year,
          _prisLe.month,
          _prisLe.day,
          choisi.hour,
          choisi.minute,
        ));
  }

  Future<void> _enregistrer() async {
    final journal = context.read<Journal>();
    await journal.modifier(Repas(
      id: widget.repas.id,
      prisLe: _prisLe,
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

            // ----- Date et heure -----
            // Un repas saisi sur la mauvaise journée doit pouvoir être
            // relogé (ex. : le dîner d'hier daté aujourd'hui par erreur).
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  key: const Key('boutonDateRepas'),
                  avatar: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(_libelleDate()),
                  onPressed: _changerDate,
                ),
                ActionChip(
                  key: const Key('boutonHeureRepas'),
                  avatar: const Icon(Icons.schedule_outlined, size: 18),
                  label: Text(DateFormat('HH:mm').format(_prisLe)),
                  onPressed: _changerHeure,
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
