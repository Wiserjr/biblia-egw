import 'package:flutter/material.dart';

import '../dados/biblioteca.dart';
import '../dados/estudo.dart';
import '../dados/guia_biblioteca.dart';
import '../dados/modelos.dart';
import 'leitor_pdf.dart';

/// Um plano no próprio ritmo: a meta é por sessão, sem dias vencidos.
class TelaGuiaBiblioteca extends StatefulWidget {
  const TelaGuiaBiblioteca({super.key, this.obra, this.carregarDados});
  final Obra? obra;
  final Future<(Map<int, Obra>, List<CapituloObra>)> Function()? carregarDados;
  @override
  State<TelaGuiaBiblioteca> createState() => _TelaGuiaBibliotecaState();
}

class _TelaGuiaBibliotecaState extends State<TelaGuiaBiblioteca> {
  late final _dados = widget.carregarDados?.call() ?? _carregar();
  final _guia = GuiaBiblioteca.instancia;

  Future<(Map<int, Obra>, List<CapituloObra>)> _carregar() async =>
      (await Estudo.instancia.obras(), await Estudo.instancia.capitulosObras());

  Future<void> _gravar(Future<void> Function() acao) async {
    try {
      await acao();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar o progresso. Tente novamente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _ler(Obra obra, {int? pagina}) async {
    final bib = Biblioteca.instancia;
    if (!bib.disponivel(obra)) {
      final baixar = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Baixar ${obra.titulo}?'),
          content: Text(
            'O livro precisa estar no aparelho para ler. Download: ${tamanhoLegivel(obra.bytes)}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Agora não'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Baixar'),
            ),
          ],
        ),
      );
      if (baixar != true) return;
      try {
        await bib.baixar(obra);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
        return;
      }
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TelaPdf(obra: obra, pagina: pagina ?? 0, retomar: pagina == null),
      ),
    );
  }

  Future<void> _novoPlano(
    Map<int, Obra> obras,
    List<CapituloObra> capitulos,
  ) async {
    final ids = capitulos.map((c) => c.obra).toSet();
    final elegiveis =
        obras.values
            .where(
              (o) =>
                  (o.deEllenWhite || o.id == widget.obra?.id) &&
                  ids.contains(o.id),
            )
            .toList()
          ..sort(
            (a, b) => a.prioridade != b.prioridade
                ? a.prioridade.compareTo(b.prioridade)
                : a.id.compareTo(b.id),
          );
    final escolhidos = <int>{if (widget.obra != null) widget.obra!.id};
    var meta = _guia.meta;
    var biblioteca = false;
    final salvar = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, atualizar) => AlertDialog(
          title: const Text('Plano de leitura EGW'),
          content: SizedBox(
            width: 480,
            height: 380,
            child: Column(
              children: [
                DropdownButtonFormField<bool>(
                  isExpanded: true,
                  initialValue: false,
                  decoration: const InputDecoration(labelText: 'Abrangência'),
                  items: const [
                    DropdownMenuItem(
                      value: false,
                      child: Text(
                        'Um ou mais livros',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: true,
                      child: Text(
                        'Biblioteca EGW completa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (v) => atualizar(() => biblioteca = v ?? false),
                ),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: meta,
                  decoration: const InputDecoration(
                    labelText: 'Etapas por sessão',
                  ),
                  items: [
                    for (var n = 1; n <= 20; n++)
                      DropdownMenuItem(value: n, child: Text('$n')),
                  ],
                  onChanged: (v) => atualizar(() => meta = v ?? 1),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Uma etapa é um capítulo; nos livros sem sumário, é a leitura integral. Avance no seu ritmo e aproveite o progresso já salvo.',
                ),
                Expanded(
                  child: biblioteca
                      ? Center(
                          child: Text(
                            '${elegiveis.where((o) => o.deEllenWhite).length} livros EGW, na ordem do catálogo. Livros sem sumário entram como leitura integral.',
                          ),
                        )
                      : ListView(
                          children: [
                            for (final o in elegiveis)
                              CheckboxListTile(
                                dense: true,
                                title: Text(o.titulo),
                                value: escolhidos.contains(o.id),
                                onChanged: (v) => atualizar(() {
                                  if (v == true) {
                                    escolhidos.add(o.id);
                                  } else {
                                    escolhidos.remove(o.id);
                                  }
                                }),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: biblioteca || escolhidos.isNotEmpty
                  ? () => Navigator.pop(c, true)
                  : null,
              child: const Text('Iniciar plano'),
            ),
          ],
        ),
      ),
    );
    if (salvar == true) {
      await _gravar(
        () => _guia.iniciarPlano(
          elegiveis
              .where(
                (o) => biblioteca ? o.deEllenWhite : escolhidos.contains(o.id),
              )
              .map((o) => o.id),
          meta,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.obra == null ? 'Guia de leitura EGW' : widget.obra!.titulo,
      ),
    ),
    body: FutureBuilder<(Map<int, Obra>, List<CapituloObra>)>(
      future: _dados,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Text('Não foi possível carregar os capítulos.'),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (obras, todos) = snap.data!;
        final caps = todos
            .where(
              (c) => widget.obra != null
                  ? c.obra == widget.obra!.id
                  : obras[c.obra]?.deEllenWhite == true,
            )
            .toList();
        return ListenableBuilder(
          listenable: _guia,
          builder: (context, _) {
            final pendentes = _guia.pendentes(todos);
            final doPlano = todos
                .where((c) => _guia.plano.contains(c.obra))
                .toList();
            final lidos = caps.where(_guia.concluido).length;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Leia, reflita e marque as leituras concluídas. Uma etapa é um capítulo; nos livros sem sumário, é o livro inteiro. O leitor guarda o lugar onde você parou.',
                ),
                const SizedBox(height: 12),
                Text(
                  '$lidos de ${caps.length} etapas concluídas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: caps.isEmpty ? 0 : lidos / caps.length,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _novoPlano(obras, todos),
                  icon: const Icon(Icons.playlist_add),
                  label: Text(
                    _guia.plano.isEmpty
                        ? 'Criar plano de leitura'
                        : 'Escolher outro plano',
                  ),
                ),
                if (_guia.plano.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plano: ${_guia.plano.length} livro(s) · ${doPlano.length - pendentes.length}/${doPlano.length} etapas',
                          ),
                          Text(
                            'Meta: ${_guia.meta} etapa(s) por sessão · ${pendentes.isEmpty ? 0 : (pendentes.length / _guia.meta).ceil()} sessões restantes',
                          ),
                          if (pendentes.isEmpty)
                            const Text('Plano concluído!')
                          else ...[
                            const SizedBox(height: 8),
                            const Text('Próxima sessão'),
                            for (final c in pendentes.take(_guia.meta))
                              ListTile(
                                title: Text(c.titulo),
                                subtitle: Text(obras[c.obra]?.titulo ?? ''),
                                onTap: obras[c.obra] == null
                                    ? null
                                    : () => _ler(
                                        obras[c.obra]!,
                                        pagina: c.pagina,
                                      ),
                              ),
                          ],
                          TextButton(
                            onPressed: () => _gravar(_guia.encerrarPlano),
                            child: const Text(
                              'Encerrar plano e preservar progresso',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (caps.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Este livro ainda não tem capítulos indexados. Você pode ler e retomar o lugar salvo.',
                    ),
                  ),
                for (final id in caps.map((c) => c.obra).toSet())
                  _livro(obras[id]!, caps.where((c) => c.obra == id).toList()),
                if (widget.obra != null && caps.isEmpty)
                  TextButton.icon(
                    onPressed: () => _ler(widget.obra!),
                    icon: const Icon(Icons.bookmark_outline),
                    label: const Text('Ler ou continuar'),
                  ),
              ],
            );
          },
        );
      },
    ),
  );

  Widget _livro(Obra obra, List<CapituloObra> caps) {
    final lidos = caps.where(_guia.concluido).length;
    final lugar = _guia.lugar(obra.id);
    return ExpansionTile(
      initiallyExpanded: widget.obra != null,
      title: Text(obra.titulo),
      subtitle: Text(
        '${caps.first.leituraIntegral ? (lidos == 0 ? 'Livro ainda não concluído' : 'Livro concluído') : '$lidos/${caps.length} capítulos'}${lugar == null ? '' : ' · página PDF ${lugar.pagina + 1}'}',
      ),
      children: [
        TextButton.icon(
          onPressed: () => _ler(obra),
          icon: const Icon(Icons.bookmark_outline),
          label: Text(
            lugar == null ? 'Iniciar leitura' : 'Continuar de onde parei',
          ),
        ),
        for (final c in caps)
          ListTile(
            leading: Checkbox(
              value: _guia.concluido(c),
              onChanged: (v) => _gravar(() => _guia.marcar(c, v == true)),
            ),
            title: Text(c.titulo),
            subtitle: Text(
              c.leituraIntegral
                  ? 'Marque somente após terminar o livro inteiro.'
                  : 'Página ${c.pagina + 1} do PDF',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _ler(obra, pagina: c.pagina),
          ),
      ],
    );
  }
}
