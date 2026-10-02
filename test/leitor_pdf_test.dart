import 'dart:convert';
import 'dart:io';

import 'package:biblia_estudo/dados/ajustes.dart';
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

/// Um PDF de uma página com uma linha de texto, montado à mão.
List<int> _pdfMinimo(String texto) {
  final objetos = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 200] '
        '/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
    null, // conteúdo, abaixo
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  final fluxo = 'BT /F1 12 Tf 20 100 Td ($texto) Tj ET';
  objetos[3] = '<< /Length ${fluxo.length} >>\nstream\n$fluxo\nendstream';
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

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.instancia.carregar();
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

    setUpAll(() async {
      if (!temPdfium) return;
      await pdfrxInitialize();
      pasta = await Directory.systemTemp.createTemp('leitor_pdf_test');
      final obras = Directory('${pasta.path}/obras')..createSync();
      File('${obras.path}/teste.pdf')
          .writeAsBytesSync(_pdfMinimo('Disse Jesus em Marcos 4 a parabola.'));
    });

    tearDownAll(() {
      if (temPdfium) pasta.deleteSync(recursive: true);
    });

    testWidgets('o livro carrega, pinta os realces e libera a busca', (
      tester,
    ) async {
      // Um realce anotado já gravado nesta página ("Marcos 4").
      Ajustes.instancia.realcar(
        const Realce(
          obra: 81,
          pagina: 1,
          inicio: 15,
          fim: 23,
          cor: 2,
          texto: 'Marcos 4',
          nota: 'parábola do semeador',
        ),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (c) async => pasta.path,
          );
      await tester.pumpWidget(
        const MaterialApp(
          home: TelaPdf(obra: _obra, pagina: 0, destaque: 'Marcos 4'),
        ),
      );
      // Carregar o PDF é trabalho de verdade: deixa o tempo correr.
      IconButton lupa() => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.search),
      );
      for (var i = 0; i < 50 && lupa().onPressed == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(PdfViewer), findsOneWidget);
      expect(lupa().onPressed, isNotNull, reason: 'o livro não carregou');

      // Deixa o texto da página carregar e o realce ser pintado.
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);

      // A busca no livro funciona e mostra a contagem.
      await tester.tap(find.widgetWithIcon(IconButton, Icons.search));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'parabola');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      for (var i = 0; i < 30 && find.text('1/1').evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('1/1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, skip: !temPdfium);
  });
}
