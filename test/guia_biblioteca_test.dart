import 'dart:convert';
import 'dart:io';

import 'package:biblia_estudo/dados/ajustes.dart';
import 'package:biblia_estudo/dados/guia_biblioteca.dart';
import 'package:biblia_estudo/dados/modelos.dart';
import 'package:biblia_estudo/telas/guia_biblioteca.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const caps = [
  CapituloObra(1, 1, 'Capítulo 1 — A criação', 10),
  CapituloObra(2, 1, 'Capítulo 2 — A promessa', 20),
  CapituloObra(3, 2, 'Capítulo 1 — Um chamado', 5),
  CapituloObra(0, 3, 'Leitura integral — sem sumário de capítulos indexado', 0),
];

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.instancia.carregar();
  });

  test('conclusões, plano e lugar persistem ao reiniciar', () async {
    final guia = GuiaBiblioteca.instancia;
    await guia.marcar(caps[0], true);
    await guia.marcar(caps[3], true);
    await guia.iniciarPlano([2, 1, 3], 2);
    await guia.guardarLugar(
      1,
      const LugarObra(12, 0.73, 'edicao-a', 100, zoom: 2, horizontal: 0.4),
    );
    await guia.carregar();
    expect(guia.concluido(caps[0]), isTrue);
    expect(guia.concluido(caps[3]), isTrue);
    expect(guia.pendentes(caps).map((c) => c.id), [3, 2]);
    expect(guia.meta, 2);
    expect(guia.lugar(1)!.fracao, 0.73);
    expect(guia.lugar(1)!.zoom, 2);
    await guia.marcar(caps[0], false);
    expect(guia.pendentes(caps).map((c) => c.id), [3, 1, 2]);
    await guia.encerrarPlano();
    expect(guia.concluido(caps[3]), isTrue);
    expect(guia.lugar(1), isNotNull);
  });

  test(
    'backup transfere o guia sem substituir progresso mais recente',
    () async {
      final guia = GuiaBiblioteca.instancia;
      await guia.iniciarPlano([1], 2);
      await guia.marcar(caps[0], true);
      await guia.guardarLugar(1, const LugarObra(8, 0.6, 'a', 100));
      final copia = jsonDecode(jsonEncode(Ajustes.instancia.exportar()));
      SharedPreferences.setMockInitialValues({});
      await Ajustes.instancia.carregar();
      await guia.marcar(caps[2], true);
      await guia.guardarLugar(1, const LugarObra(10, 0.8, 'a', 200));
      Ajustes.instancia.importar(copia);
      Ajustes.instancia.importar(copia);
      expect(guia.concluido(caps[0]), isTrue);
      expect(guia.concluido(caps[2]), isTrue);
      expect(guia.lugar(1)!.pagina, 10);
      expect(guia.plano, [1]);
      await guia.carregar();
      expect(guia.concluido(caps[0]), isTrue);
      expect(guia.lugar(1)!.pagina, 10);
    },
  );

  test('restaurar outro plano não substitui um em andamento', () async {
    final guia = GuiaBiblioteca.instancia;
    await guia.iniciarPlano([2], 3);
    guia.importar({
      'plano': [1],
      'meta': 1,
      'concluidos': ['1:1'],
    });
    expect(guia.plano, [2]);
    expect(guia.meta, 3);
    expect(guia.concluido(caps[0]), isTrue);
  });

  test('dados inválidos e lugares fora da página são ignorados', () async {
    final guia = GuiaBiblioteca.instancia;
    guia.importar({
      'concluidos': ['-1:2', 'x', true],
      'plano': [0, -1, '1'],
      'lugares': {
        '1': {'pagina': -1, 'fracao': 0.4, 'edicao': 'a', 'atualizadoEm': 0},
      },
    });
    expect(guia.plano, isEmpty);
    expect(guia.lugar(1), isNull);
    expect(
      LugarObra.deMapa({
        'pagina': 0,
        'fracao': double.nan,
        'edicao': 'a',
        'atualizadoEm': 0,
      }),
      isNull,
    );
    expect(
      LugarObra.deMapa({
        'pagina': 0,
        'fracao': 1.1,
        'edicao': 'a',
        'atualizadoEm': 0,
      }),
      isNull,
    );
  });

  test(
    'complementos citam fontes para os 39 livros do AT e preservam o NT',
    () {
      final dados = jsonDecode(
        File('assets/introducoes_andrews.json').readAsStringSync(),
      ) as Map;
      expect(dados.keys.toSet(), {for (var n = 1; n <= 39; n++) '$n'});
      for (final item in dados.values) {
        expect(item['contexto'], isNotEmpty);
        expect(item['forma_literaria'], isNotEmpty);
        expect(item['para_refletir'], isNotEmpty);
        expect(item['fontes'], contains('Andrews Bible Commentary'));
        expect(item['fontes'], contains('PDF:'));
      }
      expect(dados['23']['fontes'], contains('Andrews Study Bible'));
      for (final livro in [
        '1',
        '3',
        '4',
        '5',
        '6',
        '7',
        '9',
        '10',
        '11',
        '12',
      ]) {
        expect(dados[livro]['fontes'], contains('Bíblia de Estudo Andrews'));
        expect(dados[livro]['esboco'], contains('\n'));
      }
    },
  );

  testWidgets('leitor marca capítulo e cria plano por livro na tela', (
    tester,
  ) async {
    const obra = Obra(
      id: 1,
      arquivo: 'teste',
      sigla: 'PP',
      titulo: 'Patriarcas e Profetas',
      autor: 'Ellen G. White',
      grupo: 'egw',
      prioridade: 1,
      url: '',
      bytes: 1,
      sha256: 'a',
      paginas: 50,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TelaGuiaBiblioteca(
          obra: obra,
          carregarDados: () async =>
              ({1: obra}, caps.where((c) => c.obra == 1).toList()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(GuiaBiblioteca.instancia.concluido(caps[0]), isTrue);
    await tester.tap(find.text('Criar plano de leitura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar plano'));
    await tester.pumpAndSettle();
    expect(GuiaBiblioteca.instancia.plano, [1]);
    expect(find.text('Próxima sessão'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
