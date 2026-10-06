import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:biblia_estudo/dados/respostas_estudos.dart';
import 'package:biblia_estudo/telas/editor_pergunta_estudo.dart';
import 'package:biblia_estudo/telas/estudo_interativo.dart';

void main() {
  test(
    'respostas isoladas por edição e migração sem ressuscitar valores apagados',
    () async {
      SharedPreferences.setMockInitialValues({
        'piloto_a_licao1_resposta_4': 'antiga',
        'piloto_a_licao1_escolha_0': 2,
        'piloto_a_licao1_concluida': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final a = RespostasEstudos(prefs, 'a'), b = RespostasEstudos(prefs, 'b');
      final texto = {'id': 'p6-q5-r1', 'legadoResposta': 4},
          escolha = {'id': 'p6-q1-opcoes', 'legadoEscolha': 0};
      expect(a.texto(texto), 'antiga');
      expect(a.escolhas(escolha), [2]);
      expect(a.concluida(1), true);
      await a.salvarTexto(texto, '');
      await a.salvarEscolhas(escolha, []);
      await a.concluir(1, false);
      expect(a.texto(texto), '');
      expect(a.escolhas(escolha), isEmpty);
      expect(a.concluida(1), false);
      await b.salvarTexto(texto, 'outra edição');
      expect(a.texto(texto), '');
      expect(a.exportar().keys.every((k) => !k.contains('_b_')), true);
    },
  );
  test('sete edições: todas as lições têm campos e João mantém intervalos separados', () {
    final j = jsonDecode(
      File('assets/estudos_interativos.json').readAsStringSync(),
    ) as Map;
    expect((j['estudos'] as List).length, 7);
    var principais = 0, complementares = 0;
    for (final e in j['estudos']) {
      final campos = <String>{};
      for (final l in e['licoes']) {
        if (l['complementar'] == true) {
          complementares++;
        } else {
          principais++;
        }
        expect(
          (e['paginas'] as List)
              .sublist(l['inicio'] - 1, l['fim'])
              .any((p) => (p['perguntas'] as List).isNotEmpty),
          true,
          reason: '${e['id']} ${l['numero']}',
        );
      }
      for (final p in e['paginas']) {
        for (final q in p['perguntas']) {
          expect(q['respostas'], isNotEmpty);
          for (final c in q['respostas']) {
            if (c['continuacao'] != true) expect(campos.add(c['id']), true);
            for (final r in c['areas']) {
              expect(r[0], greaterThanOrEqualTo(0));
              expect(r[1], greaterThanOrEqualTo(0));
              expect(r[2], lessThanOrEqualTo(p['largura'] + .1));
              expect(r[3], lessThanOrEqualTo(p['altura'] + .1));
              expect(r[2], greaterThan(r[0]));
              expect(r[3], greaterThan(r[1]));
            }
          }
        }
      }
    }
    expect(principais, 119);
    expect(complementares, 14);
    final jesus = (j['estudos'] as List).firstWhere(
      (e) => e['id'] == 'jesus-restaurador',
    );
    expect(
      (jesus['paginas'][5]['referencias'] as List).any(
        (r) =>
            jsonEncode(r['referencias']) == '[[43,1001,1004],[43,1014,1014]]',
      ),
      true,
    );
    final amor = (j['estudos'] as List).firstWhere(
      (e) => e['id'] == 'deus-revela-seu-amor',
    );
    expect(
      (amor['paginas'][16]['perguntas'] as List)
          .where((q) => q['semEnunciado'] == true)
          .length,
      5,
    );
  });
  test(
    'áreas usam o recorte normalizado do PDFium e origem superior do índice',
    () {
      final raw = PdfPageRawText('AB', [
        const PdfRect(10, 90, 15, 80),
        const PdfRect(50, 30, 55, 20),
      ]);
      expect(
        textoDentroDasAreas(raw, 100, [
          [9, 9, 16, 21],
        ]),
        'A',
      );
      expect(
        textoDentroDasAreas(raw, 100, [
          [49, 69, 56, 81],
        ]),
        'B',
      );
    },
  );
  testWidgets('alternativas únicas e múltiplas salvam seleções diferentes', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final estado = RespostasEstudos(prefs, 'a');
    final unica = {
      'id': 'unica',
      'tipo': 'alternativas',
      'unica': true,
      'opcoes': [{}, {}],
    };
    final multipla = {
      'id': 'multipla',
      'tipo': 'alternativas',
      'unica': false,
      'opcoes': [{}, {}],
    };
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPerguntaEstudo(
            pergunta: {
              'respostas': [unica, multipla],
            },
            respostas: estado,
            textoOriginal: 'Escolhas',
            textosOpcoes: const {
              'unica': ['A', 'B'],
              'multipla': ['C', 'D'],
            },
          ),
        ),
      ),
    );
    await t.tap(find.text('A'));
    await t.pump();
    await t.tap(find.text('B'));
    await t.pump();
    await t.tap(find.text('C'));
    await t.pump();
    await t.tap(find.text('D'));
    await t.pump();
    await t.tap(find.text('Salvar resposta'));
    await t.pumpAndSettle();
    expect(estado.escolhas(unica), [1]);
    expect(estado.escolhas(multipla), [0, 1]);
  });
  testWidgets(
    'editor consulta sem perder rascunho, salva e recupera resposta',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final estado = RespostasEstudos(prefs, 'a');
      final pergunta = {
        'id': 'q',
        'respostas': [
          {'id': 'campo', 'tipo': 'texto', 'areas': []},
        ],
      };
      late BuildContext ctx;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: c,
                    barrierDismissible: false,
                    builder: (d) => EditorPerguntaEstudo(
                      pergunta: pergunta,
                      respostas: estado,
                      textoOriginal: 'Quem é o Verbo?',
                      textosOpcoes: const {},
                      consultarVersiculos: () => showDialog<void>(
                        context: d,
                        builder: (v) => AlertDialog(
                          title: const Text('João 1:14'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(v),
                              child: const Text('Voltar à pergunta'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Abrir'),
                ),
              );
            },
          ),
        ),
      );
      await t.tap(find.text('Abrir'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Minha reflexão');
      await t.tap(find.text('Consultar versículos sem sair'));
      await t.pumpAndSettle();
      expect(find.text('João 1:14'), findsOneWidget);
      await t.tap(find.text('Voltar à pergunta'));
      await t.pumpAndSettle();
      expect(find.text('Minha reflexão'), findsOneWidget);
      await t.tap(find.text('Salvar resposta'));
      await t.pumpAndSettle();
      expect(estado.texto({'id': 'campo'}), 'Minha reflexão');
      await t.tap(find.text('Abrir'));
      await t.pumpAndSettle();
      expect(find.text('Minha reflexão'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Atualizada');
      await Navigator.of(ctx).maybePop();
      await t.pumpAndSettle();
      expect(estado.texto({'id': 'campo'}), 'Atualizada');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('leitor retoma página, edita pergunta e conclui lição', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final indice = {
      'licoes': [
        {'numero': 1, 'inicio': 1, 'fim': 2},
      ],
      'paginas': List.generate(
        2,
        (i) => {
          'pagina': i + 1,
          'perguntas': [
            {
              'id': 'q$i',
              'areasTexto': [
                [1, 1, 2, 2],
              ],
              'respostas': [
                {'id': 'r$i', 'tipo': 'texto', 'areas': []},
              ],
            },
          ],
          'referencias': [],
        },
      ),
    };
    await t.pumpWidget(
      MaterialApp(
        home: TelaEstudoInterativo(
          arquivo: File('unused'),
          id: 'teste',
          nome: 'Estudo',
          prefs: prefs,
          carregarIndice: () async => indice,
          lerTexto: (p, a) async => 'Pergunta $p',
          construirLeitor: (_) => const Center(child: Text('PDF original')),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Responder (1)'));
    await t.pumpAndSettle();
    await t.tap(find.text('Pergunta 1'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Resposta 1');
    await t.tap(find.text('Salvar resposta'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Próxima página'));
    await t.pumpAndSettle();
    expect(prefs.getInt('estudo_pdf_pagina_teste'), 2);
    await t.tap(find.byTooltip('Concluir lição'));
    await t.pumpAndSettle();
    expect(RespostasEstudos(prefs, 'teste').concluida(1), true);
    expect(RespostasEstudos(prefs, 'teste').texto({'id': 'r0'}), 'Resposta 1');
    expect(t.takeException(), isNull);
  });
}
