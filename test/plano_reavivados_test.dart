import 'package:biblia_estudo/dados/ajustes.dart';
import 'package:biblia_estudo/dados/modelos.dart';
import 'package:biblia_estudo/dados/plano.dart';
import 'package:biblia_estudo/telas/plano.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final p = PlanoLeitura.reavivados;

  String capitulo(DateTime data) =>
      descreverLeitura(p.leituraDoDia(p.diaDe(data)));

  group('Reavivados por Sua Palavra segue o calendário da igreja', () {
    // Conferido nos posts do site reavivadosporsuapalavra.org.
    test('as datas conferidas no site', () {
      expect(capitulo(DateTime(2025, 4, 17)), 'Gênesis 1');
      expect(capitulo(DateTime(2025, 12, 25)), '1 Samuel 17');
      expect(capitulo(DateTime(2026, 1, 1)), '1 Samuel 24');
      expect(capitulo(DateTime(2026, 10, 3)), 'Salmo 57');
    });

    test('a hora do dia não muda o capítulo', () {
      expect(capitulo(DateTime(2026, 10, 3, 0, 1)), 'Salmo 57');
      expect(capitulo(DateTime(2026, 10, 3, 23, 59)), 'Salmo 57');
    });

    test('o ciclo anterior terminou na véspera, e o atual em 18/07/2028', () {
      expect(capitulo(DateTime(2025, 4, 16)), 'Apocalipse 22');
      expect(capitulo(DateTime(2028, 7, 18)), 'Apocalipse 22');
      expect(capitulo(DateTime(2028, 7, 19)), 'Gênesis 1');
    });

    test('um capítulo por dia, a Bíblia toda', () {
      expect(p.leituras, hasLength(1189));
      expect(p.leituras.every((d) => d.length == 1), isTrue);
    });

    test('dataDe é o inverso de diaDe', () {
      final d = p.diaDe(DateTime(2026, 10, 3));
      expect(p.dataDe(d), DateTime.utc(2026, 10, 3));
      expect(p.inicioDoCiclo(d), 0);
      expect(p.inicioDoCiclo(1189 + 5), 1189);
    });
  });

  group('progresso por data', () {
    test('atrasados contam só desde que a pessoa começou', () {
      final hoje = p.diaDe(DateTime(2026, 10, 3));
      expect(diasAtrasados(p, {}, hoje, comecou: hoje), isEmpty);
      expect(diasAtrasados(p, {hoje - 2}, hoje, comecou: hoje - 3), [
        hoje - 3,
        hoje - 1,
      ]);
      // Sem começo registrado: o ciclo todo até ontem.
      expect(diasAtrasados(p, {}, 3), [0, 1, 2]);
    });

    test('dias seguidos terminam hoje ou ontem', () {
      expect(diasSeguidos({8, 9, 10}, 10), 3);
      expect(diasSeguidos({8, 9}, 10), 2);
      expect(diasSeguidos({7, 9}, 10), 1);
      expect(diasSeguidos({}, 10), 0);
    });
  });

  group('leitura de hoje e cópia de segurança', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Ajustes.instancia.carregar();
    });

    test('a faixa mostra o capítulo do dia até ele ser lido', () {
      final aj = Ajustes.instancia;
      final dia = DateTime(2026, 10, 3, 9);
      final hoje = p.diaDe(dia);
      aj.iniciarPlano('reavivados', comecou: hoje);
      final l = aj.leituraHoje(dia)!;
      expect(l.capitulos, const [Posicao(19, 57)]);
      expect(l.rotulo, 'Reavivados por Sua Palavra: Salmo 57');
      aj.marcarDia(hoje, true);
      expect(aj.leituraHoje(dia), isNull);
      expect(aj.leituraHoje(DateTime(2026, 10, 4))!.descricao, 'Salmo 58');
    });

    test('quem já lia marca o ciclo até ontem de uma vez', () {
      final aj = Ajustes.instancia;
      final hoje = p.diaDe(DateTime(2026, 10, 3));
      aj.iniciarPlano(
        'reavivados',
        comecou: 0,
        lidosAntes: [for (var d = 0; d < hoje; d++) d],
      );
      expect(aj.diasLidos, hasLength(hoje));
      expect(diasAtrasados(p, aj.diasLidos, hoje, comecou: 0), isEmpty);
    });

    test('o plano por data vai e volta na cópia, com o começo', () async {
      final aj = Ajustes.instancia;
      aj.iniciarPlano('reavivados', comecou: 500);
      aj.marcarDias([500, 501, 534], true);
      final copia = aj.exportar();

      SharedPreferences.setMockInitialValues({});
      await aj.carregar();
      aj.iniciarPlano('reavivados', comecou: 530);
      aj.marcarDia(533, true);
      aj.importar(copia);

      expect(aj.plano, 'reavivados');
      expect(aj.diasLidos, {500, 501, 533, 534});
      expect(aj.planoComecou, 500); // vale o começo mais antigo
    });

    test(
      'plano sem data: depois de ler a porção, a próxima fica para amanhã',
      () {
        final aj = Ajustes.instancia;
        aj.iniciarPlano('proverbios-31-dias');
        expect(aj.leituraHoje()!.rotulo, 'Dia 1: Provérbios 1');
        aj.marcarDia(0, true);
        expect(aj.leituraHoje(), isNull);
        expect(
          aj.leituraHoje(DateTime.now().add(const Duration(days: 1)))!.rotulo,
          'Dia 2: Provérbios 2',
        );
      },
    );
  });

  group('tela do plano', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Ajustes.instancia.carregar();
    });

    Future<void> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: TelaPlano()));
      await tester.pumpAndSettle();
    }

    testWidgets('a escolha mostra o Reavivados com o capítulo de hoje', (
      tester,
    ) async {
      await abrir(tester);
      expect(find.text('Reavivados por Sua Palavra'), findsOneWidget);
      final hoje = descreverLeitura(p.leituraDoDia(p.diaDe(DateTime.now())));
      expect(find.textContaining('Hoje: $hoje'), findsOneWidget);
    });

    testWidgets('com o plano em andamento: hoje, atrasados e calendário', (
      tester,
    ) async {
      final hoje = p.diaDe(DateTime.now());
      Ajustes.instancia.iniciarPlano('reavivados', comecou: hoje - 5);
      Ajustes.instancia.marcarDias([hoje - 5, hoje - 4], true);
      await abrir(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Comentário do dia'), findsOneWidget);
      expect(find.text('3 capítulos ficaram para trás'), findsOneWidget);
      await tester.tap(find.text('Marcar como lido'));
      await tester.pumpAndSettle();
      expect(Ajustes.instancia.diasLidos, contains(hoje));
      expect(find.text('Lido'), findsOneWidget);
      await tester.tap(find.byTooltip('Próximo mês'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
