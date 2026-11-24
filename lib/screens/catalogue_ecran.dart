import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mini_base.dart';
import '../models/valeurs.dart';
import '../services/service_nutrition.dart';
import '../state/catalogue.dart';

/// Catalogue complet des aliments : base embarquée + aliments ajoutés par
/// l'utilisateur. Recherche instantanée multi-mots insensible aux accents
/// (nom + alias), liste alphabétique avec valeurs pour 100 g.
///
/// - Toucher un aliment le renvoie à l'écran appelant (pattern « pop avec
///   résultat ») qui l'ajoute au repas ;
/// - Bouton « + » : ajouter un nouvel aliment au catalogue (persistant) ;
/// - Les aliments perso (badge « Perso ») se supprient d'un swipe.
class CatalogueEcran extends StatefulWidget {
  const CatalogueEcran({super.key});

  @override
  State<CatalogueEcran> createState() => _CatalogueEcranState();
}

class _CatalogueEcranState extends State<CatalogueEcran> {
  final TextEditingController _rechercheCtl = TextEditingController();
  List<Aliment> _resultats = [];

  @override
  void initState() {
    super.initState();
    // La liste est remplie au premier build depuis le provider Catalogue
    // (prêt après l'initState) : recherche « vide » = catalogue complet.
  }

  @override
  void dispose() {
    _rechercheCtl.dispose();
    super.dispose();
  }

  /// Recherche multi-mots : « pommes terre » retrouve « Pommes de terre
  /// cuites » ; les accents sont ignorés ; les alias comptent aussi.
  /// Texte vide : catalogue complet trié alphabétiquement.
  ///
  /// Ne NOTIFIE pas seule : les appels de rentrée (onChanged) le font via
  /// setState, le chemin build() met à jour sans re-notifier.
  void _rechercher(String texte, List<Aliment> catalogue) {
    final cible = texte.trim();
    if (cible.isEmpty) {
      _resultats = [...catalogue];
      return;
    }
    _resultats = ServiceNutrition.rechercher(cible, base: catalogue);
  }

  Future<void> _ajouterAliment() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _DialogNouvelAliment(
        onValide: (nom, alias, valeurs) async {
          final catalogue = context.read<Catalogue>();
          final erreur =
              await catalogue.ajouter(nom: nom, alias: alias, valeurs: valeurs);
          if (!context.mounted) return;
          if (erreur != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(erreur)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('« $nom » ajouté au catalogue. Il apparaît dès '
                          'maintenant dans la recherche de l\'écran d\'ajout.')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = context.watch<Catalogue>();
    // Le catalogue a peut-être changé depuis le dernier build (ajout ou
    // suppression => watch notifie) : rejouer la recherche pour rafraîchir
    // les résultats SANS setState pendant le build.
    if (catalogue.perso.length != _nbPersoAffiches) {
      _nbPersoAffiches = catalogue.perso.length;
      _rechercher(_rechercheCtl.text, catalogue.tous);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Catalogue d\'aliments (${catalogue.tous.length})'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('champRechercheCatalogue'),
              controller: _rechercheCtl,
              autofocus: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText:
                    'Rechercher (mots libres, accents ignorés : ex. pommes terre)',
                border: OutlineInputBorder(),
              ),
              onChanged: (valeur) =>
                  setState(() => _rechercher(valeur, catalogue.tous)),
            ),
          ),
          Expanded(
            child: _resultats.isEmpty
                ? Center(
                    child: Text(
                      'Aucun aliment trouvé pour « ${_rechercheCtl.text} ».\n'
                      'Ajoutez-le au catalogue avec le bouton + ci-dessous.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _resultats.length,
                    itemBuilder: (context, i) {
                      final aliment = _resultats[i];
                      return _TuileAliment(
                        aliment: aliment,
                        onTap: () => Navigator.pop(context, aliment),
                        onSupprime: aliment.perso
                            ? () =>
                                context.read<Catalogue>().supprimer(aliment)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('fabAjouterAliment'),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un aliment'),
        onPressed: _ajouterAliment,
      ),
    );
  }

  int _nbPersoAffiches = -1;
}

/// Une ligne du catalogue : valeurs /100 g, badge « Perso » et swipe de
/// suppression réservé aux aliments personnalisés.
class _TuileAliment extends StatelessWidget {
  final Aliment aliment;
  final VoidCallback onTap;
  final VoidCallback? onSupprime;

  const _TuileAliment({required this.aliment, required this.onTap, this.onSupprime});

  @override
  Widget build(BuildContext context) {
    final tuile = ListTile(
      dense: true,
      leading: Icon(
        aliment.perso ? Icons.bookmark : Icons.restaurant_outlined,
        color: aliment.perso ? Colors.amber.shade700 : null,
      ),
      title: Text(aliment.nom),
      subtitle: Text(
        '${aliment.valeurs.kcal.round()} kcal / 100 g · '
        'P ${aliment.valeurs.proteines.round()} g · '
        'G ${aliment.valeurs.glucides.round()} g · '
        'L ${aliment.valeurs.lipides.round()} g'
        '${aliment.perso ? ' · Perso' : ''}',
      ),
      onTap: onTap,
    );
    if (onSupprime == null) return tuile;
    return Dismissible(
      key: ValueKey('perso-${aliment.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        onSupprime!();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('« ${aliment.nom} » retiré du catalogue')),
        );
      },
      child: tuile,
    );
  }
}

/// Boîte de dialogue d'ajout d'un aliment au catalogue : nom, alias
/// optionnels, valeurs pour 100 g. Enregistre via [onValide] qui renvoie
/// une erreur lisible ou null.
class _DialogNouvelAliment extends StatefulWidget {
  final Future<void> Function(String nom, List<String> alias,
      ValeursNutritionnelles valeurs) onValide;

  const _DialogNouvelAliment({required this.onValide});

  @override
  State<_DialogNouvelAliment> createState() => _DialogNouvelAlimentState();
}

class _DialogNouvelAlimentState extends State<_DialogNouvelAliment> {
  final _nomCtl = TextEditingController();
  final _aliasCtl = TextEditingController();
  final _kcalCtl = TextEditingController();
  final _protCtl = TextEditingController();
  final _glucCtl = TextEditingController();
  final _lipCtl = TextEditingController();
  bool _enregistre = false;

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
    await widget.onValide(
      nom,
      _aliasCtl.text
          .split(',')
          .map((a) => a.trim())
          .where((a) => a.isNotEmpty)
          .toList(),
      ValeursNutritionnelles(
        kcal: kcal,
        proteines: _lire(_protCtl) ?? 0,
        glucides: _lire(_glucCtl) ?? 0,
        lipides: _lire(_lipCtl) ?? 0,
      ),
    );
    _enregistre = false;
    if (!mounted) return;
    Navigator.pop(context);
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
              decoration: const InputDecoration(
                  labelText: 'Nom de l\'aliment *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aliasCtl,
              decoration: const InputDecoration(
                labelText: 'Alias de recherche (optionnel)',
                hintText: 'Séparés par des virgules (ex. : patate, pomme de terre)',
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
