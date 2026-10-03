import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'modelos.dart';
import 'plano.dart';

/// Preferências e o que a pessoa cria: tradução, letra, tema, onde parou,
/// marcações e anotações. Tudo nas preferências do app, fora dos bancos —
/// trocar o banco numa atualização nunca apaga nada disto.
class Ajustes extends ChangeNotifier {
  Ajustes._();
  static final Ajustes instancia = Ajustes._();

  late SharedPreferences _p;

  Future<void> carregar() async {
    _p = await SharedPreferences.getInstance();
  }

  int? get versao => _p.getInt('versao');
  set versao(int? v) {
    if (v == null) {
      _p.remove('versao');
    } else {
      _p.setInt('versao', v);
    }
    notifyListeners();
  }

  double get tamanhoLetra => _p.getDouble('tamanhoLetra') ?? 18;
  set tamanhoLetra(double v) {
    _p.setDouble('tamanhoLetra', v.clamp(13, 34));
    notifyListeners();
  }

  ThemeMode get tema => ThemeMode.values[_p.getInt('tema') ?? 0];
  set tema(ThemeMode v) {
    _p.setInt('tema', v.index);
    notifyListeners();
  }

  /// Palavras de Jesus em vermelho (nas traduções que as marcam).
  bool get letrasVermelhas => _p.getBool('letrasVermelhas') ?? true;
  set letrasVermelhas(bool v) {
    _p.setBool('letrasVermelhas', v);
    notifyListeners();
  }

  /// Mostrar, ao lado de cada versículo, quantos trechos de Ellen G. White o
  /// citam.
  bool get marcadoresEgw => _p.getBool('marcadoresEgw') ?? true;
  set marcadoresEgw(bool v) {
    _p.setBool('marcadoresEgw', v);
    notifyListeners();
  }

  /// Incluir os pioneiros (Urias Smith, J. N. Andrews...) no estudo.
  bool get mostrarPioneiros => _p.getBool('mostrarPioneiros') ?? true;
  set mostrarPioneiros(bool v) {
    _p.setBool('mostrarPioneiros', v);
    notifyListeners();
  }

  Posicao get ultimaPosicao {
    final l = _p.getInt('ultLivro') ?? 43;
    final c = _p.getInt('ultCapitulo') ?? 1;
    return Posicao(l, c);
  }

  set ultimaPosicao(Posicao p) {
    _p.setInt('ultLivro', p.livro);
    _p.setInt('ultCapitulo', p.capitulo);
  }

  // --- marcações (cor por versículo) e anotações ---

  static String _k(int livro, int cap, int ver) => '$livro:$cap:$ver';

  /// Cor da marcação (índice em [coresMarcacao]) ou null.
  ///
  /// Consultada para cada versículo a cada desenho do leitor: as marcações
  /// ficam num mapa, refeito só quando mudam.
  int? marcacao(int livro, int cap, int ver) =>
      (_marcas ??= _lerMarcas())[_k(livro, cap, ver)];

  Map<String, int>? _marcas;

  Map<String, int> _lerMarcas() {
    final mapa = <String, int>{};
    for (final e in _p.getStringList('marcacoes') ?? const <String>[]) {
      final i = e.indexOf('=');
      final cor = i < 0 ? null : int.tryParse(e.substring(i + 1));
      if (cor != null) mapa[e.substring(0, i)] = cor;
    }
    return mapa;
  }

  void marcar(int livro, int cap, int ver, int? cor) {
    final prefixo = '${_k(livro, cap, ver)}=';
    final m = [
      for (final e in _p.getStringList('marcacoes') ?? const <String>[])
        if (!e.startsWith(prefixo)) e,
    ];
    if (cor != null) m.add('$prefixo$cor');
    _p.setStringList('marcacoes', m);
    _marcas = null;
    notifyListeners();
  }

