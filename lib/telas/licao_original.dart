import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mantém a arte original: o PDF pessoal é renderizado no aparelho e os
/// controles são colocados nas posições conferidas do documento.
class LicaoOriginal extends StatefulWidget {
  const LicaoOriginal({
    super.key,
    required this.arquivo,
    required this.indice,
    required this.campos,
    required this.escolhas,
    required this.aoEscolher,
    required this.aoReferencia,
    required this.aoSalvar,
    required this.aoConcluir,
    required this.salvando,
    this.semImagem = false,
    this.carregarImagens,
    this.concluida = false,
    this.abrirLink,
  });
  final File arquivo;
  final Map indice;
  final List<TextEditingController> campos;
  final Map<int, int> escolhas;
  final void Function(int, int) aoEscolher;
  final Future<void> Function(List) aoReferencia;
  final Future<bool> Function() aoSalvar;
  final VoidCallback aoConcluir;
  final bool salvando;
  final bool semImagem;
  final Future<List<Uint8List>> Function()? carregarImagens;
  final bool concluida;
  final Future<bool> Function(Uri)? abrirLink;
  @override
  State<LicaoOriginal> createState() => _LicaoOriginalState();
}

class _LicaoOriginalState extends State<LicaoOriginal> {
  late final _imagens = widget.carregarImagens?.call() ?? _renderizar();
  double _zoom = 1;
  Future<List<Uint8List>> _renderizar() async {
    if (widget.semImagem) return [];
    final pdf = await PdfDocument.openFile(widget.arquivo.path);
    try {
      final imagens = <Uint8List>[];
      for (final n in [4, 5, 6]) {
        final pagina = pdf.pages[n];
        final pixels = await pagina.render(
          fullWidth: 1500,
          fullHeight: 1500 * pagina.height / pagina.width,
        );
        if (pixels == null) {
          throw StateError('Não foi possível desenhar a página');
        }
        try {
          final imagem = await pixels.createImage();
          try {
            imagens.add(
              (await imagem.toByteData(format: ui.ImageByteFormat.png))!.buffer
                  .asUint8List(),
            );
          } finally {
            imagem.dispose();
          }
        } finally {
          pixels.dispose();
        }
      }
      return imagens;
    } finally {
      await pdf.dispose();
    }
  }

