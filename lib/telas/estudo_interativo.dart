import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dados/respostas_estudos.dart';
import 'editor_pergunta_estudo.dart';
import 'versiculos_flutuantes.dart';

String textoDentroDasAreas(PdfPageRawText texto, double altura, List areas) {
  final partes = <String>[];
  for (final a in areas) {
    final r = Rect.fromLTRB(
      (a[0] as num).toDouble(),
      (a[1] as num).toDouble(),
      (a[2] as num).toDouble(),
      (a[3] as num).toDouble(),
    ).inflate(.7);
    final trecho = StringBuffer();
    for (
      var i = 0;
      i < texto.charRects.length && i < texto.fullText.length;
      i++
    ) {
      final c = texto.charRects[i];
      if (r.contains(
        Offset((c.left + c.right) / 2, altura - (c.top + c.bottom) / 2),
      )) {
        trecho.write(texto.fullText[i]);
      }
    }
    partes.add(trecho.toString());
  }
  return partes.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

class TelaEstudoInterativo extends StatefulWidget {
  const TelaEstudoInterativo({
    super.key,
    required this.arquivo,
    required this.id,
    required this.nome,
    required this.prefs,
    this.carregarIndice,
    this.lerTexto,
    this.construirLeitor,
  });
  final File arquivo;
  final String id, nome;
  final SharedPreferences prefs;
  final Future<Map> Function()? carregarIndice;
  final Future<String> Function(int, List)? lerTexto;
  final WidgetBuilder? construirLeitor;
  @override
  State<TelaEstudoInterativo> createState() => _TelaEstudoInterativoState();
}

class _TelaEstudoInterativoState extends State<TelaEstudoInterativo> {
  final _controle = PdfViewerController();
  late final _estado = RespostasEstudos(widget.prefs, widget.id);
  late final _carregamento = _carregar();
  Map? _indice;
  PdfDocument? _documento;
  final _textos = <int, Future<PdfPageRawText?>>{};
  late int _pagina = widget.prefs.getInt('estudo_pdf_pagina_${widget.id}') ?? 1;
  Map get _dadosPagina => (_indice!['paginas'] as List)[_pagina - 1] as Map;
  List get _licoes => _indice!['licoes'] as List;
  Map? get _licao {
    for (final l in _licoes) {
      if (_pagina >= (l['inicio'] as int) && _pagina <= (l['fim'] as int)) {
        return l as Map;
      }
    }
    return null;
  }

  Future<Map> _carregar() async {
    if (widget.carregarIndice != null) {
      return _indice = await widget.carregarIndice!();
    }
    final hash = await sha256.bind(widget.arquivo.openRead()).first;
    if (hash.toString() != widget.id) {
      throw StateError('O PDF não corresponde à edição preparada.');
    }
    final dados = jsonDecode(
      await rootBundle.loadString('assets/estudos_interativos.json'),
    ) as Map;
    _indice = (dados['estudos'] as List).cast<Map>().firstWhere(
      (e) => e['sha256'] == widget.id,
    );
    _pagina = _pagina.clamp(1, (_indice!['paginas'] as List).length);
    return _indice!;
  }

  Future<String> _extrair(int pagina, List areas) async {
    if (widget.lerTexto != null) return widget.lerTexto!(pagina, areas);
    if (_documento == null || areas.isEmpty) return '';
    final p = _documento!.pages[pagina - 1];
    final texto = await (_textos[pagina] ??= p.loadText());
    return texto == null ? '' : textoDentroDasAreas(texto, p.height, areas);
  }

  void _erro(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível concluir: $e')));
    }
  }

  Future<void> _ir(int pagina) async {
    if (_controle.isReady) await _controle.goToPage(pageNumber: pagina);
    if (mounted) setState(() => _pagina = pagina);
    await widget.prefs.setInt('estudo_pdf_pagina_${widget.id}', pagina);
  }

  String _nomeLicao(Map l) => l['complementar'] == true
      ? 'Crescendo em Cristo • semana ${(l['numero'] as int) - 20}'
      : 'Lição ${l['numero']}';
  List _refsPergunta(Map pergunta, Map pagina) {
    final areas = pergunta['areasTexto'] as List;
    final refs = <List>[];
    for (final r in pagina['referencias'] as List) {
      if ((r['areas'] as List).any(
        (a) => areas.any(
          (b) =>
              Rect.fromLTRB(
                (a[0] as num).toDouble(),
                (a[1] as num).toDouble(),
                (a[2] as num).toDouble(),
                (a[3] as num).toDouble(),
              ).overlaps(
                Rect.fromLTRB(
                  (b[0] as num).toDouble(),
                  (b[1] as num).toDouble(),
                  (b[2] as num).toDouble(),
                  (b[3] as num).toDouble(),
                ),
              ),
        ),
      )) {
        refs.addAll((r['referencias'] as List).cast<List>());
      }
    }
    return refs;
  }

  Future<void> _editar(Map pergunta, Map pagina) async {
    try {
      final n = pagina['pagina'] as int;
      final enunciado = pergunta['paginaEnunciado'] as int? ?? n;
      final texto = await _extrair(enunciado, pergunta['areasTexto'] as List);
      final opcoes = <String, List<String>>{};
      for (final c in pergunta['respostas'] as List) {
        if (c['tipo'] == 'alternativas') {
          opcoes[c['id'] as String] = [
            for (final o in c['opcoes'] as List)
              await _extrair(n, [o['textoArea']]),
          ];
        }
      }
      if (!mounted) return;
      final refs = _refsPergunta(
        pergunta,
        (_indice!['paginas'] as List)[enunciado - 1] as Map,
      );
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => EditorPerguntaEstudo(
          pergunta: pergunta,
          respostas: _estado,
          textoOriginal: texto,
          textosOpcoes: opcoes,
          consultarVersiculos: refs.isEmpty
              ? null
              : () => mostrarVersiculosFlutuantes(ctx, refs),
        ),
      );
      if (mounted) setState(() {});
    } catch (e) {
      _erro(e);
    }
  }

  Future<void> _perguntas() async {
    final pagina = _dadosPagina;
    final perguntas = pagina['perguntas'] as List;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Perguntas e atividades • página $_pagina',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: perguntas.length,
                  itemBuilder: (_, i) {
                    final q = perguntas[i] as Map;
                    return ListTile(
                      leading: Icon(
                        _estado.respondida(q)
                            ? Icons.check_circle
                            : Icons.edit_outlined,
                      ),
                      title: FutureBuilder<String>(
                        future: _extrair(
                          q['paginaEnunciado'] as int? ?? _pagina,
                          q['areasTexto'] as List,
                        ),
                        builder: (_, snap) => Text(
                          q['semEnunciado'] == true
                              ? 'Espaço ${i + 1} • enunciado incompleto no original'
                              : (snap.data?.isNotEmpty == true
                                    ? snap.data!
                                    : 'Resposta ou reflexão ${i + 1}'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(ctx);
                        _editar(q, pagina);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportar() async {
    try {
      await FilePicker.saveFile(
        fileName: 'respostas-${widget.id.substring(0, 12)}.json',
        mimeType: 'application/json',
        bytes: utf8.encode(
          const JsonEncoder.withIndent('  ').convert({
            'versao': 2,
            'estudo': widget.nome,
            'sha256': widget.id,
            'pagina': _pagina,
            'respostas': _estado.exportar(),
          }),
        ),
      );
    } catch (e) {
      _erro(e);
    }
  }

  Future<void> _link(PdfLink link) async {
    try {
      if (link.dest != null) {
        await _controle.goToDest(link.dest);
        return;
      }
      if (link.url == null || !['https', 'http'].contains(link.url!.scheme)) {
        return;
      }
      await widget.prefs.setInt('estudo_pdf_pagina_${widget.id}', _pagina);
      final url = Uri.parse(link.url.toString().replaceAll('&amp;', '&'));
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw StateError('Endereço indisponível');
      }
    } catch (e) {
      _erro(e);
    }
  }

  List<Widget> _sobrepor(BuildContext context, Rect rect, PdfPage page) {
    final dados = (_indice!['paginas'] as List)[page.pageNumber - 1] as Map;
    final escala = rect.width / (dados['largura'] as num);
    Widget pos(List a, Widget child, Future<void> Function() tap) => Positioned(
      left: (a[0] as num) * escala,
      top: (a[1] as num) * escala,
      width: ((a[2] as num) - (a[0] as num)) * escala,
      height: ((a[3] as num) - (a[1] as num)) * escala,
      child: PdfOverlayInteractionRegion(
        onTap: (_) {
          unawaited(tap());
          return true;
        },
        child: child,
      ),
    );
    final widgets = <Widget>[];
    for (final q in dados['perguntas'] as List) {
      for (final c in q['respostas'] as List) {
        if (c['tipo'] == 'alternativas') {
          final selecionadas = _estado.escolhas(c as Map);
          final opts = c['opcoes'] as List;
          for (var i = 0; i < opts.length; i++) {
            final a = opts[i]['area'] as List;
            widgets.add(
              pos(
                a,
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: selecionadas.contains(i)
                        ? const Color(0xFF008DA8)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: selecionadas.contains(i)
                      ? Icon(Icons.check, color: Colors.white, size: 7 * escala)
                      : null,
                ),
                () async {
                  try {
                    final valores = [..._estado.escolhas(c)];
                    if (valores.contains(i)) {
                      valores.remove(i);
                    } else {
                      if (c['unica'] == true) valores.clear();
                      valores.add(i);
                    }
                    await _estado.salvarEscolhas(c, valores);
                    if (mounted) setState(() {});
                  } catch (e) {
                    _erro(e);
                  }
                },
              ),
            );
          }
        } else {
          final valor = _estado.texto(c as Map);
          for (final a in c['areas'] as List) {
            widgets.add(
              pos(
                a as List,
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 2 * escala),
                  decoration: BoxDecoration(
                    color: valor.isEmpty
                        ? Colors.transparent
                        : const Color(0xF7FFFFFF),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFF52AAB6), width: .5),
                    ),
                  ),
                  alignment: Alignment.topLeft,
                  child: Text(
                    valor.isEmpty ? 'Responder…' : valor,
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8.5 * escala,
                      color: const Color(0xFF145473),
                    ),
                  ),
                ),
                () => _editar(q as Map, dados),
              ),
            );
          }
        }
      }
      if ((q['areasTexto'] as List).isNotEmpty &&
          q['paginaEnunciado'] == null) {
        final a = (q['areasTexto'] as List).first as List;
        widgets.add(
          pos(
            [(a[0] as num) - 12, a[1], (a[0] as num) - 2, (a[1] as num) + 11],
            Icon(
              _estado.respondida(q as Map)
                  ? Icons.check_circle
                  : Icons.edit_outlined,
              color: const Color(0xFF008DA8),
              size: 9 * escala,
            ),
            () => _editar(q, dados),
          ),
        );
      }
    }
    for (final r in dados['referencias'] as List) {
      for (final a in r['areas'] as List) {
        widgets.add(
          pos(
            a as List,
            Container(
              decoration: const BoxDecoration(
                color: Color(0x11008DA8),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF008DA8), width: .6),
                ),
              ),
            ),
            () =>
                mostrarVersiculosFlutuantes(context, r['referencias'] as List),
          ),
        );
      }
    }
    for (final link in (dados['linksExtras'] as List? ?? [])) {
      widgets.add(
        pos(
          link['area'] as List,
          const DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF008DA8))),
            ),
          ),
          () async {
            try {
              final url = Uri.parse(link['url'] as String);
              if (!['http', 'https'].contains(url.scheme)) return;
              await widget.prefs.setInt(
                'estudo_pdf_pagina_${widget.id}',
                _pagina,
              );
              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                throw StateError('Endereço indisponível');
              }
            } catch (e) {
              _erro(e);
            }
          },
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFEAEFF2),
    appBar: AppBar(
      title: Text(widget.nome),
      actions: [
        IconButton(
          tooltip: 'Exportar todas as respostas',
          onPressed: _exportar,
          icon: const Icon(Icons.save_alt),
        ),
      ],
    ),
    body: FutureBuilder<Map>(
      future: _carregamento,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Text(
              'Não foi possível preparar esta edição do estudo. Baixe novamente o PDF oficial.',
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final licao = _licao;
        final perguntas = _dadosPagina['perguntas'] as List;
        final total = (_indice!['paginas'] as List).length;
        return Column(
          children: [
            Material(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.menu_book_outlined,
                      color: Color(0xFF008DA8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: licao?['numero'] as int?,
                        hint: const Text('Escolher lição'),
                        items: [
                          for (final l in _licoes)
                            DropdownMenuItem(
                              value: l['numero'] as int,
                              child: Text(
                                '${_estado.concluida(l['numero'] as int) ? '✓ ' : ''}${_nomeLicao(l as Map)} • p. ${l['inicio']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (n) {
                          if (n != null) {
                            _ir(
                              (_licoes.firstWhere((l) => l['numero'] == n)
                                      as Map)['inicio']
                                  as int,
                            );
                          }
                        },
                      ),
                    ),
                    if (licao != null)
                      IconButton(
                        tooltip: _estado.concluida(licao['numero'] as int)
                            ? 'Reabrir lição'
                            : 'Concluir lição',
                        icon: Icon(
                          _estado.concluida(licao['numero'] as int)
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                        ),
                        onPressed: () async {
                          try {
                            await _estado.concluir(
                              licao['numero'] as int,
                              !_estado.concluida(licao['numero'] as int),
                            );
                            if (mounted) setState(() {});
                          } catch (e) {
                            _erro(e);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child:
                  widget.construirLeitor?.call(context) ??
                  PdfViewer.file(
                    widget.arquivo.path,
                    controller: _controle,
                    initialPageNumber: _pagina,
                    params: PdfViewerParams(
                      pageOverlaysBuilder: _sobrepor,
                      linkHandlerParams: PdfLinkHandlerParams(
                        onLinkTap: (link) => _link(link),
                        laidOverPageOverlays: false,
                      ),
                      onViewerReady: (doc, _) {
                        _documento = doc;
                      },
                      onPageChanged: (n) {
                        if (n == null || !mounted) return;
                        setState(() => _pagina = n);
                        widget.prefs.setInt(
                          'estudo_pdf_pagina_${widget.id}',
                          n,
                        );
                      },
                    ),
                  ),
            ),
            SafeArea(
              top: false,
              child: Material(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Página anterior',
                        onPressed: _pagina <= 1 ? null : () => _ir(_pagina - 1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('Página $_pagina / $total'),
                      IconButton(
                        tooltip: 'Próxima página',
                        onPressed: _pagina >= total
                            ? null
                            : () => _ir(_pagina + 1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                      FilledButton.icon(
                        onPressed: perguntas.isEmpty ? null : _perguntas,
                        icon: const Icon(Icons.edit_note),
                        label: Text('Responder (${perguntas.length})'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