  /// Todas as marcações: ((livro, capítulo, versículo), cor).
  List<((int, int, int), int)> todasMarcacoes() {
    final r = <((int, int, int), int)>[];
    for (final e in _p.getStringList('marcacoes') ?? const <String>[]) {
      final partes = e.split('=');
      final k = partes[0].split(':').map(int.tryParse).toList();
      final cor = int.tryParse(partes.length > 1 ? partes[1] : '');
      if (k.length == 3 && !k.contains(null) && cor != null) {
        r.add(((k[0]!, k[1]!, k[2]!), cor));
      }
    }
    r.sort((a, b) => _comparar(a.$1, b.$1));
    return r;
  }

  String? anotacao(int livro, int cap, int ver) =>
      _p.getString('nota:${_k(livro, cap, ver)}');

  void anotar(int livro, int cap, int ver, String? texto) {
    final k = 'nota:${_k(livro, cap, ver)}';
    if (texto == null || texto.trim().isEmpty) {
      _p.remove(k);
    } else {
      _p.setString(k, texto.trim());
    }
    notifyListeners();
  }

  List<((int, int, int), String)> todasAnotacoes() {
    final r = <((int, int, int), String)>[];
    for (final k in _p.getKeys()) {
      if (!k.startsWith('nota:')) continue;
      final p = k.substring(5).split(':').map(int.tryParse).toList();
      final t = _p.getString(k);
      if (p.length == 3 && !p.contains(null) && t != null) {
        r.add(((p[0]!, p[1]!, p[2]!), t));
      }
    }
    r.sort((a, b) => _comparar(a.$1, b.$1));
    return r;
  }

  // --- realces nos livros (Ellen G. White e pioneiros) ---

  /// Realces da [obra], na ordem em que estão no livro.
  List<Realce> realces(int obra) => [
    for (final r in todosRealces())
      if (r.obra == obra) r,
  ];

  /// Todos os realces de todos os livros, por livro e página.
  List<Realce> todosRealces() {
    final r = <Realce>[];
    for (final e in _p.getStringList('realces') ?? const <String>[]) {
      final x = Realce.deMapa(_jsonOuNull(e));
      if (x != null) r.add(x);
    }
    r.sort(Realce.comparar);
    return r;
  }

  /// Grava [r], trocando o realce que já cobria exatamente o mesmo trecho.
  void realcar(Realce r) => trocarRealces(adicionar: [r]);

  void apagarRealce(Realce r) => trocarRealces(remover: [r]);

  /// Apaga [remover] e grava [adicionar] (trocando o que já cobria o mesmo
  /// trecho) de uma vez só: uma gravação e um aviso às telas.
  void trocarRealces({
    Iterable<Realce> remover = const [],
    Iterable<Realce> adicionar = const [],
  }) {
    if (remover.isEmpty && adicionar.isEmpty) return;
    final fora = [...remover, ...adicionar];
    _gravarRealces([
      for (final x in todosRealces())
        if (!fora.any(x.mesmoTrecho)) x,
      ...adicionar,
    ]);
  }

  void _gravarRealces(List<Realce> lista) {
    _p.setStringList('realces', [
      for (final r in lista) jsonEncode(r.paraMapa()),
    ]);
    notifyListeners();
  }

  static Object? _jsonOuNull(String s) {
    try {
      return jsonDecode(s);
    } on FormatException {
      return null;
    }
  }

  // --- plano de leitura ---

  /// Id do plano em andamento ([PlanoLeitura.todos]), ou null.
  String? get plano => _p.getString('plano');

  /// Dias do plano já lidos (índices a partir de 0).
  Set<int> get diasLidos => {
    for (final d in _p.getStringList('planoLidos') ?? const <String>[])
      ?int.tryParse(d),
  };

  /// Dia do plano em que a pessoa começou (nos planos por data, contado
  /// desde o início do plano). Os dias antes dele não contam como atrasados.
  int? get planoComecou => _p.getInt('planoComecou');

