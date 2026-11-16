import 'package:flutter/material.dart';

import '../dados/ajustes.dart';
import '../dados/modelos.dart';
import '../dados/referencias.dart';

/// Escolha de livro e capítulo: abas AT/NT, grade de livros, grade de
/// capítulos.
class TelaSeletor extends StatefulWidget {
  const TelaSeletor({super.key, required this.atual});
  final Posicao atual;

  @override
  State<TelaSeletor> createState() => _TelaSeletorState();
}

class _TelaSeletorState extends State<TelaSeletor> {
  int? _livro;

  @override
  Widget build(BuildContext context) {
    final livro = _livro;
    if (livro != null) return _capitulos(context, livro);
    return DefaultTabController(
      length: 2,
      initialIndex: widget.atual.livro >= 40 ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Escolher livro'),
          actions: [
            IconButton(
              tooltip: 'Histórico de leitura',
              icon: const Icon(Icons.history),
              onPressed: () async {
                final p = await Navigator.push<Posicao>(
                  context,
                  MaterialPageRoute(builder: (_) => const TelaHistorico()),
                );
                if (p != null && context.mounted) Navigator.pop(context, p);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Antigo Testamento'),
              Tab(text: 'Novo Testamento'),
            ],
          ),
        ),
        body: Column(
          children: [
            _Recentes(atual: widget.atual),
            Expanded(
              child: TabBarView(
                children: [_grade(context, 1, 39), _grade(context, 40, 66)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grade(BuildContext context, int de, int ate) {
    final t = Theme.of(context);
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisExtent: 56,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: ate - de + 1,
      itemBuilder: (context, i) {
        final n = de + i;
        final atual = n == widget.atual.livro;
        return Material(
          color: atual
              ? t.colorScheme.primaryContainer
              : t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              if (Referencias.capitulos[n - 1] == 1) {
                Navigator.pop(context, Posicao(n, 1));
              } else {
                setState(() => _livro = n);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      Referencias.abreviacao(n),
                      style: t.textTheme.labelMedium?.copyWith(
                        color: t.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      Referencias.nome(n),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _capitulos(BuildContext context, int livro) {
    final t = Theme.of(context);
    final total = Referencias.capitulos[livro - 1];
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => setState(() => _livro = null)),
        title: Text(Referencias.nome(livro)),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 64,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: total,
        itemBuilder: (context, i) {
          final cap = i + 1;
          final atual =
              livro == widget.atual.livro && cap == widget.atual.capitulo;
          return Material(
            color: atual
                ? t.colorScheme.primaryContainer
                : t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pop(context, Posicao(livro, cap)),
              child: Center(
                child: Text('$cap', style: t.textTheme.titleMedium),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Os últimos capítulos lidos (sem o atual), num toque.
class _Recentes extends StatelessWidget {
  const _Recentes({required this.atual});

  final Posicao atual;

  static const _quantos = 5;

  @override
  Widget build(BuildContext context) {
    final recentes = [
      for (final h in Ajustes.instancia.historico)
        if (h.capitulo.livro != atual.livro ||
            h.capitulo.capitulo != atual.capitulo)
          h.capitulo,
    ].take(_quantos).toList();
    if (recentes.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context);
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text('Recentes', style: t.textTheme.labelMedium),
            ),
          ),
          for (final c in recentes)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text('${Referencias.nome(c.livro)} ${c.capitulo}'),
                onPressed: () => Navigator.pop(context, c),
              ),
            ),
        ],
      ),
    );
  }
}

/// Os capítulos abertos por último, do mais recente ao mais antigo.
class TelaHistorico extends StatelessWidget {
  const TelaHistorico({super.key});

  @override
  Widget build(BuildContext context) {
    final aj = Ajustes.instancia;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de leitura'),
        actions: [
          ListenableBuilder(
            listenable: aj,
            builder: (context, _) => IconButton(
              tooltip: 'Limpar o histórico',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: aj.historico.isEmpty ? null : aj.limparHistorico,
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: aj,
        builder: (context, _) {
          final itens = aj.historico;
          if (itens.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Os capítulos que você abrir aparecem aqui.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final agora = DateTime.now();
          return ListView(
            children: [
              for (final h in itens)
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(
                    '${Referencias.nome(h.capitulo.livro)} '
                    '${h.capitulo.capitulo}',
                  ),
                  subtitle: Text(quandoLido(h.quando, agora)),
                  onTap: () => Navigator.pop(context, h.capitulo),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// "Hoje, 07:15", "Ontem, 21:40" ou "12/11/2026, 08:03".
String quandoLido(DateTime quando, DateTime agora) {
  final hora =
      '${quando.hour.toString().padLeft(2, '0')}:'
      '${quando.minute.toString().padLeft(2, '0')}';
  final dia = DateTime(quando.year, quando.month, quando.day);
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final dias = hoje.difference(dia).inHours ~/ 24;
  if (dias == 0) return 'Hoje, $hora';
  if (dias == 1) return 'Ontem, $hora';
  return '${quando.day.toString().padLeft(2, '0')}/'
      '${quando.month.toString().padLeft(2, '0')}/${quando.year}, $hora';
}