  Future<void> _link(Map link) async {
    if (!await widget.aoSalvar() || !mounted) return;
    if (link['menu'] == true) {
      Navigator.maybePop(context);
      return;
    }
    try {
      final uri = Uri.parse(link['url'] as String);
      if (uri.scheme != 'https' && uri.scheme != 'http') {
        throw StateError('Endereço inválido');
      }
      final abriu =
          await (widget.abrirLink?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!abriu) {
        throw StateError('Não foi possível abrir o endereço');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir o link: $e')),
        );
      }
    }
  }

  Widget _pagina(int n, double largura, List<Uint8List> imagens) {
    final p = (widget.indice['paginasOriginais'] as List)[n] as Map;
    final escala = largura / (p['largura'] as num);
    Widget pos(List area, Widget child, {double margem = 0}) => Positioned(
      left: ((area[0] as num) - margem) * escala,
      top: ((area[1] as num) - margem) * escala,
      width: ((area[2] as num) - (area[0] as num) + 2 * margem) * escala,
      height: ((area[3] as num) - (area[1] as num) + 2 * margem) * escala,
      child: child,
    );
    final perguntas = widget.indice['perguntas'] as List;
    return Container(
      key: ValueKey('pagina-${p['pagina']}'),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      width: largura,
      height: (p['altura'] as num) * escala,
      child: Stack(
        children: [
          if (imagens.isNotEmpty)
            Positioned.fill(child: Image.memory(imagens[n], fit: BoxFit.fill)),
          for (final link in p['links'] as List)
            pos(
              link['area'] as List,
              Tooltip(
                message: link['menu'] == true
                    ? 'Voltar aos estudos'
                    : link['url'] as String,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.salvando ? null : () => _link(link as Map),
                    hoverColor: Colors.lightBlue.withValues(alpha: .18),
                  ),
                ),
              ),
              margem: 3,
            ),
          if (n == 1) ...[
            for (var i = 0; i < perguntas.length; i++) ...[
              pos(
                perguntas[i]['areaReferencia'] as List,
                Semantics(
                  label: 'Abrir referência da pergunta ${i + 1}',
                  button: true,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.salvando
                          ? null
                          : () => widget.aoReferencia(
                              perguntas[i]['referencias'] as List,
                            ),
                      hoverColor: Colors.lightBlue.withValues(alpha: .18),
                    ),
                  ),
                ),
                margem: 1,
              ),
              if (i < 4)
                for (var j = 0; j < 3; j++)
                  pos(
                    perguntas[i]['areasAlternativas'][j] as List,
                    Semantics(
                      label: 'Pergunta ${i + 1}, alternativa ${j + 1}',
                      checked: widget.escolhas[i] == j,
                      child: InkWell(
                        onTap: widget.salvando
                            ? null
                            : () => widget.aoEscolher(i, j),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: Offset(0, 0),
                            child: ColoredBox(
                              color: Colors.white,
                              child: Padding(
                                padding: EdgeInsets.all(2 * escala),
                                child: Container(
                                  width: 6.35 * escala,
                                  height: 6.35 * escala,
                                  decoration: BoxDecoration(
                                    color: widget.escolhas[i] == j
                                        ? const Color(0xFF009FD1)
                                        : Colors.white,
                                    border: Border.all(
                                      color: widget.escolhas[i] == j
                                          ? const Color(0xFF009FD1)
                                          : Colors.black87,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      2 * escala,
                                    ),
                                  ),
                                  child: widget.escolhas[i] == j
                                      ? Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 6 * escala,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    margem: 2,
                  ),
              if (i >= 4)
                pos(
                  perguntas[i]['areaResposta'] as List,
                  TextField(
                    controller: widget.campos[i],
                    enabled: !widget.salvando,
                    style: TextStyle(
                      fontSize: 9 * escala,
                      color: const Color(0xFF145473),
                    ),
                    maxLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Escreva sua resposta…',
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFCDD7DC)),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFCDD7DC)),
                      ),
                      filled: true,
                      fillColor: Color(0xEFFFFFFF),
                    ),
                  ),
                ),
            ],
            for (var k = 0; k < 4; k++)
              pos(
                const <List<num>>[
                  [39.4, 300, 369, 316],
                  [39.4, 414, 369, 430],
                  [68, 527, 234, 541],
                  [266, 527, 365, 541],
                ][k],
                TextField(
                  controller: widget.campos[8 + k],
                  enabled: !widget.salvando,
                  style: TextStyle(
                    fontSize: 9 * escala,
                    color: const Color(0xFF145473),
                  ),
                  maxLines: 1,
                  decoration: InputDecoration(
                    hintText: k < 2
                        ? 'Sua reflexão…'
                        : k == 2
                        ? 'Seu nome'
                        : 'Data',
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFCDD7DC)),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFCDD7DC)),
                    ),
                    filled: true,
                    fillColor: const Color(0xEFFFFFFF),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF009FD1)),
      scaffoldBackgroundColor: const Color(0xFFEAEFF2),
    ),
    child: Column(
      children: [
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'LIÇÃO 01',
                  style: TextStyle(
                    color: Color(0xFF009FD1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('Leia • responda • pratique'),
                IconButton(
                  tooltip: 'Diminuir página',
                  onPressed: () =>
                      setState(() => _zoom = (_zoom - .15).clamp(.7, 1.6)),
                  icon: const Icon(Icons.zoom_out),
                ),
                IconButton(
                  tooltip: 'Aumentar página',
                  onPressed: () =>
                      setState(() => _zoom = (_zoom + .15).clamp(.7, 1.6)),
                  icon: const Icon(Icons.zoom_in),
                ),
                TextButton.icon(
                  onPressed: widget.salvando ? null : widget.aoSalvar,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Salvar e continuar depois'),
                ),
                FilledButton(
                  onPressed: widget.salvando ? null : widget.aoConcluir,
                  child: Text(
                    widget.concluida ? '✓ Lição concluída' : 'Concluir lição',
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Uint8List>>(
            future: _imagens,
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(
                  child: Text('Não foi possível carregar as páginas do PDF.'),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return LayoutBuilder(
                builder: (context, c) {
                  final largura =
                      (c.maxWidth - 48).clamp(650.0, 1000.0) * _zoom;
                  return SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: largura > c.maxWidth ? largura + 48 : c.maxWidth,
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            for (var n = 0; n < 3; n++)
                              _pagina(n, largura, snap.data!),
                            Container(
                              width: largura,
                              padding: const EdgeInsets.all(20),
                              margin: const EdgeInsets.only(bottom: 24),
                              color: Colors.white,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Vídeos e recursos da lição',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF145473),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      for (final recurso
                                          in <(int, int, String)>[
                                            (0, 0, 'Vídeo de introdução'),
                                            (
                                              1,
                                              0,
                                              'Recapitulação e compromisso',
                                            ),
                                            (2, 0, 'Evidências'),
                                            (2, 2, 'WhatsApp'),
                                          ])
                                        OutlinedButton.icon(
                                          onPressed: widget.salvando
                                              ? null
                                              : () => _link(
                                                  widget.indice['paginasOriginais'][recurso
                                                          .$1]['links'][recurso
                                                          .$2]
                                                      as Map,
                                                ),
                                          icon: Icon(
                                            recurso.$1 < 2
                                                ? Icons.play_circle_outline
                                                : Icons.open_in_new,
                                          ),
                                          label: Text(recurso.$3),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 24),
                              child: Text(
                                'Os links abrem no navegador. Suas respostas ficam neste aparelho.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
