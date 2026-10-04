import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ajustes.dart';

/// Projeto Firebase da Bíblia de Estudo. A chave não é senha: só diz ao
/// Firebase qual é o projeto. Quem protege os dados são as regras do
/// Firestore, que deixam cada conta ler e gravar só `usuarios/{uid}` (ver
/// README, "Contas na nuvem").
const firebaseChave = 'AIzaSyDXqNS146wMl2Klz-HZ9YunkqfSHGVSYWE';
const firebaseProjeto = 'biblia-de-estudo-d2ce1';

/// Uma resposta HTTP já lida: o código e o corpo em JSON (null se vazio ou
/// se não for JSON).
typedef RespostaHttp = ({int status, Object? corpo});

/// Requisição com corpo JSON. [token] vai no cabeçalho Authorization.
typedef Requisicao = Future<RespostaHttp> Function(
  String metodo,
  Uri url, {
  Object? corpo,
  String? token,
  Map<String, String> cabecalhos,
});

final _http = HttpClient()
  ..connectionTimeout = const Duration(seconds: 15)
  ..idleTimeout = const Duration(seconds: 30)
  ..userAgent = 'BibliaDeEstudo';

/// [Requisicao] de verdade, pela rede.
Future<RespostaHttp> requisicaoHttp(
  String metodo,
  Uri url, {
  Object? corpo,
  String? token,
  Map<String, String> cabecalhos = const {},
}) async {
  try {
    final req = await _http.openUrl(metodo, url);
    req.headers.contentType = ContentType.json;
    if (token != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    cabecalhos.forEach(req.headers.set);
    if (corpo != null) req.add(utf8.encode(jsonEncode(corpo)));
    final resp = await req.close().timeout(const Duration(seconds: 30));
    final texto = await resp
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 60));
    Object? json;
    try {
      json = texto.isEmpty ? null : jsonDecode(texto);
    } on FormatException {
      json = null;
    }
    return (status: resp.statusCode, corpo: json);
  } on SocketException {
    throw FalhaNuvem.conexao;
  } on HttpException {
    throw FalhaNuvem.conexao;
  } on TlsException {
    throw FalhaNuvem.conexao;
  } on TimeoutException {
    throw FalhaNuvem.conexao;
  }
}

/// Erro ao falar com a nuvem, com a mensagem para a pessoa.
class FalhaNuvem implements Exception {
  const FalhaNuvem(
    this.mensagem, {
    this.semConexao = false,
    this.sessaoEncerrada = false,
  });

  final String mensagem;

  /// Sem internet (ou o servidor fora do ar): tentar de novo depois.
  final bool semConexao;

  /// A conta não vale mais neste aparelho (senha trocada, conta excluída):
  /// é preciso entrar de novo.
  final bool sessaoEncerrada;

  static const conexao = FalhaNuvem(
    'Sem conexão com a internet.',
    semConexao: true,
  );

  @override
  String toString() => mensagem;
}

/// A conta conectada neste aparelho. [renovacao] dura até a pessoa sair (ou
/// trocar a senha); [token] vale uma hora e é renovado com ela.
class Sessao {
  Sessao({
    required this.uid,
    required this.email,
    required this.renovacao,
    this.token,
    this.validade,
  });

  final String uid;
  final String email;
  String renovacao;
  String? token;
  DateTime? validade;
}

/// Um item como está na nuvem. [valor] null: apagado.
class ItemNuvem {
  const ItemNuvem(this.chave, this.valor);

  final String chave;
  final Object? valor;
}

/// O Firebase pela API web (REST): a mesma no Android e no Windows, sem os
/// kits nativos (o do Windows ainda é beta).
///
/// Os itens de cada pessoa ficam em `usuarios/{uid}/itens/{chave}`, com o
/// valor em JSON (`json`), `apagado` quando a pessoa o apagou e `atualizado`,
/// a hora do servidor na gravação, que diz o que mudou desde a última vez.
class ClienteFirebase {
  ClienteFirebase({
    Requisicao? requisicao,
    DateTime Function()? agora,
    this.chave = firebaseChave,
    this.projeto = firebaseProjeto,
  }) : _req = requisicao ?? requisicaoHttp,
       _agora = agora ?? DateTime.now;

