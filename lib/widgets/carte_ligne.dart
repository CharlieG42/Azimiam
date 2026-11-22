import 'package:flutter/material.dart';

import '../models/repas.dart';

String fmtQuantite(double d) =>
    d == d.roundToDouble() ? d.round().toString() : d.toStringAsFixed(1);

/// Une ligne d'aliment éditable : quantité modifiable en direct, valeurs
/// détaillées via la boîte de dialogue, suppression.
///
/// Stateful (et non plus stateless avec `initialValue`) : le TextFormField
/// garde son état interne tant que la clé ne change pas, ce qui empêchait
/// l'affichage de se mettre à jour quand la ligne était modifiée par la
/// boîte de dialogue (ex. 100 g → 250 g) alors que l'instance de
/// [LigneRepas] restait la même. Le contrôleur est ici resynchronisé à
/// chaque rebuild si la valeur affichée ne correspond plus à la ligne.
class CarteLigne extends StatefulWidget {
  final LigneRepas ligne;
  final ValueChanged<double> onGrammesModifies;
  final VoidCallback onEditer;
  final VoidCallback onSupprimer;

  const CarteLigne({
    super.key,
    required this.ligne,
    required this.onGrammesModifies,
    required this.onEditer,
    required this.onSupprimer,
  });

  @override
  State<CarteLigne> createState() => _CarteLigneState();
}

class _CarteLigneState extends State<CarteLigne> {
  late final TextEditingController _grammesCtl;

  @override
  void initState() {
    super.initState();
    _grammesCtl = TextEditingController(text: fmtQuantite(widget.ligne.grammes));
  }

  @override
  void dispose() {
    _grammesCtl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CarteLigne ancien) {
    super.didUpdateWidget(ancien);
    // Resynchronise le champ si la quantité a été changée ailleurs (boîte de
    // dialogue d'édition). Pendant la frappe directe, la valeur saisie est
    // immédiatement répercutée sur la ligne, donc pas de réécriture.
    final texte = _grammesCtl.text.trim().replaceAll(',', '.');
    if (texte.isEmpty) return; // champ vidé : frappe en cours, ne pas écraser
    final valeur = double.tryParse(texte);
    if (valeur == null) return; // texte non numérique temporaire
    if ((valeur - widget.ligne.grammes).abs() < 0.001) return;
    _grammesCtl.text = fmtQuantite(widget.ligne.grammes);
    _grammesCtl.selection = TextSelection.fromPosition(
      TextPosition(offset: _grammesCtl.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ligne = widget.ligne;
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
                onTap: widget.onEditer,
              ),
            ),
            SizedBox(
              width: 78,
              child: TextFormField(
                controller: _grammesCtl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  suffixText: 'g',
                  isDense: true,
                  border: InputBorder.none,
                ),
                onChanged: (valeur) => widget.onGrammesModifies(
                    double.tryParse(valeur.replaceAll(',', '.')) ?? 0),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Retirer',
              onPressed: widget.onSupprimer,
            ),
          ],
        ),
      ),
    );
  }
}
