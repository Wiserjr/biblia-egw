import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import 'referencias.dart';

/// Uma tradução que pertence a uma editora e por isso não vem no app.
class TraducaoBaixavel {
  const TraducaoBaixavel(
    this.id,
    this.sigla,
    this.nome,
    this.editora,
    this.ordem,
  );

  /// O mesmo ID que ela tinha no banco embarcado da 1.11.0: preferências e
  /// marcações antigas continuam valendo depois do download.
  final int id;
  final String sigla;
  final String nome;
  final String? editora;
  final int ordem;
}

/// A coleção pública de onde vêm os downloads, fixada numa revisão: o texto
/// baixado é sempre o mesmo que foi conferido (ver docs/TRADUCOES_DAMARALS.md).
const fonteTraducoes = 'https://github.com/damarals/biblias';
const revisaoTraducoes = '08bfb8f3d569e5a8dd53a0ebefafda416eb066d7';

/// As versões da coleção damarals/biblias protegidas por direitos autorais.
/// As duas de domínio público (Tradução Brasileira e Almeida 1911) continuam
/// no banco embarcado (ferramentas/importar_damarals.py).
const traducoesBaixaveis = <TraducaoBaixavel>[
  TraducaoBaixavel(16, 'AS21', 'Almeida Século 21', 'Vida Nova', 12),
  TraducaoBaixavel(17, 'JFAA', 'Almeida Atualizada', null, 13),
  TraducaoBaixavel(18, 'KJF', 'King James Fiel', 'BVBooks', 14),
  TraducaoBaixavel(19, 'NBV', 'Nova Bíblia Viva', 'Mundo Cristão', 15),
  TraducaoBaixavel(22, 'OL', 'O Livro', 'Biblica', 18),
  TraducaoBaixavel(23, 'MENS', 'A Mensagem', 'Editora Vida', 19),
  TraducaoBaixavel(
    24,
    'VFL',
    'Versão Fácil de Ler',
    'Bible League International',
    20,
  ),
];

/// IDs que, quando baixados, moram no banco de traduções extras.
final idsBaixaveis = {for (final t in traducoesBaixaveis) t.id};

/// Os nomes dos arquivos da fonte, um por livro, na ordem canônica.
const codigosLivros = <String>[
  'GEN', 'EXO', 'LEV', 'NUM', 'DEU', 'JOS', 'JDG', 'RUT', '1SA', '2SA', //
  '1KI', '2KI', '1CH', '2CH', 'EZR', 'NEH', 'EST', 'JOB', 'PSA', 'PRO',
  'ECC', 'SNG', 'ISA', 'JER', 'LAM', 'EZK', 'DAN', 'HOS', 'JOL', 'AMO',
  'OBA', 'JON', 'MIC', 'NAM', 'HAB', 'ZEP', 'HAG', 'ZEC', 'MAL', 'MAT',
  'MRK', 'LUK', 'JHN', 'ACT', 'ROM', '1CO', '2CO', 'GAL', 'EPH', 'PHP',
  'COL', '1TH', '2TH', '1TI', '2TI', 'TIT', 'PHM', 'HEB', 'JAS', '1PE',
  '2PE', '1JN', '2JN', '3JN', 'JUD', 'REV',
];

Uri urlLivroTraducao(String sigla, int livro) => Uri.https(
  'raw.githubusercontent.com',
  '/damarals/biblias/$revisaoTraducoes/data/canonical/$sigla/'
      '${codigosLivros[livro - 1]}.json',
);

bool urlTraducaoPermitida(Uri url) =>
    url.scheme == 'https' &&
    !url.hasPort &&
    url.userInfo.isEmpty &&
    url.host == 'raw.githubusercontent.com' &&
    url.path.startsWith('/damarals/biblias/$revisaoTraducoes/');

/// Um livro conferido: versículos (capítulo, versículo, texto) e, em A
/// Mensagem, os trechos agrupados (capítulo, início, fim).
typedef LivroTraducao = ({
  List<(int, int, String)> versos,
  List<(int, int, int)> intervalos,
});

