import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../dados/biblia.dart';
import '../dados/fundos.dart';
import '../dados/modelos.dart';
import '../dados/referencias.dart';
import '../dados/versiculo_do_dia.dart';

/// "João 3:16" ou "Isaías 43:18-19".
String referenciaDaPassagem(Posicao inicio, int ate) =>
    '${Referencias.nome(inicio.livro)} ${inicio.capitulo}:${inicio.versiculo}'
    '${ate > inicio.versiculo! ? '-$ate' : ''}';

/// Abre o versículo do dia como imagem, na tradução [versao]. Devolve a
/// posição a abrir no leitor, se a pessoa tocar em "Abrir na Bíblia".
Future<Posicao?> abrirVersiculoDoDia(
  BuildContext context,
  Versao versao,
) async {
  final ref = await VersiculoDoDia.hoje();
  if (ref == null) return null;
  final versos = await Biblia.instancia.capitulo(
    versao.id,
    ref.livro,
    ref.capitulo,
  );
  final texto = versos
      .where((v) => v.numero >= ref.versiculo && v.numero <= ref.ate)
      .map((v) => textoPuro(v.texto).trim())
      .join(' ');
  if (texto.isEmpty || !context.mounted) return null;
  return Navigator.push<Posicao>(
    context,
    MaterialPageRoute(
      builder: (_) => CartaoVersiculo(
        titulo: 'Versículo do dia',
        inicio: Posicao(ref.livro, ref.capitulo, ref.versiculo),
        ate: ref.ate,
        texto: texto,
        sigla: versao.sigla,
        podeAbrir: true,
      ),
    ),
  );
}

/// Monta um cartão quadrado com o versículo sobre uma foto, para compartilhar
/// ou salvar (o mesmo cartão do Louvor JA).
///
/// O cartão é um widget de verdade, capturado por `RepaintBoundary`: o PNG é
/// exatamente o que a pessoa viu na tela, sempre em 1080×1080.
class CartaoVersiculo extends StatefulWidget {
  const CartaoVersiculo({
    super.key,
    required this.inicio,
    required this.ate,
    required this.texto,
    this.sigla,
    this.titulo = 'Versículo em imagem',
    this.podeAbrir = false,
  });

  /// Primeiro versículo (com [Posicao.versiculo]).
  final Posicao inicio;

  /// Último versículo da passagem.
  final int ate;

  /// O texto, já sem marcações.
  final String texto;
  final String? sigla;
  final String titulo;

  /// Mostra "Abrir na Bíblia", que fecha a tela devolvendo [inicio].
  final bool podeAbrir;

  @override
  State<CartaoVersiculo> createState() => _CartaoVersiculoState();
}

class _CartaoVersiculoState extends State<CartaoVersiculo> {
  final _chave = GlobalKey();
  Fundo? _fundo;
  bool _gerando = false;

  String get _referencia => referenciaDaPassagem(widget.inicio, widget.ate);

  String get _comoTexto =>
      '“${widget.texto}”\n$_referencia'
      '${widget.sigla == null ? '' : ' (${widget.sigla})'}';

  @override
  void initState() {
    super.initState();
    Fundos.instancia.sugerir(widget.texto).then((f) {
      if (mounted) setState(() => _fundo = f);
    });
  }

  Future<void> _trocarFundo() async {
    final atual = _fundo;
    if (atual == null) return;
    final prox = await Fundos.instancia.proximo(atual);
    if (mounted) setState(() => _fundo = prox);
  }

  /// Captura o cartão em 1080×1080, qualquer que seja a densidade da tela.
  Future<Uint8List?> _renderizar() async {
    final limite =
        _chave.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (limite == null) return null;
    final imagem = await limite.toImage(pixelRatio: 1080 / limite.size.width);
    final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
    return dados?.buffer.asUint8List();
  }

  String get _nomeArquivo =>
      'versiculo-${_referencia.replaceAll(RegExp(r'[^\wÀ-ú]+'), '-')}.png';

  Future<void> _gerar(Future<void> Function(Uint8List) acao) async {
    final msg = ScaffoldMessenger.of(context);
    setState(() => _gerando = true);
    try {
      final bytes = await _renderizar();
      if (bytes != null) await acao(bytes);
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text('Não foi possível: $e')));
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  /// O arquivo vai para a pasta temporária: quem guarda é o app que recebe.
  Future<void> _compartilhar(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final arquivo = File(p.join(dir.path, _nomeArquivo));
    await arquivo.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(arquivo.path, mimeType: 'image/png')],
        text: _comoTexto,
      ),
    );
  }

  Future<void> _salvar(Uint8List bytes) async {
    final msg = ScaffoldMessenger.of(context);
    final destino = await FilePicker.saveFile(
      dialogTitle: 'Salvar a imagem do versículo',
      fileName: _nomeArquivo,
      bytes: bytes,
      mimeType: 'image/png',
    );
    if (destino == null) return;
    msg.showSnackBar(const SnackBar(content: Text('Imagem salva.')));
  }

  @override
  Widget build(BuildContext context) {
    final fundo = _fundo;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [
          IconButton(
            tooltip: 'Trocar a foto',
            onPressed: fundo == null ? null : _trocarFundo,
            icon: const Icon(Icons.image_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: RepaintBoundary(
                key: _chave,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: fundo == null
                      ? const ColoredBox(color: Colors.black12)
                      : _cartao(fundo),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (fundo != null)
            Center(
              child: Text(
                'Foto: ${fundo.descricao} · toque no ícone no alto para trocar',
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 20),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _gerando || fundo == null
                        ? null
                        : () => _gerar(_compartilhar),
                    icon: _gerando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share),
                    label: const Text('Compartilhar a imagem'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _gerando || fundo == null
                        ? null
                        : () => _gerar(_salvar),
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Salvar a imagem'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () =>
                        SharePlus.instance.share(ShareParams(text: _comoTexto)),
                    icon: const Icon(Icons.text_fields),
                    label: const Text('Compartilhar como texto'),
                  ),
                  if (widget.podeAbrir) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context, widget.inicio),
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Abrir na Bíblia'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartao(Fundo fundo) {
    // Texto longo encolhe, ou estoura o quadrado: um versículo curto respira
    // em 28, um parágrafo do Salmo 119 só cabe em 15.
    final n = widget.texto.length;
    final tamanho = n > 320
        ? 15.0
        : n > 180
        ? 18.0
        : n > 90
        ? 23.0
        : 28.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(fundo.asset, fit: BoxFit.cover),
        // Véu escuro: sem ele, texto claro sobre foto clara fica ilegível.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.30),
                Colors.black.withValues(alpha: 0.68),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    widget.texto,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: tamanho,
                      height: 1.42,
                      fontWeight: FontWeight.w500,
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                [_referencia, ?widget.sigla].join('  ·  '),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFC107),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bíblia de Estudo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
