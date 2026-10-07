import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:biblia_estudo/telas/estudo_interativo.dart';

// O PDF oficial não é distribuído com os testes. Para a conferência nativa,
// fornecer BIBLIA_TEST_DANIEL_PDF e PDFIUM_PATH no ambiente.
void main() {
  final path = Platform.environment['BIBLIA_TEST_DANIEL_PDF'];
  setUpAll(() async {
    if (path != null) await pdfrxInitialize();
    final fonte = Platform.environment['BIBLIA_TEST_FONTE'];
    if (fonte != null) {
      await (FontLoader('LeituraQA')..addFont(
            Future.value(ByteData.sublistView(await File(fonte).readAsBytes())),
          ))
          .load();
    }
    final icones = Platform.environment['BIBLIA_TEST_ICONES'];
    if (icones != null) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(
              ByteData.sublistView(await File(icones).readAsBytes()),
            ),
          ))
          .load();
    }
  });
  testWidgets(
    'Daniel: alternativa sobre o PDF, recorte original e resposta persistida',
    (t) async {
      const hash =
          '9a7391eb2cb16c467e88264f794b82bc2b57a31efa1df3034fb155c7edf0e53e';
      SharedPreferences.setMockInitialValues({'estudo_pdf_pagina_$hash': 61});
      final prefs = await SharedPreferences.getInstance();
      final indice =
          (jsonDecode(
                        File('assets/estudos_interativos.json')
                            .readAsStringSync(),
                      )['estudos']
                      as List)
                  .firstWhere((e) => e['sha256'] == hash)
              as Map;
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final captura = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: captura,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'LeituraQA'),
            home: TelaEstudoInterativo(
              arquivo: File(path!),
              id: hash,
              nome: 'Bíblia Fácil — Daniel',
              prefs: prefs,
              carregarIndice: () async => indice,
            ),
          ),
        ),
      );
      Future<void> aguardar() async {
        for (var i = 0; i < 25; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await t.pump(const Duration(milliseconds: 100));
        }
      }

      await aguardar();
      expect(find.byType(PdfViewer), findsOneWidget);
      final box = find
          .byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).borderRadius ==
                    BorderRadius.circular(2),
          )
          .at(1);
      await t.tapAt(t.getCenter(box));
      await t.pump(const Duration(milliseconds: 500));
      expect(prefs.getString('estudo_interativo_${hash}_p61-q1-opcoes'), '[1]');
      await t.tap(find.text('Responder (7)'));
      await aguardar();
      await t.tap(find.text('Lição 1 • pergunta 1'));
      await aguardar();
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Alternativa 4'), findsOneWidget);
      final saida = Platform.environment['BIBLIA_TEST_CAPTURA'];
      if (saida != null) {
        await t.runAsync(() async {
          final image =
              await (captura.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(saida).writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
      await t.ensureVisible(find.text('Alternativa 4'));
      await t.tap(find.text('Alternativa 4'));
      await t.pump();
      await t.tap(find.text('Salvar resposta'));
      await aguardar();
      expect(prefs.getString('estudo_interativo_${hash}_p61-q1-opcoes'), '[3]');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    skip: path == null,
  );
}