  /// Começa o plano [id]. Nos planos por data, [comecou] é o dia de hoje; com
  /// [lidosAntes], os dias do ciclo atual antes de hoje já contam como lidos
  /// (para quem já vinha lendo com a igreja).
  void iniciarPlano(
    String id, {
    int? comecou,
    Iterable<int> lidosAntes = const [],
  }) {
    _p.setString('plano', id);
    _p.remove('planoLeuEm');
    if (comecou == null) {
      _p.remove('planoComecou');
    } else {
      _p.setInt('planoComecou', comecou);
    }
    _gravarLidos(lidosAntes.toSet());
    notifyListeners();
  }

  void encerrarPlano() {
    _p.remove('plano');
    _p.remove('planoLidos');
    _p.remove('planoComecou');
    _p.remove('planoLeuEm');
    notifyListeners();
  }

  void marcarDia(int dia, bool lido) => marcarDias([dia], lido);

  void marcarDias(Iterable<int> dias, bool lido) {
    final d = diasLidos;
    lido ? d.addAll(dias) : d.removeAll(dias);
    _gravarLidos(d);
    if (lido) _p.setString('planoLeuEm', _diaDeHoje(DateTime.now()));
    notifyListeners();
  }

  static String _diaDeHoje(DateTime d) => '${d.year}-${d.month}-${d.day}';

  void _gravarLidos(Set<int> d) {
    if (d.isEmpty) {
      _p.remove('planoLidos');
    } else {
      _p.setStringList('planoLidos', [
        for (final x in d.toList()..sort()) '$x',
      ]);
    }
  }

  /// O que ler hoje no plano em andamento, ou null se não houver plano, se a
  /// leitura de hoje já foi feita ou se o plano terminou.
  LeituraHoje? leituraHoje([DateTime? agora]) {
    final pl = PlanoLeitura.porId(plano);
    if (pl == null) return null;
    final lidos = diasLidos;
    if (pl.porData) {
      final hoje = pl.diaDe(agora ?? DateTime.now());
      if (lidos.contains(hoje)) return null;
      return LeituraHoje(
        plano: pl,
        dia: hoje,
        capitulos: pl.leituraDoDia(hoje),
      );
    }
    // Nos planos sem data, depois de ler a porção de hoje a próxima fica
    // para amanhã.
    if (_p.getString('planoLeuEm') == _diaDeHoje(agora ?? DateTime.now())) {
      return null;
    }
    for (var d = 0; d < pl.dias; d++) {
      if (!lidos.contains(d)) {
        return LeituraHoje(plano: pl, dia: d, capitulos: pl.leituras[d]);
      }
    }
    return null;
  }

  // --- lembrete diário ---

  bool get lembrete => _p.getBool('lembrete') ?? false;
  set lembrete(bool v) {
    _p.setBool('lembrete', v);
    notifyListeners();
  }

  /// Hora do lembrete, em minutos desde a meia-noite (padrão: 7h).
  int get lembreteMinutos => _p.getInt('lembreteMinutos') ?? 7 * 60;
  set lembreteMinutos(int v) {
    _p.setInt('lembreteMinutos', v.clamp(0, 24 * 60 - 1));
    notifyListeners();
  }

  // --- cópia de segurança ---

  /// Tudo o que a pessoa criou, para guardar fora do aparelho: marcações,
  /// anotações e o plano de leitura. As preferências de leitura (letra, tema)
  /// ficam de fora: são do aparelho, não do estudo.
  Map<String, Object?> exportar() => {
    'app': 'br.com.wisejr.bibliaestudo',
    'formato': 1,
    'criadoEm': DateTime.now().toUtc().toIso8601String(),
    'marcacoes': {
      for (final (k, cor) in todasMarcacoes()) '${k.$1}:${k.$2}:${k.$3}': cor,
    },
    'anotacoes': {
      for (final (k, texto) in todasAnotacoes())
        '${k.$1}:${k.$2}:${k.$3}': texto,
    },
    'realces': [for (final r in todosRealces()) r.paraMapa()],
    if (plano != null)
      'plano': {
        'id': plano,
        'lidos': diasLidos.toList()..sort(),
        'comecou': ?planoComecou,
      },
  };

