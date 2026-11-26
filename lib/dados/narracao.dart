import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A Bíblia narrada com voz neural (ARA), tocada pela internet, capítulo a
/// capítulo, como o YouVersion faz: nada é baixado de antemão.
///
/// Os áudios são gerados no PC do dono por ferramentas/narrar_biblia.py e
/// ficam em duas releases (o GitHub aceita até 1.000 arquivos em cada):
/// [tagAntigo] e [tagNovo]. Cada capítulo é um NN-CCC.mp3, e cada livro tem
/// um tempos-NN.json com o início de cada versículo, para o leitor
/// acompanhar a voz. Sem o tempos do livro (ainda não publicado, ou sem
/// internet), quem lê é a voz do aparelho.
class Narracao {
  Narracao._();
  static final Narracao instancia = Narracao._();

  /// A tradução narrada (ARA no biblia.db).
  static const versao = 2;
  static const tagAntigo = 'narracao-ara-at';
  static const tagNovo = 'narracao-ara-nt';
  static const _base =
      'https://github.com/Wiserjr/biblia-egw/releases/download';

  static String _tag(int livro) => livro <= 39 ? tagAntigo : tagNovo;
  static String _nn(int n) => n.toString().padLeft(2, '0');

  static Uri urlCapitulo(int livro, int cap) => Uri.parse(
    '$_base/${_tag(livro)}/${_nn(livro)}-${cap.toString().padLeft(3, '0')}.mp3',
  );

  static Uri urlTempos(int livro) =>
      Uri.parse('$_base/${_tag(livro)}/tempos-${_nn(livro)}.json');

  /// Para os testes: a pasta do cache, sem o path_provider.
  @visibleForTesting
  Directory? pastaDeTeste;

  /// Para os testes: o que um endereço devolve (null = não existe).
  @visibleForTesting
  Future<List<int>?> Function(Uri url)? obterDeTeste;

  /// Tempos de cada livro já lidos; null = não publicado nesta abertura.
  final _tempos = <int, Map<int, CapituloGravado>?>{};

  /// Esquece o que foi lido (para os testes).
  @visibleForTesting
  void esquecer() => _tempos.clear();

  /// O capítulo narrado, para tocar pela internet, ou null (aí lê a voz do
  /// aparelho).
  Future<CapituloGravado?> capitulo(int versaoId, int livro, int cap) async {
    if (versaoId != versao || livro < 1 || livro > 66) return null;
    if (!_tempos.containsKey(livro)) _tempos[livro] = await _lerTempos(livro);
    return _tempos[livro]?[cap];
  }

  Future<Map<int, CapituloGravado>?> _lerTempos(int livro) async {
    final cache = await _arquivoCache(livro);
    // Da internet primeiro: o livro pode ter sido narrado de novo.
    try {
      final bytes = await _obter(urlTempos(livro));
      if (bytes == null) return null; // ainda não publicado
      final t = lerTemposDoLivro(livro, jsonDecode(utf8.decode(bytes)));
      if (t.isNotEmpty) {
        try {
          await cache?.writeAsBytes(bytes, flush: true);
        } catch (_) {}
        return t;
      }
    } catch (_) {
      // sem internet: o que ficou guardado da última vez
    }
    try {
      if (cache != null && await cache.exists()) {
        final t = lerTemposDoLivro(
          livro,
          jsonDecode(await cache.readAsString()),
        );
        if (t.isNotEmpty) return t;
      }
    } catch (_) {}
    return null;
  }

  Future<File?> _arquivoCache(int livro) async {
    try {
      final base = pastaDeTeste ?? await getApplicationSupportDirectory();
      final d = Directory(p.join(base.path, 'narracao'));
      await d.create(recursive: true);
      return File(p.join(d.path, 'tempos-${_nn(livro)}.json'));
    } catch (_) {
      return null; // nos testes, sem path_provider
    }
  }

  Future<List<int>?> _obter(Uri url) async {
    final teste = obterDeTeste;
    if (teste != null) return teste(url);
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..userAgent = 'BibliaDeEstudo (Android/Windows)';
    try {
      final resp = await (await cliente.getUrl(url))
          .close()
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == HttpStatus.notFound) {
        await resp.drain<void>();
        return null;
      }
      if (resp.statusCode != HttpStatus.ok) {
        await resp.drain<void>();
        throw HttpException('status ${resp.statusCode}');
      }
      final dados = BytesBuilder(copy: false);
      await for (final parte in resp.timeout(const Duration(seconds: 15))) {
        dados.add(parte);
      }
      return dados.takeBytes();
    } finally {
      cliente.close(force: true);
    }
  }
}

/// Os capítulos de um tempos-NN.json:
/// `{"capitulos": {"1": {"versiculos": [[1, 1500], ...], "duracao": ms}}}`.
Map<int, CapituloGravado> lerTemposDoLivro(int livro, Object? json) {
  final r = <int, CapituloGravado>{};
  if (json is! Map) return r;
  final caps = json['capitulos'];
  if (caps is! Map) return r;
  for (final e in caps.entries) {
    final c = int.tryParse('${e.key}');
    if (c == null || c < 1) continue;
    try {
      final g = CapituloGravado.deJson(
        Narracao.urlCapitulo(livro, c).toString(),
        e.value,
      );
      if (g.inicios.isNotEmpty) r[c] = g;
    } catch (_) {}
  }
  return r;
}

/// Um capítulo gravado: o endereço do MP3 e onde começa cada versículo.
class CapituloGravado {
  const CapituloGravado(this.endereco, this.inicios, this.duracao);

  final String endereco;

  /// (versículo, início em milissegundos), em ordem.
  final List<(int, int)> inicios;
  final int duracao;

  static CapituloGravado deJson(String endereco, Object? json) {
    if (json is! Map) throw const FormatException('tempos');
    final lista = json['versiculos'];
    if (lista is! List) throw const FormatException('tempos');
    final inicios = <(int, int)>[
      for (final x in lista)
        if (x is List && x.length == 2 && x[0] is int && x[1] is int)
          (x[0] as int, x[1] as int),
    ];
    final dur = json['duracao'];
    return CapituloGravado(endereco, inicios, dur is int ? dur : 0);
  }

  /// O versículo que está sendo lido em [ms] (0 no anúncio do capítulo).
  int versiculoEm(int ms) {
    var atual = 0;
    for (final (v, inicio) in inicios) {
      if (inicio > ms) break;
      atual = v;
    }
    return atual;
  }

  /// Onde começa o versículo [v] (ou o primeiro depois dele), em ms.
  int inicioDe(int v) {
    for (final (n, inicio) in inicios) {
      if (n >= v) return inicio;
    }
    return duracao;
  }
}
