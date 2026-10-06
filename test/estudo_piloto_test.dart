import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:biblia_estudo/telas/estudo_piloto.dart';
import 'package:biblia_estudo/telas/licao_original.dart';

void main() {
  testWidgets(
    'WhatsApp abre o endereço original depois de salvar, sem enviar mensagem',
    (tester) async {
      final indice = jsonDecode(
        File('assets/estudo_piloto.json').readAsStringSync(),
      ) as Map;
      final campos = List.generate(12, (_) => TextEditingController());
      final eventos = <String>[];
      Uri? endereco;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LicaoOriginal(
              arquivo: File('unused'),
              indice: indice,
              campos: campos,
              escolhas: const {},
              aoEscolher: (i, j) {},
              aoReferencia: (r) async {},
              aoSalvar: () async {
                eventos.add('salvar');
                return true;
              },
              aoConcluir: () {},
              salvando: false,
              semImagem: true,
              abrirLink: (uri) async {
                eventos.add('abrir');
                endereco = uri;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('WhatsApp'));
      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();
      expect(eventos, ['salvar', 'abrir']);
      expect(endereco!.host, 'api.whatsapp.com');
      expect(endereco!.queryParameters['phone'], '5561981690215');
      expect(endereco!.queryParameters['text'], 'sua mensagem');
      await tester.pumpWidget(const SizedBox());
      for (final campo in campos) {
        campo.dispose();
      }
    },
  );
  testWidgets('respostas e alternativa são recuperadas ao reabrir a lição', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Future<void> abrir() async {
      await tester.pumpWidget(
        MaterialApp(
          home: TelaEstudoPiloto(
            arquivo: File('nao-usado.pdf'),
            prefs: prefs,
            carregarTexto: () async => 'x' * 6000,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await abrir();
    await tester.enterText(find.byType(TextField).first, 'Minha reflexão');
    await tester.ensureVisible(
      find.bySemanticsLabel('Pergunta 1, alternativa 1'),
    );
    await tester.tap(find.bySemanticsLabel('Pergunta 1, alternativa 1'));
    await tester.pump();
    await tester.tap(find.text('Salvar e continuar depois'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await abrir();
    expect(
      (tester.widget<TextField>(find.byType(TextField).first)).controller!.text,
      'Minha reflexão',
    );
    expect(prefs.getInt('piloto_${hashEstudoPiloto}_licao1_escolha_0'), 0);
    expect(
      prefs.getBool('piloto_${hashEstudoPiloto}_licao1_concluida'),
      isNull,
    );
  });

  testWidgets('erro na leitura não oferece uma lição incorreta', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MaterialApp(
        home: TelaEstudoPiloto(
          arquivo: File('nao-usado.pdf'),
          prefs: prefs,
          carregarTexto: () async => throw StateError('PDF inválido'),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(
      find.text('Não foi possível ler a lição nesta edição do PDF.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });
}
