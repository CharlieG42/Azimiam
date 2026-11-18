import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/mini_base.dart';
import '../models/repas.dart';
import '../models/valeurs.dart';
import '../services/service_ia.dart';
import '../services/service_nutrition.dart';
import '../services/service_reglages.dart';
import '../state/journal.dart';

/// Écran d'ajout d'un repas : photo → analyse IA → correction → enregistrement.
///
/// Le principe d'Azimiam : l'IA propose, l'utilisateur corrige en 3 secondes.
/// Aucune valeur nutritionnelle ne vient jamais de l'IA : uniquement de la
/// base locale ou de la saisie manuelle.
class AjoutRepasEcran extends StatefulWidget {
  const AjoutRepasEcran({super.key});

  @override
  State<AjoutRepasEcran> createState() => _AjoutRepasEcranState();
}

class _AjoutRepasEcranState extends State<AjoutRepasEcran> {
  String _type = 'Déjeuner';
  final List<LigneRepas> _lignes = [];
  final ImagePicker _picker = ImagePicker();

  XFile? _photo;
  bool _enAnalyse = false;
  String? _erreur;
  Reglages _reglages = const Reglages();

  @override
  void initState() {
    super.initState();
    _chargerReglages();
  }

  Future<void> _chargerReglages() async {
    final reglages = await ServiceReglages.charger();
    if (mounted) {
      setState(() => _reglages = reglages);
    }
  }

  // ---------------------------------------------------------------- Photo

