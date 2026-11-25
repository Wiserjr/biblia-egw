import 'package:biblia_estudo/dados/ajustes.dart';
import 'package:biblia_estudo/dados/caminhada.dart';
import 'package:biblia_estudo/dados/guia_biblioteca.dart';
import 'package:biblia_estudo/dados/lembrete.dart';
import 'package:biblia_estudo/dados/meditacao.dart';
import 'package:biblia_estudo/dados/modelos.dart';
import 'package:biblia_estudo/dados/oracao.dart';
import 'package:biblia_estudo/dados/plano.dart';
import 'package:biblia_estudo/telas/caminhada.dart';
import 'package:biblia_estudo/telas/hoje.dart';
import 'package:biblia_estudo/telas/oracao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.instancia.carregar();
    Ajustes.instancia.aoMudarItens = null;
    Ajustes.instancia.aoGanharMedalhas = null;
  });

  group('sequência de dias', () {
    final hoje = DateTime(2026, 11, 25, 9);

    test('conta os dias seguidos até hoje', () {
      expect(
        sequenciaAtual({'2026-11-23', '2026-11-24', '2026-11-25'}, hoje),
        3,
      );
    });

    test('quem ainda não leu hoje não perde a sequência', () {
      expect(sequenciaAtual({'2026-11-23', '2026-11-24'}, hoje), 2);
      expect(sequenciaAtual({'2026-11-22', '2026-11-23'}, hoje), 0);
      expect(sequenciaAtual({}, hoje), 0);
    });

    test('atravessa a virada do mês e do ano', () {
      expect(
        sequenciaAtual({
          '2026-12-30',
          '2026-12-31',
          '2027-01-01',
        }, DateTime(2027, 1, 1)),
        3,
      );
    });

    test('a melhor sequência', () {
      expect(
        melhorSequencia({
          '2026-01-01',
          '2026-01-02',
          '2026-01-03',
          '2026-01-05',
          '2026-02-28',
          '2026-03-01',
          'lixo',
        }),
        3,
      );
      expect(melhorSequencia({}), 0);
    });
  });

  group('medalhas', () {
    test('livro completo, evangelhos e sequências', () {
      final caps = {
        for (final l in [40, 41, 42, 43])
          for (var c = 1; c <= [28, 16, 24, 21][l - 40]; c++) '$l:$c',
        '1:1',
        '99:1',
        '43:99',
      };
      expect(livrosCompletos(caps), {40, 41, 42, 43});
      final c = Caminhada(
        dias: {for (var d = 1; d <= 7; d++) '2026-11-0$d'},
        capitulos: caps,
      );
      final g = c.ganhas();
      expect(g, containsAll(['primeiro-dia', 'seguidos-3', 'seguidos-7']));
      expect(g, containsAll(['livro-40', 'livro-43', 'evangelhos']));
      expect(g, isNot(contains('seguidos-30')));
      expect(g, isNot(contains('livro-1')));
      expect(g, isNot(contains('nt')));
      expect(g, isNot(contains('oracao-respondida')));
    });

    test('medalhasNovas na ordem da lista', () {
      final novas = medalhasNovas(
        {'primeiro-dia'},
        {'primeiro-dia', 'livro-57', 'seguidos-3'},
      );
      expect(novas.map((m) => m.id), ['seguidos-3', 'livro-57']);
      expect(novas.last.titulo, 'Filemom');
    });
  });

  group('registrar leitura', () {
    test('grava o dia e os capítulos, e avisa a nuvem e as medalhas', () {
      final aj = Ajustes.instancia;
      final itens = <String>{};
      final medalhas = <String>[];
      aj.aoMudarItens = itens.addAll;
      aj.aoGanharMedalhas = (m) => medalhas.addAll(m.map((x) => x.id));
      aj.registrarLeitura(
        capitulos: const [Posicao(57, 1), Posicao(1, 999)],
        agora: DateTime(2026, 11, 25),
      );
      expect(aj.diasDeLeitura, {'2026-11-25'});
      expect(aj.capitulosLidos, {'57:1'});
      expect(itens, {Ajustes.chaveDias, Ajustes.chaveCapitulos});
      expect(medalhas, ['primeiro-dia', 'livro-57']);

      itens.clear();
      medalhas.clear();
      aj.registrarLeitura(
        capitulos: const [Posicao(57, 1)],
        agora: DateTime(2026, 11, 25, 20),
      );
      expect(itens, isEmpty, reason: 'nada mudou');
      expect(medalhas, isEmpty);
    });

    test('marcar o dia do plano conta os capítulos dele', () {
      final aj = Ajustes.instancia;
      aj.iniciarPlano('evangelhos-30-dias');
      aj.marcarDia(0, true);
      final pl = PlanoLeitura.porId('evangelhos-30-dias')!;
      expect(aj.capitulosLidos, {
        for (final p in pl.leituraDoDia(0)) '${p.livro}:${p.capitulo}',
      });
      expect(aj.leuNoDia(DateTime.now()), isTrue);
    });
  });

  group('lista de oração', () {
    Oracao pedido(int id, String texto, {int? atualizado}) =>
        Oracao(id: id, texto: texto, atualizado: atualizado ?? id);

    test('salvar, responder, apagar', () {
      final aj = Ajustes.instancia;
      final medalhas = <String>[];
      aj.aoGanharMedalhas = (m) => medalhas.addAll(m.map((x) => x.id));
      aj.salvarOracao(pedido(1000, 'Saúde da minha mãe'));
      aj.salvarOracao(pedido(2000, 'Trabalho novo'));
      expect(aj.oracoes.map((o) => o.texto), [
        'Trabalho novo',
        'Saúde da minha mãe',
      ]);
      final o = aj.oracoes.last;
      aj.salvarOracao(o.copiar(respondidaEm: 5000, resposta: 'Sarou!'));
      expect(aj.oracoes.last.respondida, isTrue);
      expect(aj.oracoes.last.resposta, 'Sarou!');
      expect(medalhas, ['oracao-respondida']);
      expect(aj.oracoes.last.copiar(semResposta: true).respondida, isFalse);
      aj.apagarOracao(aj.oracoes.first);
      expect(aj.oracoes.map((o) => o.id), [1000]);
    });

    test('vai na cópia; a versão mais recente fica', () {
      final aj = Ajustes.instancia;
      aj.salvarOracao(pedido(1000, 'Antigo', atualizado: 10));
      aj.salvarOracao(pedido(3000, 'Fica', atualizado: 99));
      aj.registrarLeitura(
        capitulos: const [Posicao(43, 3)],
        agora: DateTime(2026, 11, 24),
      );
      final copia = aj.exportar();
      expect((copia['oracoes'] as Map).keys, containsAll(['1000', '3000']));
      expect(copia['diasLeitura'], ['2026-11-24']);
      expect(copia['capitulosLidos'], ['43:3']);

      aj.importar({
        'app': 'br.com.wisejr.bibliaestudo',
        'oracoes': {
          '1000': {'texto': 'Mudado no outro aparelho', 'atualizado': 50},
          '3000': {'texto': 'Velho', 'atualizado': 1},
          '4000': {'texto': 'Novo', 'atualizado': 4000},
          '5000': {'texto': '', 'atualizado': 1},
        },
        'diasLeitura': ['2026-11-20', 'lixo'],
        'capitulosLidos': ['1:1', '1:51'],
      });
      expect(
        {for (final o in aj.oracoes) o.id: o.texto},
        {1000: 'Mudado no outro aparelho', 3000: 'Fica', 4000: 'Novo'},
      );
      expect(aj.diasDeLeitura, {'2026-11-20', '2026-11-24'});
      expect(aj.capitulosLidos, {'1:1', '43:3'});
    });

    test('nuvem: itens, aplicar e juntar', () {
      final aj = Ajustes.instancia;
      aj.salvarOracao(pedido(1000, 'Aqui'));
      aj.registrarLeitura(agora: DateTime(2026, 11, 24));
      final itens = aj.itens();
      expect(itens['o_1000'], isA<Map>());
      expect(itens[Ajustes.chaveDias], ['2026-11-24']);

      // Os dias se somam; o pedido vem como está; null apaga.
      aj.aplicarItens({
        Ajustes.chaveDias: ['2026-11-01'],
        Ajustes.chaveCapitulos: ['19:23'],
        'o_2000': {'texto': 'De lá', 'atualizado': 2000},
        'o_1000': null,
      });
      expect(aj.diasDeLeitura, {'2026-11-01', '2026-11-24'});
      expect(aj.capitulosLidos, {'19:23'});
      expect(aj.oracoes.map((o) => o.texto), ['De lá']);

      aj.juntar({
        'o_3000': {'texto': 'Juntado', 'atualizado': 3000},
        Ajustes.chaveDias: ['2026-10-10'],
      });
      expect(aj.oracoes.map((o) => o.texto), ['Juntado', 'De lá']);
      expect(aj.diasDeLeitura, contains('2026-10-10'));
    });

    test('texto do lembrete', () {
      expect(textoAvisoOracao([]), contains('lista de oração'));
      expect(textoAvisoOracao(['A', 'B']), 'Seus pedidos: A; B.');
      expect(
        textoAvisoOracao(['A', 'B', 'C', 'D', 'E']),
        'Seus pedidos: A; B; C e mais 2.',
      );
    });
  });

  group('meditação do dia', () {
    test('data e título', () {
      expect(dataDoTitulo('Luz para meu caminho, 1 de Janeiro'), (
        dia: 1,
        mes: 1,
      ));
      expect(dataDoTitulo('Por que foi permitido? 30 de Dezembro'), (
        dia: 30,
        mes: 12,
      ));
      expect(dataDoTitulo('Capítulo 1 — O amor de Deus'), isNull);
      expect(tituloSemData('“Deus é amor”, 1 de Janeiro'), '“Deus é amor”');
      expect(
        tituloSemData('Vitoriosos, afinal! 31 de Dezembro'),
        'Vitoriosos, afinal!',
      );
    });

    test('acha o dia, com título trocado e dia que falta', () {
      const meses = [
        'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', //
        'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
      ];
      // Um ano de 2027 (365 meditações), como os livros de verdade. Como em
      // "E Recebereis Poder", o 2 de janeiro diz "2 de Fevereiro"; o 3 de
      // fevereiro está sem data.
      final caps = <CapituloObra>[];
      for (var i = 0; i < 365; i++) {
        final d = DateTime(2027, 1, 1 + i);
        var titulo = 'Meditação $i, ${d.day} de ${meses[d.month - 1]}';
        if (i == 1) titulo = 'O Consolador, 2 de Fevereiro';
        if (d.month == 2 && d.day == 3) titulo = 'Sem data';
        caps.add(CapituloObra(i + 1, 78, titulo, 19 + 2 * i));
      }
      int? id(int mes, int dia) =>
          meditacaoDoDia(caps, DateTime(2027, mes, dia))?.id;
      expect(id(1, 3), 3);
      expect(id(2, 2), 33, reason: 'o de fevereiro, não o título trocado');
      expect(id(1, 2), 2, reason: 'o seguinte ao de 1 de janeiro');
      expect(id(2, 3), 34, reason: 'o seguinte ao de 2 de fevereiro');
      expect(id(12, 31), 365);
      // 29 de fevereiro num livro de 365 dias: o seguinte ao de 28.
      expect(meditacaoDoDia(caps, DateTime(2028, 2, 29))?.id, 60);
      expect(meditacaoDoDia([], DateTime(2027, 2, 3)), isNull);
    });
  });

  testWidgets('a lista de oração cria um pedido e marca como respondido', (
    t,
  ) async {
    await t.pumpWidget(const MaterialApp(home: TelaOracao()));
    expect(find.text('Pedidos (0)'), findsOneWidget);
    await t.tap(find.text('Novo pedido'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Pela minha família');
    await t.tap(find.text('Salvar'));
    await t.pumpAndSettle();
    expect(find.text('Pela minha família'), findsOneWidget);
    expect(find.text('Pedidos (1)'), findsOneWidget);

    await t.tap(find.byTooltip('Mais opções'));
    await t.pumpAndSettle();
    await t.tap(find.text('Deus respondeu'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Todos com saúde');
    await t.tap(find.text('Marcar como respondida'));
    await t.pumpAndSettle();
    expect(find.text('Pedidos (0)'), findsOneWidget);
    expect(find.text('Respondidas (1)'), findsOneWidget);
    expect(Ajustes.instancia.oracoes.single.resposta, 'Todos com saúde');
  });

  testWidgets('sua caminhada mostra a sequência e as medalhas', (t) async {
    final hoje = DateTime.now();
    for (var d = 0; d < 3; d++) {
      Ajustes.instancia.registrarLeitura(
        capitulos: [const Posicao(65, 1)],
        agora: hoje.subtract(Duration(days: d)),
      );
    }
    await t.pumpWidget(const MaterialApp(home: TelaCaminhada()));
    await t.pumpAndSettle();
    expect(find.text('dias seguidos'), findsOneWidget);
    await t.scrollUntilVisible(find.text('3 dias seguidos'), 200);
    expect(find.text('Primeiro passo'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Judas'), 200);
    expect(find.text('1/1'), findsWidgets);
  });

  testWidgets('hoje: escolher o livro de meditações e ver a de hoje', (
    t,
  ) async {
    final hoje = DateTime.now();
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', //
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    const obra = Obra(
      id: 83,
      arquivo: 'mar.pdf',
      sigla: 'Mar',
      titulo: 'Maranata — O Senhor Vem!',
      autor: 'Ellen G. White',
      grupo: 'egw',
      prioridade: 1,
      url: '',
      bytes: 1,
      sha256: '',
      paginas: 800,
    );
    Future<(Map<int, Obra>, List<CapituloObra>)> dados() async => (
      {83: obra},
      [
        CapituloObra(
          1,
          83,
          'A meditação de hoje, ${hoje.day} de ${meses[hoje.month - 1]}',
          300,
        ),
      ],
    );
    Ajustes.instancia.salvarOracao(
      const Oracao(id: 1, texto: 'Pelos vizinhos', atualizado: 1),
    );
    await t.pumpWidget(
      MaterialApp(
        home: TelaHoje(
          versao: const Versao(1, 'ARA', 'Almeida'),
          carregarMeditacao: dados,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('0 de 4 feitos hoje'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Escolher o livro'), 200);
    await t.tap(find.text('Escolher o livro'));
    await t.pumpAndSettle();
    await t.tap(find.text('Maranata — O Senhor Vem!'));
    await t.pumpAndSettle();
    expect(Ajustes.instancia.meditacaoObra, 83);
    expect(find.text('A meditação de hoje'), findsOneWidget);

    await t.scrollUntilVisible(find.text('Marcar: orei hoje'), 200);
    expect(find.text('• Pelos vizinhos'), findsOneWidget);
    await t.tap(find.text('Marcar: orei hoje'));
    await t.pumpAndSettle();
    expect(Ajustes.instancia.oreiHoje, isTrue);
    await t.scrollUntilVisible(find.text('1 de 4 feitos hoje'), -200);
    expect(find.text('1 de 4 feitos hoje'), findsOneWidget);
  });
}
