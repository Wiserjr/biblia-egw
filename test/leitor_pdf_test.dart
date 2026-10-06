import 'dart:convert';
import 'dart:io';

import 'package:biblia_estudo/dados/ajustes.dart';
import 'package:biblia_estudo/dados/guia_biblioteca.dart';
import 'package:biblia_estudo/dados/modelos.dart';
import 'package:biblia_estudo/telas/leitor_pdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _obra = Obra(
  id: 81,
  arquivo: 'teste',
  sigla: 'FFD',
  titulo: 'Filhos e Filhas de Deus',
  autor: 'Ellen G. White',
  grupo: 'egw',
  prioridade: 1,
  url: 'https://cdn.centrowhite.org.br/teste.pdf',
  bytes: 1,
  sha256: '',
  paginas: 1,
);

/// O mesmo livro, em páginas em pé como as de um livro de verdade.
const _retrato = Obra(
  id: 82,
  arquivo: 'retrato',
  sigla: 'RET',
  titulo: 'Livro em pé',
  autor: 'Ellen G. White',
  grupo: 'egw',
  prioridade: 1,
  url: 'https://cdn.centrowhite.org.br/retrato.pdf',
  bytes: 1,
  sha256: '',
  paginas: 1,
);

/// Um PDF com uma linha de texto em cada página, montado à mão.
List<int> _pdfMinimo(
  List<String> paginas, {
  int largura = 400,
  int altura = 200,
}) {
  final n = paginas.length;
  // 1: catálogo, 2: páginas, 3: fonte, depois página e conteúdo de cada uma.
  final objetos = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [${[for (var i = 0; i < n; i++) '${4 + 2 * i} 0 R'].join(' ')}] /Count $n >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  for (var i = 0; i < n; i++) {
    final fluxo = 'BT /F1 12 Tf 20 100 Td (${paginas[i]}) Tj ET';
    objetos
      ..add(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $largura $altura] '
        '/Resources << /Font << /F1 3 0 R >> >> /Contents ${5 + 2 * i} 0 R >>',
      )
      ..add('<< /Length ${fluxo.length} >>\nstream\n$fluxo\nendstream');
  }
  final saida = StringBuffer('%PDF-1.4\n');
  final posicoes = <int>[];
  for (var i = 0; i < objetos.length; i++) {
    posicoes.add(saida.length);
    saida.write('${i + 1} 0 obj\n${objetos[i]}\nendobj\n');
  }
  final xref = saida.length;
  saida.write('xref\n0 ${objetos.length + 1}\n0000000000 65535 f \n');
  for (final p in posicoes) {
    saida.write('${p.toString().padLeft(10, '0')} 00000 n \n');
  }
  saida.write(
    'trailer\n<< /Size ${objetos.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return latin1.encode(saida.toString());
}

