import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../dados/ajustes.dart';
import '../dados/biblioteca.dart';
import '../dados/leitura_voz.dart';
import '../dados/modelos.dart';
import 'acoes_texto.dart';

/// O livro de Ellen G. White (ou do pioneiro) aberto na página do trecho, com
/// a citação destacada quando dá para achá-la.
///
/// Ao selecionar um trecho, além de copiar dá para realçar com cor, anotar,
/// compartilhar, ouvir, procurar no livro e (no Android) mandar para os
/// outros apps do celular, como o tradutor.
class TelaPdf extends StatefulWidget {
  const TelaPdf({
    super.key,
    required this.obra,
    required this.pagina,
    this.destaque,
  });

  final Obra obra;

  /// Índice da página no PDF, a partir de 0.
  final int pagina;

  /// Texto a destacar ("Mateus 4:4").
  final String? destaque;

  @override
  State<TelaPdf> createState() => _TelaPdfState();
}

class _TelaPdfState extends State<TelaPdf> {
  final _controle = PdfViewerController();

  /// A busca no livro. Só pode ser criada depois que o livro carregou: o
  /// PdfTextSearcher lê o documento do controle já no construtor, e criá-lo
  /// antes deixava a tela cinza.
  PdfTextSearcher? _busca;
  final _campoBusca = TextEditingController();
  bool _procurando = false;
  late final Future<String> _caminho = Biblioteca.instancia
      .arquivo(widget.obra)
      .then((f) => f.path);

  /// Realces deste livro, e o texto das páginas que têm algum (para saber
  /// onde pintar).
  late List<Realce> _realces = Ajustes.instancia.realces(widget.obra.id);
  final _textos = <int, PdfPageText>{};
  final _pedidos = <int>{};

  @override
  void initState() {
    super.initState();
    Ajustes.instancia.addListener(_realcesMudaram);
  }

  void _atualizar() {
    if (mounted) setState(() {});
  }

  void _realcesMudaram() {
    _realces = Ajustes.instancia.realces(widget.obra.id);
    if (_controle.isReady) _controle.invalidate();
  }

  @override
  void dispose() {
    Ajustes.instancia.removeListener(_realcesMudaram);
    if (LeituraVoz.instancia.falandoTrecho) LeituraVoz.instancia.parar();
    _busca?.removeListener(_atualizar);
    _busca?.dispose();
    _campoBusca.dispose();
    super.dispose();
  }

  // --- realces ---

  void _pintarRealces(ui.Canvas canvas, Rect pageRect, PdfPage page) {
    final n = page.pageNumber;
    final daPagina = [
      for (final r in _realces)
        if (r.pagina == n) r,
    ];
    if (daPagina.isEmpty) return;
    final texto = _textos[n];
    if (texto == null) {
      if (_pedidos.add(n)) {
        page.loadStructuredText().then((t) {
          _textos[n] = t;
          if (mounted && _controle.isReady) _controle.invalidate();
        });
      }
      return;
    }
    for (final r in daPagina) {
      if (r.fim > texto.fullText.length) continue;
      final tinta = Paint()
        ..color = coresMarcacao[r.cor % coresMarcacao.length];
      final faixa = PdfPageTextRange(
        pageText: texto,
        start: r.inicio,
        end: r.fim,
      );
      for (final f in faixa.enumerateFragmentBoundingRects()) {
        canvas.drawRect(
          f.bounds
              .toRect(page: page, scaledPageSize: pageRect.size)
              .translate(pageRect.left, pageRect.top),
          tinta,
        );
      }
      if (r.nota != null) {
        // Um pontinho no começo do trecho avisa que há anotação.
        final inicio = PdfPageTextRange(
          pageText: texto,
          start: r.inicio,
          end: r.inicio + 1,
        ).bounds.toRect(page: page, scaledPageSize: pageRect.size);
        canvas.drawCircle(
          inicio.topLeft.translate(pageRect.left - 2, pageRect.top - 2),
          math.max(3, inicio.height / 4),
          Paint()
            ..color = coresMarcacao[r.cor % coresMarcacao.length].withValues(
              alpha: 1,
            ),
        );
      }
    }
  }

  /// Os realces que encostam no trecho selecionado.
  List<Realce> _sobrepostos(List<PdfPageTextRange> trechos) => [
    for (final r in _realces)
      if (trechos.any((t) => r.sobrepoe(t.pageNumber, t.start, t.end))) r,
  ];

