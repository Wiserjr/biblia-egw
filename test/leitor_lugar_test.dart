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

  tearDownAll(() => pasta.deleteSync(recursive: true));

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

  testWidgets('o versículo tocado continua à vista quando o painel abre', (
    tester,
  ) async {
    Ajustes.instancia.painelEstudo = false;
    await montar(tester);
    // Rola até o meio do capítulo e toca num versículo no meio da tela.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2400),
    );
    await tester.pumpAndSettle();
    final alvo = [for (var n = 1; n <= 48; n++) n].firstWhere((n) {
      final r = lugar(tester, n);
      return r.top > 300 && r.bottom < 800;
    });
    await tester.tapAt(lugar(tester, alvo).center);
    await tester.pumpAndSettle();

    expect(Ajustes.instancia.painelEstudo, isTrue);
    final depois = lugar(tester, alvo);
    expect(depois.top, greaterThanOrEqualTo(0), reason: '$depois');
    expect(depois.bottom, lessThanOrEqualTo(900), reason: '$depois');
  });

  testWidgets('fechar o painel deixa no lugar o versículo do alto da tela', (
    tester,
  ) async {
    await montar(tester);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -3000),
    );
    await tester.pumpAndSettle();
    // O primeiro versículo que aparece inteiro no alto.
    final topo = [for (var n = 1; n <= 48; n++) n]
        .firstWhere((n) => lugar(tester, n).top >= 0);
    final antes = lugar(tester, topo).top;
    debugPrint('topo $topo antes $antes');

    Ajustes.instancia.painelEstudo = false;
    await tester.pumpAndSettle();
    debugPrint('fechado ${lugar(tester, topo).top}');
    expect(lugar(tester, topo).top, closeTo(antes, 1));

    // E de novo ao abrir, e ao mudar a largura do texto.
    Ajustes.instancia.painelEstudo = true;
    await tester.pumpAndSettle();
    expect(lugar(tester, topo).top, closeTo(antes, 1));
    Ajustes.instancia.larguraTexto = 0.6;
    await tester.pumpAndSettle();
    expect(lugar(tester, topo).top, closeTo(antes, 1));
  });
}
