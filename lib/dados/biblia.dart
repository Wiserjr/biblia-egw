import 'package:sqflite/sqflite.dart';

import 'banco.dart';
import 'modelos.dart';
import 'traducoes_extras.dart';

/// Consultas ao texto bíblico: o banco embarcado (`biblia.db`) e o das
/// traduções baixadas (`traducoes_extras.db`), com o mesmo esquema.
class Biblia {
  Biblia._();
  static final Biblia instancia = Biblia._();

  Database get _db => Banco.instancia.biblia;
  Database? get _extras => Banco.instancia.extras;

  /// O banco onde mora o texto de uma tradução.
  Database _bancoDe(int versao) =>
      idsBaixaveis.contains(versao) ? _extras ?? _db : _db;

  List<Versao>? _versoes;
  List<Livro>? _livros;

  /// Depois de baixar ou remover uma tradução.
  void esquecerVersoes() => _versoes = null;

  Future<List<Versao>> versoes() async => _versoes ??= await _listarVersoes();

  Future<List<Versao>> _listarVersoes() async {
    const sql = 'SELECT id, sigla, nome, ordem FROM versao';
    final linhas = [
      ...await _db.rawQuery(sql),
      if (_extras case final extras?)
        for (final r in await extras.rawQuery(sql))
          if (idsBaixaveis.contains(r['id'])) r,
    ];
    linhas.sort((a, b) {
      final ordem = (a['ordem'] as int).compareTo(b['ordem'] as int);
      return ordem != 0
          ? ordem
          : (a['sigla'] as String).compareTo(b['sigla'] as String);
    });
    return [
      for (final r in linhas)
        Versao(r['id'] as int, r['sigla'] as String, r['nome'] as String),
    ];
  }

  Future<List<Livro>> livros() async => _livros ??= [
    for (final r in await _db.rawQuery(
      'SELECT numero, nome, abreviacao, testamento, capitulos FROM livro '
      'ORDER BY numero',
    ))
      Livro(
        r['numero'] as int,
        r['nome'] as String,
        r['abreviacao'] as String,
        r['testamento'] as int,
        r['capitulos'] as int,
      ),
  ];

  Future<Livro> livro(int numero) async => (await livros())[numero - 1];

  Future<List<Versiculo>> capitulo(int versao, int livro, int capitulo) async =>
      [
        for (final r in await _bancoDe(versao).rawQuery(
          'SELECT versiculo, texto FROM versiculo '
          'WHERE versao=? AND livro=? AND capitulo=? ORDER BY versiculo',
          [versao, livro, capitulo],
        ))
          Versiculo(r['versiculo'] as int, r['texto'] as String),
      ];

  /// Os versículos de um intervalo `ini..fim` (chaves capítulo*1000+versículo)
  /// — para mostrar o texto de uma referência cruzada. Capítulo inteiro
  /// (`fim % 1000 == 999`) é limitado a [limite] versículos.
  Future<List<(int, int, String)>> intervalo(
    int versao,
    int livro,
    int ini,
    int fim, {
    int limite = 12,
  }) async {
    // ID estável atribuído pelo importador; evita consultas extras por trecho.
    final agrupada = versao == 23;
    final cobertura = agrupada
        ? ' OR EXISTS (SELECT 1 FROM versiculo_intervalo i '
              'WHERE i.versao=versiculo.versao AND i.livro=versiculo.livro '
              'AND i.capitulo=versiculo.capitulo AND i.inicio=versiculo.versiculo '
              'AND i.capitulo*1000+i.inicio <= ? AND i.capitulo*1000+i.fim >= ?)'
        : '';
    final rows = await _bancoDe(versao).rawQuery(
      'SELECT capitulo, versiculo, texto FROM versiculo '
      'WHERE versao=? AND livro=? AND (capitulo*1000+versiculo BETWEEN ? AND ?'
      '$cobertura) '
      'ORDER BY capitulo, versiculo LIMIT ?',
      [
        versao,
        livro,
        ini,
        fim,
        if (agrupada) ...[fim, ini],
        limite,
      ],
    );
    return [
      for (final r in rows)
        (r['capitulo'] as int, r['versiculo'] as int, r['texto'] as String),
    ];
  }

  /// O mesmo versículo em todas as traduções, na ordem de exibição.
  Future<List<(Versao, String)>> comparar(
    int livro,
    int capitulo,
    int versiculo,
  ) async {
    final todas = await versoes();
    final porId = {for (final v in todas) v.id: v};
    const sql =
        'SELECT versao, texto FROM versiculo '
        'WHERE livro=? AND capitulo=? AND versiculo=?';
    final rows = [
      for (final db in [_db, ?_extras])
        ...await db.rawQuery(sql, [livro, capitulo, versiculo]),
    ];
    // A Mensagem mantém trechos agrupados (por exemplo, Gn 1:1–2).
    // Localiza o início do grupo sem duplicar seu texto no leitor.
    if (todas.any((v) => v.sigla == 'MENS')) {
      final grupos = await _bancoDe(23).rawQuery(
        'SELECT x.versao, x.texto FROM versiculo_intervalo i '
        'JOIN versiculo x ON x.versao=i.versao AND x.livro=i.livro '
        'AND x.capitulo=i.capitulo AND x.versiculo=i.inicio '
        'WHERE i.livro=? AND i.capitulo=? AND ? BETWEEN i.inicio+1 AND i.fim',
        [livro, capitulo, versiculo],
      );
      rows.addAll(
        grupos.where((g) => !rows.any((r) => r['versao'] == g['versao'])),
      );
    }
    final visiveis = [
      for (final r in rows)
        if (porId[r['versao']] != null) r,
    ];
    visiveis.sort(
      (a, b) => todas
          .indexOf(porId[a['versao']]!)
          .compareTo(todas.indexOf(porId[b['versao']]!)),
    );
    return [
      for (final r in visiveis) (porId[r['versao']]!, r['texto'] as String),
    ];
  }

  /// Busca palavras numa tradução. Todas as palavras precisam aparecer
  /// (em qualquer ordem); sem diferença de maiúsculas.
  Future<List<(int, int, int, String)>> buscar(
    int versao,
    String consulta, {
    int? testamento,
    int limite = 300,
  }) async {
    final palavras = consulta
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.length > 1)
        .toList();
    if (palavras.isEmpty) return [];
    final filtros = palavras.map((_) => 'texto LIKE ?').join(' AND ');
    final args = <Object>[versao, ...palavras.map((p) => '%$p%')];
    var extra = '';
    if (testamento != null) {
      extra = testamento == 1 ? ' AND livro <= 39' : ' AND livro >= 40';
    }
    final rows = await _bancoDe(versao).rawQuery(
      'SELECT livro, capitulo, versiculo, texto FROM versiculo '
      'WHERE versao=? AND $filtros$extra '
      'ORDER BY livro, capitulo, versiculo LIMIT $limite',
      args,
    );
    return [
      for (final r in rows)
        (
          r['livro'] as int,
          r['capitulo'] as int,
          r['versiculo'] as int,
          r['texto'] as String,
        ),
    ];
  }
}

/// Tira as marcações do texto (`<J>`, `<i>`) — para copiar e compartilhar.
String textoPuro(String texto) => texto.replaceAll(RegExp(r'<[^>]+>'), '');
