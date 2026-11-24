import 'package:flutter/material.dart';

import '../models/valeurs.dart';

/// Résultat de la création d'un aliment ([DialogNouvelAliment] renvoie
/// une instance au pop en cas de succès).
class AlimentCree {
  final String nom;
  final List<String> alias;
  final ValeursNutritionnelles valeurs;


  const AlimentCree({
    required this.nom,
    required this.alias,
    required this.valeurs,
  });
}

/// Boîte de dialogue de création d'un aliment (catalogue ou ligne hors
/// base) : nom (pré-remplissable via [nomInitial]), alias optionnels,
/// valeurs pour 100 g.
///
/// [onValide] enregistre l'aliment et renvoie un message d'erreur
/// lisible, ou null si tout s'est bien passé : le dialogue se ferme
/// alors en renvoyant la fiche créée (pop), et reste ouvert sinon.
class DialogNouvelAliment extends StatefulWidget {
  final String? nomInitial;
  final Future<String?> Function(
    String nom,
    List<String> alias,
    ValeursNutritionnelles valeurs,
  ) onValide;

  const DialogNouvelAliment({
    super.key,
    this.nomInitial,
    required this.onValide,
  });

  @override
  State<DialogNouvelAliment> createState() => _DialogNouvelAlimentState();
}

class _DialogNouvelAlimentState extends State<DialogNouvelAliment> {
  late final TextEditingController _nomCtl;
  final _aliasCtl = TextEditingController();
  final _kcalCtl = TextEditingController();
  final _protCtl = TextEditingController();
  final _glucCtl = TextEditingController();
  final _lipCtl = TextEditingController();
  bool _enregistre = false;

  @override
  void initState() {
    super.initState();
    _nomCtl = TextEditingController(text: widget.nomInitial ?? '');
  }

  @override
  void dispose() {
    _nomCtl.dispose();
    _aliasCtl.dispose();
    _kcalCtl.dispose();
    _protCtl.dispose();
    _glucCtl.dispose();
    _lipCtl.dispose();
    super.dispose();
  }

  double? _lire(TextEditingController ctl) =>
      double.tryParse(ctl.text.replaceAll(',', '.'));

  Future<void> _valider() async {
    final nom = _nomCtl.text.trim();
    final kcal = _lire(_kcalCtl);
    if (nom.isEmpty || kcal == null || kcal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom et calories / 100 g sont requis.')),
      );
      return;
    }
    setState(() => _enregistre = true);
    final alias = _aliasCtl.text
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
    final valeurs = ValeursNutritionnelles(
      kcal: kcal,
      proteines: _lire(_protCtl) ?? 0,
      glucides: _lire(_glucCtl) ?? 0,
      lipides: _lire(_lipCtl) ?? 0,
    );
    final erreur = await widget.onValide(nom, alias, valeurs);
    if (!mounted) return;
    setState(() => _enregistre = false);
    if (erreur != null) {
      // Le dialogue reste ouvert : l'utilisateur corrige.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erreur)));
      return;
    }
    Navigator.pop(
        context, AlimentCree(nom: nom, alias: alias, valeurs: valeurs));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('dialogNouvelAliment'),
      title: const Text('Ajouter un aliment au catalogue'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('champNomAliment'),
              controller: _nomCtl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration:
                  const InputDecoration(labelText: 'Nom de l\'aliment *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aliasCtl,
              decoration: const InputDecoration(
                labelText: 'Alias de recherche (optionnel)',
                hintText:
                    'Séparés par des virgules (ex. : patate, pomme de terre)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _kcalCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Calories / 100 g *', suffixText: 'kcal'),
            ),
            TextField(
              controller: _protCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Protéines / 100 g', suffixText: 'g'),
            ),
            TextField(
              controller: _glucCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Glucides / 100 g', suffixText: 'g'),
            ),
            TextField(
              controller: _lipCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Lipides / 100 g', suffixText: 'g'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('boutonEnregistrerAliment'),
          onPressed: _enregistre ? null : _valider,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
