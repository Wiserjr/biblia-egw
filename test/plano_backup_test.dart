import 'package:biblia_estudo/dados/ajustes.dart';
import 'package:biblia_estudo/dados/leitura_voz.dart';
import 'package:biblia_estudo/dados/modelos.dart';
import 'package:biblia_estudo/dados/plano.dart';
import 'package:biblia_estudo/dados/referencias.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('planos de leitura', () {
    for (final plano in PlanoLeitura.todos) {
      test('${plano.nome}: cada capítulo uma vez, em ordem', () {
        final dias = plano.leituras;
        expect(dias, hasLength(plano.dias));
        expect(dias.expand((d) => d).toList(), plano.capitulos);
        expect(dias.every((d) => d.isNotEmpty), isTrue);
        final tamanhos = dias.map((d) => d.length);
        expect(
          tamanhos.reduce((a, b) => a > b ? a : b) -
              tamanhos.reduce((a, b) => a < b ? a : b),
          lessThanOrEqualTo(1),
        );
      });
    }

    test('a Bíblia em um ano tem os 1.189 capítulos', () {
      final p = PlanoLeitura.porId('biblia-1-ano')!;
      expect(p.capitulos, hasLength(1189));
      expect(p.leituras.first.first, const Posicao(1, 1));
      expect(p.leituras.last.last, const Posicao(66, 22));
    });

    test('descrição de uma leitura', () {
      expect(descreverLeitura(const [Posicao(1, 1)]), 'Gênesis 1');
      expect(
        descreverLeitura(const [Posicao(1, 1), Posicao(1, 2), Posicao(1, 3)]),
        'Gênesis 1-3',
      );
      expect(
        descreverLeitura(const [Posicao(1, 50), Posicao(2, 1), Posicao(2, 2)]),
        '${Referencias.nome(1)} 50; Êxodo 1-2',
      );
    });
  });

  group('cópia de segurança', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Ajustes.instancia.carregar();
    });

    test('o que sai na cópia volta igual em outro aparelho', () async {
      final aj = Ajustes.instancia;
      aj.marcar(43, 3, 16, 2);
      aj.marcar(1, 1, 1, 0);
      aj.anotar(43, 3, 16, 'O amor de Deus');
      aj.iniciarPlano('nt-90-dias');
      aj.marcarDia(0, true);
      aj.marcarDia(1, true);
      final copia = aj.exportar();

      SharedPreferences.setMockInitialValues({});
      await aj.carregar();
      aj.marcar(1, 1, 1, 4); // outra cor no aparelho novo: vale a da cópia
      final r = aj.importar(copia);

      expect(r.marcacoes, 2);
      expect(r.anotacoes, 1);
      expect(aj.marcacao(43, 3, 16), 2);
      expect(aj.marcacao(1, 1, 1), 0);
      expect(aj.anotacao(43, 3, 16), 'O amor de Deus');
      expect(aj.plano, 'nt-90-dias');
      expect(aj.diasLidos, {0, 1});
    });

    test('anotações diferentes do mesmo versículo ficam as duas', () {
      final aj = Ajustes.instancia;
      aj.anotar(19, 23, 1, 'Local');
      aj.importar({
        'app': 'br.com.wisejr.bibliaestudo',
        'anotacoes': {'19:23:1': 'Da cópia'},
      });
      expect(aj.anotacao(19, 23, 1), 'Local\n\nDa cópia');
      // Restaurar a mesma cópia de novo não duplica.
      aj.importar({
        'app': 'br.com.wisejr.bibliaestudo',
        'anotacoes': {'19:23:1': 'Da cópia'},
      });
      expect(aj.anotacao(19, 23, 1), 'Local\n\nDa cópia');
    });

    test('não troca um plano em andamento por outro', () {
      final aj = Ajustes.instancia;
      aj.iniciarPlano('evangelhos-30-dias');
      aj.marcarDia(3, true);
      aj.importar({
        'app': 'br.com.wisejr.bibliaestudo',
        'plano': {
          'id': 'biblia-1-ano',
          'lidos': [0, 1, 2],
        },
      });
      expect(aj.plano, 'evangelhos-30-dias');
      expect(aj.diasLidos, {3});
    });

    test('recusa arquivo de outro app e ignora entradas inválidas', () {
      final aj = Ajustes.instancia;
      expect(() => aj.importar({'marcacoes': {}}), throwsFormatException);
      expect(() => aj.importar([1, 2]), throwsFormatException);
      final r = aj.importar({
        'app': 'br.com.wisejr.bibliaestudo',
        'marcacoes': {'99:1:1': 0, '43:3': 1, '43:3:16': 'x', '43:1:1': 1},
      });
      expect(r.marcacoes, 1);
      expect(aj.todasMarcacoes(), [((43, 1, 1), 1)]);
    });
  });

  group('realces nos livros', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Ajustes.instancia.carregar();
    });

    Realce realce(int obra, int pagina, int ini, int fim, {String? nota}) =>
        Realce(
          obra: obra,
          pagina: pagina,
          inicio: ini,
          fim: fim,
          cor: 1,
          texto: 'trecho $ini',
          nota: nota,
        );

    test('grava, troca o mesmo trecho e apaga', () {
      final aj = Ajustes.instancia;
      aj.realcar(realce(7, 30, 10, 20));
      aj.realcar(realce(7, 12, 0, 5));
      aj.realcar(realce(3, 1, 0, 5));
      aj.realcar(realce(7, 30, 10, 20).comCor(3).comNota('  boa  '));
      expect(aj.realces(7).map((r) => (r.pagina, r.inicio)), [
        (12, 0),
        (30, 10),
      ]);
      expect(aj.realces(7).last.cor, 3);
      expect(aj.realces(7).last.nota, 'boa');
      expect(aj.todosRealces().first.obra, 3);
      aj.apagarRealce(realce(7, 12, 0, 5));
      expect(aj.realces(7), hasLength(1));
    });

    test('sobreposição', () {
      final r = realce(1, 5, 10, 20);
      expect(r.sobrepoe(5, 15, 30), isTrue);
      expect(r.sobrepoe(5, 0, 11), isTrue);
      expect(r.sobrepoe(5, 20, 30), isFalse);
      expect(r.sobrepoe(6, 15, 30), isFalse);
    });

    test('vão na cópia e voltam juntando as anotações', () async {
      final aj = Ajustes.instancia;
      aj.realcar(realce(7, 30, 10, 20, nota: 'da cópia'));
      aj.realcar(realce(7, 31, 0, 8));
      final copia = aj.exportar();

      SharedPreferences.setMockInitialValues({});
      await aj.carregar();
      aj.realcar(realce(7, 30, 10, 20, nota: 'do aparelho'));
      final r = aj.importar({
        ...copia,
        'realces': [
          ...(copia['realces'] as List),
          {'obra': 1, 'pagina': 0, 'inicio': 0, 'fim': 3, 'cor': 0},
          {'obra': 1, 'pagina': 2, 'inicio': 5, 'fim': 3, 'cor': 0},
          'lixo',
        ],
      });
      expect(r.realces, 2);
      expect(aj.realces(7), hasLength(2));
      expect(aj.realces(7).first.nota, 'do aparelho\n\nda cópia');
      expect(aj.realces(1), isEmpty);

      // Restaurar a mesma cópia de novo não repete a anotação.
      aj.importar(copia);
      expect(aj.realces(7).first.nota, 'do aparelho\n\nda cópia');
    });

    test('troca vários de uma vez, com um só aviso', () {
      final aj = Ajustes.instancia;
      aj.trocarRealces(adicionar: [realce(7, 1, 0, 5), realce(7, 2, 0, 5)]);
      var avisos = 0;
      void contar() => avisos++;
      aj.addListener(contar);
      aj.trocarRealces(
        remover: [realce(7, 1, 0, 5), realce(7, 2, 0, 5)],
        adicionar: [for (var p = 1; p <= 5; p++) realce(7, p, 2, 9)],
      );
      aj.removeListener(contar);
      expect(avisos, 1);
      expect(aj.realces(7).map((r) => (r.pagina, r.inicio)), [
        for (var p = 1; p <= 5; p++) (p, 2),
      ]);
    });
  });

  group('trecho falado em partes', () {
    test('texto curto vai inteiro', () {
      expect(partesFaladas('  Uma frase.  '), ['Uma frase.']);
      expect(partesFaladas(''), isEmpty);
    });

    test('texto longo é cortado no fim das frases, sem perder nada', () {
      final frase = 'Bem-aventurados os mansos, porque herdarão a terra. ';
      final texto = (frase * 200).trim(); // ~10 mil caracteres
      final partes = partesFaladas(texto);
      expect(partes.length, greaterThan(2));
      expect(partes.every((p) => p.length <= 3500), isTrue);
      expect(partes.every((p) => p.endsWith('terra.')), isTrue);
      expect(partes.join(' '), texto);
    });

    test('sem pontuação, corta num espaço; sem espaço, no limite', () {
      final palavras = List.filled(2000, 'amor').join(' ');
      final partes = partesFaladas(palavras, max: 100);
      expect(partes.every((p) => p.length <= 100), isTrue);
      expect(partes.join(' '), palavras);
      expect(partesFaladas('x' * 250, max: 100).map((p) => p.length), [
        100,
        100,
        50,
      ]);
    });
  });

  test('a voz não lê a marcação do texto', () {
    expect(
      textoFalado('<J>Eu sou o caminho,</J> e a <i>verdade</i>.'),
      'Eu sou o caminho, e a verdade.',
    );
  });
}
