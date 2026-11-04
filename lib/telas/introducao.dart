import 'package:flutter/material.dart';

import '../dados/estudo.dart';
import '../dados/modelos.dart';
import '../dados/referencias.dart';
import '../dados/temas.dart' show tituloCurto;
import 'cartao_trecho.dart' show abrirObra;
import 'largura_texto.dart';
import 'tema.dart';

/// Introdução ao livro: autor, data, local, tema, esboço, mensagem, Cristo no
/// livro e onde Ellen G. White trata dele.
class TelaIntroducao extends StatefulWidget {
  const TelaIntroducao({super.key, required this.livro});
  final int livro;

  @override
  State<TelaIntroducao> createState() => _TelaIntroducaoState();
}

class _TelaIntroducaoState extends State<TelaIntroducao> {
  late final Future<Introducao?> _intro = Estudo.instancia.introducao(
    widget.livro,
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Introdução a ${Referencias.nome(widget.livro)}'),
      ),
      body: FutureBuilder<Introducao?>(
        future: _intro,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final i = snap.data;
          if (i == null) {
            return const Center(child: Text('Sem introdução para este livro.'));
          }
          Widget campo(String rotulo, String? valor, {IconData? icone}) {
            if (valor == null || valor.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (icone != null) ...[
                        Icon(icone, size: 18, color: t.colorScheme.primary),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          rotulo,
                          style: t.textTheme.labelLarge?.copyWith(
                            color: t.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valor,
                    style: t.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ],
              ),
            );
          }

          final esboco = (i['esboco'] ?? '')
              .split('\n')
              .where((l) => l.trim().isNotEmpty)
              .toList();
          return LarguraDoTexto(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  Referencias.nome(widget.livro),
                  style: t.textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _linha(context, 'Autor', i['autor']),
                        _linha(context, 'Data', i['data']),
                        _linha(context, 'Local', i['local']),
                        _linha(context, 'Para', i['destinatarios']),
                        _linha(
                          context,
                          'Versículo-chave',
                          i['versiculo_chave'],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                campo(
                  'Contexto histórico e literário',
                  i['contexto'],
                  icone: Icons.history_edu,
                ),
                campo(
                  'Como ler este livro',
                  i['forma_literaria'],
                  icone: Icons.auto_stories_outlined,
                ),
                campo('Tema', i['tema'], icone: Icons.lightbulb_outline),
                campo(
                  'Mensagem',
                  i['mensagem'],
                  icone: Icons.campaign_outlined,
                ),
                if (esboco.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.list_alt,
                        size: 18,
                        color: t.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Esboço',
                        style: t.textTheme.labelLarge?.copyWith(
                          color: t.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final l in esboco)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('•  $l', style: t.textTheme.bodyLarge),
                    ),
                  const SizedBox(height: 14),
                ],
                campo(
                  'Cristo no livro',
                  i['cristo'],
                  icone: Icons.favorite_border,
                ),
                Card(
                  color: corEgw(context).withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.menu_book_outlined, color: corEgw(context)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Em Ellen G. White',
                                style: t.textTheme.labelLarge?.copyWith(
                                  color: corEgw(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              LeiturasDaIntroducao(livro: widget.livro),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                campo(
                  'Perguntas para a leitura',
                  i['para_refletir'],
                  icone: Icons.help_outline,
                ),
                campo(
                  'Fontes e natureza do conteúdo',
                  i['fontes'],
                  icone: Icons.source_outlined,
                ),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      Navigator.pop(context, Posicao(widget.livro, 1)),
                  icon: const Icon(Icons.chrome_reader_mode_outlined),
                  label: const Text('Ler o livro'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _linha(BuildContext context, String rotulo, String? valor) {
    if (valor == null || valor.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              rotulo,
              style: t.textTheme.labelMedium?.copyWith(color: t.hintColor),
            ),
          ),
          Expanded(child: Text(valor, style: t.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// "Em Ellen G. White": os capítulos que ela declara baseados no livro, os
/// que mais o citam e o comentário versículo a versículo dos pioneiros —
/// todos tirados do índice dos PDFs, e cada um abre o livro na página.
class LeiturasDaIntroducao extends StatefulWidget {
  const LeiturasDaIntroducao({super.key, required this.livro});
  final int livro;

  @override
  State<LeiturasDaIntroducao> createState() => _LeiturasDaIntroducaoState();
}

class _LeiturasDaIntroducaoState extends State<LeiturasDaIntroducao> {
  late final Future<List<LeituraIntroducao>> _leituras = Estudo.instancia
      .leiturasIntroducao(widget.livro);

  /// Acima disso, os capítulos de uma obra ficam recolhidos.
  static const _visiveis = 6;

  Widget _item(LeituraIntroducao l, {String? detalhe}) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    visualDensity: VisualDensity.compact,
    title: Text(tituloCurto(l.capitulo ?? l.obra.titulo)),
    subtitle: detalhe == null ? null : Text(detalhe),
    trailing: const Icon(Icons.open_in_new, size: 18),
    onTap: () => abrirObra(context, l.obra, l.pagina),
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return FutureBuilder<List<LeituraIntroducao>>(
      future: _leituras,
      builder: (context, snap) {
        final lista = snap.data;
        if (lista == null) return const SizedBox(height: 24);
        Widget rotulo(String texto) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(texto, style: t.textTheme.bodySmall),
        );
        final baseados = lista
            .where((l) => l.tipo == LeituraIntroducao.baseadoNoLivro)
            .toList();
        final citam = lista
            .where((l) => l.tipo == LeituraIntroducao.citaOLivro)
            .toList();
        final comentarios = lista
            .where((l) => l.tipo == LeituraIntroducao.versiculoAVersiculo)
            .toList();
        if (lista.isEmpty) {
          return Text(
            'Nenhum capítulo de Ellen G. White é dedicado a este livro. Os '
            'trechos em que ela o cita aparecem em cada versículo, no painel '
            'de estudo.',
            style: t.textTheme.bodyMedium,
          );
        }
        final porObra = <int, List<LeituraIntroducao>>{};
        for (final l in baseados) {
          (porObra[l.obra.id] ??= []).add(l);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (baseados.isNotEmpty)
              rotulo(
                'Capítulos que, segundo a própria autora, são baseados '
                'neste livro:',
              ),
            for (final caps in porObra.values)
              if (caps.length <= _visiveis) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    caps.first.obra.titulo,
                    style: t.textTheme.labelLarge,
                  ),
                ),
                for (final l in caps) _item(l),
              ] else
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    caps.first.obra.titulo,
                    style: t.textTheme.labelLarge,
                  ),
                  subtitle: Text('${caps.length} capítulos'),
                  children: [for (final l in caps) _item(l)],
                ),
            if (citam.isNotEmpty) ...[
              rotulo(
                baseados.isEmpty
                    ? 'Capítulos que mais citam este livro:'
                    : 'Também citam muito este livro:',
              ),
              for (final l in citam)
                _item(
                  l,
                  detalhe: '${l.obra.titulo} • cita ${l.versiculos} versículos',
                ),
            ],
            if (comentarios.isNotEmpty) ...[
              rotulo('Comentário versículo a versículo, dos pioneiros:'),
              for (final l in comentarios) _item(l, detalhe: l.obra.autor),
            ],
          ],
        );
      },
    );
  }
}
