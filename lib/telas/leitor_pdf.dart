import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../dados/ajustes.dart';
import '../dados/biblioteca.dart';
import '../dados/leitura_voz.dart';
import '../dados/modelos.dart';
import '../dados/guia_biblioteca.dart';
import 'acoes_texto.dart';
import 'guia_biblioteca.dart';

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
    this.retomar = false,
  });

  final Obra obra;

  /// Índice da página no PDF, a partir de 0.
  final int pagina;

  /// Texto a destacar ("Mateus 4:4").
  final String? destaque;

  /// Somente a biblioteca retoma; links de versículos respeitam sua página.
  final bool retomar;

  @override
  State<TelaPdf> createState() => _TelaPdfState();
}

class _TelaPdfState extends State<TelaPdf> with WidgetsBindingObserver {
  final _controle = PdfViewerController();

  /// A busca no livro. Só pode ser criada depois que o livro carregou: o
  /// PdfTextSearcher lê o documento do controle já no construtor, e criá-lo
  /// antes deixava a tela cinza.
  PdfTextSearcher? _busca;
  final _campoBusca = TextEditingController();
  bool _procurando = false;
  late final Future<String> _caminho = _abrirCaminho();
  String? _edicao;
  LugarObra? _retomada;
  LugarObra? _ultimoLugar;
  Timer? _salvarLugar;

