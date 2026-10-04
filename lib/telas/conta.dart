import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dados/nuvem.dart';

final _privacidade = Uri.parse(
  'https://github.com/Wiserjr/biblia-egw/blob/main/PRIVACIDADE.md',
);

/// Uma linha sobre a sincronização: "Sincronizado às 10:32", "Sincronizando…"
/// ou o erro da última tentativa.
String situacaoDaNuvem(Nuvem n, [DateTime? agora]) {
  if (n.sincronizando) return 'Sincronizando…';
  final erro = n.erro;
  if (erro != null) return erro;
  final ultima = n.ultimaSincronizacao;
  if (ultima == null) return 'Ainda não sincronizado';
  final hoje = agora ?? DateTime.now();
  String dois(int x) => x.toString().padLeft(2, '0');
  final hora = '${dois(ultima.hour)}:${dois(ultima.minute)}';
  if (hoje.difference(ultima) < const Duration(minutes: 1)) {
    return 'Sincronizado agora';
  }
  if (ultima.year == hoje.year &&
      ultima.month == hoje.month &&
      ultima.day == hoje.day) {
    return 'Sincronizado às $hora';
  }
  return 'Sincronizado em ${dois(ultima.day)}/${dois(ultima.month)} às $hora';
}

/// Entrar, criar conta, sair e excluir a conta da nuvem.
class TelaConta extends StatefulWidget {
  const TelaConta({super.key, this.nuvem});

  /// Nos testes; no app, [Nuvem.instancia].
  final Nuvem? nuvem;

  @override
  State<TelaConta> createState() => _TelaContaState();
}

