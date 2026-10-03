import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../dados/ajustes.dart';
import '../dados/biblia.dart';
import '../dados/estudo.dart';
import '../dados/modelos.dart';
import '../dados/referencias.dart';
import 'acoes_versiculo.dart';
import 'cartao_trecho.dart';
import 'largura_texto.dart';
import 'tema.dart';
import 'texto_biblico.dart';

/// Um capítulo da Bíblia.
///
/// Ao lado de cada versículo, discretos: quantos trechos de Ellen G. White e
/// dos pioneiros o citam, e se ele cita o Antigo Testamento (ou é citado no
/// Novo) ou tem passagem paralela. No topo, os capítulos de Ellen G. White que
/// narram esta passagem.
class Leitor extends StatefulWidget {
  const Leitor({
    super.key,
    required this.posicao,
    required this.versao,
    required this.selecionado,
    required this.rolarPara,
    required this.aoSelecionar,
    required this.aoMudarCapitulo,
    required this.aoIr,
  });

  final Posicao posicao;
  final Versao versao;
  final int? selecionado;
  final int? rolarPara;
  final ValueChanged<int> aoSelecionar;
  final ValueChanged<int> aoMudarCapitulo;
  final ValueChanged<Posicao> aoIr;

  @override
  State<Leitor> createState() => _LeitorState();
}

class _DadosCapitulo {
  _DadosCapitulo(
    this.versiculos,
    this.contagem,
    this.citacoes,
    this.narrativas,
    this.notas,
  );
  final List<Versiculo> versiculos;
  final Map<int, int> contagem;
  final Map<int, int> citacoes;
  final List<Trecho> narrativas;
  final Set<int> notas;
}

class _LeitorState extends State<Leitor> {
  late final Future<_DadosCapitulo> _dados = _carregar();
  final _chaves = <int, GlobalKey>{};
  final _rolagem = ScrollController();
  final _vista = GlobalKey();
  final _texto = GlobalKey();

  /// O lugar da leitura, medido no instante em que as linhas vão se refazer
  /// (o painel abriu ou fechou, a divisória foi arrastada, a letra mudou):
  /// um versículo e a distância dele ao topo do texto. Sem isso, a mesma
  /// rolagem em pontos cairia em outro trecho. Logo que as linhas se
  /// refazem, antes de o quadro ser pintado, a rolagem é corrigida para o
  /// versículo ficar no mesmo lugar da tela (ver [_corrigirRolagem]).
  (int, double)? _ancora;

  /// O que define a quebra das linhas; mudou, o lugar da leitura é medido.
  Object? _forma;

  /// O versículo que ficou parado na última mudança de largura. Enquanto a
  /// pessoa não rolar, ele continua sendo o parado: fechar e abrir o painel
  /// volta exatamente ao começo.
  int? _parado;

  /// O versículo foi tocado agora, e a pessoa não rolou desde então: é ele
  /// que fica parado quando o painel abre.
  bool _mostrarSelecionado = false;

