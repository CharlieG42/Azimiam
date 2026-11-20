import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:azimiam/services/affichage_erreurs.dart';

void main() {
  testWidgets('le rendu d\u2019erreur affiche un message lisible en release',
      (tester) async {
    final details = FlutterErrorDetails(
      exception: Exception('boom'),
      library: 'test',
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AffichageErreurs.erreurLisible(details))),
    );

    expect(find.text('Erreur d\u2019affichage'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
    expect(
      find.textContaining(
          'Prenez une capture d\u2019écran de ce message pour le signaler.'),
      findsOneWidget,
    );
  });

  test('installer() remplace le builder d\u2019erreurs', () {
    final ancien = ErrorWidget.builder;
    addTearDown(() => ErrorWidget.builder = ancien);
    AffichageErreurs.installer();
    expect(identical(ErrorWidget.builder, AffichageErreurs.erreurLisible),
        isTrue);
    ErrorWidget.builder = ancien;
  });
}
