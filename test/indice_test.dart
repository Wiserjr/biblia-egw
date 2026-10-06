import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:biblia_estudo/dados/banco.dart';
import 'package:biblia_estudo/dados/estudo.dart';
import 'package:biblia_estudo/dados/mapas.dart';
import 'package:biblia_estudo/dados/sinotico.dart';
import 'package:biblia_estudo/dados/temas.dart';
import 'package:biblia_estudo/dados/modelos.dart';
import 'package:biblia_estudo/dados/trechos.dart';
import 'package:biblia_estudo/dados/ajustes.dart';
import 'package:biblia_estudo/telas/guia_biblioteca.dart';
import 'package:biblia_estudo/telas/introducao.dart';
import 'package:biblia_estudo/telas/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Confere o banco de estudo que vai no app (assets/estudo.db.gz) e, se os
/// PDFs estiverem em ferramentas/cache/pdf (rode indexar_obras.py), que o
/// pdfrx — o leitor de PDF do app — devolve exatamente o parágrafo que o
/// indexador em Python registrou.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() async {
    sqfliteFfiInit();
    tmp = await Directory.systemTemp.createTemp('estudo');
    final bytes = const GZipDecoder().decodeBytes(
      File('assets/estudo.db.gz').readAsBytesSync(),
    );
    final arq = File('${tmp.path}/estudo.db')..writeAsBytesSync(bytes);
    Banco.instancia.estudo = await databaseFactoryFfi.openDatabase(
      arq.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
  });

  tearDownAll(() async {
    await Banco.instancia.estudo.close();
    await tmp.delete(recursive: true);
  });

  test(
    'as 66 introduções carregam com o complemento Andrews apenas no AT',
    () async {
      for (var livro = 1; livro <= 66; livro++) {
        final intro = await Estudo.instancia.introducao(livro);
        expect(intro, isNotNull);
        expect(intro!['tema'], isNotEmpty);
        if (livro <= 39) {
          expect(intro['fontes'], contains('Andrews'));
          expect(intro['contexto'], isNotEmpty);
        } else {
          expect(intro['fontes'], isNull);
        }
      }
      final genesis = await Estudo.instancia.introducao(1);
      expect(genesis!['local'], contains('Midiã'));
      final isaias = await Estudo.instancia.introducao(23);
      expect(isaias!['mensagem'], contains('49:6'));
      expect(isaias['cristo'], contains('50:4-11'));
    },
  );

  test(
    'guia cobre todos os 95 livros EGW e preserva as páginas do índice',
    () async {
      final obras = await Estudo.instancia.obras();
      final etapas = await Estudo.instancia.capitulosObras();
      final egw = obras.values.where((o) => o.deEllenWhite).toList();
      expect(egw, hasLength(95));
      expect(egw.every((o) => etapas.any((c) => c.obra == o.id)), isTrue);
      final integrais = etapas.where(
        (c) => c.leituraIntegral && obras[c.obra]!.deEllenWhite,
      );
      expect(integrais, hasLength(30));
      expect(
        etapas.where((c) => !c.leituraIntegral && obras[c.obra]!.deEllenWhite),
        hasLength(2685),
      );
      expect(
        etapas.every((c) => c.pagina >= 0 && c.pagina < obras[c.obra]!.paginas),
        isTrue,
      );
      final pp = await Estudo.instancia.capitulosObras(obra: 1);
      expect(pp.every((c) => c.obra == 1), isTrue);
      expect(pp.first.pagina, 10);
    },
  );

  testWidgets('guia e introdução de Isaías cabem na tela de celular', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.instancia.carregar();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fonte = Platform.environment['BIBLIA_FONTE_QA'];
    if (fonte != null) {
      await (FontLoader('Roboto')..addFont(
            Future.value(ByteData.sublistView(File(fonte).readAsBytesSync())),
          ))
          .load();
      final icones = File(
        '${File(fonte).parent.path}/materialicons-regular.otf',
      );
      if (icones.existsSync()) {
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(ByteData.sublistView(icones.readAsBytesSync())),
            ))
            .load();
      }
    }
    final chave = GlobalKey();
    Future<void> esperarDados() async {
      for (
        var tentativa = 0;
        tentativa < 100 &&
            find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        tentativa++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    Future<void> captura(String nome) async {
      if (Platform.environment['BIBLIA_CAPTURAR_QA'] != '1') return;
      final boundary =
          chave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final imagem = await boundary.toImage(pixelRatio: 2);
        final bytes = await imagem.toByteData(format: ui.ImageByteFormat.png);
        final arquivo = File('build/qa/$nome.png');
        await arquivo.parent.create(recursive: true);
        await arquivo.writeAsBytes(bytes!.buffer.asUint8List());
        imagem.dispose();
      });
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: chave,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: temaClaro(),
          home: const TelaGuiaBiblioteca(),
        ),
      ),
    );
    await esperarDados();
    expect(find.text('Guia de leitura EGW'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captura('guia-egw-celular');
    await tester.tap(find.text('Criar plano de leitura'));
    await tester.pumpAndSettle();
    expect(find.text('Etapas por sessão'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await captura('plano-egw-celular');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      RepaintBoundary(
        key: chave,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: temaClaro(),
          home: const TelaIntroducao(livro: 23),
        ),
      ),
    );
    await esperarDados();
    expect(find.text('Contexto histórico e literário'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captura('isaias-celular');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  test('Mateus 4:4 leva ao capítulo "A tentação" de O Desejado', () async {
    final trechos = await Estudo.instancia.trechos(40, 4, 4);
    expect(trechos, isNotEmpty);
    final primeiro = trechos.first;
    expect(primeiro.tipo, TipoLigacao.capitulo);
    expect(primeiro.obra.sigla, 'DTN');
    expect(primeiro.capitulo, contains('tentação'));
    expect(
      trechos.where(
        (t) => t.tipo == TipoLigacao.citacao && t.obra.sigla == 'DTN',
      ),
      isNotEmpty,
    );
  });

  test(
    'Daniel 2 tem o comentário versículo a versículo de Urias Smith',
    () async {
      final trechos = await Estudo.instancia.trechos(27, 2, 31);
      expect(
        trechos.where(
          (t) => t.tipo == TipoLigacao.comentario && t.obra.sigla == 'DA',
        ),
        isNotEmpty,
      );
    },
  );

  test('Mateus 4:4 cita Deuteronômio 8:3, e a recíproca', () async {
    final refs = await Estudo.instancia.referencias(40, 4, 4);
    expect(refs.any((r) => r.livro == 5 && r.ini == 8003 && r.citacao), isTrue);
    final volta = await Estudo.instancia.referencias(5, 8, 3);
    expect(volta.any((r) => r.livro == 40 && r.ini == 4004), isTrue);
  });

  group('mapas', () {
    test('lugares de um versículo, com nome em português', () async {
      // Mateus 2:1 — "Belém da Judéia", "Jerusalém".
      final l = await Mapas.instancia.doVersiculo(40, 2, 1);
      final nomes = l.map((x) => x.nome).toSet();
      expect(nomes, containsAll(['Belém', 'Jerusalém']));
    });

    test(
      'mapas temáticos: rotas com lugares e coordenadas plausíveis',
      () async {
        final mapas = await Mapas.instancia.tematicos();
        expect(mapas.length, greaterThanOrEqualTo(15));
        final paulo = mapas.firstWhere((m) => m.id == 'paulo-2');
        final rota = await Mapas.instancia.lugares(paulo.rotas.first.lugares);
        expect(rota.first.nome, contains('Antioquia'));
        expect(rota.map((l) => l.nome), contains('Corinto'));
        for (final l in rota) {
          expect(l.lon, inInclusiveRange(8, 60), reason: l.nome);
          expect(l.lat, inInclusiveRange(20, 46), reason: l.nome);
        }
      },
    );

    test('a geometria tem terra, lagos e rios', () async {
      final g = await Mapas.instancia.geometria();
      expect(g.terra, isNotEmpty);
      expect(g.lagos, isNotEmpty);
      expect(g.rios, isNotEmpty);
    });
  });

  group('temas e estudos', () {
    test('o sábado tem versículos e leituras de Ellen G. White', () async {
      final passagens = await Temas.instancia.passagens('sabado');
      expect(passagens.first.livro, 1); // Gênesis 2:2-3
      final leituras = await Temas.instancia.leituras('sabado');
      expect(leituras, isNotEmpty);
      expect(leituras.first.versiculos, greaterThanOrEqualTo(2));
    });

    test('João 3:16 aparece em temas', () async {
      final t = await Temas.instancia.doVersiculo(43, 3, 16);
      expect(t.map((x) => x.id), contains('amor-de-deus'));
    });

    test('estudos bíblicos em ordem, com perguntas', () async {
      final e = await Temas.instancia.estudos();
      expect(e.first.titulo, startsWith('1.'));
      final q = await Temas.instancia.perguntas(e.first.id);
      expect(q, isNotEmpty);
    });

    test('título curto de capítulo', () {
      expect(tituloCurto('Capítulo 29 — O Sábado'), 'cap. 29 — O Sábado');
      expect(
        tituloCurto(
          'Capítulo 17 — Poesias e cânticos “Os Teus estatutos têm sido',
        ),
        'cap. 17 — Poesias e cânticos',
      );
    });
  });

  group('notas de estudo', () {
    test('todo o Novo Testamento tem notas em todos os capítulos', () async {
      for (final (livro, caps) in [
        (40, 28),
        (41, 16),
        (42, 24),
        (43, 21),
        (44, 28),
        (45, 16),
      ]) {
        for (var c = 1; c <= caps; c++) {
          final rows = await Banco.instancia.estudo.rawQuery(
            'SELECT count(*) AS n FROM nota WHERE livro=? AND ini BETWEEN ? AND ?',
            [livro, c * 1000, c * 1000 + 999],
          );
          expect(rows.first['n'], greaterThan(0), reason: '$livro:$c');
        }
      }
    });

    test('João 3:16 tem nota', () async {
      final n = await Estudo.instancia.notas(43, 3, 16);
      expect(n.single.texto, contains('amor de Deus'));
    });

    test('Romanos 3:31 tem nota sobre a lei', () async {
      final n = await Estudo.instancia.notas(45, 3, 31);
      expect(n.single.texto, contains('confirmamos a lei'));
    });

    test('1 Coríntios 15:51 tem nota sobre a ressurreição', () async {
      final n = await Estudo.instancia.notas(46, 15, 51);
      expect(n.single.texto, contains('imortalidade'));
    });

    test('Colossenses 2:16 distingue os sábados cerimoniais', () async {
      final n = await Estudo.instancia.notas(51, 2, 16);
      expect(n.single.texto, contains('cerimoniais'));
    });

    test('1 Tessalonicenses 4:13 trata a morte como sono', () async {
      final n = await Estudo.instancia.notas(52, 4, 13);
      expect(n.single.texto, contains('sono'));
    });

    test('Hebreus 8:2 fala do santuário celestial', () async {
      final n = await Estudo.instancia.notas(58, 8, 2);
      expect(n.single.texto, contains('santuário'));
    });

    test('Apocalipse 14:7 liga o primeiro anjo ao quarto mandamento', () async {
      final n = await Estudo.instancia.notas(66, 14, 7);
      expect(n.single.texto, contains('quarto mandamento'));
    });

    test('Daniel tem notas em todos os capítulos; 8:14 leva a 1844', () async {
      for (var c = 1; c <= 12; c++) {
        final rows = await Banco.instancia.estudo.rawQuery(
          'SELECT count(*) AS n FROM nota WHERE livro=27 AND ini BETWEEN ? AND ?',
          [c * 1000, c * 1000 + 999],
        );
        expect(rows.first['n'], greaterThan(0), reason: 'Daniel $c');
      }
      final n = await Estudo.instancia.notas(27, 9, 25);
      expect(n.single.texto, contains('457 a.C.'));
    });

    test('de Gênesis a Ester, todos os capítulos têm notas', () async {
      for (final (livro, caps) in [
        (1, 50),
        (2, 40),
        (3, 27),
        (4, 36),
        (5, 34),
        (6, 24),
        (7, 21),
        (8, 4),
        (9, 31),
        (10, 24),
        (11, 22),
        (12, 25),
        (13, 29),
        (14, 36),
        (15, 10),
        (16, 13),
        (17, 10),
      ]) {
        for (var c = 1; c <= caps; c++) {
          final rows = await Banco.instancia.estudo.rawQuery(
            'SELECT count(*) AS n FROM nota WHERE livro=? AND ini BETWEEN ? AND ?',
            [livro, c * 1000, c * 1000 + 999],
          );
          expect(rows.first['n'], greaterThan(0), reason: '$livro:$c');
        }
      }
      final n = await Estudo.instancia.notas(1, 2, 3);
      expect(n.single.texto, contains('sábado'));
    });

    test('Levítico 16 explica o Dia da Expiação e Azazel', () async {
      final n = await Estudo.instancia.notas(3, 16, 21);
      expect(n.single.texto, contains('Satanás'));
    });

    test('1 Samuel 28: a aparição em En-Dor não era Samuel', () async {
      final n = await Estudo.instancia.notas(9, 28, 15);
      expect(n.single.texto, contains('não era Samuel'));
    });

    test('1 Reis 18 leva a Profetas e Reis, "O Carmelo"', () async {
      final n = await Estudo.instancia.notas(11, 18, 38);
      expect(n.single.texto, contains('O Carmelo'));
    });

    test('2 Crônicas 7:14 tem nota sobre o reavivamento', () async {
      final n = await Estudo.instancia.notas(14, 7, 14);
      expect(n.single.texto, contains('reavivamento'));
    });

    test('Esdras 7: o decreto de 457 a.C. e as setenta semanas', () async {
      final n = await Estudo.instancia.notas(15, 7, 21);
      expect(n.single.texto, contains('Daniel 9:25'));
    });

    test(
      'Isaías: todos os capítulos; 53 leva a "A vinda de um libertador"',
      () async {
        for (var c = 1; c <= 66; c++) {
          final rows = await Banco.instancia.estudo.rawQuery(
            'SELECT count(*) AS n FROM nota WHERE livro=23 AND ini BETWEEN ? AND ?',
            [c * 1000, c * 1000 + 999],
          );
          expect(rows.first['n'], greaterThan(0), reason: 'Isaías $c');
        }
        final n = await Estudo.instancia.notas(23, 53, 5);
        expect(n.single.texto, contains('substituição'));
      },
    );

    test(
      'Jeremias e Lamentações: todos os capítulos; a nova aliança',
      () async {
        for (final (livro, caps) in [(24, 52), (25, 5)]) {
          for (var c = 1; c <= caps; c++) {
            final rows = await Banco.instancia.estudo.rawQuery(
              'SELECT count(*) AS n FROM nota WHERE livro=? AND ini BETWEEN ? AND ?',
              [livro, c * 1000, c * 1000 + 999],
            );
            expect(rows.first['n'], greaterThan(0), reason: '$livro:$c');
          }
        }
        final n = await Estudo.instancia.notas(24, 31, 33);
        expect(n.single.texto, contains('coração'));
      },
    );

    test(
      'Ezequiel: todos os capítulos; 28 leva a "Por que existe o sofrimento"',
      () async {
        for (var c = 1; c <= 48; c++) {
          final rows = await Banco.instancia.estudo.rawQuery(
            'SELECT count(*) AS n FROM nota WHERE livro=26 AND ini BETWEEN ? AND ?',
            [c * 1000, c * 1000 + 999],
          );
          expect(rows.first['n'], greaterThan(0), reason: 'Ezequiel $c');
        }
        final n = await Estudo.instancia.notas(26, 28, 15);
        expect(n.single.texto, contains('Por que existe o sofrimento'));
      },
    );

    test('os doze profetas menores têm notas em todos os capítulos', () async {
      for (final (livro, caps) in [
        (28, 14),
        (29, 3),
        (30, 9),
        (31, 1),
        (32, 4),
        (33, 7),
        (34, 3),
        (35, 3),
        (36, 3),
        (37, 2),
        (38, 14),
        (39, 4),
      ]) {
        for (var c = 1; c <= caps; c++) {
          final rows = await Banco.instancia.estudo.rawQuery(
            'SELECT count(*) AS n FROM nota WHERE livro=? AND ini BETWEEN ? AND ?',
            [livro, c * 1000, c * 1000 + 999],
          );
          expect(rows.first['n'], greaterThan(0), reason: '$livro:$c');
        }
      }
      final n = await Estudo.instancia.notas(39, 3, 10);
      expect(n.single.texto, contains('dízimo'));
    });

    test(
      'Jó, Provérbios, Eclesiastes e Cantares em todos os capítulos',
      () async {
        for (final (livro, caps) in [(18, 42), (20, 31), (21, 12), (22, 8)]) {
          for (var c = 1; c <= caps; c++) {
            final rows = await Banco.instancia.estudo.rawQuery(
              'SELECT count(*) AS n FROM nota WHERE livro=? AND ini BETWEEN ? AND ?',
              [livro, c * 1000, c * 1000 + 999],
            );
            expect(rows.first['n'], greaterThan(0), reason: '$livro:$c');
          }
        }
        final n = await Estudo.instancia.notas(21, 9, 5);
        expect(n.single.texto, contains('inconscientes'));
      },
    );

    test(
      'a Bíblia inteira: os 1.189 capítulos dos 66 livros têm nota',
      () async {
        const capitulos = [
          50,
          40,
          27,
          36,
          34,
          24,
          21,
          4,
          31,
          24,
          22,
          25,
          29,
          36,
          10,
          13,
          10,
          42,
          150,
          31,
          12,
          8,
          66,
          52,
          5,
          48,
          12,
          14,
          3,
          9,
          1,
          4,
          7,
          3,
          3,
          3,
          2,
          14,
          4,
          28,
          16,
          24,
          21,
          28,
          16,
          16,
          13,
          6,
          6,
          4,
          4,
          5,
          3,
          6,
          4,
          3,
          1,
          13,
          5,
          5,
          3,
          5,
          1,
          1,
          1,
          22,
        ];
        final rows = await Banco.instancia.estudo.rawQuery(
          'SELECT DISTINCT livro, ini / 1000 AS c FROM nota',
        );
        final tem = {for (final r in rows) '${r['livro']}:${r['c']}'};
        for (var l = 1; l <= 66; l++) {
          for (var c = 1; c <= capitulos[l - 1]; c++) {
            expect(tem, contains('$l:$c'));
          }
        }
      },
    );

    test('Salmos 146:4: os pensamentos cessam na morte', () async {
      final n = await Estudo.instancia.notas(19, 146, 4);
      expect(n.single.texto, contains('pensamentos cessam'));
    });
  });

  group('guia sinótico', () {
    test('episódios em ordem, do prólogo à ascensão', () async {
      final e = await Sinotico.instancia.eventos();
      expect(e.length, greaterThan(150));
      expect(e.first.passagens.keys, [43]);
      expect(e.last.titulo, contains('ascensão'));
    });

    test('a tentação está nos três sinóticos e em O Desejado', () async {
      final e = await Sinotico.instancia.doVersiculo(40, 4, 4);
      final tentacao = e.firstWhere((x) => x.titulo.contains('tentação'));
      expect(tentacao.passagens.keys, containsAll([40, 41, 42]));
      expect(tentacao.leituras.first.obra.sigla, 'DTN');
      expect(tentacao.leituras.first.capitulo, contains('A tentação'));
    });

    test('a multiplicação para cinco mil está nos quatro', () async {
      final e = await Sinotico.instancia.doVersiculo(43, 6, 10);
      expect(e.single.quantosEvangelhos, 4);
    });

    test('parábola leva a Parábolas de Jesus', () async {
      final e = await Sinotico.instancia.doVersiculo(42, 15, 11);
      expect(e.single.leituras.map((l) => l.obra.sigla), contains('PJ'));
    });

    test('fora dos evangelhos, nada', () async {
      expect(await Sinotico.instancia.doVersiculo(1, 1, 1), isEmpty);
    });
  });

  test('todos os livros têm introdução', () async {
    for (var l = 1; l <= 66; l++) {
      final i = await Estudo.instancia.introducao(l);
      expect(i?['tema'], isNotEmpty, reason: 'livro $l');
    }
  });

  test('marcadores do leitor: João 3 tem versículos citados', () async {
    final c = await Estudo.instancia.contagem(43, 3);
    expect(c[16], greaterThan(10));
  });

  group('paridade com o indexador (precisa dos PDFs em cache)', () {
    // O pdfrx no teste (sem Flutter) precisa de um libpdfium: aponte
    // PDFIUM_PATH para o que vem com o pypdfium2, por exemplo
    //   PDFIUM_PATH=$(python3 -c "import pypdfium2_raw,os;print(os.path.join(os.path.dirname(pypdfium2_raw.__file__),'libpdfium.so'))")
    final pasta = Directory('ferramentas/cache/pdf');
    final pdfium = Platform.environment['PDFIUM_PATH'];
    final temPdfs =
        pasta.existsSync() && pdfium != null && File(pdfium).existsSync();

    setUpAll(() async {
      if (temPdfs) await pdfrxInitialize();
    });

    test(
      'o pdfrx recorta o mesmo parágrafo que o PDFium do Python',
      () async {
        final obras = await Estudo.instancia.obras();
        var conferidos = 0;
        for (final sigla in ['DTN', 'PP', 'GC', 'DA', 'HS']) {
          final obra = obras.values.firstWhere((o) => o.sigla == sigla);
          final arq = File('${pasta.path}/${obra.arquivo}.pdf');
          if (!arq.existsSync()) continue;
          final doc = await PdfDocument.openFile(arq.path);
          final rows = await Banco.instancia.estudo.rawQuery(
            'SELECT segmentos, ancora FROM trecho WHERE obra=? '
            'AND ancora IS NOT NULL ORDER BY id LIMIT 40',
            [obra.id],
          );
          for (final r in rows) {
            final segs = Trecho.lerSegmentos(r['segmentos'] as String);
            final paginas = <int, String>{};
            for (final (p, _, _) in segs) {
              paginas[p] ??= (await doc.pages[p].loadText())?.fullText ?? '';
            }
            final texto = recortar(paginas, segs);
            final ancora = (r['ancora'] as String).replaceAll(' ', '');
            expect(
              texto.replaceAll(RegExp(r'\s'), ''),
              contains(ancora),
              reason: '$sigla ${r['segmentos']}',
            );
            conferidos++;
          }
          await doc.dispose();
        }
        expect(conferidos, greaterThan(0));
      },
      skip: temPdfs
          ? false
          : 'Sem PDFs em cache (indexar_obras.py) ou sem PDFIUM_PATH',
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
