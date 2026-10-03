import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dados/ajustes.dart';

/// Centraliza [child] com a largura escolhida em Ajustes → Leitura → Largura
/// do texto (a tela toda, por padrão). Vale no leitor da Bíblia e nas telas
/// de texto corrido, como a introdução ao livro e os temas.
class LarguraDoTexto extends StatelessWidget {
  const LarguraDoTexto({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.sizeOf(context).width;
    return ListenableBuilder(
      listenable: Ajustes.instancia,
      builder: (context, _) => LayoutBuilder(
        builder: (context, c) => Center(
          child: SizedBox(
            width: larguraDaColuna(
              disponivel: c.maxWidth,
              fracao: Ajustes.instancia.larguraTexto,
              larguraDaTela: tela,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A partir desta largura de tela o ajuste "Largura do texto" aparece e
/// vale. Abaixo dela (celular em pé, janela estreita) o texto usa a largura
/// toda, para o ajuste não ficar valendo onde não dá para mudá-lo.
const larguraMinimaParaAjuste = 600.0;

/// A largura da coluna de texto dentro do espaço [disponivel]: a [fracao]
/// escolhida, nunca menos de 420 pontos (ou o espaço todo, se for menor),
/// para as linhas e os botões de capítulo caberem.
double larguraDaColuna({
  required double disponivel,
  required double fracao,
  required double larguraDaTela,
}) {
  if (fracao >= 1 || larguraDaTela < larguraMinimaParaAjuste) {
    return disponivel;
  }
  return math.max(disponivel * fracao, math.min(disponivel, 420));
}
