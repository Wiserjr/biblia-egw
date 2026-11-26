/// As vozes em português que o aparelho oferece para ouvir a Bíblia.
///
/// No Android, o flutter_tts devolve, para cada voz, `name`, `locale`,
/// `quality` ("very high" a "very low"), `network_required` ("1" ou "0") e
/// `features` (separadas por tab; "notInstalled" quando falta baixar). No
/// Windows, `name` (ex.: "Microsoft Maria"), `locale` e `gender`.
class VozTts {
  const VozTts({
    required this.nome,
    required this.local,
    this.qualidade = 0,
    this.internet = false,
    this.genero,
  });

  /// O nome que o motor de voz usa (ex.: "pt-br-x-afs-network").
  final String nome;

  /// O idioma, como "pt-BR".
  final String local;

  /// De 0 (desconhecida) a 5 (muito alta).
  final int qualidade;

  /// A voz é gerada num servidor: mais natural, mas precisa de internet.
  final bool internet;

  /// "male" ou "female", quando o aparelho diz.
  final String? genero;

  bool get brasileira => local.toLowerCase().replaceAll('_', '-') == 'pt-br';

  Map<String, String> paraMotor() => {'name': nome, 'locale': local};

  static const _qualidades = {
    'very high': 5,
    'high': 4,
    'normal': 3,
    'low': 2,
    'very low': 1,
  };

  /// Lê uma voz do formato do flutter_tts, ou null se não serve: outro
  /// idioma, sem nome ou ainda não baixada.
  static VozTts? deMapa(Object? m) {
    if (m is! Map) return null;
    final nome = m['name'], local = m['locale'];
    if (nome is! String || nome.isEmpty || local is! String) return null;
    if (!local.toLowerCase().startsWith('pt')) return null;
    final recursos = '${m['features'] ?? ''}'.split('\t');
    if (recursos.contains('notInstalled')) return null;
    final genero = m['gender'];
    return VozTts(
      nome: nome,
      local: local.replaceAll('_', '-'),
      qualidade: _qualidades['${m['quality']}'] ?? 0,
      internet: '${m['network_required']}' == '1',
      genero: genero is String && genero.isNotEmpty ? genero : null,
    );
  }
}

/// As vozes em português de [lista] (o que o flutter_tts devolve), sem
/// repetir, com as do Brasil primeiro e, entre elas, as de melhor qualidade.
List<VozTts> vozesEmPortugues(Object? lista) {
  if (lista is! List) return const [];
  final vistas = <String>{};
  final vozes = <VozTts>[];
  for (final m in lista) {
    final v = VozTts.deMapa(m);
    if (v != null && vistas.add('${v.local}|${v.nome}')) vozes.add(v);
  }
  vozes.sort((a, b) {
    if (a.brasileira != b.brasileira) return a.brasileira ? -1 : 1;
    if (a.qualidade != b.qualidade) return b.qualidade - a.qualidade;
    if (a.internet != b.internet) return a.internet ? -1 : 1;
    return a.nome.compareTo(b.nome);
  });
  return vozes;
}

/// O nome que aparece na lista de vozes. As do Windows já têm nome de gente
/// ("Maria"); as do Google têm um código ("pt-br-x-afs-network"), então viram
/// "Voz 1", "Voz 2"... na ordem de [vozes].
String nomeDaVoz(VozTts v, List<VozTts> vozes) {
  final limpo = v.nome
      .replaceFirst(RegExp(r'^Microsoft\s+', caseSensitive: false), '')
      .replaceFirst(RegExp(r'\s+-\s+Portuguese.*$', caseSensitive: false), '')
      .trim();
  final codigo = RegExp(r'^[a-z]{2,3}[-_]', caseSensitive: false);
  if (limpo.isNotEmpty && !codigo.hasMatch(limpo) && !limpo.contains('#')) {
    return limpo;
  }
  final i = vozes.indexWhere((o) => o.nome == v.nome && o.local == v.local);
  return 'Voz ${i < 0 ? '' : i + 1}'.trim();
}

/// O que diz a linha de baixo da voz: país, qualidade e internet.
String detalheDaVoz(VozTts v) {
  final partes = <String>[
    v.brasileira ? 'Brasil' : 'Portugal',
    if (v.genero == 'female') 'feminina',
    if (v.genero == 'male') 'masculina',
    if (v.qualidade >= 4) 'alta qualidade',
    if (v.internet) 'mais natural, usa internet',
  ];
  return partes.join(' · ');
}

/// A frase que cada voz lê na amostra.
const amostraDeVoz =
    'No princípio, criou Deus os céus e a terra. '
    'O Senhor é o meu pastor; nada me faltará.';
