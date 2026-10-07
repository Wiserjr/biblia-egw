import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../dados/respostas_estudos.dart';

/// Edição confortável no celular, sem trocar a rota ou alterar o PDF.
class EditorPerguntaEstudo extends StatefulWidget {
  const EditorPerguntaEstudo({
    super.key,
    required this.pergunta,
    required this.respostas,
    required this.textoOriginal,
    required this.textosOpcoes,
    this.imagemOriginal,
    this.consultarVersiculos,
  });
  final Map pergunta;
  final RespostasEstudos respostas;
  final String textoOriginal;
  final Map<String, List<String>> textosOpcoes;
  final Uint8List? imagemOriginal;
  final VoidCallback? consultarVersiculos;
  @override
  State<EditorPerguntaEstudo> createState() => _EditorPerguntaEstudoState();
}

class _EditorPerguntaEstudoState extends State<EditorPerguntaEstudo> {
  final _campos = <String, TextEditingController>{};
  final _opcoes = <String, List<int>>{};
  bool _salvando = false;
  String? _erro;
  @override
  void initState() {
    super.initState();
    for (final c in widget.pergunta['respostas'] as List) {
      final id = c['id'] as String;
      if (c['tipo'] == 'alternativas') {
        _opcoes[id] = [...widget.respostas.escolhas(c as Map)];
      } else {
        _campos[id] = TextEditingController(
          text: widget.respostas.texto(c as Map),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      for (final c in widget.pergunta['respostas'] as List) {
        final id = c['id'] as String;
        if (c['tipo'] == 'alternativas') {
          await widget.respostas.salvarEscolhas(c as Map, _opcoes[id]!);
        } else {
          await widget.respostas.salvarTexto(c as Map, _campos[id]!.text);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erro = 'Não foi possível salvar. Sua resposta continua aqui; tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (saiu, resultado) {
      if (!saiu && !_salvando) _salvar();
    },
    child: AlertDialog(
      title: const Text('Sua resposta'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.imagemOriginal != null)
                InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.memory(
                    widget.imagemOriginal!,
                    semanticLabel:
                        'Pergunta e alternativas no documento original',
                  ),
                ),
              if (widget.imagemOriginal != null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Amplie a imagem com dois dedos para ler os detalhes.',
                  ),
                ),
              if (widget.textoOriginal.isNotEmpty)
                Text(
                  widget.textoOriginal,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              if (widget.pergunta['semEnunciado'] == true)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Este espaço está sem enunciado completo no PDF oficial. O documento original foi preservado.',
                  ),
                ),
              if (widget.consultarVersiculos != null)
                TextButton.icon(
                  onPressed: widget.consultarVersiculos,
                  icon: const Icon(Icons.menu_book),
                  label: const Text('Consultar versículos sem sair'),
                ),
              const SizedBox(height: 16),
              for (final c in widget.pergunta['respostas'] as List) ...[
                if (c['tipo'] == 'alternativas')
                  for (var i = 0; i < (c['opcoes'] as List).length; i++)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        widget.textosOpcoes[c['id']]?[i].trim().isNotEmpty ==
                                true
                            ? widget.textosOpcoes[c['id']]![i]
                            : 'Alternativa ${i + 1}',
                      ),
                      value: _opcoes[c['id']]!.contains(i),
                      onChanged: _salvando
                          ? null
                          : (valor) => setState(() {
                              final lista = _opcoes[c['id']]!;
                              if (c['unica'] == true && valor == true) {
                                lista.clear();
                              }
                              if (valor == true) {
                                lista.add(i);
                              } else {
                                lista.remove(i);
                              }
                            }),
                    )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: _campos[c['id']],
                      enabled: !_salvando,
                      minLines: 2,
                      maxLines: 7,
                      decoration: InputDecoration(
                        labelText: _campos.length > 1
                            ? 'Resposta ${_campos.keys.toList().indexOf(c['id'] as String) + 1}'
                            : 'Escreva sua resposta ou reflexão',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
              if (_erro != null)
                Text(
                  _erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: Text(_salvando ? 'Salvando…' : 'Salvar resposta'),
        ),
      ],
    ),
  );
}