  final Requisicao _req;
  final DateTime Function() _agora;
  final String chave;
  final String projeto;

  /// Itens por gravação ou consulta (o Firestore aceita até 500 por
  /// gravação).
  static const lote = 500;

  String get _raiz => 'projects/$projeto/databases/(default)/documents';

  Future<Sessao> criarConta(String email, String senha) =>
      _entrar('signUp', email, senha);

  Future<Sessao> entrar(String email, String senha) =>
      _entrar('signInWithPassword', email, senha);

  Future<Sessao> _entrar(String metodo, String email, String senha) async {
    final r = await _auth('accounts:$metodo', {
      'email': email,
      'password': senha,
      'returnSecureToken': true,
    });
    return Sessao(
      uid: r['localId'] as String,
      email: (r['email'] as String?) ?? email,
      renovacao: r['refreshToken'] as String,
      token: r['idToken'] as String,
      validade: _validade(r['expiresIn']),
    );
  }

  /// Manda o e-mail com o link para criar uma senha nova.
  Future<void> redefinirSenha(String email) => _auth(
    'accounts:sendOobCode',
    {'requestType': 'PASSWORD_RESET', 'email': email},
    cabecalhos: const {'X-Firebase-Locale': 'pt-BR'},
  );

  /// Exclui a conta. [s] precisa ter entrado há pouco (com a senha).
  Future<void> excluirConta(Sessao s) =>
      _auth('accounts:delete', {'idToken': s.token});

  /// Troca o [Sessao.token] vencido por um novo.
  Future<void> renovar(Sessao s) async {
    final r = await _req(
      'POST',
      Uri.parse('https://securetoken.googleapis.com/v1/token?key=$chave'),
      corpo: {'grant_type': 'refresh_token', 'refresh_token': s.renovacao},
    );
    final c = r.corpo;
    if (r.status != 200 || c is! Map) throw _falhaAuth(r);
    s.token = c['id_token'] as String;
    s.renovacao = (c['refresh_token'] as String?) ?? s.renovacao;
    s.validade = _validade(c['expires_in']);
  }

  DateTime _validade(Object? segundos) =>
      _agora().add(Duration(seconds: int.tryParse('$segundos') ?? 3600));

  /// Grava os [itens] (null: apagado) de uma vez, em lotes.
  Future<void> gravar(Sessao s, Map<String, Object?> itens) async {
    final lista = itens.entries.toList();
    for (var i = 0; i < lista.length; i += lote) {
      await _firestore(s, '$_raiz:commit', {
        'writes': [
          for (final e in lista.sublist(i, min(i + lote, lista.length)))
            {
              'update': {
                'name': '$_raiz/usuarios/${s.uid}/itens/${e.key}',
                'fields': e.value == null
                    ? {
                        'apagado': {'booleanValue': true},
                      }
                    : {
                        'json': {'stringValue': jsonEncode(e.value)},
                      },
              },
              'updateTransforms': [
                {'fieldPath': 'atualizado', 'setToServerValue': 'REQUEST_TIME'},
              ],
            },
        ],
      });
    }
  }

  /// Os itens gravados depois de [desde] (hora do servidor, como em
  /// [Firestore]; null: todos). [lidoEm] é a hora do servidor na consulta: a
  /// próxima pode começar dali.
  Future<({List<ItemNuvem> itens, String? lidoEm})> buscar(
    Sessao s, {
    String? desde,
  }) async {
    final r = await _documentos(s, desde: desde);
    return (itens: [for (final d in r.documentos) ?_item(d)], lidoEm: r.lidoEm);
  }

  /// Apaga tudo o que a conta tem na nuvem.
  Future<void> apagarDados(Sessao s) async {
    final nomes = [
      for (final d in (await _documentos(s)).documentos)
        if (d['name'] case final String nome) nome,
    ];
    for (var i = 0; i < nomes.length; i += lote) {
      await _firestore(s, '$_raiz:commit', {
        'writes': [
          for (final n in nomes.sublist(i, min(i + lote, nomes.length)))
            {'delete': n},
        ],
      });
    }
  }

