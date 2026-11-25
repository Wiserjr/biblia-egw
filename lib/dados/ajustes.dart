import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'caminhada.dart';
import 'modelos.dart';
import 'oracao.dart';
import 'plano.dart';
import 'referencias.dart';
import 'guia_biblioteca.dart';

/// Preferências e o que a pessoa cria: tradução, letra, tema, onde parou,
/// marcações e anotações. Tudo nas preferências do app, fora dos bancos —
/// trocar o banco numa atualização nunca apaga nada disto.
class Ajustes extends ChangeNotifier {
  Ajustes._();
  static final Ajustes instancia = Ajustes._();

  late SharedPreferences _p;

  Future<void> carregar() async {
    _p = await SharedPreferences.getInstance();
    await GuiaBiblioteca.instancia.carregar();
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

  // --- aparência do texto ---

  /// Letra com serifa no texto da Bíblia, como a de livro impresso.
  bool get letraSerifa => _p.getBool('letraSerifa') ?? false;
  set letraSerifa(bool v) {
    _p.setBool('letraSerifa', v);
    notifyListeners();
  }

  /// Altura da linha do texto da Bíblia, em múltiplos do tamanho da letra.
  double get espacoLinhas =>
      (_p.getDouble('espacoLinhas') ?? espacoLinhasPadrao).clamp(
        minEspacoLinhas,
        maxEspacoLinhas,
      );
  set espacoLinhas(double v) {
    _p.setDouble('espacoLinhas', v.clamp(minEspacoLinhas, maxEspacoLinhas));
    notifyListeners();
  }

  static const espacoLinhasPadrao = 1.6;
  static const minEspacoLinhas = 1.2;
  static const maxEspacoLinhas = 2.4;

  /// No tema claro, papel sépia (amarelado) em vez de branco.
  bool get papelSepia => _p.getBool('papelSepia') ?? false;
  set papelSepia(bool v) {
    _p.setBool('papelSepia', v);
    notifyListeners();
  }

  /// No tema escuro, fundo preto e letra mais suave, para ler no escuro.
  bool get poucaLuz => _p.getBool('poucaLuz') ?? false;
  set poucaLuz(bool v) {
    _p.setBool('poucaLuz', v);
    notifyListeners();
  }

  // --- ouvir o capítulo ---

  /// Velocidade da voz: 1 é a normal do aparelho.
  double get velocidadeVoz =>
      (_p.getDouble('velocidadeVoz') ?? 1.0).clamp(0.5, 2.0);
  set velocidadeVoz(double v) {
    _p.setDouble('velocidadeVoz', v.clamp(0.5, 2.0));
    notifyListeners();
  }

  /// Ao terminar um capítulo, a voz segue para o próximo.
  bool get vozContinua => _p.getBool('vozContinua') ?? true;
  set vozContinua(bool v) {
    _p.setBool('vozContinua', v);
    notifyListeners();
  }

  // --- aviso do versículo do dia ---

  bool get avisoVersiculoDoDia => _p.getBool('avisoVersiculoDoDia') ?? false;
  set avisoVersiculoDoDia(bool v) {
    _p.setBool('avisoVersiculoDoDia', v);
    notifyListeners();
  }

  /// Hora do aviso, em minutos desde a meia-noite (padrão: 6h30).
  int get avisoVersiculoMinutos =>
      _p.getInt('avisoVersiculoMinutos') ?? 6 * 60 + 30;
  set avisoVersiculoMinutos(int v) {
    _p.setInt('avisoVersiculoMinutos', v.clamp(0, 24 * 60 - 1));
    notifyListeners();
  }

  // --- tamanho das áreas da tela ---

  /// Quanto da largura do leitor o texto da Bíblia ocupa (1 = tudo). Menos
  /// que isso, o texto fica centralizado, com linhas mais curtas.
  double get larguraTexto =>
      (_p.getDouble('larguraTexto') ?? 1.0).clamp(minLarguraTexto, 1.0);
  set larguraTexto(double v) {
    _p.setDouble('larguraTexto', v.clamp(minLarguraTexto, 1.0));
    notifyListeners();
  }

  static const minLarguraTexto = 0.4;

  /// Em tela larga (PC, tablet deitado), o painel de estudo aberto ao lado do
  /// texto. Fechado, o texto ocupa a tela toda.
  bool get painelEstudo => _p.getBool('painelEstudo') ?? true;
  set painelEstudo(bool v) {
    _p.setBool('painelEstudo', v);
    notifyListeners();
  }

  /// Com o painel fechado, tocar num versículo abre o painel.
  bool get abrirPainelAoTocar => _p.getBool('abrirPainelAoTocar') ?? true;
  set abrirPainelAoTocar(bool v) {
    _p.setBool('abrirPainelAoTocar', v);
    notifyListeners();
  }

  /// Parte da largura da tela que o painel de estudo ocupa.
  double get larguraPainel =>
      (_p.getDouble('larguraPainel') ?? larguraPainelPadrao).clamp(
        minLarguraPainel,
        maxLarguraPainel,
      );
  set larguraPainel(double v) {
    _p.setDouble('larguraPainel', v.clamp(minLarguraPainel, maxLarguraPainel));
    notifyListeners();
  }

  static const larguraPainelPadrao = 0.4;
  static const minLarguraPainel = 0.2;
  static const maxLarguraPainel = 0.7;

  Posicao get ultimaPosicao {
    final l = _p.getInt('ultLivro') ?? 43;
    final c = _p.getInt('ultCapitulo') ?? 1;
    return Posicao(l, c);
  }

  set ultimaPosicao(Posicao p) {
    _p.setInt('ultLivro', p.livro);
    _p.setInt('ultCapitulo', p.capitulo);
    _registrarHistorico(p);
  }

  // --- histórico de leitura ---

  static const maxHistorico = 30;

  /// Os capítulos abertos por último, do mais recente ao mais antigo, sem
  /// repetir, com a hora em que foram abertos.
  List<({Posicao capitulo, DateTime quando})> get historico => [
    for (final e in _p.getStringList('historico') ?? const <String>[])
      ?_lerHistorico(e),
  ];

  static ({Posicao capitulo, DateTime quando})? _lerHistorico(String e) {
    final partes = e.split(':');
    if (partes.length != 3) return null;
    final l = int.tryParse(partes[0]);
    final c = int.tryParse(partes[1]);
    final t = int.tryParse(partes[2]);
    if (l == null || c == null || t == null) return null;
    return (
      capitulo: Posicao(l, c),
      quando: DateTime.fromMillisecondsSinceEpoch(t),
    );
  }

  void _registrarHistorico(Posicao p, [DateTime? agora]) {
    final quando = (agora ?? DateTime.now()).millisecondsSinceEpoch;
    final prefixo = '${p.livro}:${p.capitulo}:';
    final lista = [
      '$prefixo$quando',
      for (final e in _p.getStringList('historico') ?? const <String>[])
        if (!e.startsWith(prefixo)) e,
    ];
    _p.setStringList('historico', lista.take(maxHistorico).toList());
  }

  @visibleForTesting
  void registrarHistorico(Posicao p, DateTime agora) =>
      _registrarHistorico(p, agora);

  void limparHistorico() {
    _p.remove('historico');
    notifyListeners();
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
    _avisar({chaveMarcacao(livro, cap, ver)});
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
    _avisar({chaveAnotacao(livro, cap, ver)});
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
    _avisar({for (final r in fora) r.chave});
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
    _p.remove('planoPorEmDia');
    if (comecou == null) {
      _p.remove('planoComecou');
    } else {
      _p.setInt('planoComecou', comecou);
    }
    _gravarLidos(lidosAntes.toSet());
    notifyListeners();
    _avisar({chavePlano});
  }

  void encerrarPlano() {
    _p.remove('plano');
    _p.remove('planoLidos');
    _p.remove('planoComecou');
    _p.remove('planoLeuEm');
    _p.remove('planoPorEmDia');
    notifyListeners();
    _avisar({chavePlano});
  }

  /// Nos planos por data, a faixa "Leitura de hoje" passa a mostrar os
  /// capítulos que ficaram para trás, do mais antigo ao mais novo, até
  /// chegar ao de hoje. O calendário do plano não muda.
  bool get porEmDia => _p.getBool('planoPorEmDia') ?? false;
  set porEmDia(bool v) {
    if (v) {
      _p.setBool('planoPorEmDia', true);
    } else {
      _p.remove('planoPorEmDia');
    }
    notifyListeners();
  }

  void marcarDia(int dia, bool lido) => marcarDias([dia], lido);

  void marcarDias(Iterable<int> dias, bool lido) {
    final d = diasLidos;
    lido ? d.addAll(dias) : d.removeAll(dias);
    _gravarLidos(d);
    if (lido) _p.setString('planoLeuEm', _diaDeHoje(DateTime.now()));
    final plAtual = PlanoLeitura.porId(plano);
    if (lido && plAtual != null) {
      registrarLeitura(
        capitulos: [for (final dia in dias) ...plAtual.leituraDoDia(dia)],
      );
    }
    // Posto em dia: a faixa volta a mostrar só a leitura de hoje.
    final pl = PlanoLeitura.porId(plano);
    if (porEmDia &&
        pl != null &&
        pl.porData &&
        diasAtrasados(
          pl,
          d,
          pl.diaDe(DateTime.now()),
          comecou: planoComecou,
        ).isEmpty) {
      _p.remove('planoPorEmDia');
    }
    notifyListeners();
    _avisar({chavePlano});
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
      if (porEmDia) {
        final atrasados = diasAtrasados(pl, lidos, hoje, comecou: planoComecou);
        if (atrasados.isNotEmpty) {
          return LeituraHoje(
            plano: pl,
            dia: atrasados.first,
            capitulos: pl.leituraDoDia(atrasados.first),
            faltam: atrasados.length,
          );
        }
      }
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

  // --- respostas pessoais dos estudos bíblicos ---

  static String _kResposta(String estudo, int pergunta) =>
      'respostaEstudo:$estudo:$pergunta';

  /// O que a pessoa escreveu na pergunta [pergunta] (a partir de 1) do
  /// estudo bíblico [estudo], ou ''.
  String respostaEstudo(String estudo, int pergunta) =>
      _p.getString(_kResposta(estudo, pergunta)) ?? '';

  void definirRespostaEstudo(String estudo, int pergunta, String texto) {
    final k = _kResposta(estudo, pergunta);
    if (texto.trim().isEmpty) {
      _p.remove(k);
    } else {
      _p.setString(k, texto);
    }
  }

  /// Todas as respostas pessoais, com a chave "estudo:pergunta".
  Map<String, String> get respostasEstudos => {
    for (final k in _p.getKeys())
      if (k.startsWith('respostaEstudo:'))
        k.substring('respostaEstudo:'.length): _p.getString(k) ?? '',
  };

  // --- versículo do dia ---

  /// A faixa do versículo do dia já foi vista (ou fechada) hoje.
  bool get versiculoDoDiaVisto =>
      _p.getString('versiculoDoDiaVisto') == _diaDeHoje(DateTime.now());

  void marcarVersiculoDoDiaVisto() {
    _p.setString('versiculoDoDiaVisto', _diaDeHoje(DateTime.now()));
    notifyListeners();
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

  // --- caminhada: dias de leitura e capítulos lidos ---

  /// Item da nuvem com os dias em que a pessoa leu ("2026-11-25").
  static const chaveDias = 'diasLeitura';

  /// Item da nuvem com os capítulos lidos ("43:3").
  static const chaveCapitulos = 'capsLidos';

  /// Itens que só crescem: na nuvem e na cópia, o daqui e o de lá se somam.
  static const chavesSomadas = {chaveDias, chaveCapitulos};

  Set<String> get diasDeLeitura => {...?_p.getStringList(chaveDias)};
  Set<String> get capitulosLidos => {...?_p.getStringList(chaveCapitulos)};

  bool leuNoDia(DateTime d) => diasDeLeitura.contains(diaIso(d));

  Caminhada get caminhada => Caminhada(
    dias: diasDeLeitura,
    capitulos: capitulosLidos,
    oracoesRespondidas: oracoes.where((o) => o.respondida).length,
  );

  /// Avisado com as medalhas que a pessoa acabou de ganhar.
  void Function(List<Medalha> novas)? aoGanharMedalhas;

  /// Conta [agora] (padrão: hoje) como dia de leitura e os [capitulos] como
  /// lidos.
  void registrarLeitura({
    Iterable<Posicao> capitulos = const [],
    DateTime? agora,
  }) {
    final antes = caminhada.ganhas();
    final mudou = <String>{};
    final dias = diasDeLeitura;
    if (dias.add(diaIso(agora ?? DateTime.now()))) {
      _p.setStringList(chaveDias, dias.toList()..sort());
      mudou.add(chaveDias);
    }
    final caps = capitulosLidos;
    final n = caps.length;
    for (final c in capitulos) {
      if (c.livro < 1 || c.livro > 66) continue;
      if (c.capitulo < 1 || c.capitulo > _capitulosDoLivro(c.livro)) continue;
      caps.add('${c.livro}:${c.capitulo}');
    }
    if (caps.length != n) {
      _p.setStringList(chaveCapitulos, _ordenarCapitulos(caps));
      mudou.add(chaveCapitulos);
    }
    if (mudou.isEmpty) return;
    notifyListeners();
    _avisar(mudou);
    _verMedalhas(antes);
  }

  static int _capitulosDoLivro(int livro) => Referencias.capitulos[livro - 1];

  static List<String> _ordenarCapitulos(Iterable<String> caps) {
    int k(String c) {
      final p = c.split(':');
      return (int.tryParse(p[0]) ?? 0) * 1000 +
          (int.tryParse(p.length > 1 ? p[1] : '') ?? 0);
    }

    return caps.toList()..sort((a, b) => k(a).compareTo(k(b)));
  }

  void _verMedalhas(Set<String> antes) {
    final novas = medalhasNovas(antes, caminhada.ganhas());
    if (novas.isNotEmpty) aoGanharMedalhas?.call(novas);
  }

  /// Junta [valor] (lista de textos, vinda da nuvem ou da cópia) ao item
  /// somado [chave]. Devolve se algo entrou.
  bool _somar(String chave, Object? valor) {
    if (valor is! List) return false;
    final atual = {...?_p.getStringList(chave)};
    final n = atual.length;
    for (final v in valor) {
      if (v is! String) continue;
      if (chave == chaveDias ? numeroDoDia(v) == null : !_capituloValido(v)) {
        continue;
      }
      atual.add(v);
    }
    if (atual.length == n) return false;
    _p.setStringList(
      chave,
      chave == chaveDias ? (atual.toList()..sort()) : _ordenarCapitulos(atual),
    );
    return true;
  }

  static bool _capituloValido(String c) {
    final p = c.split(':');
    if (p.length != 2) return false;
    final l = int.tryParse(p[0]), n = int.tryParse(p[1]);
    return l != null &&
        n != null &&
        l >= 1 &&
        l <= 66 &&
        n >= 1 &&
        n <= _capitulosDoLivro(l);
  }

  // --- lista de oração ---

  static const _prefixoOracao = 'oracao:';

  /// Todos os pedidos, do mais novo ao mais antigo.
  List<Oracao> get oracoes {
    final r = <Oracao>[];
    for (final k in _p.getKeys()) {
      if (!k.startsWith(_prefixoOracao)) continue;
      final id = int.tryParse(k.substring(_prefixoOracao.length));
      final texto = _p.getString(k);
      if (id == null || texto == null) continue;
      final o = Oracao.deMapa(id, _jsonOuNull(texto));
      if (o != null) r.add(o);
    }
    r.sort((a, b) => b.id.compareTo(a.id));
    return r;
  }

  /// Grava o pedido novo ou mudado.
  void salvarOracao(Oracao o) {
    final antes = caminhada.ganhas();
    _p.setString('$_prefixoOracao${o.id}', jsonEncode(o.paraMapa()));
    notifyListeners();
    _avisar({o.chave});
    _verMedalhas(antes);
  }

  void apagarOracao(Oracao o) {
    _p.remove('$_prefixoOracao${o.id}');
    notifyListeners();
    _avisar({o.chave});
  }

  /// Grava [o] se for novo aqui ou mais recente que o daqui.
  bool _juntarOracao(Oracao o) {
    final k = '$_prefixoOracao${o.id}';
    final atual = Oracao.deMapa(o.id, _jsonOuNull(_p.getString(k) ?? ''));
    if (atual != null && atual.atualizado >= o.atualizado) return false;
    _p.setString(k, jsonEncode(o.paraMapa()));
    return true;
  }

  /// Lembrete diário de oração.
  bool get lembreteOracao => _p.getBool('lembreteOracao') ?? false;
  set lembreteOracao(bool v) {
    _p.setBool('lembreteOracao', v);
    notifyListeners();
  }

  /// Hora do lembrete de oração, em minutos desde a meia-noite (padrão: 21h).
  int get lembreteOracaoMinutos =>
      _p.getInt('lembreteOracaoMinutos') ?? 21 * 60;
  set lembreteOracaoMinutos(int v) {
    _p.setInt('lembreteOracaoMinutos', v.clamp(0, 24 * 60 - 1));
    notifyListeners();
  }

  // --- hoje: meditação matinal e oração ---

  /// O livro de meditações diárias escolhido (id em `obrasMeditacao`).
  int? get meditacaoObra => _p.getInt('meditacaoObra');
  set meditacaoObra(int? v) {
    if (v == null) {
      _p.remove('meditacaoObra');
    } else {
      _p.setInt('meditacaoObra', v);
    }
    notifyListeners();
  }

  bool get meditacaoLidaHoje =>
      _p.getString('meditacaoLidaEm') == _diaDeHoje(DateTime.now());

  void marcarMeditacaoLida() {
    _p.setString('meditacaoLidaEm', _diaDeHoje(DateTime.now()));
    notifyListeners();
  }

  bool get oreiHoje => _p.getString('oreiEm') == _diaDeHoje(DateTime.now());
  set oreiHoje(bool v) {
    if (v) {
      _p.setString('oreiEm', _diaDeHoje(DateTime.now()));
    } else {
      _p.remove('oreiEm');
    }
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
    'plano': ?_planoItem,
    'guiaBiblioteca': GuiaBiblioteca.instancia.exportar(),
    'respostasEstudos': respostasEstudos,
    'diasLeitura': diasDeLeitura.toList()..sort(),
    'capitulosLidos': _ordenarCapitulos(capitulosLidos),
    'oracoes': {for (final o in oracoes) '${o.id}': o.paraMapa()},
  };

  /// O plano em andamento como vai na cópia e na nuvem, ou null.
  Map<String, Object>? get _planoItem => switch (plano) {
    null => null,
    final id => {
      'id': id,
      'lidos': diasLidos.toList()..sort(),
      'comecou': ?planoComecou,
      'leuEm': ?_p.getString('planoLeuEm'),
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
    final antes = aoMudarItens == null ? null : itens();
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
        final novo = plano == null;
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
        // "Já leu hoje" (nos planos sem data) vem junto quando o plano é
        // novo aqui, ou quando este aparelho não sabia.
        final leu = pl['leuEm'];
        if (leu is String && (novo || _p.getString('planoLeuEm') == null)) {
          _p.setString('planoLeuEm', leu);
        }
      }
    }
    GuiaBiblioteca.instancia.importar(dados['guiaBiblioteca']);
    // Respostas dos estudos bíblicos: a da cópia entra onde não há nada;
    // diferente da local, ficam as duas, uma abaixo da outra.
    final re = dados['respostasEstudos'];
    if (re is Map) {
      for (final e in re.entries) {
        final k = e.key;
        final v = e.value;
        if (k is! String || v is! String || v.trim().isEmpty) continue;
        final i = k.lastIndexOf(':');
        final n = i < 0 ? null : int.tryParse(k.substring(i + 1));
        if (n == null || n < 1) continue;
        final estudo = k.substring(0, i);
        final local = respostaEstudo(estudo, n);
        if (local.trim().isEmpty) {
          definirRespostaEstudo(estudo, n, v);
        } else if (!local.contains(v.trim())) {
          definirRespostaEstudo(estudo, n, '$local\n\n${v.trim()}');
        }
      }
    }
    final medalhasAntes = caminhada.ganhas();
    _somar(chaveDias, dados['diasLeitura']);
    _somar(chaveCapitulos, dados['capitulosLidos']);
    final os = dados['oracoes'];
    if (os is Map) {
      for (final e in os.entries) {
        final o = Oracao.deMapa(int.tryParse('${e.key}') ?? 0, e.value);
        if (o != null) _juntarOracao(o);
      }
    }
    notifyListeners();
    if (antes != null) _avisar(itensDiferentes(antes, itens()));
    _verMedalhas(medalhasAntes);
    return (marcacoes: nMarcas, anotacoes: nNotas, realces: nRealces);
  }

  // --- itens da nuvem (ver nuvem.dart) ---

  /// Avisado com as chaves dos itens (ver [itens]) que a pessoa mudou neste
  /// aparelho, para irem à nuvem.
  void Function(Set<String> chaves)? aoMudarItens;

  void _avisar(Set<String> chaves) {
    if (chaves.isNotEmpty) aoMudarItens?.call(chaves);
  }

  static String chaveMarcacao(int livro, int cap, int ver) =>
      'm_${livro}_${cap}_$ver';
  static String chaveAnotacao(int livro, int cap, int ver) =>
      'a_${livro}_${cap}_$ver';
  static const chavePlano = 'plano';

  /// Tudo o que vai para a nuvem, um item por marcação, anotação e realce,
  /// mais o plano de leitura: chave ([chaveMarcacao], [chaveAnotacao],
  /// [Realce.chave], [chavePlano]) e valor em JSON.
  Map<String, Object> itens() => {
    for (final (k, cor) in todasMarcacoes())
      chaveMarcacao(k.$1, k.$2, k.$3): cor,
    for (final (k, texto) in todasAnotacoes())
      chaveAnotacao(k.$1, k.$2, k.$3): texto,
    for (final r in todosRealces()) r.chave: r.paraMapa(),
    chavePlano: ?_planoItem,
    if (diasDeLeitura.isNotEmpty) chaveDias: diasDeLeitura.toList()..sort(),
    if (capitulosLidos.isNotEmpty)
      chaveCapitulos: _ordenarCapitulos(capitulosLidos),
    for (final o in oracoes) o.chave: o.paraMapa(),
  };

  /// Grava, como estão, itens vindos da nuvem (null apaga o item), sem avisar
  /// [aoMudarItens]. Item de chave ou valor inválido fica de fora.
  void aplicarItens(Map<String, Object?> itens) {
    if (itens.isEmpty) return;
    Map<String, int>? marcas;
    List<Realce>? realces;
    for (final MapEntry(key: chave, value: valor) in itens.entries) {
      final partes = chave.split('_');
      final numeros = partes.skip(1).map(int.tryParse).toList();
      if (numeros.contains(null)) continue;
      final n = numeros.cast<int>();
      switch (partes.first) {
        case 'm' when n.length == 3 && _posicaoValida(n):
          marcas ??= _lerMarcas();
          final k = _k(n[0], n[1], n[2]);
          if (valor == null) {
            marcas.remove(k);
          } else if (valor is int && valor >= 0) {
            marcas[k] = valor;
          }
        case 'a' when n.length == 3 && _posicaoValida(n):
          final k = 'nota:${_k(n[0], n[1], n[2])}';
          if (valor == null) {
            _p.remove(k);
          } else if (valor is String && valor.trim().isNotEmpty) {
            _p.setString(k, valor.trim());
          }
        case 'r' when n.length == 4:
          realces ??= todosRealces();
          final r = Realce.deMapa(valor);
          if (valor == null || r?.chave == chave) {
            realces.removeWhere((x) => x.chave == chave);
            if (r != null) realces.add(r);
          }
        case chavePlano when n.isEmpty:
          _aplicarPlano(valor);
        // Só crescem: o que veio se soma ao daqui.
        case chaveDias || chaveCapitulos when n.isEmpty:
          _somar(chave, valor);
        case 'o' when n.length == 1:
          if (valor == null) {
            _p.remove('$_prefixoOracao${n[0]}');
          } else {
            final o = Oracao.deMapa(n[0], valor);
            if (o != null) {
              _p.setString('$_prefixoOracao${o.id}', jsonEncode(o.paraMapa()));
            }
          }
      }
    }
    if (marcas != null) {
      _p.setStringList('marcacoes', [
        for (final e in marcas.entries) '${e.key}=${e.value}',
      ]);
      _marcas = null;
    }
    if (realces != null) {
      _p.setStringList('realces', [
        for (final r in realces) jsonEncode(r.paraMapa()),
      ]);
    }
    notifyListeners();
  }

  static bool _posicaoValida(List<int> n) =>
      n[0] >= 1 && n[0] <= 66 && n[1] >= 1 && n[2] >= 1;

  void _aplicarPlano(Object? valor) {
    if (valor == null) {
      for (final k in ['plano', 'planoLidos', 'planoComecou', 'planoLeuEm']) {
        _p.remove(k);
      }
      return;
    }
    if (valor is! Map) return;
    final id = valor['id'];
    if (id is! String || PlanoLeitura.porId(id) == null) return;
    _p.setString('plano', id);
    _gravarLidos({
      for (final d in (valor['lidos'] as List?) ?? const [])
        if (d is int && d >= 0) d,
    });
    final comecou = valor['comecou'];
    if (comecou is int && comecou >= 0) {
      _p.setInt('planoComecou', comecou);
    } else {
      _p.remove('planoComecou');
    }
    final leu = valor['leuEm'];
    if (leu is String) {
      _p.setString('planoLeuEm', leu);
    } else {
      _p.remove('planoLeuEm');
    }
  }

  /// Junta ao aparelho os [itens] que estão na nuvem, na primeira vez que a
  /// pessoa entra na conta neste aparelho: as mesmas regras de [importar],
  /// sem apagar nada.
  void juntar(Map<String, Object?> itens) {
    final marcacoes = <String, Object?>{};
    final anotacoes = <String, Object?>{};
    final realces = <Object?>[];
    final oracoes = <String, Object?>{};
    Object? plano, dias, capitulos;
    for (final MapEntry(key: chave, value: valor) in itens.entries) {
      final partes = chave.split('_');
      final posicao = partes.skip(1).join(':');
      switch (partes.first) {
        case 'm':
          marcacoes[posicao] = valor;
        case 'a':
          anotacoes[posicao] = valor;
        case 'r':
          realces.add(valor);
        case chavePlano:
          plano = valor;
        case chaveDias:
          dias = valor;
        case chaveCapitulos:
          capitulos = valor;
        case 'o':
          oracoes[posicao] = valor;
      }
    }
    importar({
      'app': 'br.com.wisejr.bibliaestudo',
      'marcacoes': marcacoes,
      'anotacoes': anotacoes,
      'realces': realces,
      'plano': ?plano,
      'diasLeitura': ?dias,
      'capitulosLidos': ?capitulos,
      'oracoes': oracoes,
    });
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

  /// Chave do realce na nuvem: o trecho, sem a cor nem a nota.
  String get chave => 'r_${obra}_${pagina}_${inicio}_$fim';

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

/// JSON com as chaves dos mapas em ordem, para comparar valores que vieram de
/// lugares diferentes.
String jsonCanonico(Object? valor) => jsonEncode(_ordenado(valor));

Object? _ordenado(Object? v) => switch (v) {
  Map() => {
    for (final k in (v.keys.map((k) => '$k').toList()..sort()))
      k: _ordenado(v[k]),
  },
  List() => [for (final x in v) _ordenado(x)],
  _ => v,
};

/// Chaves cujo valor difere entre [a] e [b] (ou que só estão num deles).
Set<String> itensDiferentes(Map<String, Object?> a, Map<String, Object?> b) => {
  for (final k in {...a.keys, ...b.keys})
    if (jsonCanonico(a[k]) != jsonCanonico(b[k])) k,
};
