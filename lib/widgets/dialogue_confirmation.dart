import 'package:flutter/material.dart';

/// Demande confirmation avant une suppression définitive (v0.7.6).
///
/// Renvoie true si l'utilisateur confirme (« Supprimer »), false sinon
/// (Annuler, appui hors dialogue ou bouton retour) : rien ne doit être
/// supprimé tant que la réponse n'est pas true.
Future<bool> confirmerSuppression(
  BuildContext context, {
  String? titre,
  String? message,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titre ?? 'Supprimer ?'),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          key: const Key('annulerSuppression'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('confirmerSuppression'),
          style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
