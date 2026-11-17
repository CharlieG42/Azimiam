/// Valeurs nutritionnelles.
///
/// Une même instance représente soit une base « pour 100 g » (dans la
/// mini-base locale ou sur une ligne de repas), soit le total réel d'une
/// quantité (voir [pour]).
class ValeursNutritionnelles {
  final double kcal;
  final double proteines;
  final double glucides;
  final double lipides;
  final double fibres;
  final double sucres;
  final double sel;

  const ValeursNutritionnelles({
    required this.kcal,
    required this.proteines,
    required this.glucides,
    required this.lipides,
    this.fibres = 0,
    this.sucres = 0,
    this.sel = 0,
  });

  /// Valeurs nulles (somme neutre).
  static const ValeursNutritionnelles vide =
      ValeursNutritionnelles(kcal: 0, proteines: 0, glucides: 0, lipides: 0);

  /// Valeurs réelles pour [grammes] à partir d'une base pour 100 g.
  ValeursNutritionnelles pour(double grammes) => ValeursNutritionnelles(
        kcal: kcal * grammes / 100,
        proteines: proteines * grammes / 100,
        glucides: glucides * grammes / 100,
        lipides: lipides * grammes / 100,
        fibres: fibres * grammes / 100,
        sucres: sucres * grammes / 100,
        sel: sel * grammes / 100,
      );

  ValeursNutritionnelles ajouter(ValeursNutritionnelles autre) =>
      ValeursNutritionnelles(
        kcal: kcal + autre.kcal,
        proteines: proteines + autre.proteines,
        glucides: glucides + autre.glucides,
        lipides: lipides + autre.lipides,
        fibres: fibres + autre.fibres,
        sucres: sucres + autre.sucres,
        sel: sel + autre.sel,
      );
}
