import 'dart:io';

import 'package:archive/archive.dart';
import 'package:biblia_estudo/dados/ajustes.dart';
import 'package:biblia_estudo/dados/banco.dart';
import 'package:biblia_estudo/dados/biblia.dart';
import 'package:biblia_estudo/dados/modelos.dart';
import 'package:biblia_estudo/telas/area_dividida.dart';
import 'package:biblia_estudo/telas/leitor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A tela principal em miniatura: o leitor e o painel, e tocar num versículo
/// abre o painel, como em TelaInicio.
class _Tela extends StatefulWidget {
  const _Tela({required this.versao});
  final Versao versao;

  @override
  State<_Tela> createState() => _TelaState();
}

class _TelaState extends State<_Tela> {
  int? selecionado;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AreaDividida(
      telaLarga: true,
      texto: Leitor(
        key: const ValueKey('Mateus 5'),
        posicao: const Posicao(40, 5),
        versao: widget.versao,
        selecionado: selecionado,
        rolarPara: null,
        aoSelecionar: (v) {
          setState(() => selecionado = v);
          final aj = Ajustes.instancia;
          if (!aj.painelEstudo && aj.abrirPainelAoTocar) aj.painelEstudo = true;
        },
        aoMudarCapitulo: (_) {},
        aoIr: (_) {},
      ),
      painel: const SizedBox.expand(),
    ),
  );
}

void main() {
  late Directory pasta;
  late Versao versao;

  setUpAll(() async {
    pasta = await Directory.systemTemp.createTemp('leitor_lugar_test');
    sqfliteFfiInit();
    for (final nome in ['biblia', 'estudo']) {
      final gz = File('assets/$nome.db.gz').readAsBytesSync();
      final db = File('${pasta.path}/$nome.db')
        ..writeAsBytesSync(const GZipDecoder().decodeBytes(gz));
      final aberto = await databaseFactoryFfiNoIsolate.openDatabase(
        db.path,
        options: OpenDatabaseOptions(readOnly: true),
      );
      if (nome == 'biblia') {
        Banco.instancia.biblia = aberto;
      } else {
        Banco.instancia.estudo = aberto;
      }
    }
    versao = (await Biblia.instancia.versoes()).first;
  });

  tearDownAll(() async {
    // No Windows um arquivo aberto não pode ser apagado: fecha os bancos
    // antes de apagar a pasta.
    await Banco.instancia.biblia.close();
    await Banco.instancia.estudo.close();
    await pasta.delete(recursive: true);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.instancia.carregar();
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: _Tela(versao: versao)));
    for (var i = 0; i < 20 && find.byType(InkWell).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    expect(find.byType(InkWell), findsWidgets, reason: 'o capítulo abriu');
  }

  /// Onde o versículo [n] está na tela.
  Rect lugar(WidgetTester tester, int n) => tester.getRect(
    find.byWidgetPredicate(
      (w) =>
          w.runtimeType.toString() == '_LinhaVersiculo' &&
          ((w as dynamic).versiculo as Versiculo).numero == n,
    ),
  );

  /// Rola até o meio do capítulo e devolve o primeiro versículo que começa
  /// na tela.
  Future<int> rolarAteOMeio(WidgetTester tester) async {
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -3000),
    );
    await tester.pumpAndSettle();
    return [for (var n = 1; n <= 48; n++) n]
        .firstWhere((n) => lugar(tester, n).top >= 0);
  }

  testWidgets('o versículo tocado fica parado quando o painel abre', (
    tester,
  ) async {
    Ajustes.instancia.painelEstudo = false;
    await montar(tester);
    await rolarAteOMeio(tester);
    final alvo = [for (var n = 1; n <= 48; n++) n]
        .firstWhere((n) => lugar(tester, n).top > 400);
    final antes = lugar(tester, alvo).top;
    await tester.tapAt(lugar(tester, alvo).center);
    // Já no primeiro quadro, sem um quadro no lugar errado.
    await tester.pump();
    expect(Ajustes.instancia.painelEstudo, isTrue);
    expect(lugar(tester, alvo).top, closeTo(antes, 1));
    await tester.pumpAndSettle();
    expect(lugar(tester, alvo).top, closeTo(antes, 1));
  });

  testWidgets('fechar e abrir o painel deixa no lugar o versículo do alto', (
    tester,
  ) async {
    await montar(tester);
    final topo = await rolarAteOMeio(tester);
    final antes = lugar(tester, topo).top;

    Ajustes.instancia.painelEstudo = false;
    await tester.pump();
    expect(lugar(tester, topo).top, closeTo(antes, 1));
    Ajustes.instancia.painelEstudo = true;
    await tester.pump();
    expect(lugar(tester, topo).top, closeTo(antes, 1));
    Ajustes.instancia.larguraTexto = 0.6;
    await tester.pump();
    expect(lugar(tester, topo).top, closeTo(antes, 1));
    await tester.pumpAndSettle();
    expect(lugar(tester, topo).top, closeTo(antes, 1));
  });

  testWidgets('o texto não treme enquanto a divisória é arrastada', (
    tester,
  ) async {
    await montar(tester);
    final topo = await rolarAteOMeio(tester);
    final antes = lugar(tester, topo).top;
    final divisoria = find.byWidgetPredicate(
      (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
    );
    final gesto = await tester.startGesture(tester.getCenter(divisoria));
    for (var i = 0; i < 8; i++) {
      await gesto.moveBy(const Offset(-40, 0));
      await tester.pump();
      expect(lugar(tester, topo).top, closeTo(antes, 1), reason: 'passo $i');
    }
    await gesto.up();
    await tester.pumpAndSettle();
    expect(lugar(tester, topo).top, closeTo(antes, 1));
  });

  testWidgets('no começo do capítulo, o título continua à vista', (
    tester,
  ) async {
    await montar(tester);
    final titulo = tester.getRect(find.text('Mateus 5')).top;
    Ajustes.instancia.painelEstudo = false;
    await tester.pumpAndSettle();
    Ajustes.instancia.larguraTexto = 0.4;
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Mateus 5')).top, titulo);
  });
}
