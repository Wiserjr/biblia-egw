import 'package:flutter/material.dart';

import '../dados/ajustes.dart';
import '../dados/biblia.dart';
import '../dados/estudo.dart';
import '../dados/modelos.dart';
import '../dados/referencias.dart';
import 'acoes_versiculo.dart';
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
      length: 4,
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
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Salvos'),
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
                const _Salvos(),
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

/// Tudo o que a pessoa guardou nos versículos (cor, anotação, etiquetas),
/// com o texto, e filtro por etiqueta.
class _Salvos extends StatefulWidget {
  const _Salvos();

  @override
  State<_Salvos> createState() => _SalvosState();
}

class _SalvosState extends State<_Salvos> {
  String? _etiqueta;
  final _capitulos = <String, Future<List<Versiculo>>>{};
  late final Future<int?> _versao = _versaoEmUso();

  @override
  void initState() {
    super.initState();
    Ajustes.instancia.addListener(_mudou);
  }

  @override
  void dispose() {
    Ajustes.instancia.removeListener(_mudou);
    super.dispose();
  }

  void _mudou() {
    if (mounted) setState(() {});
  }

  static Future<int?> _versaoEmUso() async {
    try {
      final v = await Biblia.instancia.versoes();
      if (v.isEmpty) return null;
      final id = Ajustes.instancia.versao;
      return v.firstWhere((x) => x.id == id, orElse: () => v.first).id;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _texto(int versao, (int, int, int) k) async {
    final lista = await (_capitulos['$versao:${k.$1}:${k.$2}'] ??= Biblia
        .instancia
        .capitulo(versao, k.$1, k.$2));
    for (final v in lista) {
      if (v.numero == k.$3) return textoPuro(v.texto).trim();
    }
    return null;
  }

  Future<void> _renomear(String etiqueta) async {
    final ctrl = TextEditingController(text: etiqueta);
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Etiqueta "$etiqueta"'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Novo nome',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, ''),
            child: const Text('Tirar de todos'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text),
            child: const Text('Renomear'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (r == null) return;
    Ajustes.instancia.renomearEtiqueta(etiqueta, r);
    setState(() => _etiqueta = r.trim().isEmpty ? null : r.trim());
  }

  @override
  Widget build(BuildContext context) {
    final aj = Ajustes.instancia;
    final t = Theme.of(context);
    final marcas = {for (final (k, cor) in aj.todasMarcacoes()) k: cor};
    final notas = {for (final (k, n) in aj.todasAnotacoes()) k: n};
    final etiquetas = {for (final (k, e) in aj.todasEtiquetas()) k: e};
    final nomes = aj.nomesEtiquetas;
    final filtro = nomes.contains(_etiqueta) ? _etiqueta : null;
    final chaves =
        {...marcas.keys, ...notas.keys, ...etiquetas.keys}
            .where(
              (k) =>
                  filtro == null ||
                  (etiquetas[k] ?? const []).any(
                    (e) => e.toLowerCase() == filtro.toLowerCase(),
                  ),
            )
            .toList()
          ..sort(
            (a, b) => a.$1 != b.$1
                ? a.$1.compareTo(b.$1)
                : a.$2 != b.$2
                ? a.$2.compareTo(b.$2)
                : a.$3.compareTo(b.$3),
          );
    return Column(
      children: [
        if (nomes.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('Todos'),
                    selected: filtro == null,
                    onSelected: (_) => setState(() => _etiqueta = null),
                  ),
                ),
                for (final e in nomes)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onLongPress: () => _renomear(e),
                      child: ChoiceChip(
                        avatar: const Icon(Icons.label_outline, size: 16),
                        label: Text(e),
                        selected: filtro == e,
                        onSelected: (_) => setState(() => _etiqueta = e),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: chaves.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Os versículos que você marcar com cor, anotar ou '
                      'puser numa etiqueta aparecem aqui, com o texto. '
                      'Segure o dedo sobre um versículo e toque em Etiquetas '
                      'para juntá-los por assunto.',
                      textAlign: TextAlign.center,
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: t.hintColor,
                      ),
                    ),
                  ),
                )
              : FutureBuilder<int?>(
                  future: _versao,
                  builder: (context, snap) => ListView.separated(
                    itemCount: chaves.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final k = chaves[i];
                      final cor = marcas[k];
                      final versao = snap.data;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 10,
                          backgroundColor: cor == null
                              ? Colors.transparent
                              : coresMarcacao[cor % coresMarcacao.length],
                        ),
                        title: Text(
                          '${Referencias.nome(k.$1)} ${k.$2}:${k.$3}',
                          style: t.textTheme.labelLarge?.copyWith(
                            color: t.colorScheme.primary,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (versao != null)
                              FutureBuilder<String?>(
                                future: _texto(versao, k),
                                builder: (context, s) => Text(
                                  s.data ?? '',
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (notas[k] != null)
                              Text(
                                notas[k]!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: t.textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            if (etiquetas[k] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  etiquetas[k]!.map((e) => '#$e').join('  '),
                                  style: t.textTheme.labelSmall?.copyWith(
                                    color: t.colorScheme.tertiary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          tooltip: 'Etiquetas',
                          icon: const Icon(Icons.label_outline),
                          onPressed: () => editarEtiquetas(
                            context,
                            Posicao(k.$1, k.$2, k.$3),
                          ),
                        ),
                        onTap: () =>
                            Navigator.pop(context, Posicao(k.$1, k.$2, k.$3)),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
