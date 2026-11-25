import 'package:flutter/material.dart';

import '../dados/ajustes.dart';
import '../dados/biblia.dart';
import '../dados/memorizar.dart';
import '../dados/modelos.dart';
import '../dados/referencias.dart';
import 'cartao_versiculo.dart';
import 'oracao.dart' show dataCurta;

String referenciaDe(Memorizacao m) =>
    referenciaDaPassagem(Posicao(m.livro, m.capitulo, m.versiculo), m.ate);

/// O texto da passagem [m] na tradução [versao].
Future<String> textoDe(Memorizacao m, Versao versao) async {
  final versos = await Biblia.instancia.capitulo(
    versao.id,
    m.livro,
    m.capitulo,
  );
  return versos
      .where((v) => v.numero >= m.versiculo && v.numero <= m.ate)
      .map((v) => textoPuro(v.texto).trim())
      .join(' ');
}

/// "João 3:16-17" (ou "jo 3 16"): a passagem, ou null.
({Posicao inicio, int ate})? interpretarPassagem(String entrada) {
  final m = RegExp(r'^(.*?)(?:\s*[-–]\s*(\d{1,3}))?\s*$').firstMatch(entrada);
  final p = Referencias.interpretar(m?.group(1) ?? entrada);
  if (p == null) return null;
  final v = p.versiculo ?? 1;
  final ate = int.tryParse(m?.group(2) ?? '') ?? v;
  if (ate < v || ate - v > 20) return null;
  return (inicio: Posicao(p.livro, p.capitulo, v), ate: ate);
}

/// Memorizar versículos: a lista e a prática em quatro níveis.
class TelaMemorizar extends StatelessWidget {
  const TelaMemorizar({super.key, required this.versao});

