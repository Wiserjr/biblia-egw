import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:biblia_estudo/dados/banco.dart';
import 'package:biblia_estudo/dados/biblia.dart';
import 'package:biblia_estudo/dados/referencias.dart';
import 'package:biblia_estudo/dados/traducoes_extras.dart';
import 'package:biblia_estudo/telas/traducoes_extras.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Um livro no formato da fonte: um versículo por capítulo (dois em Gn 1).
String livroFalso(String sigla, int livro, {int? id}) => jsonEncode({
  'id': id ?? livro,
  'code': codigosLivros[livro - 1],
  'chapters': [
    for (var c = 1; c <= Referencias.capitulos[livro - 1]; c++)
      {
        'number': c,
        'verses': [
          if (livro == 1 && c == 1 && sigla == 'MENS')
            {'number': 1, 'text': '1-2 No princípio, Deus criou tudo.'}
          else ...[
            {'number': 1, 'text': '$sigla $livro:$c:1 Deus fala.'},
            if (livro == 1 && c == 1)
              {'number': 2, 'text': '$sigla 1:1:2 A terra era vazia.'},
          ],
        ],
      },
  ],
});

int livroDaUrl(Uri url) =>
    codigosLivros.indexOf(url.pathSegments.last.split('.')[0]) + 1;

TraducaoBaixavel sigla(String s) =>
    traducoesBaixaveis.singleWhere((t) => t.sigla == s);

