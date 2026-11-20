import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/foundation.dart';

import 'package:azimiam/services/affichage_erreurs.dart';

void main() {
  testWidgets(
      'un widget qui plante affiche le message d\u2019erreur lisible en release',
      (tester) async {
    final ancienBuilder = ErrorWidget.builder;
    addTearDown(() => ErrorWidget.builder = ancienBuilder);
    AffichageErreurs.installer();
    await tester.pumpWidget(
      const MaterialApp(home: WidgetQuiPlante()),
    );

    expect(tester.takeException(), isNotNull);
    expect(find.byType(WidgetQuiPlante), findsOneWidget);
    await tester.pump();
    expect(find.text('Erreur d\u2019affichage'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
    expect(
      find.textContaining(
          'Prenez une capture d\u2019écran de ce message pour le signaler.'),
      findsOneWidget,
    );
  });
}

class WidgetQuiPlante extends StatelessWidget {
  const WidgetQuiPlante({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(children: [EnfantQuiPlante()]);
  }
}

class EnfantQuiPlante extends StatelessWidget {
  const EnfantQuiPlante({super.key});

  @override
  Widget build(BuildContext context) {
    throw Exception('boom');
  }
}