final _grupo = RegExp(r'^(\d+)[-–](\d+)\s');

/// Confere um arquivo da fonte com as mesmas regras do importador em Python:
/// o livro certo, todos os capítulos, nenhum versículo vazio ou repetido.
LivroTraducao lerLivroTraducao(String sigla, int livro, String json) {
  FormatException erro(String detalhe) => FormatException(
    'Arquivo inesperado na fonte ($sigla ${codigosLivros[livro - 1]}): '
    '$detalhe.',
  );
  final Object? dados;
  try {
    dados = jsonDecode(json);
  } on FormatException {
    throw erro('não é JSON');
  }
  if (dados is! Map || dados['id'] != livro) throw erro('livro trocado');
  final capitulos = dados['chapters'];
  if (capitulos is! List) throw erro('sem capítulos');
  final versos = <(int, int, String)>[];
  final intervalos = <(int, int, int)>[];
  final vistos = <int>{};
  for (final cap in capitulos) {
    final numero = cap is Map ? cap['number'] : null;
    final lista = cap is Map ? cap['verses'] : null;
    if (numero is! int || lista is! List || lista.isEmpty) {
      throw erro('capítulo inválido');
    }
    if (!vistos.add(numero)) throw erro('capítulo $numero repetido');
    final usados = <int>{};
    for (final verso in lista) {
      final n = verso is Map ? verso['number'] : null;
      final bruto = verso is Map ? verso['text'] : null;
      final texto = bruto is String ? bruto.trim() : '';
      if (n is! int || n < 1 || texto.isEmpty || !usados.add(n)) {
        throw erro('versículo inválido em $numero');
      }
      versos.add((numero, n, texto));
      final g = sigla == 'MENS' ? _grupo.firstMatch(texto) : null;
      if (g != null && int.parse(g[1]!) == n) {
        final fim = int.parse(g[2]!);
        // Cinco rótulos invertidos na fonte: o texto fica, sem associação.
        if (fim >= n) intervalos.add((numero, n, fim));
      }
    }
  }
  final total = Referencias.capitulos[livro - 1];
  if (vistos.length != total || !vistos.every((c) => c >= 1 && c <= total)) {
    throw erro('capítulos incompletos');
  }
  return (versos: versos, intervalos: intervalos);
}

/// As traduções baixadas, num banco próprio e gravável (`traducoes_extras.db`)
/// ao lado do `biblia.db`. Uma atualização do app troca o `biblia.db`, mas não
/// este: o que a pessoa baixou continua lá.
class TraducoesExtras {
  TraducoesExtras({this.obter});

  /// Permite exercitar o download sem rede nos testes.
  final Future<String> Function(Uri)? obter;