  Future<({List<Map> documentos, String? lidoEm})> _documentos(
    Sessao s, {
    String? desde,
  }) async {
    final documentos = <Map>[];
    String? lidoEm;
    Map? ultimo;
    while (true) {
      final consulta = {
        'from': [
          {'collectionId': 'itens'},
        ],
        if (desde != null)
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'atualizado'},
              'op': 'GREATER_THAN',
              'value': {'timestampValue': desde},
            },
          },
        'orderBy': [
          {
            'field': {'fieldPath': 'atualizado'},
            'direction': 'ASCENDING',
          },
          {
            'field': {'fieldPath': '__name__'},
            'direction': 'ASCENDING',
          },
        ],
        'limit': lote,
        if (ultimo != null)
          'startAt': {
            'values': [
              (ultimo['fields'] as Map)['atualizado'],
              {'referenceValue': ultimo['name']},
            ],
            'before': false,
          },
      };
      final r = await _firestore(s, '$_raiz/usuarios/${s.uid}:runQuery', {
        'structuredQuery': consulta,
      });
      var n = 0;
      for (final e in r is List ? r : const []) {
        if (e is! Map) continue;
        // A hora da primeira página: o que for gravado durante a consulta
        // fica para a próxima.
        lidoEm ??= e['readTime'] as String?;
        final d = e['document'];
        if (d is! Map) continue;
        documentos.add(d);
        ultimo = d;
        n++;
      }
      if (n < lote) break;
    }
    return (documentos: documentos, lidoEm: lidoEm);
  }

  static ItemNuvem? _item(Map d) {
    final nome = d['name'];
    final campos = d['fields'];
    if (nome is! String || campos is! Map) return null;
    final chave = nome.substring(nome.lastIndexOf('/') + 1);
    if ((campos['apagado'] as Map?)?['booleanValue'] == true) {
      return ItemNuvem(chave, null);
    }
    final json = (campos['json'] as Map?)?['stringValue'];
    if (json is! String) return null;
    try {
      return ItemNuvem(chave, jsonDecode(json));
    } on FormatException {
      return null;
    }
  }

  Future<Map> _auth(
    String caminho,
    Map<String, Object?> corpo, {
    Map<String, String> cabecalhos = const {},
  }) async {
    final r = await _req(
      'POST',
      Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/$caminho?key=$chave',
      ),
      corpo: corpo,
      cabecalhos: cabecalhos,
    );
    final c = r.corpo;
    if (r.status == 200 && c is Map) return c;
    throw _falhaAuth(r);
  }

  /// Chama o Firestore com um token válido, renovando-o se for preciso.
  Future<Object?> _firestore(Sessao s, String caminho, Object corpo) async {
    for (var tentativa = 0; ; tentativa++) {
      final validade = s.validade;
      if (s.token == null ||
          validade == null ||
          _agora().isAfter(validade.subtract(const Duration(minutes: 1)))) {
        await renovar(s);
      }
      final r = await _req(
        'POST',
        Uri.parse('https://firestore.googleapis.com/v1/$caminho'),
        corpo: corpo,
        token: s.token,
      );
      if (r.status == 200) return r.corpo;
      if (r.status == 401 && tentativa == 0) {
        s.token = null;
        continue;
      }
      throw _falhaFirestore(r);
    }
  }

  static String? _erro(RespostaHttp r) {
    final c = r.corpo;
    final e = c is Map ? c['error'] : null;
    return e is Map ? e['message'] as String? : null;
  }

  static FalhaNuvem _falhaAuth(RespostaHttp r) {
    // "WEAK_PASSWORD : Password should be at least 6 characters"
    final codigo = (_erro(r) ?? '').split(RegExp(r'[ :]')).first;
    if (r.status >= 500) return FalhaNuvem.conexao;
    return switch (codigo) {
      'EMAIL_EXISTS' => const FalhaNuvem(
        'Já existe uma conta com este e-mail. Toque em Entrar.',
      ),
      'EMAIL_NOT_FOUND' || 'INVALID_PASSWORD' || 'INVALID_LOGIN_CREDENTIALS' =>
        const FalhaNuvem('E-mail ou senha errados.'),
      'INVALID_EMAIL' => const FalhaNuvem('Este e-mail não parece certo.'),
      'MISSING_EMAIL' => const FalhaNuvem('Digite o seu e-mail.'),
      'MISSING_PASSWORD' => const FalhaNuvem('Digite a senha.'),
      'WEAK_PASSWORD' => const FalhaNuvem(
        'A senha precisa ter pelo menos 6 caracteres.',
      ),
      'TOO_MANY_ATTEMPTS_TRY_LATER' => const FalhaNuvem(
        'Muitas tentativas. Espere alguns minutos e tente de novo.',
      ),
      'USER_DISABLED' => const FalhaNuvem(
        'Esta conta foi desativada.',
        sessaoEncerrada: true,
      ),
      'TOKEN_EXPIRED' ||
      'INVALID_REFRESH_TOKEN' ||
      'INVALID_ID_TOKEN' ||
      'USER_NOT_FOUND' ||
      'CREDENTIAL_TOO_OLD_LOGIN_AGAIN' => const FalhaNuvem(
        'Sua sessão terminou. Entre de novo na conta.',
        sessaoEncerrada: true,
      ),
      'OPERATION_NOT_ALLOWED' => const FalhaNuvem(
        'O login por e-mail não está ligado no Firebase.',
      ),
      _ => FalhaNuvem(
        'A conta não respondeu como esperado (${r.status}'
        '${codigo.isEmpty ? '' : ': $codigo'}).',
      ),
    };
  }

  static FalhaNuvem _falhaFirestore(RespostaHttp r) {
    if (r.status == 429 || r.status >= 500) {
      return const FalhaNuvem(
        'A nuvem não respondeu agora. O app tenta de novo depois.',
        semConexao: true,
      );
    }
    if (r.status == 401) {
      return const FalhaNuvem(
        'Sua sessão terminou. Entre de novo na conta.',
        sessaoEncerrada: true,
      );
    }
    return FalhaNuvem(
      'A nuvem recusou a gravação (${r.status}${_erro(r) == null ? '' : ': ${_erro(r)}'}).',
    );
  }
}

