import 'package:flutter/material.dart';

import '../version.dart';

/// Écran « À propos » : version de l'app telle que définie dans le pubspec
/// (et embarquée dans l'APK au build), principe de fonctionnement et
/// avertissement.
class AProposEcran extends StatelessWidget {
  const AProposEcran({super.key});

  @override
  Widget build(BuildContext context) {
    final parties = kVersionApp.split('+');
    final version = parties.first;
    final build = parties.length > 1 ? parties.last : '';

    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          const Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Color(0xFF2E7D32),
              child: Text(
                'A',
                style: TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Azimiam',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              'Compteur de calories et nutriments par photo (WildZimut)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Version'),
              subtitle: Text(
                build.isEmpty ? version : '$version (build $build)',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.tag_outlined),
              title: const Text('Version définie (pubspec)'),
              subtitle: Text(kVersionApp),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Principe',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "L'IA de vision identifie les aliments sur la photo ; "
                    "elle ne calcule jamais. Toutes les valeurs "
                    "nutritionnelles sont calculées localement à partir de "
                    "la base d'aliments embarquée.",
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Azimiam est un outil d'information, pas un dispositif "
                    "médical.",
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
