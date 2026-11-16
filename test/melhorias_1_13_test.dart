import 'dart:io' show Platform;

import 'package:biblia_estudo/dados/ajustes.dart';
import 'package:biblia_estudo/dados/leitura_voz.dart';
import 'package:biblia_estudo/dados/lembrete.dart';
import 'package:biblia_estudo/dados/modelos.dart';
import 'package:biblia_estudo/dados/plano.dart';
import 'package:biblia_estudo/dados/versiculo_do_dia.dart';
import 'package:biblia_estudo/dados/temas.dart';
import 'package:biblia_estudo/telas/leitura_avulsa.dart';
import 'package:biblia_estudo/telas/navegacao.dart';
import 'package:biblia_estudo/telas/seletor.dart';
import 'package:biblia_estudo/telas/temas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.instancia.carregar();
  });

  group('histórico de leitura', () {
    test('o mais recente primeiro, sem repetir o capítulo', () {
      final aj = Ajustes.instancia;
      final t = DateTime(2026, 11, 16, 8);
      aj.registrarHistorico(const Posicao(43, 1), t);
      aj.registrarHistorico(
        const Posicao(43, 2),
        t.add(const Duration(minutes: 5)),
      );
      aj.registrarHistorico(
        const Posicao(43, 1),
        t.add(const Duration(minutes: 9)),
      );
      final h = aj.historico;
      expect(h.map((e) => (e.capitulo.livro, e.capitulo.capitulo)), [
        (43, 1),
        (43, 2),
      ]);
      expect(h.first.quando, t.add(const Duration(minutes: 9)));
    });

    test('guarda só os últimos 30 e limpa', () {
      final aj = Ajustes.instancia;
      for (var c = 1; c <= 40; c++) {
        aj.registrarHistorico(Posicao(19, c), DateTime(2026, 1, 1, 0, c));
      }
      expect(aj.historico, hasLength(Ajustes.maxHistorico));
      expect(aj.historico.first.capitulo.capitulo, 40);
      aj.limparHistorico();
      expect(aj.historico, isEmpty);
    });

    test('abrir um capítulo entra no histórico', () {
      Ajustes.instancia.ultimaPosicao = const Posicao(1, 3);
      expect(Ajustes.instancia.historico.first.capitulo.capitulo, 3);
    });

    test('hoje, ontem e data', () {
      final agora = DateTime(2026, 11, 16, 10);
      expect(quandoLido(DateTime(2026, 11, 16, 7, 5), agora), 'Hoje, 07:05');
      expect(quandoLido(DateTime(2026, 11, 15, 21, 40), agora), 'Ontem, 21:40');
      expect(
        quandoLido(DateTime(2026, 11, 2, 8, 3), agora),
        '02/11/2026, 08:03',
      );
    });
  });

  group('me pôr em dia (Reavivados)', () {
    final p = PlanoLeitura.reavivados;

    test('a faixa mostra os atrasados, do mais antigo ao de hoje', () {
      final aj = Ajustes.instancia;
      final hoje = p.diaDe(DateTime.now());
      aj.iniciarPlano(p.id, comecou: hoje - 3);
      // Sem pôr em dia, a faixa é a de hoje.
      expect(aj.leituraHoje()!.dia, hoje);
      expect(aj.leituraHoje()!.atrasada, isFalse);

      aj.porEmDia = true;
      var l = aj.leituraHoje()!;
      expect(l.dia, hoje - 3);
      expect(l.faltam, 3);
      expect(l.rotulo, startsWith('Pondo em dia (faltam 3): '));

      aj.marcarDia(hoje - 3, true);
      aj.marcarDia(hoje - 2, true);
      l = aj.leituraHoje()!;
      expect(l.dia, hoje - 1);
      expect(l.rotulo, startsWith('Pondo em dia (falta 1): '));

      aj.marcarDia(hoje - 1, true);
      // Em dia: o modo desliga sozinho e volta a leitura de hoje.
      expect(aj.porEmDia, isFalse);
      expect(aj.leituraHoje()!.dia, hoje);
      expect(aj.leituraHoje()!.atrasada, isFalse);
    });

    test('começar ou encerrar o plano desliga o pôr em dia', () {
      final aj = Ajustes.instancia;
      aj.iniciarPlano(p.id, comecou: p.diaDe(DateTime.now()) - 2);
      aj.porEmDia = true;
      aj.encerrarPlano();
      expect(aj.porEmDia, isFalse);
    });
  });

  group('ouvir o capítulo', () {
    test('o próximo capítulo atravessa os livros e para em Apocalipse 22', () {
      expect(proximoCapitulo(43, 3), const Posicao(43, 4));
      expect(proximoCapitulo(1, 50), const Posicao(2, 1));
      expect(proximoCapitulo(66, 22), isNull);
    });

    test('velocidade 1 é a fala normal do plugin (0,5)', () {
      // O plugin trata 0,5 como a fala normal: no Android ele dobra o
      // valor; no Windows soma 0,5. Os testes rodam no Linux (conta do
      // Android) e no PC do publicar.ps1 (conta do Windows).
      if (Platform.isWindows) {
        expect(taxaDaVelocidade(1), 0.5);
        expect(taxaDaVelocidade(2), 1.5);
        expect(taxaDaVelocidade(0.75), 0.25);
        expect(taxaDaVelocidade(9), 1.5);
      } else {
        expect(taxaDaVelocidade(1), 0.5);
        expect(taxaDaVelocidade(2), 1.0);
        expect(taxaDaVelocidade(0.75), 0.375);
        expect(taxaDaVelocidade(9), 1.0);
      }
    });

    test('a velocidade e o seguir em frente ficam nos ajustes', () {
      final aj = Ajustes.instancia;
      expect(aj.velocidadeVoz, 1.0);
      expect(aj.vozContinua, isTrue);
      aj.velocidadeVoz = 5;
      expect(aj.velocidadeVoz, 2.0);
    });
  });

  test('aparência do texto: padrões e limites', () {
    final aj = Ajustes.instancia;
    expect(aj.espacoLinhas, Ajustes.espacoLinhasPadrao);
    expect(aj.letraSerifa, isFalse);
    expect(aj.papelSepia, isFalse);
    expect(aj.poucaLuz, isFalse);
    aj.espacoLinhas = 9;
    expect(aj.espacoLinhas, Ajustes.maxEspacoLinhas);
  });

  group('aviso do versículo do dia', () {
    const r = ReferenciaDoDia(
      dia: 1,
      livro: 23,
      capitulo: 43,
      versiculo: 18,
      ate: 19,
    );

    test('título com a referência e o texto sem marcação', () {
      final a = textoAvisoVersiculo(r, [
        (17, 'Antes.'),
        (18, 'Não vos lembreis <i>das coisas passadas</i>,'),
        (19, 'Eis que faço  coisa nova.'),
        (20, 'Depois.'),
      ])!;
      expect(a.titulo, 'Versículo do dia · Isaías 43:18-19');
      expect(
        a.corpo,
        'Não vos lembreis das coisas passadas, Eis que faço coisa nova.',
      );
    });

    test('sem os versículos no capítulo, não há aviso', () {
      expect(textoAvisoVersiculo(r, [(1, 'x')]), isNull);
    });
  });

  testWidgets('o seletor mostra os recentes e abre o histórico', (t) async {
    final aj = Ajustes.instancia;
    aj.registrarHistorico(const Posicao(19, 23), DateTime(2026, 11, 15, 21));
    aj.registrarHistorico(const Posicao(43, 3), DateTime.now());
    Posicao? escolhido;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => escolhido = await Navigator.push<Posicao>(
              c,
              MaterialPageRoute(
                builder: (_) => const TelaSeletor(atual: Posicao(43, 3)),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    // O capítulo atual não aparece nos recentes.
    expect(find.widgetWithText(ActionChip, 'Salmos 23'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'João 3'), findsNothing);

    await t.tap(find.byTooltip('Histórico de leitura'));
    await t.pumpAndSettle();
    expect(find.text('Histórico de leitura'), findsOneWidget);
    expect(find.textContaining('Hoje, '), findsOneWidget);
    await t.tap(find.text('Salmos 23'));
    await t.pumpAndSettle();
    expect(escolhido, const Posicao(19, 23));
  });

  group('respostas pessoais dos estudos bíblicos', () {
    test('gravam, apagam quando vazias e vão na cópia', () {
      final aj = Ajustes.instancia;
      aj.definirRespostaEstudo('biblia', 1, 'Deus inspirou.');
      expect(aj.respostaEstudo('biblia', 1), 'Deus inspirou.');
      expect(aj.respostaEstudo('biblia', 2), '');
      expect(aj.exportar()['respostasEstudos'], {'biblia:1': 'Deus inspirou.'});
      aj.definirRespostaEstudo('biblia', 1, '   ');
      expect(aj.respostasEstudos, isEmpty);
    });

    test('restaurar junta sem apagar', () {
      final aj = Ajustes.instancia;
      aj.definirRespostaEstudo('biblia', 1, 'Minha.');
      aj.importar({
        'app': 'br.com.wisejr.bibliaestudo',
        'respostasEstudos': {
          'biblia:1': 'Da cópia.',
          'biblia:2': 'Nova.',
          'biblia:x': 'inválida',
        },
      });
      expect(aj.respostaEstudo('biblia', 1), 'Minha.\n\nDa cópia.');
      expect(aj.respostaEstudo('biblia', 2), 'Nova.');
      // A mesma cópia de novo não repete o texto.
      aj.importar({
        'app': 'br.com.wisejr.bibliaestudo',
        'respostasEstudos': {'biblia:1': 'Da cópia.'},
      });
      expect(aj.respostaEstudo('biblia', 1), 'Minha.\n\nDa cópia.');
    });
  });

  testWidgets('o campo da resposta grava e volta preenchido', (t) async {
    Widget campo() => const MaterialApp(
      home: Scaffold(body: SuaResposta(estudo: 'biblia', pergunta: 3)),
    );
    await t.pumpWidget(campo());
    await t.enterText(find.byType(TextField), 'Jesus, o Filho.');
    expect(Ajustes.instancia.respostaEstudo('biblia', 3), 'Jesus, o Filho.');
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(campo());
    expect(find.text('Jesus, o Filho.'), findsOneWidget);
  });

  testWidgets(
    'no estudo, o botão da Bíblia abre o capítulo e volta ao estudo',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => TextButton(
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(
                  builder: (_) => const Scaffold(
                    body: CartaoPassagem(
                      passagem: Passagem(55, 3016, 3017),
                      versao: Versao(1, 'ARA', 'Almeida'),
                      oculto: true,
                      noEstudo: true,
                    ),
                  ),
                ),
              ),
              child: const Text('abrir estudo'),
            ),
          ),
        ),
      );
      await t.tap(find.text('abrir estudo'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Abrir na Bíblia (volta ao estudo depois)'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(TelaLeituraAvulsa), findsOneWidget);
      expect(destinoLeitura.value, isNull);
      await t.tap(find.text('Voltar ao estudo'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(TelaLeituraAvulsa), findsNothing);
      expect(find.byType(CartaoPassagem), findsOneWidget);
      // A referência abre só a janela dos versículos, sem sair do estudo.
      await t.tap(find.textContaining('Timóteo'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(CartaoPassagem), findsOneWidget);
      expect(destinoLeitura.value, isNull);
    },
  );
}
