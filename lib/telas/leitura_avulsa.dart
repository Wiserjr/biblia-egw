import 'package:flutter/material.dart';

import '../dados/modelos.dart';
import '../dados/referencias.dart';
import 'leitor.dart';
import 'navegacao.dart';

/// A Bíblia aberta por cima de outra tela (um estudo, por exemplo): o mesmo
/// leitor da tela principal, e voltar leva de novo à tela de onde veio.
class TelaLeituraAvulsa extends StatefulWidget {
  const TelaLeituraAvulsa({
    super.key,
    required this.posicao,
    required this.versao,
    this.voltarPara = 'Voltar ao estudo',
  });

  final Posicao posicao;
  final Versao versao;

  /// Dica do botão de voltar.
  final String voltarPara;

  @override
  State<TelaLeituraAvulsa> createState() => _TelaLeituraAvulsaState();
}

class _TelaLeituraAvulsaState extends State<TelaLeituraAvulsa> {
  late Posicao _pos = Posicao(widget.posicao.livro, widget.posicao.capitulo);
  late int? _selecionado = widget.posicao.versiculo;
  late int? _rolarPara = widget.posicao.versiculo;

  void _ir(Posicao p) => setState(() {
    _pos = Posicao(p.livro, p.capitulo);
    _selecionado = p.versiculo;
    _rolarPara = p.versiculo;
  });

  void _vizinho(int delta) {
    var livro = _pos.livro;
    var cap = _pos.capitulo + delta;
    if (cap < 1) {
      if (livro == 1) return;
      livro--;
      cap = Referencias.capitulos[livro - 1];
    } else if (cap > Referencias.capitulos[livro - 1]) {
      if (livro == 66) return;
      livro++;
      cap = 1;
    }
    _ir(Posicao(livro, cap));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${Referencias.nome(_pos.livro)} ${_pos.capitulo}'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.undo),
            label: Text(widget.voltarPara),
          ),
          IconButton(
            tooltip: 'Continuar na tela principal da Bíblia',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => irParaVersiculo(
              context,
              Posicao(_pos.livro, _pos.capitulo, _selecionado),
            ),
          ),
        ],
      ),
      body: Leitor(
        key: ValueKey('${_pos.livro}:${_pos.capitulo}:${widget.versao.id}'),
        posicao: _pos,
        versao: widget.versao,
        selecionado: _selecionado,
        rolarPara: _rolarPara,
        aoSelecionar: (v) => setState(() => _selecionado = v),
        aoMudarCapitulo: _vizinho,
        aoIr: _ir,
      ),
    );
  }
}
