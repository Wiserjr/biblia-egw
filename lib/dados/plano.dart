import 'modelos.dart';
import 'referencias.dart';

/// Um plano de leitura: um trecho da Bíblia (de [livroInicial] a
/// [livroFinal], capítulo a capítulo, na ordem do cânon) dividido em [dias]
/// leituras de tamanho parecido.
///
/// Sem [inicio], o progresso é por dia lido, não por data: quem atrasa
/// continua de onde parou, sem uma lista de dias "vencidos" para pôr em dia.
///
/// Com [inicio], o plano segue o calendário: o dia 0 caiu em [inicio] e o
/// plano recomeça sozinho depois do último dia, em ciclos. É assim que a
/// igreja lê o Reavivados por Sua Palavra: no mesmo dia, todos no mesmo
/// capítulo. Os dias lidos guardam o número do dia contado desde [inicio]
/// (no segundo ciclo passam de [dias]).
class PlanoLeitura {
  const PlanoLeitura({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.livroInicial,
    required this.livroFinal,
    required this.dias,
    this.inicio,
  });

  final String id;
  final String nome;
  final String descricao;
  final int livroInicial;
  final int livroFinal;
  final int dias;

  /// Data (em UTC, só o dia) do dia 0, nos planos que seguem o calendário.
  final DateTime? inicio;

  bool get porData => inicio != null;

  /// Reavivados por Sua Palavra: um capítulo por dia, de Gênesis a
  /// Apocalipse, sem pular dias. O ciclo atual começou em 17/04/2025 com
  /// Gênesis 1 (o anterior terminou na véspera com Apocalipse 22) e vai até
  /// 18/07/2028. Conferido no site reavivadosporsuapalavra.org: 25/12/2025 foi
  /// 1 Samuel 17, 01/01/2026 foi 1 Samuel 24 e 03/10/2026 foi o Salmo 57.
  static final reavivados = PlanoLeitura(
    id: 'reavivados',
    nome: 'Reavivados por Sua Palavra',
    descricao:
        'Um capítulo por dia, junto com a igreja: no mesmo dia, todos leem o '
        'mesmo capítulo.',
    livroInicial: 1,
    livroFinal: 66,
    dias: 1189,
    inicio: DateTime.utc(2025, 4, 17),
  );

  static final todos = <PlanoLeitura>[
    reavivados,
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
    PlanoLeitura(
      id: 'capitulo-por-dia',
      nome: 'Um capítulo por dia',
      descricao: 'A Bíblia toda, um capítulo por dia, no seu ritmo.',
      livroInicial: 1,
      livroFinal: 66,
      dias: 1189,
    ),
    PlanoLeitura(
      id: 'salmos-30-dias',
      nome: 'Os Salmos em um mês',
      descricao: 'Cinco salmos por dia.',
      livroInicial: 19,
      livroFinal: 19,
      dias: 30,
    ),
    PlanoLeitura(
      id: 'proverbios-31-dias',
      nome: 'Provérbios em um mês',
      descricao: 'Um capítulo de Provérbios por dia.',
      livroInicial: 20,
      livroFinal: 20,
      dias: 31,
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

  /// O dia do plano em [data] (só o dia conta; a hora é ignorada), nos
  /// planos que seguem o calendário. Pode passar de [dias] (ciclos seguintes)
  /// ou ser negativo (antes de [inicio]).
  int diaDe(DateTime data) =>
      DateTime.utc(data.year, data.month, data.day).difference(inicio!).inDays;

  /// A data de um dia do plano, nos planos que seguem o calendário.
  DateTime dataDe(int dia) => inicio!.add(Duration(days: dia));

  /// A leitura de um dia. Nos planos por data, [dia] pode ser de qualquer
  /// ciclo.
  List<Posicao> leituraDoDia(int dia) => leituras[dia % dias];

  /// Primeiro dia do ciclo em que cai [dia] (planos por data).
  int inicioDoCiclo(int dia) => dia - dia % dias;
}

/// O que ler hoje no plano em andamento.
class LeituraHoje {
  const LeituraHoje({
    required this.plano,
    required this.dia,
    required this.capitulos,
  });

  final PlanoLeitura plano;

  /// O dia do plano (nos planos por data, contado desde o início).
  final int dia;
  final List<Posicao> capitulos;

  String get descricao => descreverLeitura(capitulos);

  /// Na tela inicial: "Reavivados por Sua Palavra: Salmo 57" ou
  /// "Dia 12: Gênesis 34-36".
  String get rotulo => plano.porData
      ? '${plano.nome}: $descricao'
      : 'Dia ${dia + 1}: $descricao';
}

/// Quantos dias lidos em sequência terminam hoje (ou ontem, se hoje ainda
/// não foi lido). Só para planos por data.
int diasSeguidos(Set<int> lidos, int hoje) {
  var d = lidos.contains(hoje) ? hoje : hoje - 1;
  var n = 0;
  while (lidos.contains(d)) {
    n++;
    d--;
  }
  return n;
}

/// Dias do ciclo atual, desde que a pessoa começou, que ficaram sem ler
/// (sem contar hoje). Só para planos por data.
List<int> diasAtrasados(
  PlanoLeitura plano,
  Set<int> lidos,
  int hoje, {
  int? comecou,
}) {
  final ciclo = plano.inicioDoCiclo(hoje);
  final desde = comecou == null || comecou < ciclo ? ciclo : comecou;
  return [
    for (var d = desde; d < hoje; d++)
      if (!lidos.contains(d)) d,
  ];
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
    // Um salmo só: "Salmo 57", como se fala.
    final n = livro == 19 && ini == fim ? 'Salmo' : Referencias.nome(livro);
    partes.add(ini == fim ? '$n $ini' : '$n $ini-$fim');
    i++;
  }
  return partes.join('; ');
}
