import 'package:biblia_estudo/dados/ajustes.dart';
import 'package:biblia_estudo/dados/vozes.dart';
import 'package:biblia_estudo/telas/vozes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.instancia.carregar();
  });

  test('lista só as vozes em português, a melhor do Brasil primeiro', () {
    final vozes = vozesEmPortugues([
      {'name': 'en-us-x-sfg-local', 'locale': 'en-US', 'quality': 'high'},
      {
        'name': 'pt-br-x-pte-local',
        'locale': 'pt-BR',
        'quality': 'normal',
        'network_required': '0',
        'features': '',
      },
      {
        'name': 'pt-br-x-afs-network',
        'locale': 'pt-BR',
        'quality': 'very high',
        'network_required': '1',
        'features': 'networkTimeoutMs\tnetworkRetriesCount',
      },
      {
        'name': 'pt-pt-x-jfb-local',
        'locale': 'pt-PT',
        'quality': 'very high',
        'network_required': '0',
      },
      {
        'name': 'pt-br-x-ptd-local',
        'locale': 'pt-BR',
        'quality': 'high',
        'features': 'notInstalled',
      },
      {'name': 'pt-br-x-pte-local', 'locale': 'pt-BR', 'quality': 'normal'},
      'lixo',
    ]);
    expect(vozes.map((v) => v.nome), [
      'pt-br-x-afs-network',
      'pt-br-x-pte-local',
      'pt-pt-x-jfb-local',
    ]);
    expect(nomeDaVoz(vozes[1], vozes), 'Voz 2');
    expect(
      detalheDaVoz(vozes.first),
      'Brasil · alta qualidade · mais natural, usa internet',
    );
    expect(detalheDaVoz(vozes.last), 'Portugal · alta qualidade');
  });

  test('as vozes do Windows mantêm o nome', () {
    final vozes = vozesEmPortugues([
      {'name': 'Microsoft Maria', 'locale': 'pt-BR', 'gender': 'female'},
      {'name': 'Microsoft Daniel', 'locale': 'pt-BR', 'gender': 'male'},
    ]);
    expect(vozes.map((v) => nomeDaVoz(v, vozes)), ['Daniel', 'Maria']);
    expect(detalheDaVoz(vozes.last), 'Brasil · feminina');
  });

  test('a voz escolhida fica guardada', () {
    final aj = Ajustes.instancia;
    expect(aj.vozEscolhida, isNull);
    aj.vozEscolhida = ('pt-br-x-afs-network', 'pt-BR');
    expect(aj.vozEscolhida, ('pt-br-x-afs-network', 'pt-BR'));
    expect(descreverVozEscolhida(), 'Escolhida por você');
    aj.vozEscolhida = ('Microsoft Maria', 'pt-BR');
    expect(descreverVozEscolhida(), 'Maria');
    aj.vozEscolhida = null;
    expect(descreverVozEscolhida(), 'A padrão do aparelho');
  });

  testWidgets('a tela mostra as vozes e marca a escolhida', (t) async {
    Ajustes.instancia.vozEscolhida = ('pt-br-x-afs-network', 'pt-BR');
    await t.pumpWidget(
      MaterialApp(
        home: TelaVozes(
          carregar: () async => vozesEmPortugues([
            {
              'name': 'pt-br-x-afs-network',
              'locale': 'pt-BR',
              'quality': 'very high',
              'network_required': '1',
            },
            {'name': 'pt-br-x-pte-local', 'locale': 'pt-BR'},
          ]),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Padrão do aparelho'), findsOneWidget);
    expect(find.text('Voz 1'), findsOneWidget);
    expect(find.text('Voz 2'), findsOneWidget);
    expect(find.textContaining('precisam de internet'), findsOneWidget);
    final marcado = find.descendant(
      of: find.widgetWithText(ListTile, 'Voz 1'),
      matching: find.byIcon(Icons.radio_button_checked),
    );
    expect(marcado, findsOneWidget);
  });
}