class _TelaContaState extends State<TelaConta> {
  Nuvem get _nuvem => widget.nuvem ?? Nuvem.instancia;

  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _criar = false;
  bool _verSenha = false;
  bool _ocupado = false;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final email = _email.text.trim();
    final senha = _senha.text;
    final erro = !email.contains('@')
        ? 'Digite o seu e-mail.'
        : senha.isEmpty
        ? 'Digite a senha.'
        : _criar && senha.length < 6
        ? 'A senha precisa ter pelo menos 6 caracteres.'
        : null;
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    final msg = ScaffoldMessenger.of(context);
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final r = await _nuvem.entrar(email, senha, criar: _criar);
      _senha.clear();
      msg.showSnackBar(SnackBar(content: Text(_resumo(r))));
    } on FalhaNuvem catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  String _resumo(({int vieram, int foram})? r) {
    if (r == null) {
      return 'Conta conectada. Suas marcações vão para a nuvem quando a '
          'internet voltar.';
    }
    String itens(int n) => n == 1 ? '1 item' : '$n itens';
    if (r.vieram == 0 && r.foram == 0) return 'Conta conectada.';
    return 'Conta conectada: ${itens(r.vieram)} da nuvem e ${itens(r.foram)} '
        'deste aparelho. Nada foi apagado.';
  }

  Future<void> _esqueciSenha() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _erro = 'Digite o seu e-mail e toque de novo.');
      return;
    }
    final msg = ScaffoldMessenger.of(context);
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await _nuvem.redefinirSenha(email);
      msg.showSnackBar(
        SnackBar(
          content: Text(
            'Se houver uma conta com $email, chega lá um e-mail com o link '
            'para criar uma senha nova.',
          ),
        ),
      );
    } on FalhaNuvem catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _sair() async {
    final pendentes = _nuvem.pendentes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: Text(
          'Suas marcações, anotações e o plano continuam neste aparelho, mas '
          'deixam de ir para a nuvem.'
          '${pendentes == 0 ? '' : ' O app ainda tenta mandar as mudanças que faltam.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _ocupado = true);
    await _nuvem.sair();
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _excluir() async {
    final senha = await showDialog<String>(
      context: context,
      builder: (c) => const _ConfirmarExclusao(),
    );
    if (senha == null || !mounted) return;
    final msg = ScaffoldMessenger.of(context);
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await _nuvem.excluirConta(senha);
      msg.showSnackBar(
        const SnackBar(
          content: Text(
            'Conta excluída, com tudo o que ela tinha na nuvem. O que está '
            'neste aparelho continua aqui.',
          ),
        ),
      );
    } on FalhaNuvem catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sua conta')),
      body: ListenableBuilder(
        listenable: _nuvem,
        builder: (context, _) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _nuvem.conectada ? _conectada(context) : _form(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _texto(BuildContext context, String texto) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Text(texto, style: Theme.of(context).textTheme.bodyMedium),
  );

  Widget _mensagemErro(BuildContext context, String erro) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Text(
      erro,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );

  Widget _linkPrivacidade() => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextButton(
        onPressed: () async {
          final msg = ScaffoldMessenger.of(context);
          try {
            if (await launchUrl(
              _privacidade,
              mode: LaunchMode.externalApplication,
            )) {
              return;
            }
          } catch (_) {}
          msg.showSnackBar(
            const SnackBar(
              content: Text('Não foi possível abrir o navegador.'),
            ),
          );
        },
        child: const Text('Política de privacidade'),
      ),
    ),
  );

  List<Widget> _form(BuildContext context) {
    // Saiu sozinha (senha trocada em outro aparelho, conta excluída): diz
    // por quê.
    final aviso = _erro ?? _nuvem.erro;
    return [
      _texto(
        context,
        'Com uma conta, suas marcações, anotações, realces nos livros e o '
        'plano de leitura ficam guardados na nuvem e aparecem no celular e no '
        'PC em que você entrar. Sem conta, o app continua funcionando como '
        'sempre.',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Entrar')),
            ButtonSegment(value: true, label: Text('Criar conta')),
          ],
          selected: {_criar},
          onSelectionChanged: _ocupado
              ? null
              : (v) => setState(() {
                  _criar = v.first;
                  _erro = null;
                }),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: _email,
          enabled: !_ocupado,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'E-mail',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: _senha,
          enabled: !_ocupado,
          obscureText: !_verSenha,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: [
            _criar ? AutofillHints.newPassword : AutofillHints.password,
          ],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _entrar(),
          decoration: InputDecoration(
            labelText: 'Senha',
            helperText: _criar ? 'Pelo menos 6 caracteres' : null,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _verSenha ? 'Esconder a senha' : 'Mostrar a senha',
              icon: Icon(_verSenha ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _verSenha = !_verSenha),
            ),
          ),
        ),
      ),
      if (aviso != null) _mensagemErro(context, aviso),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: FilledButton(
          onPressed: _ocupado ? null : _entrar,
          child: _ocupado
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_criar ? 'Criar conta' : 'Entrar'),
        ),
      ),
      if (!_criar)
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              onPressed: _ocupado ? null : _esqueciSenha,
              child: const Text('Esqueci a senha'),
            ),
          ),
        ),
      _texto(
        context,
        'Os livros baixados e os ajustes de leitura não vão para a nuvem: '
        'ficam em cada aparelho.',
      ),
      _linkPrivacidade(),
    ];
  }

  List<Widget> _conectada(BuildContext context) {
    final n = _nuvem;
    final t = Theme.of(context);
    return [
      ListTile(
        leading: const Icon(Icons.account_circle_outlined),
        title: Text(n.email ?? ''),
        subtitle: const Text('Conta da Bíblia de Estudo'),
      ),
      ListTile(
        leading: Icon(
          n.sincronizando
              ? Icons.sync
              : n.erro != null
              ? Icons.cloud_off_outlined
              : Icons.cloud_done_outlined,
        ),
        title: Text(situacaoDaNuvem(n)),
        trailing: IconButton(
          tooltip: 'Sincronizar agora',
          icon: const Icon(Icons.sync),
          onPressed: n.sincronizando || _ocupado ? null : n.sincronizar,
        ),
      ),
      _texto(
        context,
        'Marcações, anotações, realces nos livros e o plano de leitura vão '
        'para a nuvem sozinhos, alguns segundos depois de cada mudança, e '
        'chegam aos outros aparelhos ao abrir o app (e a cada poucos minutos '
        'com ele aberto).',
      ),
      if (_erro != null) _mensagemErro(context, _erro!),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: OutlinedButton.icon(
          onPressed: _ocupado ? null : _sair,
          icon: const Icon(Icons.logout),
          label: const Text('Sair da conta'),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: TextButton(
          onPressed: _ocupado ? null : _excluir,
          style: TextButton.styleFrom(foregroundColor: t.colorScheme.error),
          child: const Text('Excluir conta e dados na nuvem'),
        ),
      ),
      _linkPrivacidade(),
    ];
  }
}

/// Pede a senha para excluir a conta. Devolve a senha, ou null se cancelou.
class _ConfirmarExclusao extends StatefulWidget {
  const _ConfirmarExclusao();

  @override
  State<_ConfirmarExclusao> createState() => _ConfirmarExclusaoState();
}

class _ConfirmarExclusaoState extends State<_ConfirmarExclusao> {
  final _senha = TextEditingController();

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void confirmar() {
      if (_senha.text.isNotEmpty) Navigator.pop(context, _senha.text);
    }

    return AlertDialog(
      title: const Text('Excluir a conta?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A conta e tudo o que ela guarda na nuvem são apagados, e não dá '
            'para desfazer. O que está neste aparelho continua aqui. Digite a '
            'senha para confirmar.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _senha,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => confirmar(),
            decoration: const InputDecoration(
              labelText: 'Senha',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: confirmar,
          child: const Text('Excluir'),
        ),
      ],
    );
  }
}
