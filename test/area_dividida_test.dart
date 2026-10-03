import 'package:biblia_estudo/dados/ajustes.dart';
import 'package:biblia_estudo/telas/area_dividida.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Conta quantas vezes o texto foi criado: abrir ou fechar o painel não pode
/// recriá-lo (perderia a rolagem do capítulo).
class _Texto extends StatefulWidget {
  const _Texto();

  static var criado = 0;

  @override
  State<_Texto> createState() => _TextoState();
}

class _TextoState extends State<_Texto> {
  @override
  void initState() {
    super.initState();
    _Texto.criado++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.instancia.carregar();
    _Texto.criado = 0;
  });

  test('o painel de estudo respeita os limites do texto e do painel', () {
    // 40% de uma tela de 1600.
    expect(larguraDoPainel(1600, 0.4), 640);
    // Os limites dos ajustes: de 20% a 70%.
    expect(larguraDoPainel(1600, 0.05), 320);
    expect(larguraDoPainel(1600, 0.95), 1120);
    // O texto fica com pelo menos 360 (mais a divisória).
    expect(larguraDoPainel(1000, 0.7), 1000 - 360 - 9);
    // E o painel com pelo menos 280, mesmo no limite da divisão.
    expect(larguraDoPainel(900, 0.2), 280);
    expect(larguraDoPainel(600, 0.4), 280);
  });

  test('ajustes da tela: padrão e limites', () {
    final aj = Ajustes.instancia;
    expect(aj.larguraTexto, 1.0, reason: 'o texto ocupa a tela toda');
    expect(aj.painelEstudo, isTrue);
    expect(aj.abrirPainelAoTocar, isTrue);
    expect(aj.larguraPainel, Ajustes.larguraPainelPadrao);
    expect(aj.zoomLivros, 1.0, reason: 'a página inteira');

    aj.larguraTexto = 0.1;
    expect(aj.larguraTexto, Ajustes.minLarguraTexto);
    aj.larguraPainel = 0.95;
    expect(aj.larguraPainel, Ajustes.maxLarguraPainel);
    aj.zoomLivros = 0.5;
    expect(aj.zoomLivros, Ajustes.minZoomLivros);
    aj.zoomLivros = 50;
    expect(aj.zoomLivros, Ajustes.maxZoomLivros);
  });

  group('na tela do PC', () {
    const painel = Key('painel');
    final divisoria = find.byWidgetPredicate(
      (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
    );

    Future<void> montar(WidgetTester tester, {bool telaLarga = true}) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AreaDividida(
              telaLarga: telaLarga,
              texto: const _Texto(),
              painel: const SizedBox.expand(key: painel),
            ),
          ),
        ),
      );
    }

    testWidgets('o painel abre e fecha sem recriar o texto', (tester) async {
      await montar(tester);
      expect(tester.getSize(find.byKey(painel)).width, 640);
      expect(tester.getSize(find.byType(_Texto)).width, 1600 - 640 - 9);

      Ajustes.instancia.painelEstudo = false;
      await tester.pump();
      expect(find.byKey(painel), findsNothing);
      expect(divisoria, findsNothing);
      expect(tester.getSize(find.byType(_Texto)).width, 1600);

      Ajustes.instancia.painelEstudo = true;
      await tester.pump();
      expect(find.byKey(painel), findsOneWidget);
      expect(_Texto.criado, 1);
    });

    testWidgets('arrastar a divisória muda e guarda a largura', (tester) async {
      await montar(tester);
      await tester.drag(divisoria, const Offset(-160, 0));
      await tester.pumpAndSettle();
      final largura = tester.getSize(find.byKey(painel)).width;
      // O arrasto só começa depois de uns pontos de folga.
      expect(largura, inInclusiveRange(780, 800));
      expect(Ajustes.instancia.larguraPainel, closeTo(largura / 1600, 1e-9));

      // Arrastar além do limite para nos 70% (o máximo dos ajustes), e é
      // isso que fica guardado.
      await tester.drag(divisoria, const Offset(-2000, 0));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(painel)).width, 1120);
      expect(Ajustes.instancia.larguraPainel, closeTo(0.7, 1e-9));

      // E volta logo ao arrastar de volta, sem "sobra" guardada.
      await tester.drag(divisoria, const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(painel)).width, lessThan(1000));

      // Dois cliques: a largura padrão.
      await tester.tap(divisoria);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(divisoria);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(painel)).width, 640);
      expect(Ajustes.instancia.larguraPainel, Ajustes.larguraPainelPadrao);
      expect(_Texto.criado, 1);
    });

    testWidgets('tela estreita: sem painel ao lado', (tester) async {
      await montar(tester, telaLarga: false);
      expect(find.byKey(painel), findsNothing);
      expect(tester.getSize(find.byType(_Texto)).width, 1600);
    });
  });
}
