import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/activite.dart';
import '../services/service_activites.dart';
import '../state/activites.dart';
import '../state/progression.dart';
import '../widgets/dialogue_confirmation.dart';

/// Format affichable d'une durée en minutes : « 45 min », « 1 h 05 ».
String _fmtDuree(double minutes) {
  if (minutes < 60) return '${minutes.round()} min';
  final h = minutes ~/ 60;
  final m = (minutes % 60).round();
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

/// Écran Activités : historique des séances déclarées et calories
/// sportives dépensées.
class ActivitesEcran extends StatelessWidget {
  const ActivitesEcran({super.key});

  @override
  Widget build(BuildContext context) {
    final activites = context.watch<Activites>();

    return Scaffold(
      appBar: AppBar(title: const Text('Activités')),
      body: activites.enChargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: activites.charger,
              child: activites.liste.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Icon(Icons.directions_run,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Aucune activité déclarée.\n'
                              'Touchez « Déclarer une activité » pour '
                              'enregistrer une séance : type, durée, '
                              'distance et dénivelé le cas échéant. Les '
                              'calories sont calculées automatiquement.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        _CarteSemaine(activites: activites),
                        // v0.7.0 : retour discret du dernier import santé
                        // (ex. « 2 séances importées depuis Health Connect »).
                        if (activites.infoImport != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              activites.infoImport!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                        const SizedBox(height: 8),
                        for (final groupe in activites.parJour) ...[
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              DateFormat('EEEE d MMMM', 'fr_FR')
                                  .format(groupe.key),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          for (final a in groupe.value)
                            _CarteActivite(activite: a),
                        ],
                        if (activites.erreur != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              activites.erreur!,
                              style:
                                  TextStyle(color: Colors.orange.shade800),
                            ),
                          ),
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Déclarer une activité'),
        onPressed: () => ajouterActiviteDialog(context),
      ),
    );
  }
}

/// Résumé des 7 derniers jours : séances et calories dépensées.
class _CarteSemaine extends StatelessWidget {
  final Activites activites;

  const _CarteSemaine({required this.activites});

  @override
  Widget build(BuildContext context) {
    final seances = activites.derniers7Jours;
    final kcal = activites.kcal7Jours;
    final km = seances.fold<double>(
      0,
      (acc, a) => acc + (a.distanceKm ?? 0),
    );
    final minutes = seances.fold<double>(
      0,
      (acc, a) => acc + a.dureeMin,
    );
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('7 derniers jours',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${kcal.round()} kcal',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${seances.length} séance${seances.length > 1 ? 's' : ''}'
                    '${minutes > 0 ? ' · ${_fmtDuree(minutes)}' : ''}'
                    '${km > 0 ? ' · ${km.toStringAsFixed(1)} km' : ''}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
            if (seances.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Rien cette semaine : bougez, ça compte !',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Une séance dans l'historique : type, détail, calories, suppression.
class _CarteActivite extends StatelessWidget {
  final ActiviteSport activite;

  const _CarteActivite({required this.activite});

  @override
  Widget build(BuildContext context) {
    final type = ServiceActivites.typeParCle(activite.type);
    final details = <String>[
      _fmtDuree(activite.dureeMin),
      if (activite.distanceKm != null)
        '${activite.distanceKm!.toStringAsFixed(1)} km',
      if (activite.deniveleM != null)
        'D+ ${activite.deniveleM!.round()} m',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('activite-${activite.id}'),
        direction: DismissDirection.endToStart,
        // v0.7.6 : confirmation avant suppression de la séance.
        confirmDismiss: (_) async => await confirmerSuppression(context,
            message:
                'Supprimer cette séance (${activite.kcal.round()} kcal) ?'),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red,
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        onDismissed: (_) {
          final etat = context.read<Activites>();
          etat.supprimer(activite.id!);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Activité « ${ServiceActivites.libelle(activite.type)} » supprimée'),
            ),
          );
        },
        child: Card(
          elevation: 2,
          child: ListTile(
            leading: Icon(
              type?.icone ?? Icons.more_horiz,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    type?.libelle ?? activite.type,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                // v0.7.0 : badge d'origine sur les séances importées
                // depuis une source santé (montre Garmin ou autre).
                if ((activite.source ?? '').contains('garmin')) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Importée depuis la montre Garmin',
                    child: Icon(
                      Icons.watch_outlined,
                      size: 18,
                      color: Colors.blueGrey.shade400,
                    ),
                  ),
                ] else if (activite.importee) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Importée depuis Health Connect',
                    child: Icon(
                      Icons.health_and_safety_outlined,
                      size: 18,
                      color: Colors.blueGrey.shade400,
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(details.join(' · ')),
            trailing: Text(
              '${activite.kcal.round()} kcal',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ouvre la boîte de dialogue de déclaration d'une activité :
/// type, date et heure, durée, distance et dénivelé si le type le
/// prévoit, et calories calculées (saisie manuelle possible).
Future<void> ajouterActiviteDialog(BuildContext context) async {
  final activites = context.read<Activites>();
  final progression = context.read<Progression>();
  final poids = progression.dernier?.kg;

  final declaree = await showDialog<ActiviteSport>(
    context: context,
    builder: (context) =>
        _DialogActivite(poidsKg: poids, maintenant: DateTime.now()),
  );
  if (declaree != null) {
    await activites.ajouter(declaree);
  }
}

/// Contenu de la saisie : garde le type courant et recalcule les
/// calories à chaque changement (sauf saisie manuelle des calories).
class _DialogActivite extends StatefulWidget {
  /// Poids de référence pour le calcul (null : estimation sur 70 kg).
  final double? poidsKg;
  final DateTime maintenant;

  const _DialogActivite({required this.poidsKg, required this.maintenant});

  @override
  State<_DialogActivite> createState() => _DialogActiviteState();
}

class _DialogActiviteState extends State<_DialogActivite> {
  late final TextEditingController _dureeCtl;
  late final TextEditingController _distanceCtl;
  late final TextEditingController _deniveleCtl;
  late final TextEditingController _kcalCtl;

  TypeActivite _type = ServiceActivites.types.first;
  late DateTime _moment;
  bool _kcalManuel = false;

  @override
  void initState() {
    super.initState();
    _dureeCtl = TextEditingController();
    _distanceCtl = TextEditingController();
    _deniveleCtl = TextEditingController();
    _kcalCtl = TextEditingController();
    _moment = widget.maintenant;
    // Actualise l'aperçu des calories à chaque champ modifié.
    for (final ctl in [_dureeCtl, _distanceCtl, _deniveleCtl]) {
      ctl.addListener(_recalculer);
    }
  }

  @override
  void dispose() {
    _dureeCtl.dispose();
    _distanceCtl.dispose();
    _deniveleCtl.dispose();
    _kcalCtl.dispose();
    super.dispose();
  }

  double? _lire(TextEditingController ctl) =>
      double.tryParse(ctl.text.replaceAll(',', '.'));

  /// Recalcule les calories (mode auto uniquement).
  void _recalculer() {
    if (_kcalManuel) return;
    final kcal = ServiceActivites.calories(
      type: _type.cle,
      dureeMin: _lire(_dureeCtl) ?? 0,
      poidsKg: widget.poidsKg,
      distanceKm: _type.avecDistance ? _lire(_distanceCtl) : null,
      deniveleM: _type.avecDenivele ? _lire(_deniveleCtl) : null,
    );
    final texte = kcal <= 0 ? '' : kcal.round().toString();
    // Remplacer sans recréer le contrôleur : le champ garde le focus et
    // le curseur (seules les décimales d'arrondi changent en pratique).
    if (_kcalCtl.text != texte) {
      _kcalCtl.value = TextEditingValue(
        text: texte,
        selection: TextSelection.collapsed(offset: texte.length),
      );
    }
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _moment,
      firstDate: _moment.subtract(const Duration(days: 365)),
      lastDate: DateTime(_moment.year, _moment.month, _moment.day + 1),
    );
    if (d != null) {
      setState(() {
        _moment = DateTime(
            d.year, d.month, d.day, _moment.hour, _moment.minute);
      });
    }
  }

  Future<void> _choisirHeure() async {
    final h = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_moment),
    );
    if (h != null) {
      setState(() {
        _moment = DateTime(_moment.year, _moment.month, _moment.day,
            h.hour, h.minute);
      });
    }
  }

  void _valider() {
    final duree = _lire(_dureeCtl) ?? 0;
    if (duree <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indiquez une durée en minutes')),
      );
      return;
    }
    Navigator.pop(
      context,
      ActiviteSport(
        moment: _moment,
        type: _type.cle,
        dureeMin: duree,
        distanceKm: _type.avecDistance ? _lire(_distanceCtl) : null,
        deniveleM: _type.avecDenivele ? _lire(_deniveleCtl) : null,
        kcal: _lire(_kcalCtl) ??
            ServiceActivites.calories(
              type: _type.cle,
              dureeMin: duree,
              poidsKg: widget.poidsKg,
              distanceKm: _type.avecDistance ? _lire(_distanceCtl) : null,
              deniveleM: _type.avecDenivele ? _lire(_deniveleCtl) : null,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateTxt = DateFormat('EEE d MMM', 'fr_FR').format(_moment);
    final heureTxt =
        '${_moment.hour.toString().padLeft(2, '0')}:${_moment.minute.toString().padLeft(2, '0')}';
    return AlertDialog(
      title: const Text('Déclarer une activité'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<TypeActivite>(
              key: const Key('dropdownTypeActivite'),
              value: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final t in ServiceActivites.types)
                  DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        Icon(t.icone, size: 20),
                        const SizedBox(width: 8),
                        Text(t.libelle),
                      ],
                    ),
                  ),
              ],
              onChanged: (t) {
                if (t == null) return;
                setState(() => _type = t);
                _recalculer();
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                        '${dateTxt[0].toUpperCase()}${dateTxt.substring(1)}'),
                    onPressed: _choisirDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule, size: 16),
                    label: Text(heureTxt),
                    onPressed: _choisirHeure,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dureeCtl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Durée (minutes)',
                suffixText: 'min',
              ),
            ),
            if (_type.avecDistance) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _distanceCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Distance (km, optionnel)',
                  suffixText: 'km',
                ),
              ),
            ],
            if (_type.avecDenivele) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _deniveleCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Dénivelé positif (m, optionnel)',
                  suffixText: 'm',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _kcalCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Calories dépensées (kcal)',
                suffixText: 'kcal',
              ),
              onChanged: (_) {
                // Saisie manuelle : fige la valeur, le bouton Automatique
                // la rend de nouveau au calcul.
                setState(() => _kcalManuel = true);
              },
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.autorenew, size: 18),
                  label: const Text('Calcul automatique'),
                  onPressed: () {
                    setState(() => _kcalManuel = false);
                    _recalculer();
                  },
                ),
              ],
            ),
            if (!_kcalManuel)
              Text(
                widget.poidsKg != null
                    ? 'Calcul sur la base de votre dernière pesée : '
                        '${widget.poidsKg!.toStringAsFixed(1)} kg'
                    : 'Aucune pesée enregistrée : calcul estimé sur 70 kg',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
          onPressed: _valider,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
