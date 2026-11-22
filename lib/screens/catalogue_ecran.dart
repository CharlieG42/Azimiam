import 'package:flutter/material.dart';

import '../data/mini_base.dart';

/// Catalogue complet de la base locale d'aliments : recherche instantanée,
/// liste alphabétique avec valeurs pour 100 g. Toucher un aliment le renvoie
/// à l'écran appelant (Pattern « pop avec résultat »), qui l'ajoute au repas.
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
    _rechercher('');
  }

  @override
  void dispose() {
    _rechercheCtl.dispose();
    super.dispose();
  }

  /// Recherche insensible aux accents : le catalogue doit retrouver
  /// « côtelette » en tapant « cotelette », et les alias aussi.
  String _normalise(String s) => s
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('û', 'u')
      .replaceAll('ç', 'c')
      .replaceAll('\'', ' ');

  void _rechercher(String texte) {
    final cible = _normalise(texte.trim());
    setState(() {
      if (cible.isEmpty) {
        _resultats = [...BaseAliments.tous]
          ..sort((a, b) => a.nom.compareTo(b.nom));
        return;
      }
      _resultats = BaseAliments.tous.where((aliment) {
        if (_normalise(aliment.nom).contains(cible)) return true;
        return aliment.alias.any((a) => _normalise(a).contains(cible));
      }).toList()
        ..sort((a, b) => a.nom.compareTo(b.nom));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalogue d\'aliments')),
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
                hintText: 'Rechercher un aliment (ex. : poulet, riz…)',
                border: OutlineInputBorder(),
              ),
              onChanged: _rechercher,
            ),
          ),
          Expanded(
            child: _resultats.isEmpty
                ? Center(
                    child: Text(
                      'Aucun aliment trouvé pour « ${_rechercheCtl.text} ».\n'
                      'Ajoutez-le en « saisie libre » depuis l\'écran d\'ajout.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _resultats.length,
                    itemBuilder: (context, i) {
                      final aliment = _resultats[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.restaurant_outlined),
                        title: Text(aliment.nom),
                        subtitle: Text(
                          '${aliment.valeurs.kcal.round()} kcal / 100 g · '
                          'P ${aliment.valeurs.proteines.round()} g · '
                          'G ${aliment.valeurs.glucides.round()} g · '
                          'L ${aliment.valeurs.lipides.round()} g',
                        ),
                        onTap: () => Navigator.pop(context, aliment),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