  Future<String> _abrirCaminho() async {
    final arquivo = await Biblioteca.instancia.arquivo(widget.obra);
    final marca = File('${arquivo.path}.sha256');
    _edicao = await marca.exists() ? (await marca.readAsString()).trim() : null;
    final lugar = GuiaBiblioteca.instancia.lugar(widget.obra.id);
    if (widget.retomar &&
        lugar != null &&
        _edicao != null &&
        lugar.edicao == _edicao) {
      _retomada = lugar;
    } else if (widget.retomar && lugar != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'A edição do PDF mudou. Confira o capítulo antes de retomar a leitura.',
              ),
            ),
          );
        }
      });
    }
    return arquivo.path;
  }

  void _lugarMudou() {
    if (!_pronto || !_controle.isReady || _edicao == null) return;
    final pagina = (_controle.pageNumber ?? 1) - 1;
    final layouts = _controle.layout.pageLayouts;
    if (pagina < 0 || pagina >= layouts.length) return;
    final rect = layouts[pagina];
    final centro = _controle.centerPosition;
    _ultimoLugar = LugarObra(
      pagina,
      ((centro.dy - rect.top) / rect.height).clamp(0, 1),
      _edicao!,
      DateTime.now().millisecondsSinceEpoch,
      zoom: (_controle.currentZoom / _controle.coverScale).clamp(0.01, 100),
      horizontal: ((centro.dx - rect.left) / rect.width).clamp(0, 1),
    );
    _salvarLugar?.cancel();
    _salvarLugar = Timer(const Duration(milliseconds: 600), _gravarLugar);
  }

  void _gravarLugar() {
    final lugar = _ultimoLugar;
    if (lugar == null) return;
    unawaited(
      GuiaBiblioteca.instancia.guardarLugar(widget.obra.id, lugar).catchError((
        Object _,
      ) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível salvar o lugar da leitura.'),
            ),
          );
        }
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _salvarLugar?.cancel();
      _gravarLugar();
    }
  }

  /// Realces deste livro, e o texto das páginas que têm algum (para saber
  /// onde pintar).
  late List<Realce> _realces = Ajustes.instancia.realces(widget.obra.id);
  final _textos = <int, PdfPageText>{};
  final _pedidos = <int>{};
  StreamSubscription<PdfDocumentEvent>? _eventos;

  /// Realçar muitas páginas de uma vez (um "Selecionar tudo") guardaria o
  /// livro inteiro nos ajustes; acima disto, pede um trecho menor.
  static const _maxPaginasRealce = 10;

  /// O livro já abriu e está na página e no zoom iniciais.
  bool _pronto = false;

  /// O zoom de abertura, enquanto a pessoa não muda o zoom: se a tela mudar
  /// de tamanho (o celular girou, a janela mudou), ele é refeito para a
  /// tela nova. `null` depois que a pessoa escolhe o próprio zoom.
  double? _zoomDeAbertura;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _controle.removeListener(_lugarMudou);
    _salvarLugar?.cancel();
    // Notificar outras telas depois da desmontagem da árvore.
    Future.microtask(_gravarLugar);
    Ajustes.instancia.removeListener(_realcesMudaram);
    // Fora do dispose: parar avisa outras telas, que não podem se refazer
    // enquanto a árvore de widgets está sendo desmontada.
    if (LeituraVoz.instancia.falandoTrecho) {
      Future.microtask(LeituraVoz.instancia.parar);
    }
    _eventos?.cancel();
    _busca?.removeListener(_atualizar);
    _busca?.dispose();
    _campoBusca.dispose();
    super.dispose();
  }

  // --- zoom ---

  static double? _zoomInicial(
    PdfDocument documento,
    PdfViewerController controle,
    double paginaInteira,
    double larguraDaTela,
  ) => zoomInicial(paginaInteira: paginaInteira, larguraDaTela: larguraDaTela);

  /// A tela mudou de tamanho. O leitor só refaz sozinho o zoom que estava
  /// na página inteira; o de abertura com a letra no tamanho real (celular
  /// deitado) ficaria maior que a tela depois de girar o celular.
  void _telaMudou(Size tela, Size? antes, PdfViewerController controle) {
    final abertura = _zoomDeAbertura;
    if (!_pronto || abertura == null || !controle.isReady) return;
    final atual = controle.currentZoom;
    final seguiu =
        (atual - abertura).abs() < 0.01 ||
        (atual - controle.minScale).abs() < 0.01;
    if (!seguiu) {
      // A pessoa escolheu o próprio zoom: fica o dela.
      _zoomDeAbertura = null;
      return;
    }
    final novo = zoomInicial(
      paginaInteira: controle.alternativeFitScale ?? controle.coverScale,
      larguraDaTela: controle.coverScale,
    ).clamp(controle.minScale, controle.maxScale);
    _zoomDeAbertura = novo;
    if ((novo - atual).abs() > 0.001) {
      controle.setZoom(controle.centerPosition, novo, duration: Duration.zero);
    }
  }

  /// Volta a mostrar a página atual inteira.
  void _paginaInteira() {
    if (!_controle.isReady) return;
    final n = _controle.pageNumber ?? 1;
    final paginas = _controle.layout.pageLayouts;
    if (n < 1 || n > paginas.length) return;
    final r = paginas[n - 1].inflate(_parametros.margin);
    final tela = _controle.viewSize;
    final zoom = math
        .min(tela.width / r.width, tela.height / r.height)
        .clamp(_controle.minScale, _controle.maxScale);
    _controle.setZoom(r.center, zoom);
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
      // O leitor carrega as páginas aos poucos e já desenha as que ainda não
      // carregaram; o texto delas viria vazio. Espera a página carregar (o
      // aviso chega em _eventoDoLivro, que manda redesenhar).
      if (!page.isLoaded) return;
      if (_pedidos.add(n)) {
        page.loadStructuredText().then(
          (t) {
            _textos[n] = t;
            if (mounted && _controle.isReady) _controle.invalidate();
          },
          onError: (Object _) {
            _pedidos.remove(n);
          },
        );
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
  /// (Os de outra edição do PDF, que passam do fim da página, ficam de fora,
  /// como em [_gravar].)
  List<Realce> _sobrepostos(List<PdfPageTextRange> trechos) => [
    for (final r in _realces)
      if (trechos.any(
        (t) =>
            r.fim <= t.pageText.fullText.length &&
            r.sobrepoe(t.pageNumber, t.start, t.end),
      ))
        r,
  ];

  /// Grava o trecho selecionado como realce. Realces que encostam nele são
  /// juntados num só, sem perder as anotações. Com [trocarNota], a anotação
  /// digitada substitui as de todo o trecho e fica na primeira página dele.
  ///
  /// Tudo é montado antes e gravado de uma vez: se algo der errado no meio,
  /// nenhum realce antigo some.
  void _gravar(
    List<PdfPageTextRange> trechos, {
    int? cor,
    String? nota,
    bool trocarNota = false,
  }) {
    final apagar = <Realce>[];
    final novos = <Realce>[];
    for (final t in trechos) {
      final tamanho = t.pageText.fullText.length;
      final ini0 = t.start.clamp(0, tamanho);
      final fim0 = t.end.clamp(0, tamanho);
      if (fim0 <= ini0) continue;
      _textos[t.pageNumber] = t.pageText;
      // Realces de outra edição do PDF passam do fim da página: não dá para
      // juntá-los (nem são desenhados), então ficam como estão.
      final juntos = [
        for (final r in _realces)
          if (r.fim <= tamanho && r.sobrepoe(t.pageNumber, ini0, fim0)) r,
      ];
      final ini = juntos.fold(ini0, (m, r) => math.min(m, r.inicio));
      final fim = juntos.fold(fim0, (m, r) => math.max(m, r.fim));
      final notas = {
        for (final r in juntos)
          if (r.nota != null) r.nota!,
      }.join('\n\n');
      apagar.addAll(juntos);
      novos.add(
        Realce(
          obra: widget.obra.id,
          pagina: t.pageNumber,
          inicio: ini,
          fim: fim,
          cor: cor ?? (juntos.isEmpty ? 0 : juntos.first.cor),
          texto: t.pageText.fullText.substring(ini, fim).trim(),
        ).comNota(trocarNota ? (novos.isEmpty ? nota : null) : notas),
      );
    }
    if (novos.isEmpty) return;
    Ajustes.instancia.trocarRealces(remover: apagar, adicionar: novos);
  }

  Future<void> _realcar(List<PdfPageTextRange> trechos) async {
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
    if (escolha == null || !mounted) return;
    if (escolha < 0) {
      Ajustes.instancia.trocarRealces(remover: existentes);
    } else {
      _gravar(trechos, cor: escolha);
    }
  }

  Future<void> _anotar(List<PdfPageTextRange> trechos) async {
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
    if (salvar != true || !mounted) return;
    _gravar(trechos, nota: nota, trocarNota: true);
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

  /// Os trechos selecionados, um por página, na ordem do livro; null se a
  /// seleção passa de [maxPaginas] páginas.
  ///
  /// Não usa getSelectedTextRanges/getSelectedText do pdfrx: quando a
  /// seleção é feita de trás para a frente entre duas páginas, eles pegam a
  /// página errada (ou lançam RangeError), porque supõem que a ponta A está
  /// na primeira página.
  Future<List<PdfPageTextRange>?> _trechosDaSelecao(
    PdfTextSelectionDelegate sel, {
    int? maxPaginas,
  }) async {
    final faixa = sel.textSelectionPointRange;
    if (faixa == null) return const [];
    final a = faixa.start, b = faixa.end;
    if (maxPaginas != null &&
        b.text.pageNumber - a.text.pageNumber + 1 > maxPaginas) {
      return null;
    }
    PdfPageTextRange trecho(PdfPageText t, int ini, int fim) {
      final n = t.fullText.length;
      return PdfPageTextRange(
        pageText: t,
        start: ini.clamp(0, n),
        end: fim.clamp(0, n),
      );
    }

    if (a.text.pageNumber == b.text.pageNumber) {
      return [
        trecho(
          a.text,
          math.min(a.index, b.index),
          math.max(a.index, b.index) + 1,
        ),
      ];
    }
    final trechos = [trecho(a.text, a.index, a.text.fullText.length)];
    final doc = _controle.document;
    for (var p = a.text.pageNumber + 1; p < b.text.pageNumber; p++) {
      final t = await doc.pages[p - 1].loadStructuredText();
      if (t.fullText.isNotEmpty) trechos.add(trecho(t, 0, t.fullText.length));
    }
    trechos.add(trecho(b.text, 0, b.index + 1));
    return [
      for (final t in trechos)
        if (t.end > t.start) t,
    ];
  }

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

    /// Cada ação lê a seleção e a desfaz antes de agir: no Android a barra de
    /// opções só some quando a seleção acaba.
    void item(
      String rotulo,
      Future<void> Function(String texto, List<PdfPageTextRange> trechos) f, {
      int? maxPaginas,
    }) {
      itens.add(
        ContextMenuButtonItem(
          label: rotulo,
          onPressed: () async {
            List<PdfPageTextRange>? trechos;
            try {
              trechos = await _trechosDaSelecao(sel, maxPaginas: maxPaginas);
            } catch (_) {
              trechos = const [];
            } finally {
              params.dismissContextMenu();
              await sel.clearTextSelection();
            }
            if (!mounted) return;
            if (trechos == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Para realçar ou anotar, selecione um trecho de até '
                    '$maxPaginas páginas.',
                  ),
                ),
              );
              return;
            }
            final texto = trechos.map((t) => t.text).join();
            if (texto.trim().isEmpty) return;
            await f(texto, trechos);
          },
        ),
      );
    }

    item(
      'Realçar',
      (_, trechos) => _realcar(trechos),
      maxPaginas: _maxPaginasRealce,
    );
    item(
      'Nota',
      (_, trechos) => _anotar(trechos),
      maxPaginas: _maxPaginasRealce,
    );
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
    item('Procurar no livro', (texto, _) async => _abrirBusca(texto));
    if (acoesDoSistemaDisponiveis) {
      item('Mais', (texto, _) => mostrarMaisAcoes(context, texto));
    }
  }

  // --- busca no livro ---

  /// O livro abriu: passa a acompanhar as páginas que vão carregando.
  void _livroPronto(PdfDocument documento, PdfViewerController controle) {
    _eventos ??= documento.events.listen(_eventoDoLivro);
    _pronto = true;
    _zoomDeAbertura = controle.currentZoom;
    _criarBusca();
    final lugar = _retomada;
    _retomada = null;
    Future<void> restaurar() async {
      if (lugar != null && lugar.pagina < controle.layout.pageLayouts.length) {
        final rect = controle.layout.pageLayouts[lugar.pagina];
        await controle.setZoom(
          Offset(
            rect.left + rect.width * lugar.horizontal,
            rect.top + rect.height * lugar.fracao,
          ),
          (controle.coverScale * lugar.zoom).clamp(
            controle.minScale,
            controle.maxScale,
          ),
          duration: Duration.zero,
        );
        _zoomDeAbertura = null;
      }
      if (!mounted) return;
      _controle.removeListener(_lugarMudou);
      _controle.addListener(_lugarMudou);
      _lugarMudou();
    }

    unawaited(restaurar());
    _atualizar();
  }

  void _eventoDoLivro(PdfDocumentEvent evento) {
    if (evento is PdfDocumentPageStatusChangedEvent) {
      // A página mudou (em geral, acabou de carregar): o texto dela, se
      // havia, é refeito no próximo desenho.
      for (final n in evento.changes.keys) {
        _textos.remove(n);
        _pedidos.remove(n);
      }
      if (_controle.isReady) _controle.invalidate();
    }
    _criarBusca();
  }

  /// A busca só nasce com todas as páginas carregadas. O PdfTextSearcher lê
  /// o documento do controle já no construtor (criá-lo antes de o livro abrir
  /// deixava a tela cinza) e guarda o texto de cada página na primeira
  /// leitura: uma página ainda não carregada ficaria sem texto para sempre.
  void _criarBusca() {
    if (_busca != null || !mounted || !_controle.isReady) return;
    if (!_controle.document.pages.every((p) => p.isLoaded)) return;
    final busca = _busca = PdfTextSearcher(_controle)..addListener(_atualizar);
    final pedido = _campoBusca.text.trim();
    if (_procurando && pedido.isNotEmpty) {
      // A pessoa pediu uma busca enquanto o livro carregava: faz agora.
      _procurar(pedido, jaVai: true);
    } else {
      _procurarDestaque(busca);
    }
    _atualizar();
  }

  void _procurarDestaque(PdfTextSearcher busca) {
    final d = widget.destaque?.trim();
    if (d != null && d.isNotEmpty) {
      busca.startTextSearch(padraoDeBusca(d), goToFirstMatch: false);
    }
  }

  /// Pinta os resultados linha a linha (o pdfrx pinta um retângulo só, que
  /// cobriria duas linhas inteiras quando o resultado quebra de linha).
  void _pintarBusca(ui.Canvas canvas, Rect pageRect, PdfPage page) {
    final busca = _busca;
    final faixa = busca?.getMatchesRangeForPage(page.pageNumber);
    if (busca == null || faixa == null) return;
    final atual = busca.currentIndex;
    final resultados = busca.matches;
    for (var i = faixa.start; i < faixa.end && i < resultados.length; i++) {
      final tinta = Paint()
        ..color = (i == atual ? Colors.orange : Colors.yellow).withAlpha(127);
      for (final f in resultados[i].enumerateFragmentBoundingRects()) {
        canvas.drawRect(
          f.bounds
              .toRect(page: page, scaledPageSize: pageRect.size)
              .translate(pageRect.left, pageRect.top),
          tinta,
        );
      }
    }
  }

  /// O último padrão que a pessoa pediu (null: nenhum; a busca da citação
  /// não conta).
  String? _padraoPedido;

  void _procurar(String texto, {bool jaVai = false}) {
    // Sem a busca ainda (o livro carregando), _criarBusca refaz o pedido.
    final busca = _busca;
    if (busca == null) return;
    if (texto.trim().isEmpty) {
      _padraoPedido = null;
      busca.resetTextSearch();
      return;
    }
    final padrao = padraoDeBusca(texto);
    // O mesmo pedido de novo (Enter repetido) não faz nada: pedir outra vez
    // cancelaria a busca em andamento.
    if (padrao.pattern == _padraoPedido) return;
    _padraoPedido = padrao.pattern;
    // O pdfrx ignora um padrão igual ao último que ele começou (por exemplo,
    // o da citação, que não vai ao primeiro resultado); limpa antes.
    final atual = busca.pattern;
    if (atual is RegExp && atual.pattern == padrao.pattern) {
      busca.resetTextSearch();
    }
    busca.startTextSearch(padrao, searchImmediately: jaVai);
  }

  void _abrirBusca([String? texto]) {
    final t = (texto ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    setState(() => _procurando = true);
    if (t.isNotEmpty) {
      _campoBusca.text = (t.length > 80 ? t.substring(0, 80) : t).trim();
      _procurar(_campoBusca.text, jaVai: true);
    }
  }

  void _fecharBusca() {
    setState(() => _procurando = false);
    _campoBusca.clear();
    final busca = _busca;
    if (busca == null) return;
    _padraoPedido = null;
    busca.resetTextSearch();
    // Volta a marcar a citação que trouxe a pessoa até o livro.
    _procurarDestaque(busca);
  }

  bool get _temResultados =>
      _campoBusca.text.trim().isNotEmpty && _busca?.hasMatches == true;

  void _irPara(Future<int> Function() ir) {
    unawaited(ir());
    _atualizar(); // o índice já mudou; a contagem acompanha
  }

  String get _contagem {
    final busca = _busca;
    if (busca == null || _campoBusca.text.trim().isEmpty) return '';
    if (busca.isSearching && !busca.hasMatches) return '…';
    final i = busca.currentIndex;
    final n = busca.matches.length;
    if (n == 0) return '0';
    return '${(i ?? 0) + 1}/$n${busca.isSearching ? '…' : ''}';
  }

  PreferredSizeWidget _barra() {
    if (!_procurando) {
      // No celular o zoom é com os dedos; no PC, os botões ajudam (também
      // há Ctrl + roda do mouse).
      final botoesZoom = MediaQuery.sizeOf(context).width >= 600;
      return AppBar(
        title: Text(widget.obra.titulo, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Capítulos e progresso',
            icon: const Icon(Icons.checklist),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TelaGuiaBiblioteca(obra: widget.obra),
              ),
            ),
          ),
          if (botoesZoom) ...[
            IconButton(
              tooltip: 'Diminuir',
              icon: const Icon(Icons.zoom_out),
              onPressed: _pronto ? () => _controle.zoomDown() : null,
            ),
            IconButton(
              tooltip: 'Página inteira',
              icon: const Icon(Icons.fit_screen_outlined),
              onPressed: _pronto ? _paginaInteira : null,
            ),
            IconButton(
              tooltip: 'Aumentar',
              icon: const Icon(Icons.zoom_in),
              onPressed: _pronto ? () => _controle.zoomUp() : null,
            ),
          ],
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
          onPressed: _temResultados
              ? () => _irPara(_busca!.goToPrevMatch)
              : null,
        ),
        IconButton(
          tooltip: 'Próximo',
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: _temResultados
              ? () => _irPara(_busca!.goToNextMatch)
              : null,
        ),
      ],
    );
  }

  /// Os mesmos parâmetros a cada desenho, para o leitor não achar que mudaram.
  late final _parametros = PdfViewerParams(
    // O livro abre com a página inteira na tela, não na largura da tela: num
    // monitor largo, a largura deixava a letra enorme.
    sizeDelegateProvider: PdfViewerSizeDelegateProviderLegacy(
      calculateInitialZoom: _zoomInicial,
    ),
    // Zoom em passos pequenos (botões e Ctrl + / Ctrl -), e o Ctrl com a
    // roda do mouse pela metade. (A pinça, no celular e no touchpad do PC,
    // segue os dedos e não passa por aqui.)
    zoomStepsDelegateProvider: const _PassosDeZoom(),
    scaleByPointerScale: 0.5,
    pagePaintCallbacks: [_pintarRealces, _pintarBusca],
    customizeContextMenuItems: _itensDoMenu,
    onViewerReady: _livroPronto,
    onViewSizeChanged: _telaMudou,
    onDocumentLoadFinished: (_, carregou) {
      if (carregou) _criarBusca();
    },
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
            initialPageNumber: (_retomada?.pagina ?? widget.pagina) + 1,
            params: _parametros,
          );
        },
      ),
    );
  }
}

