import 'modelos.dart';
import 'referencias.dart';

/// Um plano de leitura: um trecho da Bíblia (de [livroInicial] a
/// [livroFinal], capítulo a capítulo, na ordem do cânon) dividido em [dias]
/// leituras de tamanho parecido.
///
/// O progresso é por dia lido, não por data: quem atrasa continua de onde
/// parou, sem uma lista de dias "vencidos" para pôr em dia.
class PlanoLeitura {
  const PlanoLeitura({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.livroInicial,
    required this.livroFinal,
    required this.dias,
  });

  final String id;
  final String nome;
  final String descricao;
  final int livroInicial;
  final int livroFinal;
  final int dias;

  static const todos = <PlanoLeitura>[
    PlanoLeitura(
      id: 'biblia-1-ano',
      nome: 'A Bíblia em um ano',
      descricao: 'De Gênesis a Apocalipse, três ou quatro capítulos por dia.',
      livroInicial: 1,
      livroFinal: 66,
      dias: 365,
    ),
    PlanoLeitura(
      id: 'nt-90-dias',
      nome: 'O Novo Testamento em 90 dias',
      descricao: 'De Mateus a Apocalipse, cerca de três capítulos por dia.',
      livroInicial: 40,
      livroFinal: 66,
      dias: 90,
    ),
    PlanoLeitura(
      id: 'evangelhos-30-dias',
      nome: 'Os evangelhos em 30 dias',
      descricao: 'Mateus, Marcos, Lucas e João, três capítulos por dia.',
      livroInicial: 40,
      livroFinal: 43,
      dias: 30,
    ),
  ];

  static PlanoLeitura? porId(String? id) {
    for (final p in todos) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Os capítulos do plano, em ordem.
  List<Posicao> get capitulos => [
    for (var l = livroInicial; l <= livroFinal; l++)
      for (var c = 1; c <= Referencias.capitulos[l - 1]; c++) Posicao(l, c),
  ];

  /// As leituras de cada dia: os capítulos repartidos o mais igualmente
  /// possível (nenhum dia tem mais de um capítulo a mais que outro).
  List<List<Posicao>> get leituras => _leituras[id] ??= () {
    final caps = capitulos;
    return [
      for (var d = 0; d < dias; d++)
        caps.sublist(d * caps.length ~/ dias, (d + 1) * caps.length ~/ dias),
    ];
  }();

  static final _leituras = <String, List<List<Posicao>>>{};
}

/// "Gênesis 1-3", "Gênesis 50; Êxodo 1-2", "Obadias 1".
String descreverLeitura(List<Posicao> caps) {
  final partes = <String>[];
  var i = 0;
  while (i < caps.length) {
    final livro = caps[i].livro;
    final ini = caps[i].capitulo;
    var fim = ini;
    while (i + 1 < caps.length &&
        caps[i + 1].livro == livro &&
        caps[i + 1].capitulo == fim + 1) {
      i++;
      fim = caps[i].capitulo;
    }
    final n = Referencias.nome(livro);
    partes.add(ini == fim ? '$n $ini' : '$n $ini-$fim');
    i++;
  }
  return partes.join('; ');
}