/// Deixa o tempo correr (o PDFium trabalha de verdade) até [pronto].
Future<void> _esperar(
  WidgetTester tester,
  bool Function() pronto, {
  int vezes = 50,
}) async {
  for (var i = 0; i < vezes && !pronto(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.instancia.carregar();
  });

  test('a busca aceita quebra de linha entre as palavras', () {
    final p = padraoDeBusca('  Marcos 4:4 (ARA)  ');
    expect(p.hasMatch('cita marcos\n4:4 (ara) aqui'), isTrue);
    expect(p.hasMatch('Marcos 4:40'), isFalse);
    expect(padraoDeBusca('é a vida').hasMatch('É A\nVIDA'), isTrue);
    expect(padraoDeBusca('a.b').hasMatch('axb'), isFalse);
    expect(padraoDeBusca('por que').hasMatch('porque'), isFalse);
  });

  group('zoom', () {
    test('o livro abre com a página inteira, e a letra legível', () {
      // Monitor largo: a página inteira, bem menor que a largura da tela
      // (com que os livros abriam até a 1.4).
      expect(zoomInicial(paginaInteira: 1.4, larguraDaTela: 3.8), 1.4);
      // Celular em pé: a largura da tela é a página inteira.
      expect(zoomInicial(paginaInteira: 0.9, larguraDaTela: 0.9), 0.9);
      expect(zoomInicial(paginaInteira: 0.9, larguraDaTela: 0.92), 0.92);
      // Celular deitado: a página inteira deixaria a letra miúda; abre no
      // tamanho real da página, ainda menor que a largura.
      expect(zoomInicial(paginaInteira: 0.56, larguraDaTela: 2.04), 1.0);
      // Janela estreita e baixa: nunca passa da largura.
      expect(zoomInicial(paginaInteira: 0.5, larguraDaTela: 0.7), 0.7);
    });

    test('passos de 15%, pela página inteira e pela largura', () {
      const m = PdfViewerLayoutMetrics(
        minScale: 1.37,
        maxScale: 8,
        coverScale: 3.85,
        alternativeFitScale: 1.37,
      );
      final passos = passosDeZoom(m);
      expect(passos.first, 1.37);
      expect(passos.last, 8);
      expect(passos, contains(3.85));
      for (var i = 1; i < passos.length; i++) {
        final razao = passos[i] / passos[i - 1];
        expect(razao, greaterThan(1.0), reason: 'em ordem: $passos');
        expect(razao, lessThanOrEqualTo(1.15 + 1e-9), reason: '$passos');
      }
      // O padrão do leitor ia de 1,37 direto para 2,74.
      expect(passos[1], closeTo(1.37 * 1.15, 1e-9));
    });

    test('passos sem repetição quando as duas medidas coincidem', () {
      const m = PdfViewerLayoutMetrics(
        minScale: 0.9,
        maxScale: 8,
        coverScale: 0.905,
        alternativeFitScale: 0.9,
      );
      final passos = passosDeZoom(m);
      for (var i = 1; i < passos.length; i++) {
        expect(passos[i] - passos[i - 1], greaterThanOrEqualTo(0.02));
      }
      expect(passos.first, 0.9);
    });
  });

  // Antes, o leitor criava a busca do destaque antes de o livro carregar, e a
  // tela ficava cinza em quase todo "No livro" (os trechos que citam o
  // versículo sempre têm destaque).
  testWidgets('abre o livro com destaque sem quebrar a tela', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TelaPdf(obra: _obra, pagina: 0, destaque: 'Marcos 4'),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Filhos e Filhas de Deus'), findsOneWidget);
  });

  group('com o PDFium (PDFIUM_PATH)', () {
    final pdfium = Platform.environment['PDFIUM_PATH'];
    final temPdfium = pdfium != null && File(pdfium).existsSync();
    late Directory pasta;
    late int inicioMarcos; // onde "Marcos 4" começa no texto de cada página

    setUpAll(() async {
      if (!temPdfium) return;
      await pdfrxInitialize();
      pasta = await Directory.systemTemp.createTemp('leitor_pdf_test');
      final obras = Directory('${pasta.path}/obras')..createSync();
      final arquivo = File('${obras.path}/teste.pdf')
        ..writeAsBytesSync(
          _pdfMinimo([
            for (var p = 1; p <= 5; p++)
              'Pagina $p: Disse Jesus em Marcos 4 a parabola.',
          ]),
        );
      File('${obras.path}/retrato.pdf').writeAsBytesSync(
        _pdfMinimo([
          for (var p = 1; p <= 5; p++) 'Pagina $p em pe.',
        ], altura: 600),
      );
      final doc = await PdfDocument.openFile(arquivo.path);
      final texto = await doc.pages[2].loadStructuredText();
      inicioMarcos = texto.fullText.indexOf('Marcos 4');
      await doc.dispose();
      expect(inicioMarcos, greaterThan(0));
    });

    tearDownAll(() {
      if (temPdfium) pasta.deleteSync(recursive: true);
    });

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (c) async => pasta.path,
          );
    });

    IconButton botao(WidgetTester tester, IconData icone) =>
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, icone));

    /// Abre o livro em pé numa janela de PC (1600 x 900), ou na [tela] dada.
    Future<PdfViewerController> abrirNoPc(
      WidgetTester tester, {
      int pagina = 0,
      Size tela = const Size(1600, 900),
    }) async {
      tester.view.physicalSize = tela;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: TelaPdf(obra: _retrato, pagina: pagina),
        ),
      );
      await _esperar(
        tester,
        () => botao(tester, Icons.zoom_in).onPressed != null,
      );
      expect(
        botao(tester, Icons.zoom_in).onPressed,
        isNotNull,
        reason: 'o livro não carregou',
      );
      await _esperar(tester, () => false, vezes: 3);
      return tester.widget<PdfViewer>(find.byType(PdfViewer)).controller!;
    }

    testWidgets('retoma página, posição e zoom sem alterar links explícitos', (
      tester,
    ) async {
      File('${pasta.path}/obras/retrato.pdf.sha256')
          .writeAsStringSync('edicao-teste');
      final guia = GuiaBiblioteca.instancia;
      await guia.guardarLugar(
        _retrato.id,
        const LugarObra(2, 0.7, 'edicao-teste', 100, zoom: 2, horizontal: 0.5),
      );
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: TelaPdf(obra: _retrato, pagina: 0, retomar: true),
        ),
      );
      await _esperar(
        tester,
        () => botao(tester, Icons.zoom_in).onPressed != null,
      );
      await _esperar(tester, () => false, vezes: 4);
      final c = tester.widget<PdfViewer>(find.byType(PdfViewer)).controller!;
      expect(c.pageNumber, 3);
      expect(c.currentZoom / c.coverScale, closeTo(2, 0.03));
      final r = c.layout.pageLayouts[2];
      expect((c.centerPosition.dy - r.top) / r.height, closeTo(0.7, 0.03));
      await c.setZoom(
        Offset(r.center.dx, r.top + r.height * 0.8),
        c.currentZoom,
        duration: Duration.zero,
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(guia.lugar(_retrato.id)!.fracao, closeTo(0.8, 0.03));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(
        const MaterialApp(home: TelaPdf(obra: _retrato, pagina: 1)),
      );
      await _esperar(
        tester,
        () => botao(tester, Icons.zoom_in).onPressed != null,
      );
      await _esperar(tester, () => false, vezes: 3);
      final explicito = tester
          .widget<PdfViewer>(find.byType(PdfViewer))
          .controller!;
      expect(explicito.pageNumber, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }, skip: !temPdfium);

    testWidgets('edição diferente avisa e abre sem aplicar lugar antigo', (
      tester,
    ) async {
      File('${pasta.path}/obras/retrato.pdf.sha256')
          .writeAsStringSync('edicao-nova');
      await GuiaBiblioteca.instancia.guardarLugar(
        _retrato.id,
        const LugarObra(3, 0.8, 'edicao-antiga', 100, zoom: 2),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: TelaPdf(obra: _retrato, pagina: 0, retomar: true),
        ),
      );
      await _esperar(
        tester,
        () => botao(tester, Icons.zoom_in).onPressed != null,
      );
      await _esperar(tester, () => false, vezes: 3);
      final c = tester.widget<PdfViewer>(find.byType(PdfViewer)).controller!;
      expect(c.pageNumber, 1);
      expect(
        find.text(
          'A edição do PDF mudou. Confira o capítulo antes de retomar a leitura.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }, skip: !temPdfium);

    testWidgets('no PC, o livro abre com a página inteira na tela', (
      tester,
    ) async {
      final c = await abrirNoPc(tester, pagina: 2);
      expect(tester.takeException(), isNull);
      expect(c.pageNumber, 3);
      final inteira = c.alternativeFitScale!;
      expect(c.currentZoom, closeTo(inteira, 0.01));
      // Antes abria na largura da tela, quase três vezes maior.
      expect(c.coverScale, greaterThan(inteira * 2));

      // Um passo de zoom aumenta 15%, não o dobro.
      await tester.tap(find.widgetWithIcon(IconButton, Icons.zoom_in));
      await _esperar(tester, () => false, vezes: 4);
      expect(c.currentZoom, closeTo(inteira * 1.15, 0.01));
      await tester.tap(find.widgetWithIcon(IconButton, Icons.zoom_in));
      await _esperar(tester, () => false, vezes: 4);
      expect(c.currentZoom, closeTo(inteira * 1.15 * 1.15, 0.01));

      // "Página inteira" volta, na mesma página.
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.fit_screen_outlined),
      );
      await _esperar(tester, () => false, vezes: 4);
      expect(c.currentZoom, closeTo(inteira, 0.01));
      expect(c.pageNumber, 3);

      // Aproximar num livro não faz o próximo abrir aproximado.
      await tester.tap(find.widgetWithIcon(IconButton, Icons.zoom_in));
      await _esperar(tester, () => false, vezes: 10);
      await tester.pumpWidget(const SizedBox());
      final outro = await abrirNoPc(tester);
      expect(outro.currentZoom, closeTo(outro.alternativeFitScale!, 0.01));
      expect(tester.takeException(), isNull);
    }, skip: !temPdfium);

    testWidgets('pinta os realces das páginas que ainda estavam carregando', (
      tester,
    ) async {
      // Realces nas páginas 2 e 3, que o leitor desenha antes de carregar
      // quando o livro abre na página 1.
      Ajustes.instancia.trocarRealces(
        adicionar: [
          for (final (pagina, cor) in [(2, 1), (3, 2)])
            Realce(
              obra: 81,
              pagina: pagina,
              inicio: inicioMarcos,
              fim: inicioMarcos + 8,
              cor: cor,
              texto: 'Marcos 4',
              nota: pagina == 3 ? 'parábola do semeador' : null,
            ),
        ],
      );
      await tester.pumpWidget(
        const MaterialApp(home: TelaPdf(obra: _obra, pagina: 0)),
      );
      await _esperar(
        tester,
        () => botao(tester, Icons.search).onPressed != null,
      );
      expect(
        botao(tester, Icons.search).onPressed,
        isNotNull,
        reason: 'o livro não carregou',
      );
      await _esperar(tester, () => false, vezes: 5);
      expect(tester.takeException(), isNull);
      final leitor = tester.renderObject(find.byType(PdfViewer));
      PaintPattern pintaCom(Color cor) => paints
        ..something(
          (metodo, args) =>
              metodo == #drawRect &&
              (args[1] as Paint).color.toARGB32() == cor.toARGB32(),
        );
      expect(leitor, pintaCom(coresMarcacao[1]));
      expect(leitor, pintaCom(coresMarcacao[2]));
    }, skip: !temPdfium);

    testWidgets(
      'abre com destaque e a busca conta, avança e aceita Enter repetido',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: TelaPdf(obra: _obra, pagina: 2, destaque: 'Marcos 4'),
          ),
        );
        await _esperar(
          tester,
          () => botao(tester, Icons.search).onPressed != null,
        );
        expect(tester.takeException(), isNull);
        expect(botao(tester, Icons.search).onPressed, isNotNull);

        await tester.tap(find.widgetWithIcon(IconButton, Icons.search));
        await tester.pump();
        // Sem nada digitado, a contagem da citação não aparece.
        expect(find.text('0'), findsNothing);
        await tester.enterText(find.byType(TextField), 'PARABOLA');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await _esperar(tester, () => find.text('1/5').evaluate().isNotEmpty);
        expect(find.text('1/5'), findsOneWidget);

        await tester.tap(
          find.widgetWithIcon(IconButton, Icons.keyboard_arrow_down),
        );
        await tester.pump();
        expect(find.text('2/5'), findsOneWidget);

        // Enter de novo com o mesmo texto: a busca não pode empacar.
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await _esperar(tester, () => false, vezes: 10);
        expect(find.text('2/5'), findsOneWidget);

        // Uma letra a mais, apagada logo: vale o que está no campo.
        await tester.enterText(find.byType(TextField), 'PARABOLAX');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(find.byType(TextField), 'PARABOLA');
        await _esperar(tester, () => false, vezes: 15);
        expect(find.text('1/5'), findsOneWidget);

        // A mesma citação que já estava marcada: vai ao primeiro resultado.
        await tester.enterText(find.byType(TextField), 'Marcos 4');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await _esperar(tester, () => find.text('1/5').evaluate().isNotEmpty);
        expect(find.text('1/5'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.keyboard_arrow_down),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
      skip: !temPdfium,
    );

    testWidgets('celular deitado: letra legível, e a página cabe ao girar', (
      tester,
    ) async {
      final c = await abrirNoPc(tester, tela: const Size(800, 420));
      // A página inteira deixaria a letra miúda: abre no tamanho real.
      expect(c.alternativeFitScale!, lessThan(0.7));
      expect(c.currentZoom, closeTo(1.0, 0.01));

      // Em pé, a página cabe na largura da tela.
      tester.view.physicalSize = const Size(380, 800);
      await _esperar(tester, () => false, vezes: 5);
      expect(c.currentZoom, closeTo(c.coverScale, 0.01));
      expect(c.currentZoom, lessThan(1.0));
      expect(tester.takeException(), isNull);
    }, skip: !temPdfium);
  });
}
