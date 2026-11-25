import 'package:biblia_estudo/dados/ajustes.dart';
import 'package:biblia_estudo/dados/memorizar.dart';
import 'package:biblia_estudo/dados/modelos.dart';
import 'package:biblia_estudo/dados/referencias.dart';
import 'package:biblia_estudo/telas/cartao_versiculo.dart';
import 'package:biblia_estudo/telas/memorizar.dart';
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

  group('etiquetas', () {
    test('limpa, junta sem repetir e renomeia', () {
      final aj = Ajustes.instancia;
      final itens = <String>{};
      aj.aoMudarItens = itens.addAll;
      aj.definirEtiquetas(43, 3, 16, [
        ' promessas ',
        'Família',
        'PROMESSAS',
        '',
      ]);
      expect(aj.etiquetas(43, 3, 16), ['Família', 'promessas']);
      expect(itens, {'e_43_3_16'});
      aj.definirEtiquetas(19, 23, 1, ['Promessas']);
      expect(aj.nomesEtiquetas, ['Família', 'Promessas']);
      expect(aj.todasEtiquetas().map((e) => e.$1), [(19, 23, 1), (43, 3, 16)]);

      aj.renomearEtiqueta('promessas', 'Promessas de Deus');
      expect(aj.etiquetas(43, 3, 16), ['Família', 'Promessas de Deus']);
      expect(aj.etiquetas(19, 23, 1), ['Promessas de Deus']);
      aj.renomearEtiqueta('Promessas de Deus', '');
      expect(aj.etiquetas(19, 23, 1), isEmpty);
      expect(aj.nomesEtiquetas, ['Família']);
    });

    test('cópia e nuvem', () {
      final aj = Ajustes.instancia;
      aj.definirEtiquetas(43, 3, 16, ['Amor']);
      expect(aj.exportar()['etiquetas'], {
        '43:3:16': ['Amor'],
      });
      expect(aj.itens()['e_43_3_16'], ['Amor']);
      aj.importar({
        'app': 'br.com.wisejr.bibliaestudo',
        'etiquetas': {
          '43:3:16': ['Salvação'],
          '1:1:1': ['Criação'],
        },
      });
      expect(aj.etiquetas(43, 3, 16), ['Amor', 'Salvação']);
      expect(aj.etiquetas(1, 1, 1), ['Criação']);
      aj.aplicarItens({
        'e_1_1_1': null,
        'e_43_3_16': ['Graça'],
      });
      expect(aj.etiquetas(1, 1, 1), isEmpty);
      expect(aj.etiquetas(43, 3, 16), ['Graça']);
    });
  });

  group('memorizar', () {
    Memorizacao m({int atualizado = 1, int praticas = 0}) => Memorizacao(
      livro: 19,
      capitulo: 119,
      versiculo: 11,
      ate: 11,
      criada: 1,
      atualizado: atualizado,
      praticas: praticas,
    );

    test('níveis da prática', () {
      const t = 'Guardo no coração as tuas palavras, para não pecar.';
      expect(textoDoNivel(t, 0), t);
      expect(textoDoNivel(t, 1), 'Guardo no ____ as tuas ____, para não ____.');
      expect(
        textoDoNivel(t, 2),
        'G····· n· c······ a· t··· p·······, p··· n·· p····.',
      );
      expect(textoDoNivel(t, 3), '');
    });

    test('a referência com intervalo', () {
      final p = interpretarPassagem('João 3:16-17')!;
      expect(
        (p.inicio.livro, p.inicio.capitulo, p.inicio.versiculo, p.ate),
        (43, 3, 16, 17),
      );
      expect(interpretarPassagem('Sl 119:11')!.ate, 11);
      expect(interpretarPassagem('João 3:17-16'), isNull);
      expect(interpretarPassagem('nada'), isNull);
    });

    test('salva, junta pela mais recente e vai para a nuvem', () {
      final aj = Ajustes.instancia;
      aj.salvarMemorizacao(m(atualizado: 10, praticas: 2));
      expect(aj.memorizar.single.praticas, 2);
      expect(aj.itens()['v_19_119_11'], containsPair('praticas', 2));
      aj.importar({
        'app': 'br.com.wisejr.bibliaestudo',
        'memorizar': {
          '19:119:11': m(atualizado: 5, praticas: 9).paraMapa(),
          '43:3:16': {
            'ate': 17,
            'criada': 3,
            'atualizado': 3,
            'decorada': true,
          },
        },
      });
      expect(
        aj.memorizacao(19, 119, 11)!.praticas,
        2,
        reason: 'a daqui é mais nova',
      );
      expect(aj.memorizacao(43, 3, 16)!.decorada, isTrue);
      expect(aj.memorizacao(43, 3, 16)!.ate, 17);
      aj.aplicarItens({'v_43_3_16': null});
      expect(aj.memorizar, hasLength(1));
    });

    testWidgets('praticar até o fim conta uma prática', (t) async {
      final aj = Ajustes.instancia;
      aj.salvarMemorizacao(m());
      await t.pumpWidget(
        MaterialApp(
          home: TelaPraticar(
            memorizacao: m(),
            versao: const Versao(1, 'ARA', 'Almeida'),
            texto: 'Guardo no coração as tuas palavras.',
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Passo 1 de 4'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await t.tap(find.text('Próximo passo'));
        await t.pumpAndSettle();
      }
      expect(find.textContaining('Passo 4 de 4'), findsOneWidget);
      await t.tap(find.text('Conferir o texto'));
      await t.pumpAndSettle();
      expect(find.text('Guardo no coração as tuas palavras.'), findsOneWidget);
      await t.tap(find.text('Consegui!'));
      await t.pumpAndSettle();
      expect(find.text('Muito bem!'), findsOneWidget);
      expect(aj.memorizacao(19, 119, 11)!.praticas, 1);
      expect(aj.memorizacao(19, 119, 11)!.ultimaPratica, isNotNull);
    });
  });

  group('referência dentro de um texto', () {
    Object? achar(String s) {
      final p = Referencias.encontrar(s);
      return p == null ? null : (p.livro, p.capitulo, p.versiculo);
    }

    test('acha a primeira e ignora horas e números soltos', () {
      expect(achar('Leia João 3:16 hoje'), (43, 3, 16));
      expect(achar('cf. 1 Co 13.4-7'), (46, 13, 4));
      expect(achar('Às 10:30 do dia 25, Salmo 23'), (19, 23, null));
      expect(achar('Cântico dos Cânticos 2:4'), (22, 2, 4));
      expect(achar('Gênesis 1'), (1, 1, null));
      expect(achar('Reunião às 19:30 na igreja'), isNull);
      expect(achar('amor ao próximo'), isNull);
    });
  });

  test('buscas recentes: a mais nova primeiro, sem repetir, até 10', () {
    final aj = Ajustes.instancia;
    for (var i = 0; i < 12; i++) {
      aj.registrarBusca('busca $i');
    }
    aj.registrarBusca('BUSCA 5');
    expect(aj.buscasRecentes.first, 'BUSCA 5');
    expect(aj.buscasRecentes, hasLength(Ajustes.maxBuscas));
    expect(
      aj.buscasRecentes.where((b) => b.toLowerCase() == 'busca 5'),
      hasLength(1),
    );
    aj.registrarBusca(' x ');
    expect(aj.buscasRecentes.first, 'BUSCA 5', reason: 'curta demais');
    aj.limparBuscas();
    expect(aj.buscasRecentes, isEmpty);
  });

  testWidgets('o editor do cartão muda o fundo, a letra e o tamanho', (
    t,
  ) async {
    var estilo = const EstiloCartao();
    var pediuFoto = false;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: EditorCartao(
                estilo: estilo,
                temFoto: false,
                aoMudar: (e) => setState(() => estilo = e),
                aoTrocarFoto: () {},
                aoEscolherFoto: () => pediuFoto = true,
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Cor'));
    await t.pumpAndSettle();
    expect(estilo.fundo, TipoFundo.cor);
    expect(find.text('Escurecer'), findsNothing);
    await t.tap(find.text('Clássica'));
    await t.pumpAndSettle();
    expect(estilo.fonte, 1);
    await t.tap(find.byTooltip('Alinhar à esquerda'));
    await t.pumpAndSettle();
    expect(estilo.esquerda, isTrue);
    await t.tap(find.text('Sua foto'));
    expect(pediuFoto, isTrue, reason: 'sem foto ainda, abre a galeria');
  });
}
