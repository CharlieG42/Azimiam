// Suivi de l'hydratation (v0.7.9) : eau bue par jour et objectif
// journalier extrapolé depuis le profil et le sport du jour.

/// Objectif d'hydratation journalier, en millilitres (v0.7.9).
///
/// Base : 30 mL par kg de poids corporel connu (repli 2 000 mL sans
/// pesée), majorée de 500 mL par heure de sport (séances du jour) :
/// l'effort et la transpiration doivent être compensés. Plancher
/// 1 500 mL, plafond 5 000 mL, arrondi au multiple de 50 mL pour un
/// affichage lisible.
int objectifEau({double? poidsKg, int minutesSport = 0}) {
  final base = (poidsKg != null && poidsKg > 0) ? poidsKg * 30.0 : 2000.0;
  final sport = minutesSport / 60.0 * 500.0;
  var brut = base + sport;
  if (brut < 1500) brut = 1500;
  if (brut > 5000) brut = 5000;
  return (brut / 50.0).ceil() * 50;
}
