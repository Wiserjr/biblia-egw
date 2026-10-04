import 'dart:convert';

import 'package:biblia_estudo/dados/ajustes.dart';
import 'package:biblia_estudo/dados/nuvem.dart';
import 'package:biblia_estudo/telas/conta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase de mentira: as contas e o Firestore na memória, com as mesmas
/// respostas da API web (ver ClienteFirebase).
class FirebaseFalso {
  final _contas = <String, ({String uid, String senha})>{};
  final _tokens = <String, String>{};
  final _renovacoes = <String, String>{};
  final docs = <String, Map<String, Map<String, Object?>>>{};
  final emailsDeSenha = <String>[];
  var _n = 0;

  /// Milissegundos desde 4/10/2026; cada gravação avança um segundo.
  var _relogio = 0;
  var gravacoes = 0;
  var consultas = 0;
  bool foraDoAr = false;

  static final _base = DateTime.utc(2026, 10, 4);
  String _hora(int ms) =>
      _base.add(Duration(milliseconds: ms)).toIso8601String();
  int _ms(String hora) => DateTime.parse(hora).difference(_base).inMilliseconds;

  String criarConta(String email, String senha) {
    final uid = 'uid${++_n}';
    _contas[email] = (uid: uid, senha: senha);
    return uid;
  }

  /// Vence todos os tokens (como depois de uma hora).
  void vencerTokens() => _tokens.clear();

  /// A conta não vale mais (senha trocada em outro lugar).
  void encerrarSessoes() {
    _tokens.clear();
    _renovacoes.clear();
  }

  /// Outro aparelho grava um item ([valor] null: apagado).
  void gravarDeOutroAparelho(String uid, String chave, Object? valor) {
    _relogio += 1000;
    (docs[uid] ??= {})[chave] = {
      if (valor == null) 'apagado': true else 'json': jsonEncode(valor),
      'atualizado': _relogio,
    };
  }

  /// O valor de [chave] na nuvem; 'apagado' se apagado; null se não existe.
  Object? valor(String uid, String chave) {
    final d = docs[uid]?[chave];
    if (d == null) return null;
    if (d['apagado'] == true) return 'apagado';
    return jsonDecode(d['json'] as String);
  }

  Map<String, Object?> _sessao(String uid, String email) {
    final token = 'token${++_n}';
    final renovacao = 'renovacao${++_n}';
    _tokens[token] = uid;
    _renovacoes[renovacao] = uid;
    return {
      'localId': uid,
      'email': email,
      'idToken': token,
      'refreshToken': renovacao,
      'expiresIn': '3600',
    };
  }

  RespostaHttp _erro(int status, String mensagem) => (
    status: status,
    corpo: {
      'error': {'code': status, 'message': mensagem},
    },
  );