  Future<_DadosCapitulo> _carregar() async {
    final p = widget.posicao;
    final r = await Future.wait([
      Biblia.instancia.capitulo(widget.versao.id, p.livro, p.capitulo),
      Estudo.instancia.contagem(p.livro, p.capitulo),
      Estudo.instancia.citacoesDoCapitulo(p.livro, p.capitulo),
      Estudo.instancia.narrativas(p.livro, p.capitulo),
      Estudo.instancia.versiculosComNota(p.livro, p.capitulo),
    ]);
    final dados = _DadosCapitulo(
      r[0] as List<Versiculo>,
      r[1] as Map<int, int>,
      r[2] as Map<int, int>,
      r[3] as List<Trecho>,
      r[4] as Set<int>,
    );
    final alvo = widget.rolarPara;
    if (alvo != null && alvo > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _chaves[alvo]?.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx, alignment: 0.2);
        }
      });
    }
    return dados;
  }

  @override
  void didUpdateWidget(Leitor antes) {
    super.didUpdateWidget(antes);
    if (widget.selecionado != antes.selecionado) {
      _mostrarSelecionado = widget.selecionado != null;
    }
  }

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  // --- lugar da leitura ---

  /// Distância do versículo [n] ao topo de [referencia], e a altura dele.
  (double, double)? _medir(int n, RenderObject? referencia) {
    final caixa = _chaves[n]?.currentContext?.findRenderObject();
    if (referencia is! RenderBox || caixa is! RenderBox) return null;
    if (!caixa.attached || !caixa.hasSize) return null;
    return (
      caixa.localToGlobal(Offset.zero, ancestor: referencia).dy,
      caixa.size.height,
    );
  }

  bool _aoRolar(ScrollEndNotification n) {
    if (n.depth == 0) {
      _mostrarSelecionado = false;
      _parado = null;
    }
    return false;
  }

  /// Chamado na montagem do quadro em que a largura muda, com as linhas
  /// ainda na largura antiga: escolhe o versículo que deve ficar parado.
  void _medirAncora(RenderObject? conteudo) {
    _ancora = null;
    if (!_rolagem.hasClients) return;
    final pos = _rolagem.position;
    // No começo do capítulo, continua no começo, com o título à vista.
    if (!pos.hasPixels || pos.pixels <= pos.minScrollExtent) return;
    final vista = _vista.currentContext?.findRenderObject();
    if (vista is! RenderBox || !vista.hasSize) return;
    final altura = vista.size.height;
    bool aVista((double, double)? p) =>
        p != null && p.$1 + p.$2 > 0 && p.$1 < altura;

    // O versículo recém-tocado; senão, o que já estava parado; senão, o
    // primeiro que começa na tela; senão (um versículo maior que a tela), o
    // que está à vista.
    int? escolhido;
    final s = widget.selecionado;
    final parado = _parado;
    if (_mostrarSelecionado && s != null && aVista(_medir(s, vista))) {
      escolhido = s;
    } else if (parado != null && aVista(_medir(parado, vista))) {
      escolhido = parado;
    } else {
      int? cortado;
      for (final n in _chaves.keys.toList()..sort()) {
        final p = _medir(n, vista);
        if (!aVista(p)) continue;
        if (p!.$1 >= 0) {
          escolhido = n;
          break;
        }
        cortado ??= n;
      }
      escolhido ??= cortado;
    }
    final y = escolhido == null ? null : _medir(escolhido, conteudo);
    if (y == null) return;
    _ancora = (escolhido!, y.$1);
    _parado = escolhido;
    // Se as linhas não chegarem a se refazer neste quadro, a medida perde
    // a validade.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ancora = null);
  }

  /// Chamado logo depois de as linhas se refazerem, antes da pintura.
  void _corrigirRolagem(RenderBox conteudo) {
    final a = _ancora;
    if (a == null) return;
    _ancora = null;
    // Só a posição: a altura de um versículo não pode ser lida aqui, no
    // meio da montagem.
    final caixa = _chaves[a.$1]?.currentContext?.findRenderObject();
    if (caixa is! RenderBox || !caixa.attached || !_rolagem.hasClients) {
      return;
    }
    final agora = caixa.localToGlobal(Offset.zero, ancestor: conteudo).dy;
    final diferenca = agora - a.$2;
    if (diferenca.abs() > 0.5) _rolagem.position.correctBy(diferenca);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Ajustes.instancia,
      builder: (context, _) => FutureBuilder<_DadosCapitulo>(
        future: _dados,
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) {
            return snap.hasError
                ? Center(child: Text('Erro ao abrir o capítulo: ${snap.error}'))
                : const Center(child: CircularProgressIndicator());
          }
          return GestureDetector(
            // Deslizar para os lados troca de capítulo.
            onHorizontalDragEnd: (e) {
              final v = e.primaryVelocity ?? 0;
              if (v.abs() < 600) return;
              widget.aoMudarCapitulo(v < 0 ? 1 : -1);
            },
            child: _conteudo(context, d),
          );
        },
      ),
    );
  }

  Widget _conteudo(BuildContext context, _DadosCapitulo d) {
    final t = Theme.of(context);
    final aj = Ajustes.instancia;
    final p = widget.posicao;
    return LayoutBuilder(
      builder: (context, c) {
        final forma = (
          c.maxWidth,
          aj.larguraTexto,
          aj.tamanhoLetra,
          MediaQuery.sizeOf(context).width >= larguraMinimaParaAjuste,
        );
        if (_forma != null && _forma != forma) {
          _medirAncora(_texto.currentContext?.findRenderObject());
        }
        _forma = forma;
        return NotificationListener<ScrollEndNotification>(
          onNotification: _aoRolar,
          child: SingleChildScrollView(
            key: _vista,
            controller: _rolagem,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            // A largura do texto é ajuste da pessoa: a tela toda, ou menos, com
            // linhas mais curtas no meio da tela.
            child: LarguraDoTexto(
              child: _Ancorador(
                key: _texto,
                aoDispor: _corrigirRolagem,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${Referencias.nome(p.livro)} ${p.capitulo}',
                      textAlign: TextAlign.center,
                      style: t.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.versao.nome,
                      textAlign: TextAlign.center,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.hintColor,
                      ),
                    ),
                    if (d.narrativas.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _Narrativas(trechos: d.narrativas),
                    ],
                    const SizedBox(height: 12),
                    for (final v in d.versiculos)
                      KeyedSubtree(
                        key: _chaves.putIfAbsent(v.numero, GlobalKey.new),
                        child: _LinhaVersiculo(
                          posicao: p,
                          versiculo: v,
                          versao: widget.versao,
                          selecionado: v.numero == widget.selecionado,
                          egw: aj.marcadoresEgw
                              ? (d.contagem[v.numero] ?? 0)
                              : 0,
                          citacao: d.citacoes[v.numero],
                          temNota: d.notas.contains(v.numero),
                          aoTocar: () => widget.aoSelecionar(v.numero),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (p.livro > 1 || p.capitulo > 1)
                          OutlinedButton.icon(
                            onPressed: () => widget.aoMudarCapitulo(-1),
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('Anterior'),
                          ),
                        const Spacer(),
                        if (p.livro < 66 ||
                            p.capitulo < Referencias.capitulos[p.livro - 1])
                          FilledButton.tonalIcon(
                            onPressed: () => widget.aoMudarCapitulo(1),
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Próximo'),
                            iconAlignment: IconAlignment.end,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "Narrado em: O Desejado de Todas as Nações — cap. 12, A tentação".
class _Narrativas extends StatelessWidget {
  const _Narrativas({required this.trechos});
  final List<Trecho> trechos;

  @override
  Widget build(BuildContext context) {
    final cor = corEgw(context);
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories_outlined, size: 18, color: cor),
                const SizedBox(width: 6),
                Text(
                  'Esta passagem é narrada em',
                  style: t.textTheme.labelLarge?.copyWith(color: cor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tr in trechos.take(8))
                  ActionChip(
                    label: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${tr.obra.sigla}  ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: cor,
                            ),
                          ),
                          TextSpan(text: tr.capitulo ?? tr.obra.titulo),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => abrirTrechoCompleto(context, tr),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaVersiculo extends StatelessWidget {
  const _LinhaVersiculo({
    required this.posicao,
    required this.versiculo,
    required this.versao,
    required this.selecionado,
    required this.egw,
    required this.citacao,
    required this.temNota,
    required this.aoTocar,
  });

  final Posicao posicao;
  final Versiculo versiculo;
  final Versao versao;
  final bool selecionado;
  final int egw;
  final int? citacao;
  final bool temNota;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final aj = Ajustes.instancia;
    final tam = aj.tamanhoLetra;
    final base = t.textTheme.bodyLarge!.copyWith(fontSize: tam, height: 1.6);
    final cor = aj.marcacao(posicao.livro, posicao.capitulo, versiculo.numero);
    final anotado =
        aj.anotacao(posicao.livro, posicao.capitulo, versiculo.numero) != null;

    final indicadores = <InlineSpan>[];
    void indicador(IconData icone, Color c, String? texto, String dica) {
      indicadores.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Tooltip(
            message: dica,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icone, size: tam * 0.7, color: c),
                  if (texto != null)
                    Text(
                      texto,
                      style: TextStyle(
                        fontSize: tam * 0.6,
                        color: c,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (egw > 0) {
      indicador(
        Icons.menu_book_outlined,
        corEgw(context),
        '$egw',
        '$egw trecho(s) de Ellen G. White e pioneiros',
      );
    }
    if (citacao != null) {
      indicador(
        citacao == 3 ? Icons.compare_arrows : Icons.format_quote,
        t.colorScheme.tertiary,
        null,
        citacao == 3
            ? 'Tem passagem paralela'
            : posicao.livro >= 40
            ? 'Cita o Antigo Testamento'
            : 'Citado no Novo Testamento',
      );
    }
    if (temNota) {
      indicador(
        Icons.sticky_note_2_outlined,
        t.colorScheme.primary,
        null,
        'Nota de estudo',
      );
    }
    if (anotado) {
      indicador(Icons.edit_note, t.colorScheme.secondary, null, 'Sua anotação');
    }

    return InkWell(
      onTap: aoTocar,
      onLongPress: () => mostrarAcoesVersiculo(
        context,
        Posicao(posicao.livro, posicao.capitulo, versiculo.numero),
        versiculo.texto,
        versao,
      ),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: cor != null ? coresMarcacao[cor % coresMarcacao.length] : null,
          borderRadius: BorderRadius.circular(6),
          border: selecionado
              ? Border.all(color: t.colorScheme.primary, width: 1.5)
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        margin: const EdgeInsets.symmetric(vertical: 1),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${versiculo.numero} ',
                style: base.copyWith(
                  fontSize: tam * 0.65,
                  fontWeight: FontWeight.bold,
                  color: t.colorScheme.primary,
                  fontFeatures: const [FontFeature.superscripts()],
                ),
              ),
              ...spansDoTexto(
                versiculo.texto,
                estilo: base,
                corJesus: corJesus(context),
                vermelho: aj.letrasVermelhas,
              ),
              ...indicadores,
            ],
          ),
        ),
      ),
    );
  }
}

/// Avisa quando o texto acabou de ser disposto, ainda antes da pintura: é
/// ali que a rolagem pode ser corrigida sem um quadro no lugar errado.
class _Ancorador extends SingleChildRenderObjectWidget {
  const _Ancorador({super.key, required this.aoDispor, super.child});

  final ValueChanged<RenderBox> aoDispor;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAncorador(aoDispor);

  @override
  void updateRenderObject(BuildContext context, _RenderAncorador r) =>
      r.aoDispor = aoDispor;
}

class _RenderAncorador extends RenderProxyBox {
  _RenderAncorador(this.aoDispor);

  ValueChanged<RenderBox> aoDispor;

  @override
  void performLayout() {
    super.performLayout();
    aoDispor(this);
  }
}
