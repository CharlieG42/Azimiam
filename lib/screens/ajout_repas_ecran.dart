import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/mini_base.dart';
import '../models/repas.dart';
import '../models/valeurs.dart';
import 'catalogue_ecran.dart';
import '../services/service_ia.dart';
import '../services/service_nutrition.dart';
import '../services/service_reglages.dart';
import '../state/catalogue.dart';
import '../state/journal.dart';
import '../widgets/carte_ligne.dart';
import '../widgets/dialog_ligne.dart';

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
  final ScrollController _defilement = ScrollController();
  final GlobalKey _cleCarteAjout = GlobalKey();
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
    _defilement.dispose();
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
          final trouve = ServiceNutrition.retrouve(analyse.nom,
              base: context.mounted
                  ? context.read<Catalogue>().tous
                  : BaseAliments.tous);
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
      // Erreur réseau ou autre : message clair plutôt qu'une exception brute
      // incompréhensible (« Failed host lookup errno = 7 »).
      setState(
          () => _erreur = ServiceIa.messageErreur(e, baseUrl: _reglages.baseUrl));
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
    final modifiee = await editerLigneDialog(context, _lignes[index]);
    if (modifiee && mounted) setState(() {});
  }

  /// Ouvre le catalogue complet : l'aliment touché revient ici et est
  /// ajouté au repas.
  Future<void> _ouvrirCatalogue() async {
    final aliment = await Navigator.push<Aliment>(
      context,
      MaterialPageRoute(builder: (_) => const CatalogueEcran()),
    );
    if (aliment != null) _ajouterDepuisBase(aliment);
  }

  void _focusSaisie() {
    // Fait défiler jusqu'au panneau « Ajouter un aliment » puis ouvre le
    // clavier : le panneau est toujours atteignable, même après l'ajout de
    // plusieurs lignes (la photo peut le pousser hors de l'écran).
    final contexteCarte = _cleCarteAjout.currentContext;
    if (contexteCarte != null) {
      Scrollable.ensureVisible(
        contexteCarte,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
      );
    }
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
        controller: _defilement,
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
                child: CarteLigne(
                  ligne: _lignes[i],
                  onGrammesModifies: (g) =>
                      setState(() => _lignes[i].grammes = g),
                  onEditer: () => _editerLigne(i),
                  onSupprimer: () => _supprimerLigne(i),
                ),
              ),

            Card(
              key: _cleCarteAjout,
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
                      onChanged: (valeur) => setState(() =>
                          _suggestions = ServiceNutrition.suggestions(
                              valeur,
                              base: context.read<Catalogue>().tous)),
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
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('boutonCatalogue'),
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Catalogue complet'),
                      onPressed: _ouvrirCatalogue,
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