  Future<RespostaHttp> requisicao(
    String metodo,
    Uri url, {
    Object? corpo,
    String? token,
    Map<String, String> cabecalhos = const {},
  }) async {
    if (foraDoAr) throw FalhaNuvem.conexao;
    final c = (corpo as Map?) ?? const {};
    switch (url.host) {
      case 'identitytoolkit.googleapis.com':
        final email = c['email'] as String?;
        final senha = c['password'] as String?;
        switch (url.pathSegments.last) {
          case 'accounts:signUp':
            if (_contas.containsKey(email)) return _erro(400, 'EMAIL_EXISTS');
            if ((senha ?? '').length < 6) {
              return _erro(
                400,
                'WEAK_PASSWORD : Password should be at least 6 characters',
              );
            }
            return (
              status: 200,
              corpo: _sessao(criarConta(email!, senha!), email),
            );
          case 'accounts:signInWithPassword':
            final conta = _contas[email];
            if (conta == null || conta.senha != senha) {
              return _erro(400, 'INVALID_LOGIN_CREDENTIALS');
            }
            return (status: 200, corpo: _sessao(conta.uid, email!));
          case 'accounts:sendOobCode':
            emailsDeSenha.add(email!);
            return (status: 200, corpo: <String, Object?>{'email': email});
          case 'accounts:delete':
            final uid = _tokens[c['idToken']];
            if (uid == null) return _erro(400, 'INVALID_ID_TOKEN');
            _contas.removeWhere((_, v) => v.uid == uid);
            return (status: 200, corpo: <String, Object?>{});
        }
      case 'securetoken.googleapis.com':
        final uid = _renovacoes[c['refresh_token']];
        if (uid == null) return _erro(400, 'INVALID_REFRESH_TOKEN');
        final token = 'token${++_n}';
        _tokens[token] = uid;
        return (
          status: 200,
          corpo: {
            'id_token': token,
            'refresh_token': c['refresh_token'],
            'expires_in': '3600',
            'user_id': uid,
          },
        );
      case 'firestore.googleapis.com':
        final uid = _tokens[token];
        if (uid == null) return _erro(401, 'UNAUTHENTICATED');
        final caminho = url.pathSegments.join('/');
        if (caminho.endsWith('documents:commit')) return _commit(uid, c);
        if (caminho.endsWith('/usuarios/$uid:runQuery')) {
          return _consulta(uid, c['structuredQuery'] as Map);
        }
        return _erro(403, 'PERMISSION_DENIED');
    }
    return _erro(404, 'NOT_FOUND');
  }

  (String, String)? _doc(String nome) {
    final m = RegExp(r'/usuarios/([^/]+)/itens/([^/]+)$').firstMatch(nome);
    return m == null ? null : (m[1]!, m[2]!);
  }

  RespostaHttp _commit(String uid, Map c) {
    final escritas = c['writes'] as List;
    if (escritas.length > 500) return _erro(400, 'INVALID_ARGUMENT');
    gravacoes++;
    _relogio += 1000;
    for (final w in escritas.cast<Map>()) {
      final apagar = w['delete'] as String?;
      final atualizar = w['update'] as Map?;
      final alvo = _doc(apagar ?? atualizar!['name'] as String);
      if (alvo == null || alvo.$1 != uid) {
        return _erro(403, 'PERMISSION_DENIED');
      }
      if (apagar != null) {
        docs[uid]?.remove(alvo.$2);
        continue;
      }
      final campos = atualizar!['fields'] as Map;
      expect(w['updateTransforms'], [
        {'fieldPath': 'atualizado', 'setToServerValue': 'REQUEST_TIME'},
      ]);
      (docs[uid] ??= {})[alvo.$2] = {
        if ((campos['apagado'] as Map?)?['booleanValue'] == true)
          'apagado': true,
        if (campos['json'] case {'stringValue': final String j}) 'json': j,
        'atualizado': _relogio,
      };
    }
    return (status: 200, corpo: <String, Object?>{'writeResults': []});
  }

  RespostaHttp _consulta(String uid, Map q) {
    consultas++;
    _relogio += 1;
    final desde = switch (q['where']) {
      {
        'fieldFilter': {
          'op': 'GREATER_THAN',
          'value': {'timestampValue': final String t},
        },
      } =>
        _ms(t),
      _ => null,
    };
    final depois = switch (q['startAt']) {
      {
        'values': [
          {'timestampValue': final String t},
          {'referenceValue': final String n},
        ],
      } =>
        (_ms(t), n),
      _ => null,
    };
    String nome(String id) =>
        'projects/p/databases/(default)/documents/usuarios/$uid/itens/$id';
    final lista =
        [
          for (final MapEntry(key: id, value: d) in (docs[uid] ?? {}).entries)
            if (desde == null || (d['atualizado'] as int) > desde) (id, d),
        ]..sort((a, b) {
          final t = (a.$2['atualizado'] as int).compareTo(
            b.$2['atualizado'] as int,
          );
          return t != 0 ? t : nome(a.$1).compareTo(nome(b.$1));
        });
    final filtrada = depois == null
        ? lista
        : lista.where((e) {
            final t = e.$2['atualizado'] as int;
            return t > depois.$1 ||
                (t == depois.$1 && nome(e.$1).compareTo(depois.$2) > 0);
          }).toList();
    final pagina = filtrada.take(q['limit'] as int).toList();
    final lido = _hora(_relogio);
    if (pagina.isEmpty) {
      return (
        status: 200,
        corpo: [
          {'readTime': lido},
        ],
      );
    }
    return (
      status: 200,
      corpo: [
        for (final (id, d) in pagina)
          {
            'document': {
              'name': nome(id),
              'fields': {
                if (d['apagado'] == true) 'apagado': {'booleanValue': true},
                if (d['json'] case final String j) 'json': {'stringValue': j},
                'atualizado': {'timestampValue': _hora(d['atualizado'] as int)},
              },
            },
            'readTime': lido,
          },
      ],
    );
  }
}