/// A conta da pessoa e a sincronização das marcações, anotações, realces e
/// plano de leitura (ver [Ajustes.itens]) com a nuvem.
///
/// Sem conta, nada muda: tudo continua só no aparelho. Com conta:
/// - na primeira vez que a pessoa entra neste aparelho, o que está nele se
///   junta ao que está na nuvem, sem apagar nada ([Ajustes.juntar]);
/// - depois, cada mudança fica pendente e vai para a nuvem alguns segundos
///   depois; o que mudou na nuvem (vindo de outro aparelho) chega ao abrir o
///   app, ao voltar para ele e a cada poucos minutos com ele aberto.
/// - Se o mesmo item mudou nos dois aparelhos entre uma sincronização e
///   outra, vale o último enviado; no plano de leitura, se for o mesmo plano,
///   os dias lidos se somam.
///
/// Sem internet, as mudanças esperam no aparelho (ficam gravadas) até a
/// próxima vez.
class Nuvem extends ChangeNotifier {
  Nuvem({ClienteFirebase? cliente, this.automatica = true})
    : cliente = cliente ?? ClienteFirebase();

  static final Nuvem instancia = Nuvem();

  final ClienteFirebase cliente;

  /// Sincroniza sozinha (depois de cada mudança, ao voltar ao app e de tempos
  /// em tempos). Desligada nos testes, que chamam [sincronizar].
  final bool automatica;

  /// Chamado quando um plano de leitura começou ou terminou em outro
  /// aparelho (o lembrete diário depende dele).
  void Function()? aoMudarPlano;

  static const esperaAposMudanca = Duration(seconds: 4);
  static const intervalo = Duration(minutes: 5);

  SharedPreferences? _p;
  Sessao? _sessao;
  bool _aplicando = false;
  Future<void>? _rodando;
  bool _deNovo = false;
  Timer? _espera;
  Timer? _periodico;
  AppLifecycleListener? _ciclo;