  static Future<void> criarEsquema(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS versao (id INTEGER PRIMARY KEY, '
      'sigla TEXT NOT NULL, nome TEXT NOT NULL, ordem INTEGER NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS versiculo (versao INTEGER NOT NULL, '
      'livro INTEGER NOT NULL, capitulo INTEGER NOT NULL, '
      'versiculo INTEGER NOT NULL, texto TEXT NOT NULL, '
      'PRIMARY KEY (versao, livro, capitulo, versiculo)) WITHOUT ROWID',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS versiculo_intervalo (versao INTEGER, '
      'livro INTEGER, capitulo INTEGER, inicio INTEGER, fim INTEGER, '
      'PRIMARY KEY(versao,livro,capitulo,inicio))',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS info (chave TEXT PRIMARY KEY, valor TEXT)',
    );
  }

  static Future<Set<int>> instaladas(Database db) async => {
    for (final r in await db.rawQuery('SELECT id FROM versao')) r['id'] as int,
  };

  /// Baixa os 66 livros, confere cada um e só então grava, numa transação:
  /// uma falha ou um cancelamento no meio não deixa tradução pela metade.
  Future<void> baixar(
    Database db,
    TraducaoBaixavel t, {
    required void Function(double) progresso,
    required bool Function() cancelado,
  }) async {
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final livros = List<LivroTraducao?>.filled(66, null);
      var proximo = 0;
      var prontos = 0;
      var parar = false;
      Future<void> trabalhar() async {
        while (!parar && proximo < 66) {
          final livro = ++proximo;
          try {
            if (cancelado()) throw const TraducaoDownloadCancelado();
            final url = urlLivroTraducao(t.sigla, livro);
            final texto = await (obter?.call(url) ?? _obter(cliente, url));
            if (cancelado()) throw const TraducaoDownloadCancelado();
            livros[livro - 1] = lerLivroTraducao(t.sigla, livro, texto);
            progresso(++prontos / 66);
          } catch (_) {
            parar = true;
            rethrow;
          }
        }
      }

      await Future.wait([for (var i = 0; i < 4; i++) trabalhar()]);
      if (cancelado()) throw const TraducaoDownloadCancelado();
      await db.transaction((txn) async {
        await _apagar(txn, t);
        await txn.insert('versao', {
          'id': t.id,
          'sigla': t.sigla,
          'nome': t.nome,
          'ordem': t.ordem,
        });
        final lote = txn.batch();
        for (var i = 0; i < 66; i++) {
          final livro = livros[i]!;
          for (final (cap, n, texto) in livro.versos) {
            lote.insert('versiculo', {
              'versao': t.id,
              'livro': i + 1,
              'capitulo': cap,
              'versiculo': n,
              'texto': texto,
            });
          }
          for (final (cap, inicio, fim) in livro.intervalos) {
            lote.insert('versiculo_intervalo', {
              'versao': t.id,
              'livro': i + 1,
              'capitulo': cap,
              'inicio': inicio,
              'fim': fim,
            });
          }
        }
        lote.insert('info', {
          'chave': 'fonte_${t.sigla}',
          'valor': jsonEncode({
            'repositorio': fonteTraducoes,
            'revisao': revisaoTraducoes,
            'editora': t.editora,
            'baixado': DateTime.now().toUtc().toIso8601String(),
          }),
        });
        await lote.commit(noResult: true);
      });
    } on SocketException {
      throw const FormatException(
        'Sem conexão. Confira a internet e tente novamente.',
      );
    } on TimeoutException {
      throw const FormatException('A conexão demorou demais. Tente novamente.');
    } on HttpException {
      throw const FormatException(
        'A conexão caiu no meio do download. Tente novamente.',
      );
    } finally {
      cliente.close(force: true);
    }
  }

  static Future<void> remover(Database db, TraducaoBaixavel t) =>
      db.transaction((txn) => _apagar(txn, t));

  static Future<void> _apagar(Transaction txn, TraducaoBaixavel t) async {
    for (final tabela in ['versiculo', 'versiculo_intervalo']) {
      await txn.delete(tabela, where: 'versao=?', whereArgs: [t.id]);
    }
    await txn.delete('versao', where: 'id=?', whereArgs: [t.id]);
    await txn.delete('info', where: 'chave=?', whereArgs: ['fonte_${t.sigla}']);
  }

  static const _limite = 4 * 1024 * 1024;

  Future<String> _obter(HttpClient cliente, Uri url) async {
    if (!urlTraducaoPermitida(url)) {
      throw const FormatException('Endereço da tradução não permitido.');
    }
    final pedido = await cliente.getUrl(url);
    pedido.followRedirects = false;
    final resposta = await pedido.close().timeout(const Duration(seconds: 30));
    if (resposta.statusCode != 200) {
      await resposta.drain<void>().timeout(const Duration(seconds: 30));
      throw const FormatException(
        'A tradução não está disponível na fonte agora. Tente mais tarde.',
      );
    }
    final bytes = BytesBuilder(copy: false);
    await for (final dados in resposta.timeout(const Duration(seconds: 30))) {
      bytes.add(dados);
      if (bytes.length > _limite) {
        throw const FormatException('Arquivo grande demais na fonte.');
      }
    }
    return utf8.decode(bytes.takeBytes());
  }
}

class TraducaoDownloadCancelado implements Exception {
  const TraducaoDownloadCancelado();
}
