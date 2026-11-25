/// Uma passagem que a pessoa está decorando.
///
/// Fica guardada por [livro], [capitulo] e [versiculo] (o primeiro); vai à
/// nuvem como `v_livro_capitulo_versiculo`.
class Memorizacao {
  const Memorizacao({
    required this.livro,
    required this.capitulo,
    required this.versiculo,
    required this.ate,
    required this.criada,
    required this.atualizado,
    this.praticas = 0,
    this.ultimaPratica,
    this.decorada = false,
  });

  final int livro;
  final int capitulo;
  final int versiculo;

  /// Último versículo da passagem (igual a [versiculo] se for um só).
  final int ate;

  /// Quando entrou na lista, em milissegundos.
  final int criada;

  /// Última mudança, em milissegundos: decide qual versão fica.
  final int atualizado;

  /// Quantas vezes a pessoa praticou até o fim.
  final int praticas;

  /// Quando praticou por último, em milissegundos.
  final int? ultimaPratica;

  /// A pessoa disse que já sabe de cor.
  final bool decorada;

  String get posicao => '$livro:$capitulo:$versiculo';
  String get chave => 'v_${livro}_${capitulo}_$versiculo';

  Memorizacao copiar({int? praticas, int? ultimaPratica, bool? decorada}) =>
      Memorizacao(
        livro: livro,
        capitulo: capitulo,
        versiculo: versiculo,
        ate: ate,
        criada: criada,
        atualizado: DateTime.now().millisecondsSinceEpoch,
        praticas: praticas ?? this.praticas,
        ultimaPratica: ultimaPratica ?? this.ultimaPratica,
        decorada: decorada ?? this.decorada,
      );

  Map<String, Object?> paraMapa() => {
    'ate': ate,
    'criada': criada,
    'atualizado': atualizado,
    'praticas': praticas,
    'ultimaPratica': ?ultimaPratica,
    if (decorada) 'decorada': true,
  };

  static Memorizacao? deMapa(
    int livro,
    int capitulo,
    int versiculo,
    Object? m,
  ) {
    if (m is! Map) return null;
    final ate = m['ate'], criada = m['criada'], atualizado = m['atualizado'];
    final praticas = m['praticas'], ultima = m['ultimaPratica'];
    if (livro < 1 || livro > 66 || capitulo < 1 || versiculo < 1) return null;
    if (ate is! int || ate < versiculo || criada is! int) return null;
    if (atualizado is! int) return null;
    return Memorizacao(
      livro: livro,
      capitulo: capitulo,
      versiculo: versiculo,
      ate: ate,
      criada: criada,
      atualizado: atualizado,
      praticas: praticas is int && praticas >= 0 ? praticas : 0,
      ultimaPratica: ultima is int ? ultima : null,
      decorada: m['decorada'] == true,
    );
  }
}

/// Os níveis da prática, do texto inteiro ao texto escondido.
const niveisMemorizar = [
  'Leia com atenção',
  'Complete as palavras que faltam',
  'Só as primeiras letras',
  'Diga de cor',
];

/// O [texto] como aparece no [nivel] (0 a 3) da prática.
///
/// 0: o texto inteiro. 1: uma palavra em cada três vira "____" (a primeira
/// fica, para dar a partida). 2: só a primeira letra de cada palavra,
/// com a pontuação. 3: nada; só a referência ajuda.
String textoDoNivel(String texto, int nivel) {
  final palavras = texto.trim().split(RegExp(r'\s+'));
  switch (nivel) {
    case 0:
      return texto.trim();
    case 1:
      return [
        for (var i = 0; i < palavras.length; i++)
          i % 3 == 2 ? _esconder(palavras[i], (_) => '____') : palavras[i],
      ].join(' ');
    case 2:
      return [
        for (final p in palavras)
          _esconder(p, (miolo) => '${miolo[0]}${'·' * (miolo.length - 1)}'),
      ].join(' ');
    default:
      return '';
  }
}

/// Troca a parte de letras de [palavra] por [troca], mantendo a pontuação
/// em volta ("amor," vira "a···,").
String _esconder(String palavra, String Function(String miolo) troca) {
  final m = RegExp(
    r'^([^\p{L}\p{N}]*)([\p{L}\p{N}].*?)([^\p{L}\p{N}]*)$',
    unicode: true,
  ).firstMatch(palavra);
  if (m == null) return palavra;
  return '${m.group(1)}${troca(m.group(2)!)}${m.group(3)}';
}