  bool get conectada => _sessao != null;
  String? get email => _sessao?.email;
  bool get sincronizando => _rodando != null;

  /// Hora da última sincronização completa neste aparelho.
  DateTime? get ultimaSincronizacao =>
      DateTime.tryParse(_p?.getString('nuvemUltima') ?? '');

  /// O que deu errado na última tentativa, ou null.
  String? get erro => _erro;
  String? _erro;

  /// Quantos itens mudaram aqui e ainda não foram para a nuvem.
  int get pendentes => _pendentes.length;

  Set<String> get _pendentes =>
      (_p?.getStringList('nuvemPendentes') ?? const <String>[]).toSet();

  void _gravarPendentes(Set<String> chaves) {
    if (chaves.isEmpty) {
      _p!.remove('nuvemPendentes');
    } else {
      _p!.setStringList('nuvemPendentes', chaves.toList()..sort());
    }
  }

  /// Lê a conta salva neste aparelho e passa a acompanhar as mudanças.
  Future<void> carregar() async {
    final p = _p = await SharedPreferences.getInstance();
    final uid = p.getString('nuvemUid');
    final email = p.getString('nuvemEmail');
    final renovacao = p.getString('nuvemRenovacao');
    _sessao = uid == null || email == null || renovacao == null
        ? null
        : Sessao(uid: uid, email: email, renovacao: renovacao);
    Ajustes.instancia.aoMudarItens = _mudaram;
    notifyListeners();
  }

  /// Sincroniza ao abrir o app, ao voltar para ele, e de tempos em tempos.
  void iniciarAutomatica() {
    if (!automatica || _ciclo != null) return;
    _ciclo = AppLifecycleListener(
      onResume: sincronizar,
      // Indo para o fundo (ou fechando): manda o que falta.
      onPause: _enviarPendentes,
      onHide: _enviarPendentes,
    );
    _periodico = Timer.periodic(intervalo, (_) {
      final estado = WidgetsBinding.instance.lifecycleState;
      if (estado == null || estado == AppLifecycleState.resumed) {
        sincronizar();
      }
    });
    sincronizar();
  }

  void _enviarPendentes() {
    if (_pendentes.isNotEmpty) sincronizar();
  }

  void _mudaram(Set<String> chaves) {
    if (_sessao == null || _aplicando || _p == null) return;
    _gravarPendentes({..._pendentes, ...chaves});
    if (automatica) {
      _espera?.cancel();
      _espera = Timer(esperaAposMudanca, sincronizar);
    }
    notifyListeners();
  }

  /// Entra na conta (ou cria uma, com [criar]) e junta o que está neste
  /// aparelho ao que está na nuvem. Devolve quantos itens vieram da nuvem e
  /// quantos foram para ela, ou null se a junção ficou para depois (sem
  /// internet: ver [erro]).
  ///
  /// Lança [FalhaNuvem] se não deu para entrar.
  Future<({int vieram, int foram})?> entrar(
    String email,
    String senha, {
    bool criar = false,
  }) async {
    final s = criar
        ? await cliente.criarConta(email.trim(), senha)
        : await cliente.entrar(email.trim(), senha);
    final p = _p!;
    // Outra conta (ou a mesma de novo): junta tudo outra vez.
    for (final k in ['nuvemDesde', 'nuvemPendentes', 'nuvemJuntou']) {
      p.remove(k);
    }
    p.remove('nuvemUltima');
    _sessao = s;
    _gravarSessao();
    _erro = null;
    notifyListeners();
    ({int vieram, int foram})? resumo;
    await _sincronizar((s) async => resumo = await _juntar(s));
    return resumo;
  }

  Future<void> redefinirSenha(String email) =>
      cliente.redefinirSenha(email.trim());

  /// Sai da conta neste aparelho. Antes, tenta mandar o que ainda não foi.
  /// Marcações e anotações continuam no aparelho.
  Future<void> sair() async {
    // Sem internet, sai mesmo assim: o que não foi continua aqui.
    if (_pendentes.isNotEmpty) await sincronizar();
    _esquecerConta();
  }

