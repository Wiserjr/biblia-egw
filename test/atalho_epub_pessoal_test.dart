import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:biblia_estudo/telas/atalho_epub_pessoal.dart';

void main() {
  testWidgets('link pessoal salva, reaparece, abre e pode ser removido', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    Uri? aberto;
    Future<void> tela() async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AtalhoEpubPessoal(
              key: UniqueKey(),
              abrir: (u) async {
                aberto = u;
                return true;
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    await tela();
    expect(find.text('Baixar meu EPUB'), findsNothing);
    await t.tap(find.text('Adicionar link pessoal de download'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), 'http://exemplo.test/livro');
    await t.tap(find.text('Salvar'));
    await t.pumpAndSettle();
    expect(find.text('Informe um endereço HTTPS válido.'), findsOneWidget);
    await t.enterText(
      find.byType(TextFormField),
      'https://exemplo.test/meu-livro.epub',
    );
    await t.tap(find.text('Salvar'));
    await t.pumpAndSettle();
    await tela();
    await t.tap(find.text('Baixar meu EPUB'));
    await t.pumpAndSettle();
    expect(aberto.toString(), 'https://exemplo.test/meu-livro.epub');
    await t.tap(find.text('Editar meu link de download'));
    await t.pumpAndSettle();
    await t.tap(find.text('Remover'));
    await t.pumpAndSettle();
    expect(find.text('Baixar meu EPUB'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString(
        AtalhoEpubPessoal.chave,
      ),
      null,
    );
  });
  testWidgets('falha ao abrir explica o problema e mantém o link', (t) async {
    SharedPreferences.setMockInitialValues({
      AtalhoEpubPessoal.chave: 'https://exemplo.test/livro',
    });
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AtalhoEpubPessoal(abrir: (_) async => false)),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Baixar meu EPUB'));
    await t.pumpAndSettle();
    expect(
      find.text('Não foi possível abrir o navegador. Confira o link pessoal.'),
      findsOneWidget,
    );
    expect(find.text('Baixar meu EPUB'), findsOneWidget);
  });
}
