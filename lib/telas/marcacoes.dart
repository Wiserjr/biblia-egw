import 'package:flutter/material.dart';

import '../dados/ajustes.dart';
import '../dados/estudo.dart';
import '../dados/modelos.dart';
import '../dados/referencias.dart';
import 'backup.dart';
import 'cartao_trecho.dart';

/// Versículos marcados e anotados, e trechos realçados nos livros. Tocar leva
/// ao versículo (ou abre o livro na página).
class TelaMarcacoes extends StatelessWidget {
  const TelaMarcacoes({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Marcações e anotações'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (op) => op == 'salvar'
                  ? salvarCopia(context)
                  : restaurarCopia(context),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'salvar',
                  child: ListTile(
                    leading: Icon(Icons.save_alt),
                    title: Text('Salvar cópia'),
                  ),
                ),
                PopupMenuItem(
                  value: 'restaurar',
                  child: ListTile(
                    leading: Icon(Icons.restore),
                    title: Text('Restaurar cópia'),
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Marcações'),
              Tab(text: 'Anotações'),
              Tab(text: 'Livros'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: Ajustes.instancia,
          builder: (context, _) {
            final marcas = Ajustes.instancia.todasMarcacoes();
            final notas = Ajustes.instancia.todasAnotacoes();
            final realces = Ajustes.instancia.todosRealces();
            String ref((int, int, int) k) =>
                '${Referencias.nome(k.$1)} ${k.$2}:${k.$3}';
            Widget vazio(String s) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  s,
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor),
                ),
              ),
            );
            return TabBarView(
              children: [
                marcas.isEmpty
                    ? vazio(
                        'Segure o dedo sobre um versículo (ou use o painel de '
                        'estudo) para marcá-lo com uma cor.',
                      )
                    : ListView(
                        children: [
                          for (final (k, cor) in marcas)
                            ListTile(
                              leading: CircleAvatar(
                                radius: 10,
                                backgroundColor:
                                    coresMarcacao[cor % coresMarcacao.length],
                              ),
                              title: Text(ref(k)),
                              onTap: () => Navigator.pop(
                                context,
                                Posicao(k.$1, k.$2, k.$3),
                              ),
                            ),
                        ],
                      ),
                notas.isEmpty
                    ? vazio('Suas anotações sobre os versículos aparecem aqui.')
                    : ListView(
                        children: [
                          for (final (k, texto) in notas)
                            ListTile(
                              leading: const Icon(Icons.edit_note),
                              title: Text(ref(k)),
                              subtitle: Text(
                                texto,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.pop(
                                context,
                                Posicao(k.$1, k.$2, k.$3),
                              ),
                            ),
                        ],
                      ),
                realces.isEmpty
                    ? vazio(
                        'Selecione um trecho num livro de Ellen G. White e '
                        'toque em Realçar ou Nota. Ele aparece aqui.',
                      )
                    : _ListaRealces(realces: realces),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ListaRealces extends StatelessWidget {
  const _ListaRealces({required this.realces});
  final List<Realce> realces;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<int, Obra>>(
      future: Estudo.instancia.obras(),
      builder: (context, snap) {
        final obras = snap.data;
        if (obras == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          children: [
            for (final r in realces)
              ListTile(
                leading: CircleAvatar(
                  radius: 10,
                  backgroundColor: coresMarcacao[r.cor % coresMarcacao.length],
                  child: r.nota == null
                      ? null
                      : const Icon(Icons.edit_note, size: 14),
                ),
                title: Text(
                  '${obras[r.obra]?.titulo ?? 'Livro ${r.obra}'}, '
                  'p. ${r.pagina}',
                ),
                subtitle: Text(
                  ['“${r.texto}”', if (r.nota != null) r.nota!].join('\n'),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Apagar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => Ajustes.instancia.apagarRealce(r),
                ),
                onTap: obras[r.obra] == null
                    ? null
                    : () => abrirObra(context, obras[r.obra]!, r.pagina - 1),
              ),
          ],
        );
      },
    );
  }
}