  /// Junta uma cópia de [exportar] ao que já está no aparelho, sem apagar
  /// nada: a marcação da cópia vale sobre a local; anotações diferentes do
  /// mesmo versículo ficam as duas, uma abaixo da outra. O plano da cópia só
  /// entra se não houver outro em andamento (ou se for o mesmo plano, quando
  /// os dias lidos se somam).
  ///
  /// Lança [FormatException] se o conteúdo não for uma cópia deste app.
  ({int marcacoes, int anotacoes, int realces}) importar(Object? dados) {
    if (dados is! Map || dados['app'] != 'br.com.wisejr.bibliaestudo') {
      throw const FormatException(
        'Este arquivo não é uma cópia da Bíblia de Estudo.',
      );
    }
    (int, int, int)? chave(Object? k) {
      if (k is! String) return null;
      final p = k.split(':').map(int.tryParse).toList();
      if (p.length != 3 || p.contains(null)) return null;
      final (l, c, v) = (p[0]!, p[1]!, p[2]!);
      if (l < 1 || l > 66 || c < 1 || v < 1) return null;
      return (l, c, v);
    }

    var nMarcas = 0;
    final marcas = _lerMarcas();
    final m = dados['marcacoes'];
    if (m is Map) {
      for (final e in m.entries) {
        final k = chave(e.key);
        final cor = e.value;
        if (k == null || cor is! int || cor < 0) continue;
        marcas[_k(k.$1, k.$2, k.$3)] = cor;
        nMarcas++;
      }
    }
    _p.setStringList('marcacoes', [
      for (final e in marcas.entries) '${e.key}=${e.value}',
    ]);
    _marcas = null;

    var nNotas = 0;
    final a = dados['anotacoes'];
    if (a is Map) {
      for (final e in a.entries) {
        final k = chave(e.key);
        final texto = e.value;
        if (k == null || texto is! String || texto.trim().isEmpty) continue;
        final atual = anotacao(k.$1, k.$2, k.$3);
        final novo = texto.trim();
        final junto = atual == null || atual == novo || atual.contains(novo)
            ? (atual ?? novo)
            : '$atual\n\n$novo';
        _p.setString('nota:${_k(k.$1, k.$2, k.$3)}', junto);
        nNotas++;
      }
    }

    var nRealces = 0;
    final rs = dados['realces'];
    if (rs is List) {
      final lista = todosRealces();
      for (final e in rs) {
        final r = Realce.deMapa(e);
        if (r == null) continue;
        final i = lista.indexWhere((x) => x.mesmoTrecho(r));
        if (i < 0) {
          lista.add(r);
        } else {
          // Restaurar a mesma cópia de novo não repete a anotação.
          final a = lista[i].nota?.trim() ?? '';
          final b = r.nota?.trim() ?? '';
          lista[i] = r.comNota(
            a.isEmpty || a == b || b.isEmpty || a.contains(b)
                ? (a.isEmpty ? b : a)
                : '$a\n\n$b',
          );
        }
        nRealces++;
      }
      _p.setStringList('realces', [
        for (final r in lista) jsonEncode(r.paraMapa()),
      ]);
    }

    final pl = dados['plano'];
    if (pl is Map && PlanoLeitura.porId(pl['id'] as String?) != null) {
      final id = pl['id'] as String;
      if (plano == null || plano == id) {
        final lidos = {
          if (plano == id) ...diasLidos,
          for (final d in (pl['lidos'] as List?) ?? const [])
            if (d is int && d >= 0) d,
        };
        // Vale o começo mais antigo: o que a pessoa leu em qualquer aparelho.
        final c = pl['comecou'];
        final atual = plano == id ? planoComecou : null;
        final comecou = c is int && c >= 0
            ? (atual == null || c < atual ? c : atual)
            : atual;
        _p.setString('plano', id);
        _gravarLidos(lidos);
        if (comecou != null) _p.setInt('planoComecou', comecou);
      }
    }
    notifyListeners();
    return (marcacoes: nMarcas, anotacoes: nNotas, realces: nRealces);
  }

