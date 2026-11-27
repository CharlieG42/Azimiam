import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mini_base.dart';
import '../services/service_nutrition.dart';
import '../state/catalogue.dart';
import '../widgets/dialog_nouvel_aliment.dart';
import '../widgets/dialogue_confirmation.dart';

/// Catalogue complet des aliments : base embarquée + aliments ajoutés par
/// l'utilisateur. Recherche instantanée multi-mots insensible aux accents
/// (nom + alias), liste alphabétique avec valeurs pour 100 g.
///
/// - Toucher un aliment le renvoie à l'écran appelant (pattern « pop avec
///   résultat ») qui l'ajoute au repas ;
/// - Bouton « + » : ajouter un nouvel aliment au catalogue (persistant) ;
/// - Les aliments perso (badge « Perso ») se suppriment d'un swipe.
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
    final cree = await showDialog<AlimentCree>(
      context: context,
      builder: (context) => DialogNouvelAliment(
        onValide: (nom, alias, valeurs) =>
            context.read<Catalogue>().ajouter(
                  nom: nom,
                  alias: alias,
                  valeurs: valeurs,
                ),
      ),
    );
    if (!mounted) return;
    if (cree != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('« ${cree.nom} » ajouté au catalogue. Il apparaît '
                'dès maintenant dans la recherche de l\'écran d\'ajout.')),
      );
    }
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
      // v0.7.6 : confirmation avant suppression de l'aliment perso.
      confirmDismiss: (_) async => await confirmerSuppression(context,
          message: 'Supprimer « ${aliment.nom} » du catalogue ?'),
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