void main() {
  late FirebaseFalso fb;
  late Nuvem nuvem;
  final aj = Ajustes.instancia;

  /// Um aparelho novo (preferências vazias), com o Firebase [fb].
  Future<void> aparelhoNovo([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    await aj.carregar();
    nuvem = Nuvem(
      cliente: ClienteFirebase(requisicao: fb.requisicao),
      automatica: false,
    );
    await nuvem.carregar();
  }

  setUp(() async {
    fb = FirebaseFalso();
    await aparelhoNovo();
  });

  tearDown(() => nuvem.dispose());

  test('sem conta, nada vai para a nuvem', () async {
    aj.marcar(43, 3, 16, 2);
    await nuvem.sincronizar();
    expect(nuvem.conectada, isFalse);
    expect(nuvem.pendentes, 0);
    expect(fb.docs, isEmpty);
  });

  test('criar conta manda para a nuvem o que já estava no aparelho', () async {
    aj.marcar(43, 3, 16, 2);
    aj.anotar(43, 3, 16, 'O amor de Deus');
    aj.iniciarPlano('nt-90-dias');
    aj.marcarDia(0, true);
    aj.realcar(
      const Realce(
        obra: 7,
        pagina: 30,
        inicio: 10,
        fim: 20,
        cor: 1,
        texto: 'trecho',
        nota: 'nota do livro',
      ),
    );

    final r = await nuvem.entrar('ana@exemplo.com', 'segredo1', criar: true);

    expect(r, (vieram: 0, foram: 4));
    expect(nuvem.conectada, isTrue);
    expect(nuvem.email, 'ana@exemplo.com');
    expect(nuvem.pendentes, 0);
    expect(nuvem.erro, isNull);
    final uid = fb.docs.keys.single;
    expect(fb.valor(uid, 'm_43_3_16'), 2);
    expect(fb.valor(uid, 'a_43_3_16'), 'O amor de Deus');
    expect(
      fb.valor(uid, 'r_7_30_10_20'),
      containsPair('nota', 'nota do livro'),
    );
    expect(fb.valor(uid, 'plano'), containsPair('lidos', [0]));
  });

  test('entrar em outro aparelho junta tudo, sem apagar nada', () async {
    final uid = fb.criarConta('ana@exemplo.com', 'segredo1');
    fb.gravarDeOutroAparelho(uid, 'm_1_1_1', 0);
    fb.gravarDeOutroAparelho(uid, 'a_19_23_1', 'Da nuvem');
    fb.gravarDeOutroAparelho(uid, 'm_2_2_2', null); // apagado lá
    aj.anotar(19, 23, 1, 'Daqui');
    aj.marcar(2, 2, 2, 3);

    final r = await nuvem.entrar('ana@exemplo.com', 'segredo1');

    expect(r, (vieram: 2, foram: 2));
    expect(aj.marcacao(1, 1, 1), 0);
    // O que foi apagado em outro aparelho continua aqui, e volta para lá.
    expect(aj.marcacao(2, 2, 2), 3);
    expect(fb.valor(uid, 'm_2_2_2'), 3);
    expect(aj.anotacao(19, 23, 1), 'Daqui\n\nDa nuvem');
    expect(fb.valor(uid, 'a_19_23_1'), 'Daqui\n\nDa nuvem');
  });

  test('o que muda aqui vai para a nuvem, inclusive o que é apagado', () async {
    await nuvem.entrar('ana@exemplo.com', 'segredo1', criar: true);
    final uid = fb.docs.keys.firstOrNull ?? 'uid1';

    aj.marcar(43, 3, 16, 2);
    aj.anotar(1, 1, 1, 'No princípio');
    expect(nuvem.pendentes, 2);
    await nuvem.sincronizar();
    expect(nuvem.pendentes, 0);
    expect(fb.valor(uid, 'm_43_3_16'), 2);
    expect(fb.valor(uid, 'a_1_1_1'), 'No princípio');

    aj.marcar(43, 3, 16, null);
    aj.anotar(1, 1, 1, '');
    await nuvem.sincronizar();
    expect(fb.valor(uid, 'm_43_3_16'), 'apagado');
    expect(fb.valor(uid, 'a_1_1_1'), 'apagado');
  });

  test('o que muda em outro aparelho chega, inclusive o apagado', () async {
    aj.marcar(43, 3, 16, 2);
    aj.anotar(43, 3, 16, 'Velha');
    await nuvem.entrar('ana@exemplo.com', 'segredo1', criar: true);
    final uid = fb.docs.keys.single;

    fb.gravarDeOutroAparelho(uid, 'm_43_3_16', null);
    fb.gravarDeOutroAparelho(uid, 'a_43_3_16', 'Nova');
    fb.gravarDeOutroAparelho(uid, 'm_1_1_1', 4);
    fb.gravarDeOutroAparelho(uid, 'plano', {
      'id': 'evangelhos-30-dias',
      'lidos': [0, 1],
    });
    var avisos = 0;
    nuvem.aoMudarPlano = () => avisos++;
    await nuvem.sincronizar();

    expect(aj.marcacao(43, 3, 16), isNull);
    expect(aj.anotacao(43, 3, 16), 'Nova');
    expect(aj.marcacao(1, 1, 1), 4);
    expect(aj.plano, 'evangelhos-30-dias');
    expect(aj.diasLidos, {0, 1});
    expect(avisos, 1, reason: 'o lembrete segue o plano novo');
    // O que veio de lá não volta para lá.
    expect(nuvem.pendentes, 0);

    fb.gravarDeOutroAparelho(uid, 'plano', null);
    await nuvem.sincronizar();
    expect(aj.plano, isNull);
    expect(avisos, 2);
  });

  test(
    'a mudança daqui ainda não enviada vale; no plano, os dias se somam',
    () async {
      aj.iniciarPlano('nt-90-dias');
      aj.marcarDia(0, true);
      await nuvem.entrar('ana@exemplo.com', 'segredo1', criar: true);
      final uid = fb.docs.keys.single;

      aj.anotar(43, 3, 16, 'Daqui');
      aj.marcarDia(1, true);
      fb.gravarDeOutroAparelho(uid, 'a_43_3_16', 'De lá');
      fb.gravarDeOutroAparelho(uid, 'plano', {
        'id': 'nt-90-dias',
        'lidos': [0, 2],
      });
      await nuvem.sincronizar();

      expect(aj.anotacao(43, 3, 16), 'Daqui');
      expect(fb.valor(uid, 'a_43_3_16'), 'Daqui');
      expect(aj.diasLidos, {0, 1, 2});
      expect(fb.valor(uid, 'plano'), containsPair('lidos', [0, 1, 2]));
    },
  );

  test('sem internet, as mudanças esperam no aparelho', () async {
    await nuvem.entrar('ana@exemplo.com', 'segredo1', criar: true);
    fb.foraDoAr = true;
    aj.marcar(43, 3, 16, 1);
    await nuvem.sincronizar();
    expect(nuvem.erro, startsWith('Sem conexão com a internet.'));
    expect(nuvem.conectada, isTrue);
    expect(nuvem.pendentes, 1);

    // Mesmo fechando e abrindo o app.
    final prefs = await SharedPreferences.getInstance();
    final salvo = {for (final k in prefs.getKeys()) k: prefs.get(k)!};
    nuvem.dispose();
    await aparelhoNovo(salvo.cast());
    expect(nuvem.conectada, isTrue);
    expect(nuvem.pendentes, 1);

    fb.foraDoAr = false;
    await nuvem.sincronizar();
    expect(nuvem.erro, isNull);
    expect(nuvem.pendentes, 0);
    expect(fb.valor(fb.docs.keys.single, 'm_43_3_16'), 1);
  });

  test('renova o acesso vencido; sessão encerrada sai da conta', () async {
    await nuvem.entrar('ana@exemplo.com', 'segredo1', criar: true);
    fb.vencerTokens();
    aj.marcar(43, 3, 16, 1);
    await nuvem.sincronizar();
    expect(nuvem.erro, isNull);
    expect(nuvem.pendentes, 0);

    fb.encerrarSessoes();
    aj.marcar(43, 3, 17, 1);
    await nuvem.sincronizar();
    expect(nuvem.conectada, isFalse);
    expect(nuvem.erro, 'Sua sessão terminou. Entre de novo na conta.');
    // As marcações ficam.
    expect(aj.marcacao(43, 3, 17), 1);
  });

  test('senha errada e e-mail repetido dizem o que houve', () async {
    fb.criarConta('ana@exemplo.com', 'segredo1');
    await expectLater(
      nuvem.entrar('ana@exemplo.com', 'errada'),
      throwsA(
        isA<FalhaNuvem>().having(
          (e) => e.mensagem,
          'mensagem',
          'E-mail ou senha errados.',
        ),
      ),
    );
    await expectLater(
      nuvem.entrar('ana@exemplo.com', 'outra123', criar: true),
      throwsA(
        isA<FalhaNuvem>().having(
          (e) => e.mensagem,
          'mensagem',
          contains('Já existe uma conta'),
        ),
      ),
    );
    await expectLater(
      nuvem.entrar('bia@exemplo.com', '123', criar: true),
      throwsA(
        isA<FalhaNuvem>().having(
          (e) => e.mensagem,
          'mensagem',
          'A senha precisa ter pelo menos 6 caracteres.',
        ),
      ),
    );
    expect(nuvem.conectada, isFalse);

    await nuvem.redefinirSenha(' ana@exemplo.com ');
    expect(fb.emailsDeSenha, ['ana@exemplo.com']);
  });

  test('sair deixa tudo no aparelho e para de mandar', () async {
    aj.marcar(43, 3, 16, 2);
    await nuvem.entrar('ana@exemplo.com', 'segredo1', criar: true);
    aj.marcar(1, 1, 1, 1);
    await nuvem.sair();
    final uid = fb.docs.keys.single;
    // O pendente foi antes de sair.
    expect(fb.valor(uid, 'm_1_1_1'), 1);
    expect(nuvem.conectada, isFalse);
    expect(aj.marcacao(43, 3, 16), 2);

    aj.marcar(5, 5, 5, 0);
    expect(nuvem.pendentes, 0);
    await nuvem.sincronizar();
    expect(fb.valor(uid, 'm_5_5_5'), isNull);
  });

  test('excluir a conta apaga a nuvem e a conta, e deixa o aparelho', () async {
    aj.marcar(43, 3, 16, 2);
    await nuvem.entrar('ana@exemplo.com', 'segredo1', criar: true);
    final uid = fb.docs.keys.single;

    await expectLater(nuvem.excluirConta('errada'), throwsA(isA<FalhaNuvem>()));
    expect(nuvem.conectada, isTrue);

    await nuvem.excluirConta('segredo1');
    expect(fb.docs[uid], isEmpty);
    expect(nuvem.conectada, isFalse);
    expect(aj.marcacao(43, 3, 16), 2);
    await expectLater(
      nuvem.entrar('ana@exemplo.com', 'segredo1'),
      throwsA(isA<FalhaNuvem>()),
    );
  });

  test(
    'restaurar uma cópia com a conta conectada manda só o que mudou',
    () async {
      aj.marcar(43, 3, 16, 2);
      await nuvem.entrar('ana@exemplo.com', 'segredo1', criar: true);
      aj.importar({
        'app': 'br.com.wisejr.bibliaestudo',
        'marcacoes': {'43:3:16': 2, '1:1:1': 3},
        'anotacoes': {'1:1:1': 'Da cópia'},
      });
      expect(nuvem.pendentes, 2);
      await nuvem.sincronizar();
      expect(fb.valor(fb.docs.keys.single, 'a_1_1_1'), 'Da cópia');
    },
  );

  test('planos diferentes ao entrar: fica o mais adiantado', () async {
    final uid = fb.criarConta('ana@exemplo.com', 'segredo1');
    fb.gravarDeOutroAparelho(uid, 'plano', {
      'id': 'biblia-1-ano',
      'lidos': [0, 1, 2],
    });
    aj.iniciarPlano('evangelhos-30-dias');
    aj.marcarDia(0, true);
    await nuvem.entrar('ana@exemplo.com', 'segredo1');
    expect(aj.plano, 'biblia-1-ano');
    expect(aj.diasLidos, {0, 1, 2});
    expect(nuvem.pendentes, 0);
  });

  test('muitos itens vão e voltam em lotes', () async {
    for (var c = 1; c <= 50; c++) {
      for (var v = 1; v <= 24; v++) {
        aj.marcar(19, c, v, (c + v) % 5);
      }
    }
    await nuvem.entrar('ana@exemplo.com', 'segredo1', criar: true);
    expect(fb.gravacoes, 3); // 1.200 itens, 500 por gravação
    expect(fb.docs.values.single, hasLength(1200));

    nuvem.dispose();
    await aparelhoNovo();
    final consultas = fb.consultas;
    await nuvem.entrar('ana@exemplo.com', 'segredo1');
    expect(fb.consultas - consultas, 3, reason: '500 por consulta');
    expect(aj.todasMarcacoes(), hasLength(1200));
    expect(aj.marcacao(19, 50, 24), (50 + 24) % 5);
  });

  test('situação da sincronização em uma linha', () async {
    expect(situacaoDaNuvem(nuvem), 'Ainda não sincronizado');
    await nuvem.entrar('ana@exemplo.com', 'segredo1', criar: true);
    final agora = nuvem.ultimaSincronizacao!;
    expect(situacaoDaNuvem(nuvem, agora), 'Sincronizado agora');
    expect(
      situacaoDaNuvem(nuvem, agora.add(const Duration(hours: 1))),
      startsWith(agora.hour == 23 ? 'Sincronizado em' : 'Sincronizado às'),
    );
  });

  testWidgets('tela da conta: entrar e sair', (tester) async {
    await tester.pumpWidget(MaterialApp(home: TelaConta(nuvem: nuvem)));
    expect(find.text('Entrar'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextField, 'E-mail'),
      'ana@exemplo.com',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'segredo1');
    await tester.tap(find.text('Criar conta'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await tester.pumpAndSettle();

    expect(find.text('ana@exemplo.com'), findsOneWidget);
    expect(find.text('Conta conectada.'), findsOneWidget);

    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sair'));
    await tester.pumpAndSettle();
    expect(nuvem.conectada, isFalse);
    expect(find.widgetWithText(TextField, 'E-mail'), findsOneWidget);
  });

  testWidgets('tela da conta: avisa senha errada', (tester) async {
    fb.criarConta('ana@exemplo.com', 'segredo1');
    await tester.pumpWidget(MaterialApp(home: TelaConta(nuvem: nuvem)));
    await tester.enterText(
      find.widgetWithText(TextField, 'E-mail'),
      'ana@exemplo.com',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'errada');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('E-mail ou senha errados.'), findsOneWidget);
    expect(nuvem.conectada, isFalse);
  });
}