/// O zoom com que o livro abre: a página inteira na tela. Só quando a tela
/// é baixa demais para isso (celular deitado, janela achatada), a letra
/// ficaria miúda: aí abre no tamanho real da página (zoom 1), sem passar da
/// largura da tela, que era o zoom com que os livros abriam até a 1.4.
@visibleForTesting
double zoomInicial({
  required double paginaInteira,
  required double larguraDaTela,
}) {
  final menor = math.min(paginaInteira, larguraDaTela);
  final maior = math.max(paginaInteira, larguraDaTela);
  return math
      .max(paginaInteira, math.min(1.0, larguraDaTela))
      .clamp(menor, maior);
}

/// Os passos do zoom dos botões e do teclado: de 15% em 15%, passando pela
/// página inteira e pela largura da tela. O padrão do leitor dobrava o zoom a
/// cada passo.
@visibleForTesting
List<double> passosDeZoom(PdfViewerLayoutMetrics m) {
  const passo = 1.15;
  final marcos = <double>[
    m.coverScale,
    ?m.alternativeFitScale,
  ].where((z) => z >= m.minScale && z <= m.maxScale).toList()..sort();
  final base = marcos.isEmpty ? m.minScale : marcos.first;
  final passos = <double>[m.minScale, ...marcos, m.maxScale];
  for (var z = base / passo; z > m.minScale; z /= passo) {
    passos.add(z);
  }
  for (var z = base * passo; z < m.maxScale; z *= passo) {
    passos.add(z);
  }
  passos.sort();
  // Sem passos quase iguais: o leitor os trataria como o mesmo zoom. Dos
  // parecidos fica o mínimo ou o máximo, depois a página inteira ou a
  // largura, e só então um passo comum.
  int peso(double z) => z == m.minScale || z == m.maxScale
      ? 2
      : marcos.contains(z)
      ? 1
      : 0;
  final saida = <double>[];
  for (final z in passos) {
    if (saida.isEmpty || z - saida.last >= 0.02) {
      saida.add(z);
    } else if (peso(z) > peso(saida.last)) {
      saida.last = z;
    }
  }
  return saida;
}

class _PassosDeZoom extends PdfViewerZoomStepsDelegateProvider {
  const _PassosDeZoom();

  @override
  PdfViewerZoomStepsDelegate create() => _DelegadoPassosDeZoom();

  @override
  bool operator ==(Object other) => other is _PassosDeZoom;

  @override
  int get hashCode => runtimeType.hashCode;
}

class _DelegadoPassosDeZoom implements PdfViewerZoomStepsDelegate {
  @override
  void dispose() {}

  @override
  List<double> generateZoomStops(PdfViewerLayoutMetrics metrics) =>
      passosDeZoom(metrics);
}

/// O texto procurado como expressão que aceita quebra de linha entre as
/// palavras e ignora maiúsculas e minúsculas.
@visibleForTesting
RegExp padraoDeBusca(String texto) => RegExp(
  texto.trim().split(RegExp(r'\s+')).map(RegExp.escape).join(r'\s+'),
  caseSensitive: false,
);
