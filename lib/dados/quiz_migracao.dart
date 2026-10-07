import 'quiz_biblico.dart';

/// Reconstrói o índice a partir do texto já importado, sem exigir o EPUB de novo.
Map<String, dynamic> atualizarBancoQuiz(
  Map<String, dynamic> livro,
  Map<String, dynamic> indice,
) {
  if (livro['hash'] != indice['sha256Epub']) {
    throw const FormatException('Edição incompatível.');
  }
  if (livro['versaoIndice'] == indice['versao']) return livro;
  final secoes = List<Map<String, dynamic>>.from(livro['secoes']);
  final capitulos = [
    for (var i = 5; i <= 133; i++)
      if (![31, 63, 84, 116].contains(i)) i,
  ];
  if (secoes.length != capitulos.length) {
    throw const FormatException(
      'Importe novamente o EPUB para atualizar as perguntas.',
    );
  }
  final porCapitulo = <int, Map<String, dynamic>>{};
  for (var i = 0; i < secoes.length; i++) {
    porCapitulo[(secoes[i]['capitulo'] as int?) ?? capitulos[i]] = secoes[i];
  }
  String numero(int cap, int n) {
    for (final texto in porCapitulo[cap]!['paragrafos'] as List) {
      final m = RegExp(r'^(\d+)\.\s*(.*)').firstMatch(texto as String);
      if (m != null && int.parse(m[1]!) == n) return m[2]!;
    }
    throw const FormatException(
      'Importe novamente o EPUB para atualizar as perguntas.',
    );
  }

  final perguntas = <Map<String, dynamic>>[];
  for (final item in indice['perguntas'] as List) {
    final cap = item['capitulo'] as int, n = item['numero'] as int;
    final resposta = numero(cap + 53, n)
        .replaceFirst(RegExp(r'\s*\([^)]*\)\.?$'), '')
        .replaceFirst(RegExp(r'\.$'), '')
        .trim();
    final alternativas = [resposta, ...List<String>.from(item['distratores'])];
    if (alternativas.toSet().length != 4) {
      throw const FormatException('Alternativas inconsistentes.');
    }
    perguntas.add(
      PerguntaQuiz(
        item['id'],
        numero(cap, n),
        resposta,
        item['dificuldade'],
        alternativas,
        (item['referencias'] as List).map((r) => List<int>.from(r)).toList(),
      ).toJson(),
    );
  }
  return {...livro, 'versaoIndice': indice['versao'], 'perguntas': perguntas};
}