  /// Apaga a conta e tudo o que ela tem na nuvem. A [senha] confirma que é a
  /// dona da conta (e o Firebase exige ter entrado há pouco para excluir).
  /// O que está neste aparelho fica.
  Future<void> excluirConta(String senha) async {
    final atual = _sessao;
    if (atual == null) return;
    final s = await cliente.entrar(atual.email, senha);
    await cliente.apagarDados(s);
    await cliente.excluirConta(s);
    _esquecerConta();
  }

  void _esquecerConta() {
    _espera?.cancel();
    final p = _p;
    if (p != null) {
      for (final k in [
        'nuvemUid',
        'nuvemEmail',
        'nuvemRenovacao',
        'nuvemDesde',
        'nuvemPendentes',
        'nuvemJuntou',
        'nuvemUltima',
      ]) {
        p.remove(k);
      }
    }
    _sessao = null;
    _erro = null;
    notifyListeners();
  }

  void _gravarSessao() {
    final s = _sessao;
    if (s == null) return;
    _p!
      ..setString('nuvemUid', s.uid)
      ..setString('nuvemEmail', s.email)
      ..setString('nuvemRenovacao', s.renovacao);
  }

  /// Traz o que mudou na nuvem e manda o que mudou aqui. Se já houver uma
  /// sincronização em andamento, outra roda logo depois dela.
  Future<void> sincronizar() async {
    if (_sessao == null) return;
    await _sincronizar((s) async {
      if (_p!.getBool('nuvemJuntou') ?? false) {
        await _trocar(s);
      } else {
        await _juntar(s);
      }
    });
  }

  Future<void> _sincronizar(Future<void> Function(Sessao s) passo) async {
    final rodando = _rodando;
    if (rodando != null) {
      _deNovo = true;
      return rodando;
    }
    final feito = Completer<void>();
    _rodando = feito.future;
    notifyListeners();
    try {
      final s = _sessao;
      if (s != null) {
        await passo(s);
        // Saiu da conta no meio: não marca nada.
        if (identical(_sessao, s)) {
          _p!.setString('nuvemUltima', DateTime.now().toIso8601String());
          _erro = null;
        }
      }
    } on FalhaNuvem catch (e) {
      _erro = e.semConexao
          ? '${e.mensagem} O que você mudar vai para a nuvem quando ela '
                'voltar.'
          : e.mensagem;
      if (e.sessaoEncerrada) {
        // Guarda o aviso: a tela da conta mostra por que saiu.
        final aviso = e.mensagem;
        _esquecerConta();
        _erro = aviso;
      }
    } catch (e) {
      // Resposta fora do esperado: tenta de novo na próxima vez.
      _erro = 'Não foi possível sincronizar ($e).';
    } finally {
      // A renovação pode ter trocado a chave da sessão.
      if (_sessao != null) _gravarSessao();
      _rodando = null;
      feito.complete();
      notifyListeners();
    }
    if (_deNovo && _sessao != null) {
      _deNovo = false;
      await sincronizar();
    }
  }

  /// Primeira vez nesta conta, neste aparelho: junta tudo.
  Future<({int vieram, int foram})> _juntar(Sessao s) async {
    final r = await cliente.buscar(s);
    final naNuvem = {
      for (final i in r.itens)
        if (i.valor != null) i.chave: i.valor,
    };
    final aj = Ajustes.instancia;
    final planoAntes = aj.plano;
    // Planos diferentes aqui e na nuvem: fica o mais adiantado (empate: o da
    // nuvem, que é o dos outros aparelhos).
    final planoNuvem = naNuvem[Ajustes.chavePlano];
    final planoAqui = aj.itens()[Ajustes.chavePlano];
    if (planoNuvem is Map &&
        planoAqui is Map &&
        planoNuvem['id'] != planoAqui['id'] &&
        _diasLidos(planoNuvem) >= _diasLidos(planoAqui)) {
      aj.aplicarItens({Ajustes.chavePlano: planoNuvem});
    }
    _aplicando = true;
    try {
      aj.juntar(naNuvem);
    } finally {
      _aplicando = false;
    }
    final aqui = aj.itens();
    // Só o que está aqui vai: o que a nuvem tem e o aparelho recusou (outro
    // plano, item inválido) não é apagado de lá.
    final diferentes = itensDiferentes(aqui, naNuvem)
      ..removeWhere((k) => !aqui.containsKey(k));
    _gravarPendentes({..._pendentes, ...diferentes});
    _p!.setBool('nuvemJuntou', true);
    if (aj.plano != planoAntes) aoMudarPlano?.call();
    if (r.lidoEm != null) _p!.setString('nuvemDesde', r.lidoEm!);
    await _enviar(s);
    return (vieram: naNuvem.length, foram: diferentes.length);
  }