  /// Grava o trecho selecionado como realce. Realces que encostam nele são
  /// juntados num só, sem perder as anotações.
  void _gravar(
    List<PdfPageTextRange> trechos, {
    int? cor,
    String? nota,
    bool trocarNota = false,
  }) {
    final aj = Ajustes.instancia;
    var primeiro = true;
    for (final t in trechos) {
      if (t.end <= t.start) continue;
      _textos[t.pageNumber] = t.pageText;
      final juntos = [
        for (final r in _realces)
          if (r.sobrepoe(t.pageNumber, t.start, t.end)) r,
      ];
      final ini = juntos.fold(t.start, (m, r) => math.min(m, r.inicio));
      final fim = juntos.fold(t.end, (m, r) => math.max(m, r.fim));
      final notas = {
        for (final r in juntos)
          if (r.nota != null) r.nota!,
      }.join('\n\n');
      for (final r in juntos) {
        aj.apagarRealce(r);
      }
      aj.realcar(
        Realce(
          obra: widget.obra.id,
          pagina: t.pageNumber,
          inicio: ini,
          fim: fim,
          cor: cor ?? (juntos.isEmpty ? 0 : juntos.first.cor),
          texto: t.pageText.fullText.substring(ini, fim).trim(),
        ).comNota(trocarNota && primeiro ? nota : notas),
      );
      primeiro = false;
    }
  }

