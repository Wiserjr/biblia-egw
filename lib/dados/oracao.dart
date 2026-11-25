/// Um pedido da lista de oração.
///
/// [id] é a hora em que o pedido foi criado, em milissegundos: único o
/// bastante para os aparelhos de uma pessoa, e vira a chave na nuvem
/// (`o_<id>`). [atualizado] decide qual versão fica quando o mesmo pedido
/// mudou em dois lugares.
class Oracao {
  const Oracao({
    required this.id,
    required this.texto,
    this.detalhes,
    required this.atualizado,
    this.respondidaEm,
    this.resposta,
    this.arquivada = false,
  });

  final int id;

  /// Pelo que orar ("Saúde da minha mãe").
  final String texto;

  /// Mais detalhes, se a pessoa quiser.
  final String? detalhes;

  /// Última mudança, em milissegundos.
  final int atualizado;

  /// Quando a pessoa marcou como respondida (milissegundos), ou null.
  final int? respondidaEm;

  /// Como Deus respondeu, com as palavras da pessoa.
  final String? resposta;

  /// Guardada fora da lista de pedidos, sem ter sido marcada como respondida.
  final bool arquivada;

  bool get respondida => respondidaEm != null;
  bool get ativa => !respondida && !arquivada;

  DateTime get criadaEm => DateTime.fromMillisecondsSinceEpoch(id);

  /// Chave do pedido na nuvem.
  String get chave => 'o_$id';

  Oracao copiar({
    String? texto,
    String? detalhes,
    int? atualizado,
    int? respondidaEm,
    bool semResposta = false,
    String? resposta,
    bool? arquivada,
  }) => Oracao(
    id: id,
    texto: texto ?? this.texto,
    detalhes: _limpo(detalhes ?? this.detalhes),
    atualizado: atualizado ?? DateTime.now().millisecondsSinceEpoch,
    respondidaEm: semResposta ? null : (respondidaEm ?? this.respondidaEm),
    resposta: semResposta ? null : _limpo(resposta ?? this.resposta),
    arquivada: arquivada ?? this.arquivada,
  );

  static String? _limpo(String? s) =>
      s == null || s.trim().isEmpty ? null : s.trim();

  Map<String, Object?> paraMapa() => {
    'texto': texto,
    'detalhes': ?detalhes,
    'atualizado': atualizado,
    'respondidaEm': ?respondidaEm,
    'resposta': ?resposta,
    if (arquivada) 'arquivada': true,
  };

  /// O pedido [id] a partir de [paraMapa], ou null se o mapa não servir.
  static Oracao? deMapa(int id, Object? m) {
    if (m is! Map || id <= 0) return null;
    final texto = m['texto'], atualizado = m['atualizado'];
    final detalhes = m['detalhes'], respondidaEm = m['respondidaEm'];
    final resposta = m['resposta'], arquivada = m['arquivada'];
    if (texto is! String || texto.trim().isEmpty || atualizado is! int) {
      return null;
    }
    return Oracao(
      id: id,
      texto: texto.trim(),
      detalhes: detalhes is String ? _limpo(detalhes) : null,
      atualizado: atualizado,
      respondidaEm: respondidaEm is int ? respondidaEm : null,
      resposta: resposta is String ? _limpo(resposta) : null,
      arquivada: arquivada == true,
    );
  }
}