  final Versao versao;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memorizar versículos')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
        onPressed: () => _adicionar(context),
      ),
      body: ListenableBuilder(
        listenable: Ajustes.instancia,
        builder: (context, _) {
          final lista = Ajustes.instancia.memorizar;
          if (lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Guarde a Palavra no coração. Toque em "Adicionar" e '
                  'escreva a referência, ou segure o dedo sobre um versículo '
                  'na Bíblia e toque em Memorizar.\n\nA prática vai do texto '
                  'inteiro ao texto escondido, em quatro passos.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final aprendendo = [
            for (final m in lista)
              if (!m.decorada) m,
          ];
          final decoradas = [
            for (final m in lista)
              if (m.decorada) m,
          ];
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              if (aprendendo.isNotEmpty) const _Titulo('Aprendendo'),
              for (final m in aprendendo) _Item(m: m, versao: versao),
              if (decoradas.isNotEmpty) const _Titulo('Já sei de cor'),
              for (final m in decoradas) _Item(m: m, versao: versao),
            ],
          );
        },
      ),
    );
  }

  Future<void> _adicionar(BuildContext context) async {
    final ctrl = TextEditingController();
    final msg = ScaffoldMessenger.of(context);
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Versículo para memorizar'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Referência',
            hintText: 'Ex.: Salmo 119:11 ou João 3:16-17',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (t) => Navigator.pop(c, t),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (r == null || r.trim().isEmpty) return;
    final p = interpretarPassagem(r);
    if (p == null) {
      msg.showSnackBar(
        SnackBar(content: Text('Não entendi a referência "$r".')),
      );
      return;
    }
    final agora = DateTime.now().millisecondsSinceEpoch;
    final m = Memorizacao(
      livro: p.inicio.livro,
      capitulo: p.inicio.capitulo,
      versiculo: p.inicio.versiculo!,
      ate: p.ate,
      criada: agora,
      atualizado: agora,
    );
    if (await textoDe(m, versao).then((t) => t.isEmpty, onError: (_) => true)) {
      msg.showSnackBar(
        SnackBar(
          content: Text('${referenciaDe(m)} não existe nesta tradução.'),
        ),
      );
      return;
    }
    Ajustes.instancia.salvarMemorizacao(m);
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(texto, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _Item extends StatelessWidget {
  const _Item({required this.m, required this.versao});

  final Memorizacao m;
  final Versao versao;

  @override
  Widget build(BuildContext context) {
    final pratica = m.ultimaPratica == null
        ? 'Ainda não praticou'
        : 'Praticou ${m.praticas} ${m.praticas == 1 ? 'vez' : 'vezes'}, '
              'a última em ${dataCurta(DateTime.fromMillisecondsSinceEpoch(m.ultimaPratica!))}';
    return ListTile(
      leading: Icon(
        m.decorada ? Icons.verified : Icons.psychology_outlined,
        color: m.decorada ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(referenciaDe(m)),
      subtitle: Text(pratica),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TelaPraticar(memorizacao: m, versao: versao),
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Mais opções',
        onSelected: (op) {
          final aj = Ajustes.instancia;
          switch (op) {
            case 'decorada':
              aj.salvarMemorizacao(m.copiar(decorada: !m.decorada));
            case 'abrir':
              Navigator.pop(context, Posicao(m.livro, m.capitulo, m.versiculo));
            case 'apagar':
              aj.apagarMemorizacao(m);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'decorada',
            child: Text(m.decorada ? 'Voltar a praticar' : 'Já sei de cor'),
          ),
          const PopupMenuItem(value: 'abrir', child: Text('Abrir na Bíblia')),
          const PopupMenuItem(value: 'apagar', child: Text('Tirar da lista')),
        ],
      ),
    );
  }
}

/// A prática de uma passagem: do texto inteiro ao texto escondido.
class TelaPraticar extends StatefulWidget {
  const TelaPraticar({
    super.key,
    required this.memorizacao,
    required this.versao,
    this.texto,
  });

  final Memorizacao memorizacao;
  final Versao versao;

  /// Para os testes: o texto, sem ler o banco.
  final String? texto;

  @override
  State<TelaPraticar> createState() => _TelaPraticarState();
}

class _TelaPraticarState extends State<TelaPraticar> {
  late final Future<String> _texto = widget.texto != null
      ? Future.value(widget.texto)
      : textoDe(widget.memorizacao, widget.versao);
  int _nivel = 0;
  bool _espiar = false;

  void _terminar() {
    final m = widget.memorizacao;
    final aj = Ajustes.instancia;
    final atual = aj.memorizacao(m.livro, m.capitulo, m.versiculo) ?? m;
    aj.salvarMemorizacao(
      atual.copiar(
        praticas: atual.praticas + 1,
        ultimaPratica: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    setState(() => _nivel = niveisMemorizar.length);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final m = widget.memorizacao;
    final fim = _nivel >= niveisMemorizar.length;
    return Scaffold(
      appBar: AppBar(title: Text(referenciaDe(m))),
      body: FutureBuilder<String>(
        future: _texto,
        builder: (context, snap) {
          final texto = snap.data;
          if (texto == null) {
            return Center(
              child: snap.hasError
                  ? const Text('Não foi possível ler o texto.')
                  : const CircularProgressIndicator(),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (!fim) ...[
                LinearProgressIndicator(
                  value: (_nivel + 1) / niveisMemorizar.length,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Passo ${_nivel + 1} de ${niveisMemorizar.length}: '
                  '${niveisMemorizar[_nivel]}',
                  style: t.textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                Text(
                  _espiar || _nivel == 0
                      ? texto
                      : _nivel == niveisMemorizar.length - 1
                      ? 'Diga a passagem em voz alta ou escreva num papel. '
                            'Depois confira.'
                      : textoDoNivel(texto, _nivel),
                  style: t.textTheme.headlineSmall?.copyWith(
                    height: 1.5,
                    fontStyle: _nivel == niveisMemorizar.length - 1 && !_espiar
                        ? FontStyle.italic
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(referenciaDe(m), style: t.textTheme.titleSmall),
                const SizedBox(height: 32),
                if (_nivel > 0)
                  OutlinedButton.icon(
                    icon: Icon(
                      _espiar ? Icons.visibility_off : Icons.visibility,
                    ),
                    label: Text(_espiar ? 'Esconder' : 'Conferir o texto'),
                    onPressed: () => setState(() => _espiar = !_espiar),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    if (_nivel == niveisMemorizar.length - 1) {
                      _terminar();
                    } else {
                      setState(() {
                        _nivel++;
                        _espiar = false;
                      });
                    }
                  },
                  child: Text(
                    _nivel == niveisMemorizar.length - 1
                        ? 'Consegui!'
                        : 'Próximo passo',
                  ),
                ),
                if (_nivel > 0)
                  TextButton(
                    onPressed: () => setState(() {
                      _nivel--;
                      _espiar = false;
                    }),
                    child: const Text('Voltar um passo'),
                  ),
              ] else ...[
                Icon(Icons.celebration, size: 64, color: t.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Muito bem!',
                  textAlign: TextAlign.center,
                  style: t.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pratique de novo amanhã: repetir em dias diferentes é o '
                  'que fixa o texto.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.tonal(
                  onPressed: () {
                    final aj = Ajustes.instancia;
                    final atual =
                        aj.memorizacao(m.livro, m.capitulo, m.versiculo) ?? m;
                    aj.salvarMemorizacao(atual.copiar(decorada: true));
                    Navigator.pop(context);
                  },
                  child: const Text('Já sei de cor'),
                ),
                TextButton(
                  onPressed: () => setState(() => _nivel = 0),
                  child: const Text('Praticar de novo'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