  static int _comparar((int, int, int) x, (int, int, int) y) => x.$1 != y.$1
      ? x.$1.compareTo(y.$1)
      : x.$2 != y.$2
      ? x.$2.compareTo(y.$2)
      : x.$3.compareTo(y.$3);
}

/// Cores das marcações, translúcidas para o texto continuar legível nos dois
/// temas.
const coresMarcacao = <Color>[
  Color(0x66FFD54F), // amarelo
  Color(0x5581C784), // verde
  Color(0x5564B5F6), // azul
  Color(0x55F48FB1), // rosa
  Color(0x55FFB74D), // laranja
];

/// Um trecho realçado (e, se quiser, anotado) num livro em PDF.
///
/// [pagina] conta a partir de 1; [inicio] e [fim] são posições no texto da
/// página como o leitor de PDF o extrai, e [texto] guarda o trecho, para a
/// lista de marcações não precisar abrir o livro.
class Realce {
  const Realce({
    required this.obra,
    required this.pagina,
    required this.inicio,
    required this.fim,
    required this.cor,
    required this.texto,
    this.nota,
  });

  final int obra;
  final int pagina;
  final int inicio;
  final int fim;
  final int cor;
  final String texto;
  final String? nota;

  bool mesmoTrecho(Realce o) =>
      o.obra == obra &&
      o.pagina == pagina &&
      o.inicio == inicio &&
      o.fim == fim;

  /// Se o trecho [inicio]..[fim] da [pagina] encosta neste realce.
  bool sobrepoe(int pagina, int inicio, int fim) =>
      pagina == this.pagina && inicio < this.fim && this.inicio < fim;

  Realce comCor(int cor) => Realce(
    obra: obra,
    pagina: pagina,
    inicio: inicio,
    fim: fim,
    cor: cor,
    texto: texto,
    nota: nota,
  );

  Realce comNota(String? nota) => Realce(
    obra: obra,
    pagina: pagina,
    inicio: inicio,
    fim: fim,
    cor: cor,
    texto: texto,
    nota: nota == null || nota.trim().isEmpty ? null : nota.trim(),
  );

  Map<String, Object?> paraMapa() => {
    'obra': obra,
    'pagina': pagina,
    'inicio': inicio,
    'fim': fim,
    'cor': cor,
    'texto': texto,
    if (nota != null) 'nota': nota,
  };

  static Realce? deMapa(Object? m) {
    if (m is! Map) return null;
    final obra = m['obra'], pagina = m['pagina'];
    final inicio = m['inicio'], fim = m['fim'], cor = m['cor'];
    final texto = m['texto'], nota = m['nota'];
    if (obra is! int ||
        pagina is! int ||
        inicio is! int ||
        fim is! int ||
        cor is! int ||
        texto is! String ||
        pagina < 1 ||
        inicio < 0 ||
        fim <= inicio ||
        cor < 0) {
      return null;
    }
    return Realce(
      obra: obra,
      pagina: pagina,
      inicio: inicio,
      fim: fim,
      cor: cor,
      texto: texto,
      nota: nota is String && nota.trim().isNotEmpty ? nota : null,
    );
  }

  static int comparar(Realce a, Realce b) => a.obra != b.obra
      ? a.obra.compareTo(b.obra)
      : a.pagina != b.pagina
      ? a.pagina.compareTo(b.pagina)
      : a.inicio.compareTo(b.inicio);
}
