import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:biblia_estudo/dados/ajustes.dart';
import 'package:biblia_estudo/dados/banco.dart';
import 'package:biblia_estudo/dados/temas.dart';
import 'package:biblia_estudo/telas/versiculos_flutuantes.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    Banco.instancia.biblia = db;
    await db.execute(
      'CREATE TABLE versao(id INTEGER, sigla TEXT, nome TEXT, ordem INTEGER)',
    );
    await db.insert('versao', {
      'id': 11,
      'sigla': 'ARA',
      'nome': 'Almeida Revista e Atualizada',
      'ordem': 1,
    });
    await db.insert('versao', {
      'id': 99,
      'sigla': 'NAA',
      'nome': 'Nova Almeida Atualizada',
      'ordem': 2,
    });
    await db.execute(
      'CREATE TABLE versiculo(versao INTEGER, livro INTEGER, capitulo INTEGER, versiculo INTEGER, texto TEXT)',
    );
    for (var v = 1; v <= 14; v++) {
      await db.insert('versiculo', {
        'versao': 99,
        'livro': 43,
        'capitulo': 1,
        'versiculo': v,
        'texto': 'Texto NAA do verso $v.',
      });
      await db.insert('versiculo', {
        'versao': 11,
        'livro': 43,
        'capitulo': 1,
        'versiculo': v,
        'texto': 'Texto ARA do verso $v.',
      });
    }
  });
  tearDownAll(() => Banco.instancia.biblia.close());
  setUp(() async {
    SharedPreferences.setMockInitialValues({'versao': 99});
    await Ajustes.instancia.carregar();
  });

  testWidgets(
    'trechos separados respeitam a tradução e fechar mantém o estudo',
    (tester) async {
      final campo = TextEditingController(text: 'Resposta em andamento');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextField(controller: campo),
                  TextButton(
                    onPressed: () => mostrarVersiculosFlutuantes(context, [
                      [43, 1001, 1004],
                      [43, 1014, 1014],
                    ]),
                    child: const Text('Consultar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Consultar'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('João 1:1-4'), findsOneWidget);
      expect(find.text('João 1:14'), findsOneWidget);
      expect(
        find.textContaining('Texto NAA do verso 1.', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Texto NAA do verso 14.', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Texto NAA do verso 5.', findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining('Texto ARA', findRichText: true),
        findsNothing,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Voltar ao estudo'));
      await tester.pumpAndSettle();
      expect(find.text('Consultar'), findsOneWidget);
      expect(campo.text, 'Resposta em andamento');
      expect(find.byType(VersiculosFlutuantes), findsNothing);
      await tester.pumpWidget(const SizedBox());
      campo.dispose();
    },
  );

  testWidgets('referência ausente explica o resultado sem fechar o estudo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VersiculosFlutuantes(
          passagens: const [Passagem(19, 33009, 33009)],
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(
      find.text('Esta passagem não está disponível nesta tradução.'),
      findsOneWidget,
    );
  });
}
