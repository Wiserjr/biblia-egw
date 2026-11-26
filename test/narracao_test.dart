import 'dart:convert';
import 'dart:io';

import 'package:biblia_estudo/dados/narracao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final n = Narracao.instancia;
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('narracao');
    n.pastaDeTeste = tmp;
    n.esquecer();
  });
  tearDown(() {
    n.obterDeTeste = null;
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  final temposSalmos = utf8.encode(
    jsonEncode({
      'versao': 2,
      'livro': 19,
      'capitulos': {
        '23': {
          'versiculos': [
            [1, 1500],
            [2, 6000],
            [4, 9000],
          ],
          'duracao': 12000,
        },
        '24': {'versiculos': 'lixo'},
      },
    }),
  );

  test('os endereços ficam na release de cada testamento', () {
    expect(
      Narracao.urlCapitulo(19, 23).toString(),
      'https://github.com/Wiserjr/biblia-egw/releases/download/'
      'narracao-ara-at/19-023.mp3',
    );
    expect(
      Narracao.urlTempos(43).toString(),
      'https://github.com/Wiserjr/biblia-egw/releases/download/'
      'narracao-ara-nt/tempos-43.json',
    );
  });

  test('acha o versículo pelo tempo e o tempo pelo versículo', () {
    final g = lerTemposDoLivro(19, jsonDecode(utf8.decode(temposSalmos)))[23]!;
    expect(g.endereco, endsWith('/19-023.mp3'));
    expect(g.versiculoEm(0), 0, reason: 'o anúncio do capítulo');
    expect(g.versiculoEm(1500), 1);
    expect(g.versiculoEm(8999), 2);
    expect(g.versiculoEm(11000), 4);
    expect(g.inicioDe(2), 6000);
    expect(g.inicioDe(3), 9000, reason: 'o 3 está junto com o 4');
    expect(g.inicioDe(9), 12000);
  });

  test('toca pela internet só o que foi publicado, na ARA', () async {
    final pedidos = <String>[];
    n.obterDeTeste = (url) async {
      pedidos.add(url.pathSegments.last);
      return url.path.endsWith('tempos-19.json') ? temposSalmos : null;
    };
    expect(await n.capitulo(2, 19, 23), isNotNull);
    expect(await n.capitulo(2, 19, 24), isNull, reason: 'tempos inválidos');
    expect(await n.capitulo(2, 1, 1), isNull, reason: 'não publicado');
    expect(await n.capitulo(5, 19, 23), isNull, reason: 'só a ARA');
    expect(await n.capitulo(2, 1, 2), isNull);
    expect(pedidos, ['tempos-19.json', 'tempos-01.json'], reason: 'uma vez');
  });

  test('sem internet, usa os tempos da última vez', () async {
    n.obterDeTeste = (url) async => temposSalmos;
    expect(await n.capitulo(2, 19, 23), isNotNull);
    n.esquecer();
    n.obterDeTeste = (url) async => throw const SocketException('sem rede');
    expect(await n.capitulo(2, 19, 23), isNotNull);
    expect(await n.capitulo(2, 20, 1), isNull);
  });
}
