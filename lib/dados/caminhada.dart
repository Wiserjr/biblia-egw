import 'package:flutter/material.dart';

import 'referencias.dart';

/// A caminhada de leitura: os dias em que a pessoa leu a Bíblia, a sequência
/// de dias seguidos e as medalhas. Só contas sobre o que [Ajustes] guarda
/// (dias como "2026-11-25" e capítulos como "43:3"); nada aqui grava.

/// "2026-11-25": o dia de [d] no calendário do aparelho.
String diaIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Número do dia (dias desde 1970) de "2026-11-25", ou null se inválido.
int? numeroDoDia(String iso) {
  final p = iso.split('-');
  if (p.length != 3) return null;
  final a = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (a == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return DateTime.utc(a, m, d).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

int _numero(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// Dias seguidos de leitura até hoje. Quem ainda não leu hoje não perde a
/// sequência até o dia acabar: conta a partir de ontem.
int sequenciaAtual(Iterable<String> dias, DateTime hoje) {
  final n = {for (final d in dias) ?numeroDoDia(d)};
  var dia = _numero(hoje);
  if (!n.contains(dia)) dia--;
  var conta = 0;
  while (n.contains(dia)) {
    conta++;
    dia--;
  }
  return conta;
}

/// A maior sequência de dias seguidos que a pessoa já fez.
int melhorSequencia(Iterable<String> dias) {
  final n = {for (final d in dias) ?numeroDoDia(d)}.toList()..sort();
  var melhor = 0, atual = 0;
  int? anterior;
  for (final d in n) {
    atual = anterior != null && d == anterior + 1 ? atual + 1 : 1;
    if (atual > melhor) melhor = atual;
    anterior = d;
  }
  return melhor;
}

/// Capítulos lidos de cada livro (1 a 66), a partir de "livro:capítulo".
Map<int, int> capitulosPorLivro(Iterable<String> capitulos) {
  final r = <int, int>{};
  for (final c in capitulos) {
    final p = c.split(':');
    if (p.length != 2) continue;
    final l = int.tryParse(p[0]), n = int.tryParse(p[1]);
    if (l == null || n == null || l < 1 || l > 66) continue;
    if (n < 1 || n > Referencias.capitulos[l - 1]) continue;
    r[l] = (r[l] ?? 0) + 1;
  }
  return r;
}

/// Livros lidos do primeiro ao último capítulo.
Set<int> livrosCompletos(Iterable<String> capitulos) => {
  for (final MapEntry(key: l, value: n) in capitulosPorLivro(
    capitulos.toSet(),
  ).entries)
    if (n >= Referencias.capitulos[l - 1]) l,
};

/// Uma medalha da caminhada.
class Medalha {
  const Medalha(this.id, this.titulo, this.descricao, this.icone);

  final String id;
  final String titulo;
  final String descricao;
  final IconData icone;
}

/// Tudo o que conta para as medalhas.
class Caminhada {
  const Caminhada({
    required this.dias,
    required this.capitulos,
    this.oracoesRespondidas = 0,
  });

  final Set<String> dias;
  final Set<String> capitulos;
  final int oracoesRespondidas;

  int get melhor => melhorSequencia(dias);
  Set<int> get livros => livrosCompletos(capitulos);

  /// As medalhas fixas, na ordem em que aparecem.
  static const sequencias = [3, 7, 30, 100, 365];
  static const totais = [10, 50, 100, 365, 1000];

  /// Todas as medalhas que existem, ganhas ou não.
  static List<Medalha> todas() => [
    const Medalha(
      'primeiro-dia',
      'Primeiro passo',
      'Ler a Bíblia pela primeira vez no aplicativo.',
      Icons.directions_walk,
    ),
    for (final n in sequencias)
      Medalha(
        'seguidos-$n',
        '$n dias seguidos',
        'Ler a Bíblia $n dias seguidos, sem falhar nenhum.',
        Icons.local_fire_department,
      ),
    for (final n in totais)
      Medalha(
        'dias-$n',
        '$n dias com a Palavra',
        'Ler a Bíblia em $n dias diferentes, seguidos ou não.',
        Icons.calendar_month,
      ),
    for (var l = 1; l <= 66; l++)
      Medalha(
        'livro-$l',
        Referencias.nome(l),
        'Ler os ${Referencias.capitulos[l - 1]} '
            'capítulo${Referencias.capitulos[l - 1] == 1 ? '' : 's'} '
            'de ${Referencias.nome(l)}.',
        Icons.menu_book,
      ),
    const Medalha(
      'evangelhos',
      'Os quatro evangelhos',
      'Ler Mateus, Marcos, Lucas e João inteiros.',
      Icons.auto_stories,
    ),
    const Medalha(
      'nt',
      'Novo Testamento',
      'Ler os 27 livros do Novo Testamento.',
      Icons.workspace_premium,
    ),
    const Medalha(
      'at',
      'Antigo Testamento',
      'Ler os 39 livros do Antigo Testamento.',
      Icons.workspace_premium,
    ),
    const Medalha(
      'biblia',
      'A Bíblia inteira',
      'Ler os 1.189 capítulos, de Gênesis a Apocalipse.',
      Icons.emoji_events,
    ),
    const Medalha(
      'oracao-respondida',
      'Oração respondida',
      'Marcar um pedido da lista de oração como respondido.',
      Icons.volunteer_activism,
    ),
  ];

  /// Ids das medalhas ganhas.
  Set<String> ganhas() {
    final melhor = this.melhor;
    final livros = this.livros;
    bool todos(int de, int ate) {
      for (var l = de; l <= ate; l++) {
        if (!livros.contains(l)) return false;
      }
      return true;
    }

    return {
      if (dias.isNotEmpty) 'primeiro-dia',
      for (final n in sequencias)
        if (melhor >= n) 'seguidos-$n',
      for (final n in totais)
        if (dias.length >= n) 'dias-$n',
      for (final l in livros) 'livro-$l',
      if (todos(40, 43)) 'evangelhos',
      if (todos(40, 66)) 'nt',
      if (todos(1, 39)) 'at',
      if (todos(1, 66)) 'biblia',
      if (oracoesRespondidas > 0) 'oracao-respondida',
    };
  }
}

/// Medalhas que estão em [depois] e não em [antes], na ordem de
/// [Caminhada.todas].
List<Medalha> medalhasNovas(Set<String> antes, Set<String> depois) => [
  for (final m in Caminhada.todas())
    if (depois.contains(m.id) && !antes.contains(m.id)) m,
];
