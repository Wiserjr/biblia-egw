import 'dart:io';

import 'package:biblia_estudo/dados/ajustes.dart';
import 'package:biblia_estudo/dados/nuvem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Com o Firebase de verdade: cria uma conta de teste, sincroniza dois
/// "aparelhos" e exclui a conta no fim. Só roda com FIREBASE_TESTE=1:
///
///     FIREBASE_TESTE=1 flutter test test/nuvem_firebase_test.dart
///
/// Usa o proxy e o certificado do ambiente (HTTPS_PROXY, SSL_CERT_FILE), se
/// houver.
void main() {
  final ligado = Platform.environment['FIREBASE_TESTE'] == '1';

  test(
    'dois aparelhos na mesma conta',
    () async {
      HttpOverrides.global = _Ambiente();
      final aj = Ajustes.instancia;
      final email =
          'teste-${DateTime.now().millisecondsSinceEpoch}@example.com';
      const senha = 'senha-de-teste-123';

      Future<Map<String, Object>> salvar() async {
        final p = await SharedPreferences.getInstance();
        return {for (final k in p.getKeys()) k: p.get(k)!};
      }

      Future<Nuvem> aparelho(Map<String, Object> prefs) async {
        SharedPreferences.setMockInitialValues(prefs);
        await aj.carregar();
        final n = Nuvem(automatica: false);
        await n.carregar();
        return n;
      }

      // Aparelho A cria a conta com o que já tinha.
      var a = await aparelho({});
      aj.marcar(43, 3, 16, 2);
      aj.iniciarPlano('nt-90-dias');
      aj.marcarDia(0, true);
      expect(await a.entrar(email, senha, criar: true), (vieram: 0, foram: 2));
      final prefsA = await salvar();
      a.dispose();

      try {
        // Aparelho B entra com outra coisa marcada: junta.
        final b = await aparelho({});
        aj.anotar(1, 1, 1, 'No princípio');
        expect(await b.entrar(email, senha), (vieram: 2, foram: 1));
        expect(aj.marcacao(43, 3, 16), 2);
        expect(aj.plano, 'nt-90-dias');
        aj.marcarDia(1, true);
        aj.marcar(43, 3, 16, null);
        await b.sincronizar();
        expect(b.erro, isNull);
        expect(b.pendentes, 0);
        final prefsB = await salvar();
        b.dispose();

        // De volta ao A: chega o que B fez, inclusive o que B apagou.
        a = await aparelho(prefsA);
        await a.sincronizar();
        expect(a.erro, isNull);
        expect(aj.anotacao(1, 1, 1), 'No princípio');
        expect(aj.marcacao(43, 3, 16), isNull);
        expect(aj.diasLidos, {0, 1});
        a.dispose();

        // B exclui a conta.
        final b2 = await aparelho(prefsB);
        await b2.excluirConta(senha);
        expect(b2.conectada, isFalse);
        b2.dispose();
      } finally {
        // Se algo falhou no meio, não deixa a conta de teste para trás.
        final c = ClienteFirebase();
        try {
          final s = await c.entrar(email, senha);
          await c.apagarDados(s);
          await c.excluirConta(s);
        } on FalhaNuvem {
          // Já foi excluída.
        }
      }
      await expectLater(
        ClienteFirebase().entrar(email, senha),
        throwsA(isA<FalhaNuvem>()),
      );
    },
    skip: ligado
        ? false
        : 'Rode com FIREBASE_TESTE=1 (cria e exclui uma conta no Firebase)',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _Ambiente extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final certificado = Platform.environment['SSL_CERT_FILE'];
    final contexto = SecurityContext(withTrustedRoots: true);
    if (certificado != null) contexto.setTrustedCertificates(certificado);
    return super.createHttpClient(contexto)
      ..findProxy = HttpClient.findProxyFromEnvironment;
  }
}