  static int _diasLidos(Map plano) => ((plano['lidos'] as List?) ?? []).length;

  /// Traz o que mudou na nuvem desde a última vez e manda o pendente.
  Future<void> _trocar(Sessao s) async {
    final desde = DateTime.tryParse(_p!.getString('nuvemDesde') ?? '');
    // Uma gravação leva a hora de quando chegou ao servidor, um pouco antes
    // de aparecer nas consultas: a margem pega a que estava no meio do
    // caminho na consulta anterior. Trazer de novo o que já veio não muda
    // nada.
    final r = await cliente.buscar(
      s,
      desde: desde
          ?.subtract(const Duration(minutes: 1))
          .toUtc()
          .toIso8601String(),
    );
    final pendentes = _pendentes;
    final aqui = Ajustes.instancia.itens();
    final aplicar = <String, Object?>{};
    for (final item in r.itens) {
      final local = aqui[item.chave];
      Object? novo = item.valor;
      if (pendentes.contains(item.chave)) {
        // Mudou aqui também: vale o daqui, que vai em seguida. Do mesmo
        // plano, os dias lidos lá entram também.
        if (item.chave != Ajustes.chavePlano) continue;
        novo = juntarPlanos(local, item.valor);
      }
      if (jsonCanonico(novo) != jsonCanonico(local)) aplicar[item.chave] = novo;
    }
    final planoAntes = Ajustes.instancia.plano;
    Ajustes.instancia.aplicarItens(aplicar);
    if (Ajustes.instancia.plano != planoAntes) aoMudarPlano?.call();
    if (r.lidoEm != null) _p!.setString('nuvemDesde', r.lidoEm!);
    await _enviar(s);
  }

  Future<void> _enviar(Sessao s) async {
    final pendentes = _pendentes;
    if (pendentes.isEmpty) return;
    final aqui = Ajustes.instancia.itens();
    final envio = {for (final k in pendentes) k: aqui[k]};
    await cliente.gravar(s, envio);
    // O que mudou de novo durante o envio continua pendente.
    final agora = Ajustes.instancia.itens();
    _gravarPendentes(
      _pendentes..removeWhere(
        (k) =>
            envio.containsKey(k) &&
            jsonCanonico(agora[k]) == jsonCanonico(envio[k]),
      ),
    );
  }

  @override
  void dispose() {
    _espera?.cancel();
    _periodico?.cancel();
    _ciclo?.dispose();
    if (identical(Ajustes.instancia.aoMudarItens, _mudaram)) {
      Ajustes.instancia.aoMudarItens = null;
    }
    super.dispose();
  }
}

/// O plano daqui com os dias lidos de [remoto], se for o mesmo plano; senão,
/// o daqui.
Object? juntarPlanos(Object? local, Object? remoto) {
  if (local is! Map || remoto is! Map || local['id'] != remoto['id']) {
    return local;
  }
  List<int> lidos(Map m) => [
    for (final d in (m['lidos'] as List?) ?? const [])
      if (d is int) d,
  ];
  final comecos = [local['comecou'], remoto['comecou']].whereType<int>();
  return {
    'id': local['id'],
    'lidos': ({...lidos(local), ...lidos(remoto)}.toList()..sort()),
    if (comecos.isNotEmpty) 'comecou': comecos.reduce(min),
    'leuEm': ?(local['leuEm'] ?? remoto['leuEm']),
  };
}