  Future<void> _realcar(
    PdfTextSelectionDelegate sel,
    List<PdfPageTextRange> trechos,
  ) async {
    final existentes = _sobrepostos(trechos);
    final escolha = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Realçar o trecho',
                style: Theme.of(c).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Wrap(
                children: [
                  for (var i = 0; i < coresMarcacao.length; i++)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.pop(c, i),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: coresMarcacao[i].withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (existentes.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.format_color_reset_outlined),
                title: const Text('Tirar realce'),
                onTap: () => Navigator.pop(c, -1),
              ),
          ],
        ),
      ),
    );
    if (escolha == null) return;
    if (escolha < 0) {
      for (final r in existentes) {
        Ajustes.instancia.apagarRealce(r);
      }
    } else {
      _gravar(trechos, cor: escolha);
    }
    await sel.clearTextSelection();
  }

  Future<void> _anotar(
    PdfTextSelectionDelegate sel,
    List<PdfPageTextRange> trechos,
  ) async {
    final atuais = {
      for (final r in _sobrepostos(trechos))
        if (r.nota != null) r.nota!,
    }.join('\n\n');
    final ctrl = TextEditingController(text: atuais);
    final salvar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Anotação no trecho'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 8,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: 'Escreva o que este trecho diz a você…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    final nota = ctrl.text;
    ctrl.dispose();
    if (salvar != true) return;
    _gravar(trechos, nota: nota, trocarNota: true);
    await sel.clearTextSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nota.trim().isEmpty
                ? 'Trecho realçado, sem anotação.'
                : 'Anotação salva. Ela aparece em Marcações, na aba Livros.',
          ),
        ),
      );
    }
  }

  // --- menu da seleção ---

  void _itensDoMenu(
    PdfViewerContextMenuBuilderParams params,
    List<ContextMenuButtonItem> itens,
  ) {
    final sel = params.textSelectionDelegate;
    if (!params.isTextSelectionEnabled ||
        !sel.hasSelectedText ||
        !sel.isCopyAllowed) {
      return;
    }

    void item(
      String rotulo,
      Future<void> Function(String texto, List<PdfPageTextRange> trechos) f,
    ) {
      itens.add(
        ContextMenuButtonItem(
          label: rotulo,
          onPressed: () async {
            final trechos = await sel.getSelectedTextRanges();
            final texto = await sel.getSelectedText();
            params.dismissContextMenu();
            if (!mounted || texto.trim().isEmpty) return;
            await f(texto, trechos);
          },
        ),
      );
    }

    item('Realçar', (_, trechos) => _realcar(sel, trechos));
    item('Nota', (_, trechos) => _anotar(sel, trechos));
    item('Compartilhar', (texto, _) async {
      final o = widget.obra;
      await SharePlus.instance.share(
        ShareParams(
          text:
              '“${texto.replaceAll(RegExp(r'\s+'), ' ').trim()}”\n'
              '— ${o.autor}, ${o.titulo}',
        ),
      );
    });
    if (LeituraVoz.suportada) {
      item('Ouvir', (texto, _) => LeituraVoz.instancia.falar(texto));
    }
    item('Procurar no livro', (texto, _) async {
      await sel.clearTextSelection();
      _abrirBusca(texto);
    });
    if (acoesDoSistemaDisponiveis) {
      item('Mais', (texto, _) => mostrarMaisAcoes(context, texto));
    }
  }

  // --- busca no livro ---

  void _livroPronto(PdfDocument documento, PdfViewerController controle) {
    final busca = _busca ??= PdfTextSearcher(controle)..addListener(_atualizar);
    final d = widget.destaque;
    if (d != null && d.isNotEmpty && !_procurando) {
      busca.startTextSearch(d, goToFirstMatch: false);
    }
    _atualizar();
  }

  void _pintarBusca(ui.Canvas canvas, Rect pageRect, PdfPage page) =>
      _busca?.pageTextMatchPaintCallback(canvas, pageRect, page);

  void _procurar(String texto, {bool jaVai = false}) =>
      _busca?.startTextSearch(texto, searchImmediately: jaVai);

  void _abrirBusca([String? texto]) {
    final t = (texto ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    setState(() => _procurando = true);
    if (t.isNotEmpty) {
      _campoBusca.text = t.length > 80 ? t.substring(0, 80) : t;
      _procurar(_campoBusca.text, jaVai: true);
    }
  }

  void _fecharBusca() {
    setState(() => _procurando = false);
    _campoBusca.clear();
    _busca?.resetTextSearch();
  }

  String get _contagem {
    final busca = _busca;
    if (busca == null) return '';
    if (busca.isSearching && !busca.hasMatches) return '…';
    final i = busca.currentIndex;
    final n = busca.matches.length;
    if (n == 0) return _campoBusca.text.isEmpty ? '' : '0';
    return '${(i ?? 0) + 1}/$n${busca.isSearching ? '…' : ''}';
  }

  PreferredSizeWidget _barra() {
    if (!_procurando) {
      return AppBar(
        title: Text(widget.obra.titulo, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Procurar no livro',
            icon: const Icon(Icons.search),
            onPressed: _busca == null ? null : _abrirBusca,
          ),
        ],
      );
    }
    return AppBar(
      leading: IconButton(
        tooltip: 'Fechar a busca',
        icon: const Icon(Icons.close),
        onPressed: _fecharBusca,
      ),
      title: TextField(
        controller: _campoBusca,
        autofocus: _campoBusca.text.isEmpty,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Procurar no livro',
          border: InputBorder.none,
        ),
        onChanged: (t) => _procurar(t.trim()),
        onSubmitted: (t) => _procurar(t.trim(), jaVai: true),
      ),
      actions: [
        Center(child: Text(_contagem)),
        IconButton(
          tooltip: 'Anterior',
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: _busca?.hasMatches == true ? _busca!.goToPrevMatch : null,
        ),
        IconButton(
          tooltip: 'Próximo',
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: _busca?.hasMatches == true ? _busca!.goToNextMatch : null,
        ),
      ],
    );
  }

  /// Os mesmos parâmetros a cada desenho, para o leitor não achar que mudaram.
  late final _parametros = PdfViewerParams(
    pagePaintCallbacks: [_pintarRealces, _pintarBusca],
    customizeContextMenuItems: _itensDoMenu,
    onViewerReady: _livroPronto,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _barra(),
      bottomNavigationBar: ListenableBuilder(
        listenable: LeituraVoz.instancia,
        builder: (context, _) {
          final voz = LeituraVoz.instancia;
          if (!voz.falandoTrecho) return const SizedBox.shrink();
          return Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: SafeArea(
              top: false,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.record_voice_over_outlined),
                title: const Text('Lendo o trecho'),
                trailing: TextButton(
                  onPressed: voz.parar,
                  child: const Text('Parar'),
                ),
              ),
            ),
          );
        },
      ),
      body: FutureBuilder<String>(
        future: _caminho,
        builder: (context, snap) {
          final caminho = snap.data;
          if (caminho == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return PdfViewer.file(
            caminho,
            controller: _controle,
            initialPageNumber: widget.pagina + 1,
            params: _parametros,
          );
        },
      ),
    );
  }
}
