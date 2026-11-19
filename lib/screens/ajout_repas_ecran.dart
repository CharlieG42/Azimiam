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

  final TextEditingController _saisieCtl = TextEditingController();
  final FocusNode _saisieFocus = FocusNode();
  List<Aliment> _suggestions = [];

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

  @override
  void dispose() {
    _saisieCtl.dispose();
    _saisieFocus.dispose();
    super.dispose();
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

  void _focusSaisie() {
    _saisieFocus.requestFocus();
  }

  void _ajouterDepuisBase(Aliment aliment) {
    setState(() {
      _lignes.add(LigneRepas(
        nom: aliment.nom,
        grammes: 100,
        pour100: aliment.valeurs,
        source: 'base',
      ));
      _saisieCtl.clear();
      _suggestions = [];
    });
  }

  void _ajouterSaisieLibre() {
    final texte = _saisieCtl.text.trim();
    if (texte.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saisissez d'abord un nom d'aliment.")),
      );
      return;
    }
    setState(() {
      _lignes.add(LigneRepas(
        nom: texte,
        grammes: 100,
        pour100: ValeursNutritionnelles.vide,
        source: 'manuel',
        reconnu: false,
      ));
      _saisieCtl.clear();
      _suggestions = [];
    });
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
            onPressed: _focusSaisie,
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

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ajouter un aliment',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('champSaisieAliment'),
                      controller: _saisieCtl,
                      focusNode: _saisieFocus,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Ex. : poulet, riz, pomme…',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (valeur) => setState(
                          () => _suggestions = ServiceNutrition.suggestions(valeur)),
                      onSubmitted: (_) => _ajouterSaisieLibre(),
                    ),
                    if (_suggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (_, i) {
                            final aliment = _suggestions[i];
                            return ListTile(
                              dense: true,
                              title: Text(aliment.nom),
                              subtitle: Text(
                                  '${aliment.valeurs.kcal.round()} kcal / 100 g'),
                              onTap: () => _ajouterDepuisBase(aliment),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Saisie libre (hors base)'),
                      onPressed: _ajouterSaisieLibre,
                    ),
                  ],
                ),
              ),
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
