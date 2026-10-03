import 'package:biblia_estudo/dados/fundos.dart';
import 'package:biblia_estudo/dados/modelos.dart';
import 'package:biblia_estudo/dados/versiculo_do_dia.dart';
import 'package:biblia_estudo/telas/cartao_versiculo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('o calendário tem os 366 dias', () async {
    for (final d in [DateTime(2028, 1, 1), DateTime(2028, 12, 31)]) {
      expect(await VersiculoDoDia.de(d), isNotNull);
    }
    expect(VersiculoDoDia.diaDoAno(DateTime(2026, 10, 3, 23, 30)), 276);
  });

  test('3 de outubro: Êxodo 20:8, o mesmo do Louvor JA', () async {
    final r = (await VersiculoDoDia.de(DateTime(2026, 10, 3)))!;
    expect((r.livro, r.capitulo, r.versiculo, r.ate), (2, 20, 8, 8));
    expect(
      referenciaDaPassagem(Posicao(r.livro, r.capitulo, r.versiculo), r.ate),
      'Êxodo 20:8',
    );
    final r1 = (await VersiculoDoDia.de(DateTime(2026, 1, 1)))!;
    expect(
      referenciaDaPassagem(
        Posicao(r1.livro, r1.capitulo, r1.versiculo),
        r1.ate,
      ),
      'Isaías 43:18-19',
    );
  });

  test('as 21 fotos estão no app e o tema puxa a foto', () async {
    final todos = await Fundos.instancia.todos;
    expect(todos, hasLength(21));
    final f = await Fundos.instancia.sugerir('O Senhor é o meu pastor');
    expect(f.tema, 'cuidado');
  });

  testWidgets('o cartão mostra o texto, a referência e o nome do app', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: CartaoVersiculo(
          inicio: Posicao(19, 23, 1),
          ate: 1,
          texto: 'O Senhor é o meu pastor; nada me faltará.',
          sigla: 'ARA',
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(
      find.text('O Senhor é o meu pastor; nada me faltará.'),
      findsOneWidget,
    );
    expect(find.text('Salmos 23:1  ·  ARA'), findsOneWidget);
    expect(find.text('Bíblia de Estudo'), findsOneWidget);
    expect(find.text('Compartilhar a imagem'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
