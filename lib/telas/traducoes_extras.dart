import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dados/banco.dart';
import '../dados/biblia.dart';
import '../dados/traducoes_extras.dart';

/// As traduções protegidas por direitos autorais: não vêm no app, e a pessoa
/// pode baixá-las, uma a uma, direto da coleção pública damarals/biblias.
class TelaTraducoesExtras extends StatefulWidget {
  const TelaTraducoesExtras({super.key, this.banco, this.traducoes});

  /// Nos testes: um banco e um baixador sem rede.
  final Database? banco;
  final TraducoesExtras? traducoes;

  @override
  State<TelaTraducoesExtras> createState() => _TelaTraducoesExtrasState();
}

class _TelaTraducoesExtrasState extends State<TelaTraducoesExtras> {
  Database? get _banco => widget.banco ?? Banco.instancia.extras;
  late final _traducoes = widget.traducoes ?? TraducoesExtras();

  Set<int> _instaladas = {};
  final _progresso = <int, double>{};
  final _cancelar = <int>{};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final db = _banco;
    if (db == null) return;
    final ids = await TraducoesExtras.instaladas(db);
    if (mounted) setState(() => _instaladas = ids);
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _baixar(TraducaoBaixavel t) async {
    final db = _banco;
    if (db == null) {
      _avisar('Não foi possível abrir o banco das traduções neste aparelho.');
      return;
    }
    setState(() => _progresso[t.id] = 0);
    try {
      await _traducoes.baixar(
        db,
        t,
        progresso: (v) {
          if (mounted) setState(() => _progresso[t.id] = v);
        },
        cancelado: () => _cancelar.contains(t.id),
      );
      Biblia.instancia.esquecerVersoes();
      _avisar('${t.nome} baixada. Escolha-a pela sigla, no alto da tela.');
    } on TraducaoDownloadCancelado {
      _avisar('Download cancelado.');
    } on FormatException catch (e) {
      _avisar(e.message);
    } catch (_) {
      _avisar('Não foi possível concluir o download. Tente novamente.');
    } finally {
      _cancelar.remove(t.id);
      if (mounted) setState(() => _progresso.remove(t.id));
      await _carregar();
    }
  }

  Future<void> _remover(TraducaoBaixavel t) async {
    final db = _banco;
    if (db == null) return;
    final sim = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remover ${t.nome}?'),
        content: const Text(
          'O texto sai deste aparelho. Marcações e anotações continuam, e você '
          'pode baixá-la de novo quando quiser.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (sim != true) return;
    await TraducoesExtras.remover(db, t);
    Biblia.instancia.esquecerVersoes();
    await _carregar();
  }

  Future<void> _abrirFonte() async {
    try {
      if (await launchUrl(
        Uri.parse(fonteTraducoes),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {}
    _avisar('Não foi possível abrir o navegador.');
  }

  Widget _acao(TraducaoBaixavel t) {
    final progresso = _progresso[t.id];
    if (progresso != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              value: progresso == 0 ? null : progresso,
              strokeWidth: 3,
            ),
          ),
          IconButton(
            tooltip: 'Cancelar',
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _cancelar.add(t.id)),
          ),
        ],
      );
    }
    if (_instaladas.contains(t.id)) {
      return IconButton(
        tooltip: 'Remover do aparelho',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _remover(t),
      );
    }
    return IconButton(
      tooltip: 'Baixar',
      icon: const Icon(Icons.download),
      onPressed: () => _baixar(t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mais traduções')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Estas traduções pertencem às suas editoras e não vêm com o '
              'aplicativo. Se quiser usá-las, o download é feito a seu pedido, '
              'direto da coleção pública damarals/biblias, no GitHub, e o texto '
              'fica só neste aparelho. Confira se a editora permite o seu uso.',
              style: tema.textTheme.bodyMedium,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                onPressed: _abrirFonte,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Ver a coleção no GitHub'),
              ),
            ),
          ),
          const Divider(),
          for (final t in traducoesBaixaveis)
            ListTile(
              leading: SizedBox(
                width: 56,
                child: Text(
                  t.sigla,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(t.nome),
              subtitle: Text(
                [
                  t.editora ?? 'Editora não informada pela fonte',
                  if (_instaladas.contains(t.id)) 'baixada',
                ].join(' • '),
              ),
              trailing: _acao(t),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'Cada tradução ocupa cerca de 5 MB no aparelho. A coleção avisa que há textos '
              'truncados na origem; o aplicativo confere a estrutura (66 '
              'livros, todos os capítulos), mas não corrige o texto.',
              style: tema.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
