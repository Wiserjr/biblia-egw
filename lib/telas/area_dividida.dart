import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dados/ajustes.dart';

/// O texto e, em tela larga com o painel de estudo aberto (ver
/// [Ajustes.painelEstudo]), a divisória e o painel à direita.
///
/// O texto fica sempre na mesma posição da árvore: abrir ou fechar o painel
/// não o recria (nem perde a rolagem). Arrastar a divisória muda a largura do
/// painel, guardada nos ajustes ao soltar; dois cliques voltam à largura
/// padrão.
class AreaDividida extends StatefulWidget {
  const AreaDividida({
    super.key,
    required this.telaLarga,
    required this.texto,
    required this.painel,
  });

  /// Cabe o painel ao lado do texto. No celular, ele sobe por baixo.
  final bool telaLarga;
  final Widget texto;
  final Widget painel;

  @override
  State<AreaDividida> createState() => _AreaDivididaState();
}

class _AreaDivididaState extends State<AreaDividida> {
  /// Largura do painel enquanto a divisória é arrastada, como fração da
  /// largura toda; ao soltar, vai para os ajustes.
  double? _arrastando;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Ajustes.instancia,
    builder: (context, _) => LayoutBuilder(
      builder: (context, c) {
        final aj = Ajustes.instancia;
        final total = c.maxWidth;
        double largura() =>
            larguraDoPainel(total, _arrastando ?? aj.larguraPainel);
        return Row(
          children: [
            Expanded(child: widget.texto),
            if (widget.telaLarga && aj.painelEstudo) ...[
              _Divisoria(
                aoArrastar: (dx) =>
                    setState(() => _arrastando = (largura() - dx) / total),
                aoSoltar: () {
                  if (_arrastando == null) return;
                  // A largura que ficou na tela, já com os limites.
                  aj.larguraPainel = largura() / total;
                  setState(() => _arrastando = null);
                },
                aoRestaurar: () {
                  aj.larguraPainel = Ajustes.larguraPainelPadrao;
                  setState(() => _arrastando = null);
                },
              ),
              SizedBox(width: largura(), child: widget.painel),
            ],
          ],
        );
      },
    ),
  );
}

/// Largura do painel de estudo para a [fracao] pedida da largura [total],
/// dentro dos limites dos ajustes: o painel não fica com menos de 280
/// pontos, nem o texto com menos de 360.
double larguraDoPainel(double total, double fracao) {
  const minPainel = 280.0;
  const minTexto = 360.0;
  final pedida =
      total * fracao.clamp(Ajustes.minLarguraPainel, Ajustes.maxLarguraPainel);
  final maximo = math.max(minPainel, total - minTexto - _Divisoria.largura);
  return pedida.clamp(minPainel, maximo);
}

/// A divisória entre o texto e o painel, com uma alça no meio.
class _Divisoria extends StatelessWidget {
  const _Divisoria({
    required this.aoArrastar,
    required this.aoSoltar,
    required this.aoRestaurar,
  });

  static const largura = 9.0;

  final ValueChanged<double> aoArrastar;
  final VoidCallback aoSoltar;
  final VoidCallback aoRestaurar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      label: 'Divisória do painel de estudo. Arraste para mudar a largura.',
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => aoArrastar(d.delta.dx),
          onHorizontalDragEnd: (_) => aoSoltar(),
          onHorizontalDragCancel: aoSoltar,
          onDoubleTap: aoRestaurar,
          child: SizedBox(
            width: largura,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VerticalDivider(width: largura, color: t.dividerColor),
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: t.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