  Future<void> _prendrePhoto(ImageSource source) async {
    try {
      final photo = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 85,
      );
      if (photo == null) return;
      setState(() {
        _photo = photo;
        _erreur = null;
      });
      if (_reglages.iaDisponible) {
        await _analyser();
      } else {
        setState(() {
          _erreur =
              'Aucune clé API configurée : ajout manuel uniquement (voir Réglages).';
        });
      }
    } catch (e) {
      setState(() => _erreur = 'Photo impossible : $e');
    }
  }

  // ---------------------------------------------------------------- IA

  Future<void> _analyser() async {
    if (_photo == null) return;
    setState(() {
      _enAnalyse = true;
      _erreur = null;
    });
    try {
      final octets = await File(_photo!.path).readAsBytes();
      final service = ServiceIa(
        cleApi: _reglages.cleApi,
        baseUrl: _reglages.baseUrl,
        modele: _reglages.modele,
      );
      final analyses = await service.analyserPhoto(octets);

      if (analyses.isEmpty) {
        setState(() {
          _erreur =
              'L\'IA n\'a rien reconnu sur cette photo. Ajoutez les aliments à la main.';
        });
      } else {
        for (final analyse in analyses) {
          final trouve = ServiceNutrition.retrouve(analyse.nom);
          _lignes.add(
            LigneRepas(
              nom: trouve?.nom ?? analyse.nom,
              grammes: analyse.grammes,
              pour100: trouve?.valeurs ?? ValeursNutritionnelles.vide,
              source: 'ia',
              reconnu: trouve != null,
            ),
          );
        }
      }
    } on AiException catch (e) {
      setState(() => _erreur = 'Analyse IA échouée : ${e.message}');
    } catch (e) {
      setState(() => _erreur = 'Analyse IA échouée : $e');
    }
    if (mounted) {
      setState(() => _enAnalyse = false);
    }
  }

  // ------------------------------------------------------------ Lignes

  void _supprimerLigne(int index) {
    setState(() => _lignes.removeAt(index));
  }

  Future<void> _editerLigne(int index) async {
    final ligne = _lignes[index];
    String fmt(double d) =>
        d == d.roundToDouble() ? d.round().toString() : d.toStringAsFixed(1);

    final nomCtl = TextEditingController(text: ligne.nom);
    final grammesCtl = TextEditingController(text: fmt(ligne.grammes));
    final kcalCtl = TextEditingController(text: fmt(ligne.pour100.kcal));
    final protCtl = TextEditingController(text: fmt(ligne.pour100.proteines));
    final glucCtl = TextEditingController(text: fmt(ligne.pour100.glucides));
    final lipCtl = TextEditingController(text: fmt(ligne.pour100.lipides));

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
      setState(() {
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
      });
    }
    nomCtl.dispose();
    grammesCtl.dispose();
    kcalCtl.dispose();
    protCtl.dispose();
    glucCtl.dispose();
    lipCtl.dispose();
  }

  Future<void> _ajouterManuel() async {
    try {
      await _dialogueAjoutManuel();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ajout d\'aliment impossible : $e')),
        );
      }
    }
  }

  Future<void> _dialogueAjoutManuel() async {
    final controleur = TextEditingController();
    final resultat = await showDialog<Object>(
      context: context,
      builder: (context) {
        var suggestions = <Aliment>[];
        return StatefulBuilder(
          builder: (context, majEtat) => AlertDialog(
            title: const Text('Ajouter un aliment'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controleur,
                    autofocus: true,
                    decoration: const InputDecoration(
                        hintText: 'Ex. : poulet, riz, pomme…'),
                    onChanged: (valeur) => majEtat(() =>
                        suggestions = ServiceNutrition.suggestions(valeur)),
                  ),
                  const SizedBox(height: 12),
                  if (suggestions.isEmpty)
                    const Text(
                      'Aucune suggestion : « Saisie libre » créera une ligne à compléter (valeurs / 100 g à la main).',
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        itemBuilder: (_, i) {
                          final aliment = suggestions[i];
                          return ListTile(
                            dense: true,
                            title: Text(aliment.nom),
                            subtitle: Text(
                                '${aliment.valeurs.kcal.round()} kcal / 100 g'),
                            onTap: () => Navigator.pop(context, aliment),
                          );
                        },
                      ),
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
                // Désactivé si le champ est vide : évite de fermer le
                // dialogue sans rien ajouter.
                onPressed: controleur.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(context, controleur.text.trim()),
                child: const Text('Saisie libre'),
              ),
            ],
          ),
        );
      },
    );
    controleur.dispose();

    if (resultat is Aliment) {
      setState(() {
        _lignes.add(LigneRepas(
          nom: resultat.nom,
          grammes: 100,
          pour100: resultat.valeurs,
          source: 'base',
        ));
      });
    } else if (resultat is String && resultat.isNotEmpty) {
      setState(() {
        _lignes.add(LigneRepas(
          nom: resultat,
          grammes: 100,
          pour100: ValeursNutritionnelles.vide,
          source: 'manuel',
          reconnu: false,
        ));
      });
    }
  }

  // ------------------------------------------------------------ Enregistrement

  Future<void> _enregistrer() async {
    if (_lignes.isEmpty) return;
    final journal = context.read<Journal>();

    String? photoSauvee;
    if (_photo != null) {
      photoSauvee = await _sauverPhoto(_photo!);
    }

    final repas = Repas(
      prisLe: DateTime.now(),
      type: _type,
      photo: photoSauvee,
      lignes: List<LigneRepas>.of(_lignes),
    );
    await journal.ajouter(repas);
    if (mounted) Navigator.pop(context);
  }

  Future<String?> _sauverPhoto(XFile photo) async {
    try {
      final dossier = await getApplicationDocumentsDirectory();
      final destination = p.join(dossier.path, 'photos',
          'repas_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await Directory(p.dirname(destination)).create(recursive: true);
      return (await File(photo.path).copy(destination)).path;
    } catch (_) {
      return null; // la photo est facultative
    }
  }

  // ------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final total = _lignes.fold(
      ValeursNutritionnelles.vide,
      (acc, ligne) => acc.ajouter(ligne.valeurs),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un repas'),
        actions: [
          IconButton(
            tooltip: 'Ajouter un aliment manuellement',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _ajouterManuel,
          ),
        ],
      ),
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

            // ----- Photo -----
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  if (_photo != null)
                    Image.file(
                      File(_photo!.path),
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      height: 120,
                      color: Colors.grey.shade100,
                      alignment: Alignment.center,
                      child: Text(
                        '📷 Prenez votre assiette en photo,\nl\'IA listera les aliments',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  if (_enAnalyse) ...[
                    const LinearProgressIndicator(),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Analyse de l\'assiette en cours…',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                  OverflowBar(
                    alignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Caméra'),
                        onPressed: _enAnalyse
                            ? null
                            : () => _prendrePhoto(ImageSource.camera),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galerie'),
                        onPressed: _enAnalyse
                            ? null
                            : () => _prendrePhoto(ImageSource.gallery),
                      ),
                      if (_photo != null &&
                          _reglages.iaDisponible &&
                          !_enAnalyse)
                        TextButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réanalyser'),
                          onPressed: _analyser,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ----- Erreur -----
            if (_erreur != null)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_erreur!)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),

            // ----- Lignes d'aliments -----
            for (var i = 0; i < _lignes.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CarteLigne(
                  ligne: _lignes[i],
                  onGrammesModifies: (g) =>
                      setState(() => _lignes[i].grammes = g),
                  onEditer: () => _editerLigne(i),
                  onSupprimer: () => _supprimerLigne(i),
                ),
              ),

            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un aliment (base ou saisie libre)'),
              onPressed: _ajouterManuel,
            ),
            const SizedBox(height: 12),

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
              label: const Text('Enregistrer le repas'),
              onPressed: _lignes.isEmpty ? null : _enregistrer,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

String _fmt(double d) =>
    d == d.roundToDouble() ? d.round().toString() : d.toStringAsFixed(1);

/// Une ligne d'aliment éditable : quantité modifiable en direct, valeurs
/// détaillées via la boîte de dialogue, suppression.
class _CarteLigne extends StatelessWidget {
  final LigneRepas ligne;
  final ValueChanged<double> onGrammesModifies;
  final VoidCallback onEditer;
  final VoidCallback onSupprimer;

  const _CarteLigne({
    required this.ligne,
    required this.onGrammesModifies,
    required this.onEditer,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  ligne.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${ligne.pour100.kcal.round()} kcal / 100 g'
                  '${ligne.reconnu ? '' : ' · hors base, à vérifier'}',
                  style: ligne.reconnu
                      ? null
                      : TextStyle(color: Colors.orange.shade800),
                ),
                onTap: onEditer,
              ),
            ),
            SizedBox(
              width: 78,
              child: TextFormField(
                key: ObjectKey(ligne),
                initialValue: _fmt(ligne.grammes),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  suffixText: 'g',
                  isDense: true,
                  border: InputBorder.none,
                ),
                onChanged: (valeur) => onGrammesModifies(
                    double.tryParse(valeur.replaceAll(',', '.')) ?? 0),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Retirer',
              onPressed: onSupprimer,
            ),
          ],
        ),
      ),
    );
  }
}
