import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biblia_estudo/dados/quiz_biblico.dart';
import 'package:biblia_estudo/telas/quiz_biblico.dart';

void main() {
  List<PerguntaQuiz> banco() => [
    for (var n = 1; n <= 3; n++)
      for (var i = 0; i < 20; i++)
        PerguntaQuiz(
          '$n-$i',
          'Pergunta $i',
          'Correta',
          n,
          ['Correta', 'A', 'B', 'C'],
          [
            [1, 1001, 1001],
          ],
        ),
  ];
  test('quinze acertos chegam ao milhão, uma confirmação por rodada', () {
    final p = PartidaQuiz(banco(), random: Random(2));
    for (var i = 0; i < 15; i++) {
      p.confirmar('Correta');
      p.confirmar('Correta');
      expect(p.acertos, i + 1);
      if (!p.terminou) p.proxima();
    }
    expect(p.resultado, 1000000);
    expect(p.usados.length, 15);
  });
  test('erro respeita checkpoints e parar conserva pontuação', () {
    for (final n in [0, 4, 5, 9, 10, 14]) {
      final p = PartidaQuiz(banco());
      for (var i = 0; i < n; i++) {
        p.confirmar('Correta');
        p.proxima();
      }
      final garantidos = p.garantidos;
      p.confirmar('A');
      expect(p.resultado, garantidos);
    }
    final p = PartidaQuiz(banco());
    p.confirmar('Correta');
    p.proxima();
    p.parar();
    expect(p.resultado, 1000);
  });
  test(
    'ajudas são limitadas e nunca eliminam a correta ou repetem pergunta',
    () {
      final p = PartidaQuiz(banco());
      p.metade();
      expect(p.ocultas.length, 2);
      expect(p.ocultas.contains('Correta'), false);
      for (var i = 0; i < 3; i++) {
        p.pular();
      }
      final id = p.atual.id;
      p.pular();
      expect(p.atual.id, id);
      expect(p.usados.length, 4);
      expect(p.pulos, 0);
    },
  );
  test('arquivo incompatível é recusado antes de descompactar', () {
    expect(
      () => importarQuiz({
        'bytes': Uint8List(1),
        'indice': {'sha256Epub': 'outro'},
      }),
      throwsFormatException,
    );
  });
  final caminho = Platform.environment['BIBLIA_TEST_QUIZ_EPUB'];
  test(
    'EPUB pessoal: 60 perguntas, níveis e conteúdo textual',
    () {
      final indice = jsonDecode(
        File('assets/quiz_indice_cpb.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final livro = importarQuiz({
        'bytes': File(caminho!).readAsBytesSync(),
        'indice': indice,
      });
      final perguntas = (livro['perguntas'] as List)
          .map((j) => PerguntaQuiz.fromJson(j))
          .toList();
      expect(perguntas.length, 60);
      for (var n = 1; n <= 3; n++) {
        expect(perguntas.where((p) => p.nivel == n).length, 20);
      }
      expect((livro['secoes'] as List).length, 125);
      expect(perguntas.first.resposta, 'Pão e carne');
      expect(
        perguntas.every(
          (p) => p.referencias.isNotEmpty && p.alternativas.length == 4,
        ),
        true,
      );
    },
    skip: caminho == null
        ? 'Forneça BIBLIA_TEST_QUIZ_EPUB para validar a cópia pessoal.'
        : false,
  );
  for (final largura in [360.0, 1100.0]) {
    testWidgets(
      'partida em $largura px confirma sem mostrar referência antes',
      (tester) async {
        tester.view.physicalSize = Size(largura, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final p = PartidaQuiz(banco());
        await tester.pumpWidget(MaterialApp(home: TelaPartidaQuiz(partida: p)));
        expect(find.text('Conferir na Bíblia'), findsNothing);
        await tester.tap(find.textContaining('. Correta'));
        await tester.pump();
        await tester.ensureVisible(find.text('Confirmar resposta'));
        await tester.tap(find.text('Confirmar resposta'));
        await tester.pump();
        expect(find.text('Resposta correta!'), findsOneWidget);
        expect(find.text('Conferir na Bíblia'), findsOneWidget);
        expect(tester.takeException(), null);
      },
    );
  }
}
