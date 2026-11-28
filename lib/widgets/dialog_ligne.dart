import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/repas.dart';
import '../models/valeurs.dart';
import '../state/catalogue.dart';

String _fmt(double d) =>
    d == d.roundToDouble() ? d.round().toString() : d.toStringAsFixed(1);

/// Ouvre la boîte de dialogue d'édition complète d'une ligne d'aliment
/// (nom, quantité, valeurs pour 100 g). Modifie [ligne] en place si
/// l'utilisateur valide, et renvoie vrai dans ce cas.
///
/// Partagée entre l'écran d'ajout et l'écran de modification d'un repas :
/// une seule implémentation pour garantir le même comportement.
///
/// v0.8.2 : une ligne saisie librement (hors base) dont on renseigne les
/// calories entre automatiquement au catalogue comme aliment personnel —
/// les prochaines recherches et analyses IA la reconnaîtront.
Future<bool> editerLigneDialog(BuildContext context, LigneRepas ligne) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => _DialogEditionLigne(ligne: ligne),
      ) ??
      false;
}

/// Fiche d'édition : [StatefulWidget] car les contrôleurs de champs
/// appartiennent à la fiche, qui survit à sa fermeture le temps de
/// l'animation de sortie (les relâcher depuis la fonction appelante
/// cassait les reconstructions en cours de route).
class _DialogEditionLigne extends StatefulWidget {
  final LigneRepas ligne;

  const _DialogEditionLigne({required this.ligne});

  @override
  State<_DialogEditionLigne> createState() => _DialogEditionLigneState();
}

class _DialogEditionLigneState extends State<_DialogEditionLigne> {
  late final TextEditingController _nomCtl;
  late final TextEditingController _grammesCtl;
  late final TextEditingController _kcalCtl;
  late final TextEditingController _protCtl;
  late final TextEditingController _glucCtl;
  late final TextEditingController _lipCtl;

  /// Catalogue capturé à l'ouverture, en lecture nullable : un hôte sans
  /// provider Catalogue ignore simplement l'ajout automatique (v0.8.2).
  late final Catalogue? _catalogue;

  /// Messager capturé à l'ouverture : la confirmation d'ajout au
  /// catalogue s'affiche après la fermeture de la fiche.
  late final ScaffoldMessengerState _messenger;

  /// État « hors base » avant édition : seule une ligne saisie librement
  /// entre au catalogue à la validation (v0.8.2).
  late final bool _reconnuAvant;

  /// Captures faites une seule fois dans [didChangeDependencies] :
  /// `ScaffoldMessenger.of` enregistre une dépendance, interdite
  /// dans initState.
  bool _capturesFaites = false;

  @override
  void initState() {
    super.initState();
    final ligne = widget.ligne;
    _nomCtl = TextEditingController(text: ligne.nom);
    _grammesCtl = TextEditingController(text: _fmt(ligne.grammes));
    _kcalCtl = TextEditingController(text: _fmt(ligne.pour100.kcal));
    _protCtl = TextEditingController(text: _fmt(ligne.pour100.proteines));
    _glucCtl = TextEditingController(text: _fmt(ligne.pour100.glucides));
    _lipCtl = TextEditingController(text: _fmt(ligne.pour100.lipides));
    _reconnuAvant = ligne.reconnu;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_capturesFaites) return;
    _capturesFaites = true;
    _catalogue = context.read<Catalogue?>();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _nomCtl.dispose();
    _grammesCtl.dispose();
    _kcalCtl.dispose();
    _protCtl.dispose();
    _glucCtl.dispose();
    _lipCtl.dispose();
    super.dispose();
  }

  /// Applique les valeurs saisies à la ligne, referme la fiche, puis
  /// entre la ligne hors base au catalogue (v0.8.2).
  Future<void> _valider() async {
    final ligne = widget.ligne;
    ligne.nom =
        _nomCtl.text.trim().isEmpty ? ligne.nom : _nomCtl.text.trim();
    ligne.grammes =
        double.tryParse(_grammesCtl.text.replaceAll(',', '.')) ??
            ligne.grammes;
    ligne.pour100 = ValeursNutritionnelles(
      kcal: double.tryParse(_kcalCtl.text.replaceAll(',', '.')) ??
          ligne.pour100.kcal,
      proteines: double.tryParse(_protCtl.text.replaceAll(',', '.')) ??
          ligne.pour100.proteines,
      glucides: double.tryParse(_glucCtl.text.replaceAll(',', '.')) ??
          ligne.pour100.glucides,
      lipides: double.tryParse(_lipCtl.text.replaceAll(',', '.')) ??
          ligne.pour100.lipides,
    );
    ligne.reconnu = true;
    final aCataloguer =
        !_reconnuAvant && ligne.pour100.kcal > 0 && _catalogue != null;
    Navigator.of(context).pop(true);

    // v0.8.2 : la ligne hors base qui vient d'être renseignée entre au
    // catalogue comme aliment personnel. Un doublon (déjà présent) ne
    // fait rien : l'important est que l'aliment y soit, pas de quand.
    if (aCataloguer) {
      try {
        final erreur = await _catalogue.ajouter(
            nom: ligne.nom, alias: const [], valeurs: ligne.pour100);
        if (erreur == null) {
          _messenger.showSnackBar(SnackBar(
              content: Text('« ${ligne.nom} » ajouté au catalogue')));
        }
      } catch (_) {
        // Base indisponible : la ligne garde ses valeurs saisies,
        // l'édition n'échoue jamais pour l'ajout au catalogue.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ligne = widget.ligne;
    return AlertDialog(
      title: const Text('Modifier la ligne'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nomCtl,
              decoration: const InputDecoration(labelText: 'Aliment'),
            ),
            TextField(
              controller: _grammesCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantité (g)'),
            ),
            TextField(
              controller: _kcalCtl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Calories / 100 g'),
            ),
            TextField(
              controller: _protCtl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Protéines / 100 g'),
            ),
            TextField(
              controller: _glucCtl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Glucides / 100 g'),
            ),
            TextField(
              controller: _lipCtl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Lipides / 100 g'),
            ),
            if (!ligne.reconnu) ...[
              const SizedBox(height: 12),
              const Text(
                'Aliment hors base : en validant avec des calories, il '
                'sera ajouté automatiquement à votre catalogue (et reconnu '
                'par les prochaines analyses IA).',
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
          onPressed: _valider,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
