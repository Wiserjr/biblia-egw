import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:biblia_estudo/telas/estudo_piloto.dart';

void main() {
  testWidgets('respostas e alternativa são recuperadas ao reabrir a lição', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Future<void> abrir() async {
      await tester.pumpWidget(
        MaterialApp(
          home: TelaEstudoPiloto(
            arquivo: File('nao-usado.pdf'),
            prefs: prefs,
            carregarTexto: () async => 'x' * 6000,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await abrir();
    await tester.enterText(find.byType(TextField).first, 'Minha reflexão');
    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pump();
    // A lista cria os campos de todas as perguntas e o botão está ao final.
    await tester.scrollUntilVisible(
      find.text('Salvar e continuar depois'),
      500,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Salvar e continuar depois'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await abrir();
    expect(
      (tester.widget<TextField>(find.byType(TextField).first)).controller!.text,
      'Minha reflexão',
    );
    expect(
      tester.widget<ChoiceChip>(find.byType(ChoiceChip).first).selected,
      true,
    );
    expect(
      prefs.getBool('piloto_${hashEstudoPiloto}_licao1_concluida'),
      isNull,
    );
  });

  testWidgets('erro na leitura não oferece uma lição incorreta', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MaterialApp(
        home: TelaEstudoPiloto(
          arquivo: File('nao-usado.pdf'),
          prefs: prefs,
          carregarTexto: () async => throw StateError('PDF inválido'),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(
      find.text('Não foi possível ler a lição nesta edição do PDF.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });
}