void main() {
  late Directory temporario;
  setUpAll(() async {
    sqfliteFfiInit();
    temporario = await Directory.systemTemp.createTemp('traducoes_');
    final arquivo = File('${temporario.path}/biblia.db');
    await arquivo.writeAsBytes(
      const GZipDecoder().decodeBytes(
        await File('assets/biblia.db.gz').readAsBytes(),
      ),
    );
    Banco.instancia.biblia = await databaseFactoryFfi.openDatabase(
      arquivo.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    final extras = await databaseFactoryFfi.openDatabase(
      '${temporario.path}/traducoes_extras.db',
    );
    await TraducoesExtras.criarEsquema(extras);
    Banco.instancia.extras = extras;
  });
  tearDownAll(() async {
    await Banco.instancia.biblia.close();
    await Banco.instancia.extras!.close();
    Banco.instancia.extras = null;
    await temporario.delete(recursive: true);
  });
  setUp(() async {
    for (final t in traducoesBaixaveis) {
      await TraducoesExtras.remover(Banco.instancia.extras!, t);
    }
    Biblia.instancia.esquecerVersoes();
  });

  test('o app embarca 14 traduções; as das editoras ficam fora', () async {
    final biblia = Biblia.instancia;
    final versoes = await biblia.versoes();
    expect(versoes, hasLength(14));
    expect(versoes.first.sigla, 'ARA');
    expect(versoes.first.id, 2);
    expect(versoes.where((v) => v.id >= 16).map((v) => (v.id, v.sigla)), [
      (20, 'TB'),
      (21, 'ALM1911'),
    ]);
    for (final id in idsBaixaveis) {
      final linhas = await Banco.instancia.biblia.rawQuery(
        'SELECT count(*) n FROM versiculo WHERE versao=?',
        [id],
      );
      expect(linhas.single['n'], 0, reason: 'ID $id');
    }
    for (final v in versoes.where((v) => v.id >= 20)) {
      final caps = await Banco.instancia.biblia.rawQuery(
        'SELECT livro, capitulo FROM versiculo WHERE versao=? GROUP BY livro, capitulo',
        [v.id],
      );
      expect(caps, hasLength(1189), reason: v.sigla);
      expect(await biblia.capitulo(v.id, 66, 22), isNotEmpty);
      expect(await biblia.buscar(v.id, 'Deus'), isNotEmpty);
    }
  });

  test('o download vem só da revisão fixada do damarals/biblias', () {
    final url = urlLivroTraducao('NBV', 43);
    expect(
      url.toString(),
      'https://raw.githubusercontent.com/damarals/biblias/'
      '$revisaoTraducoes/data/canonical/NBV/JHN.json',
    );
    expect(urlTraducaoPermitida(url), isTrue);
    expect(
      urlTraducaoPermitida(
        Uri.parse('https://raw.githubusercontent.com/outro/repo/x.json'),
      ),
      isFalse,
    );
    expect(urlTraducaoPermitida(url.replace(scheme: 'http')), isFalse);
    expect(codigosLivros, hasLength(66));
    expect(idsBaixaveis, {16, 17, 18, 19, 22, 23, 24});
  });

  test('baixada, a tradução entra na lista, na leitura e na busca', () async {
    final db = Banco.instancia.extras!;
    final pedidos = <Uri>[];
    final progresso = <double>[];
    await TraducoesExtras(
      obter: (url) async {
        pedidos.add(url);
        return livroFalso('NBV', livroDaUrl(url));
      },
    ).baixar(
      db,
      sigla('NBV'),
      progresso: progresso.add,
      cancelado: () => false,
    );
    expect(pedidos, hasLength(66));
    expect(pedidos.every(urlTraducaoPermitida), isTrue);
    expect(progresso.last, 1);
    expect(await TraducoesExtras.instaladas(db), {19});

    final biblia = Biblia.instancia;
    biblia.esquecerVersoes();
    final versoes = await biblia.versoes();
    expect(versoes, hasLength(15));
    // Na mesma posição em que estava na 1.11.0: depois do BLIVRE-TR.
    final i = versoes.indexWhere((v) => v.sigla == 'NBV');
    expect(versoes[i - 1].sigla, 'BLIVRE-TR');
    expect(versoes[i + 1].sigla, 'TB');
    expect(versoes[i].id, 19);

    final gn1 = await biblia.capitulo(19, 1, 1);
    expect(gn1.map((v) => v.numero), [1, 2]);
    expect(await biblia.intervalo(19, 43, 3001, 3001), hasLength(1));
    expect(await biblia.buscar(19, 'terra vazia'), hasLength(1));
    final comparacao = await biblia.comparar(1, 1, 2);
    expect(comparacao.map((c) => c.$1.sigla), contains('NBV'));
    expect(comparacao.first.$1.sigla, 'ARA');

    await TraducoesExtras.remover(db, sigla('NBV'));
    biblia.esquecerVersoes();
    expect(await biblia.versoes(), hasLength(14));
    expect(await biblia.capitulo(19, 1, 1), isEmpty);
  });

  test('A Mensagem baixada cobre Gn 1:2 sem duplicar o grupo', () async {
    final db = Banco.instancia.extras!;
    await TraducoesExtras(
      obter: (url) async => livroFalso('MENS', livroDaUrl(url)),
    ).baixar(db, sigla('MENS'), progresso: (_) {}, cancelado: () => false);
    final biblia = Biblia.instancia;
    biblia.esquecerVersoes();
    final capitulo = await biblia.capitulo(23, 1, 1);
    expect(capitulo.single.numero, 1);
    final comparacao = await biblia.comparar(1, 1, 2);
    expect(
      comparacao.singleWhere((v) => v.$1.sigla == 'MENS').$2,
      startsWith('1-2 '),
    );
    final referencia = await biblia.intervalo(23, 1, 1002, 1002);
    expect(referencia, hasLength(1));
    expect(referencia.single.$2, 1);
    expect(await biblia.intervalo(23, 1, 1001, 1002), hasLength(1));
  });

  test(
    'arquivo errado ou cancelamento não deixam tradução pela metade',
    () async {
      final db = Banco.instancia.extras!;
      await expectLater(
        TraducoesExtras(
          obter: (url) async {
            final livro = livroDaUrl(url);
            return livroFalso('OL', livro, id: livro == 40 ? 41 : null);
          },
        ).baixar(db, sigla('OL'), progresso: (_) {}, cancelado: () => false),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'mensagem',
            contains('OL MAT'),
          ),
        ),
      );
      expect(await TraducoesExtras.instaladas(db), isEmpty);

      var pedidos = 0;
      await expectLater(
        TraducoesExtras(
          obter: (url) async {
            pedidos++;
            return livroFalso('OL', livroDaUrl(url));
          },
        ).baixar(
          db,
          sigla('OL'),
          progresso: (_) {},
          cancelado: () => pedidos >= 10,
        ),
        throwsA(isA<TraducaoDownloadCancelado>()),
      );
      expect(pedidos, lessThan(66));
      expect(await TraducoesExtras.instaladas(db), isEmpty);
    },
  );

  test('capítulo faltando, versículo vazio ou HTML são recusados', () {
    final semCapitulo = jsonDecode(livroFalso('VFL', 19)) as Map;
    (semCapitulo['chapters'] as List).removeLast();
    expect(
      () => lerLivroTraducao('VFL', 19, jsonEncode(semCapitulo)),
      throwsA(isA<FormatException>()),
    );
    final vazio = jsonDecode(livroFalso('VFL', 1)) as Map;
    ((vazio['chapters'] as List).first['verses'] as List).first['text'] = ' ';
    expect(
      () => lerLivroTraducao('VFL', 1, jsonEncode(vazio)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => lerLivroTraducao('VFL', 1, '<html>'),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets('a tela avisa dos direitos, baixa e remove', (tester) async {
    // A lista inteira na tela (a ListView só monta o que aparece).
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = Banco.instancia.extras!;
    final baixador = TraducoesExtras(
      obter: (url) async => livroFalso('KJF', livroDaUrl(url)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TelaTraducoesExtras(banco: db, traducoes: baixador),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.textContaining('pertencem às suas editoras'), findsOneWidget);
    expect(find.text('Ver a coleção no GitHub'), findsOneWidget);
    expect(find.byTooltip('Baixar'), findsNWidgets(7));

    final kjf = find.ancestor(
      of: find.text('King James Fiel'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: kjf, matching: find.byTooltip('Baixar')),
    );
    await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        if ((await TraducoesExtras.instaladas(db)).isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(await tester.runAsync(() => TraducoesExtras.instaladas(db)), {18});
    expect(find.textContaining('King James Fiel baixada'), findsOneWidget);
    expect(find.byTooltip('Remover do aparelho'), findsOneWidget);

    await tester.tap(find.byTooltip('Remover do aparelho'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(
      await tester.runAsync(() => TraducoesExtras.instaladas(db)),
      isEmpty,
    );
    expect(find.byTooltip('Baixar'), findsNWidgets(7));
  });
}
