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
import 'tema.dart';
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

  // Personalização (ver [_Editor]).
  var _estilo = const EstiloCartao();

  /// Foto escolhida da galeria (ou de uma pasta, no PC).
  Uint8List? _foto;

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
    if (mounted) {
      setState(() {
        _fundo = prox;
        _estilo = _estilo.copiar(fundo: TipoFundo.foto);
      });
    }
  }

  Future<void> _escolherFoto() async {
    final msg = ScaffoldMessenger.of(context);
    try {
      final f = await FilePicker.pickFile(type: FileType.image);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      setState(() {
        _foto = bytes;
        _estilo = _estilo.copiar(fundo: TipoFundo.suaFoto);
      });
    } catch (e) {
      msg.showSnackBar(
        SnackBar(content: Text('Não foi possível abrir a foto: $e')),
      );
    }
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
                _estilo.fundo == TipoFundo.foto
                    ? 'Foto: ${fundo.descricao} · toque no ícone no alto para trocar'
                    : '',
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
          const SizedBox(height: 20),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: EditorCartao(
                estilo: _estilo,
                temFoto: _foto != null,
                aoMudar: (e) => setState(() => _estilo = e),
                aoTrocarFoto: _trocarFundo,
                aoEscolherFoto: _escolherFoto,
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
    final e = _estilo;
    final tamanho =
        (n > 320
            ? 15.0
            : n > 180
            ? 18.0
            : n > 90
            ? 23.0
            : 28.0) *
        e.escala;
    final foto = _foto;
    final alinhar = e.esquerda ? TextAlign.left : TextAlign.center;

    return Stack(
      fit: StackFit.expand,
      children: [
        switch (e.fundo) {
          // Uma foto do celular tem 4000 px; o cartão sai com 1080.
          TipoFundo.suaFoto when foto != null => Image.memory(
            foto,
            fit: BoxFit.cover,
            cacheWidth: 1440,
          ),
          TipoFundo.cor => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: degradesCartao[e.degrade % degradesCartao.length],
              ),
            ),
          ),
          _ => Image.asset(fundo.asset, fit: BoxFit.cover),
        },
        // Véu escuro: sem ele, texto claro sobre foto clara fica ilegível.
        if (e.fundo != TipoFundo.cor)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6 * e.veu),
                  Colors.black.withValues(alpha: (1.36 * e.veu).clamp(0, 0.9)),
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
                    textAlign: alinhar,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: tamanho,
                      height: 1.42,
                      fontFamily: e.fonte == 1 ? familiaSerifa() : null,
                      fontStyle: e.fonte == 2 ? FontStyle.italic : null,
                      fontWeight: e.fonte == 2
                          ? FontWeight.w300
                          : FontWeight.w500,
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
                textAlign: alinhar,
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

enum TipoFundo { foto, suaFoto, cor }

/// Os degradês de fundo do cartão.
const degradesCartao = <List<Color>>[
  [Color(0xFF2F4A73), Color(0xFF0F1B2D)],
  [Color(0xFF7A5A2F), Color(0xFF2B1D0E)],
  [Color(0xFF3E7C59), Color(0xFF12291C)],
  [Color(0xFF8E3B5B), Color(0xFF2A0E1C)],
  [Color(0xFFE0864B), Color(0xFF7A2E3A)],
  [Color(0xFF4B6CB7), Color(0xFF182848)],
];

/// Como o cartão é desenhado: fundo, letra, tamanho, véu e alinhamento.
class EstiloCartao {
  const EstiloCartao({
    this.fundo = TipoFundo.foto,
    this.degrade = 0,
    this.fonte = 0,
    this.escala = 1,
    this.veu = 0.5,
    this.esquerda = false,
  });

  final TipoFundo fundo;
  final int degrade;

  /// 0 moderna, 1 clássica (com serifa), 2 leve (fina e inclinada).
  final int fonte;

  /// Multiplica o tamanho da letra (de 0,8 a 1,3).
  final double escala;

  /// Quanto a foto escurece (0 a 0,8).
  final double veu;
  final bool esquerda;

  EstiloCartao copiar({
    TipoFundo? fundo,
    int? degrade,
    int? fonte,
    double? escala,
    double? veu,
    bool? esquerda,
  }) => EstiloCartao(
    fundo: fundo ?? this.fundo,
    degrade: degrade ?? this.degrade,
    fonte: fonte ?? this.fonte,
    escala: escala ?? this.escala,
    veu: veu ?? this.veu,
    esquerda: esquerda ?? this.esquerda,
  );
}

/// Os controles para personalizar o cartão do versículo.
class EditorCartao extends StatelessWidget {
  const EditorCartao({
    super.key,
    required this.estilo,
    required this.temFoto,
    required this.aoMudar,
    required this.aoTrocarFoto,
    required this.aoEscolherFoto,
  });

  final EstiloCartao estilo;
  final bool temFoto;
  final ValueChanged<EstiloCartao> aoMudar;
  final VoidCallback aoTrocarFoto;
  final VoidCallback aoEscolherFoto;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final e = estilo;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fundo', style: t.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Foto do app'),
                  selected: e.fundo == TipoFundo.foto,
                  onSelected: (_) => e.fundo == TipoFundo.foto
                      ? aoTrocarFoto()
                      : aoMudar(e.copiar(fundo: TipoFundo.foto)),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('Sua foto'),
                  selected: e.fundo == TipoFundo.suaFoto,
                  onSelected: (_) => temFoto && e.fundo != TipoFundo.suaFoto
                      ? aoMudar(e.copiar(fundo: TipoFundo.suaFoto))
                      : aoEscolherFoto(),
                ),
                ChoiceChip(
                  label: const Text('Cor'),
                  selected: e.fundo == TipoFundo.cor,
                  onSelected: (_) => aoMudar(e.copiar(fundo: TipoFundo.cor)),
                ),
              ],
            ),
            if (e.fundo == TipoFundo.cor) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < degradesCartao.length; i++)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => aoMudar(e.copiar(degrade: i)),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: degradesCartao[i]),
                          border: e.degrade == i
                              ? Border.all(
                                  width: 2.5,
                                  color: t.colorScheme.onSurface,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.brightness_6_outlined, size: 18),
                  const SizedBox(width: 8),
                  const Text('Escurecer'),
                  Expanded(
                    child: Slider(
                      value: e.veu,
                      max: 0.8,
                      onChanged: (v) => aoMudar(e.copiar(veu: v)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text('Letra', style: t.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final (i, nome) in const [
                  (0, 'Moderna'),
                  (1, 'Clássica'),
                  (2, 'Leve'),
                ])
                  ChoiceChip(
                    label: Text(nome),
                    selected: e.fonte == i,
                    onSelected: (_) => aoMudar(e.copiar(fonte: i)),
                  ),
                IconButton(
                  tooltip: e.esquerda ? 'Centralizar' : 'Alinhar à esquerda',
                  icon: Icon(
                    e.esquerda
                        ? Icons.format_align_center
                        : Icons.format_align_left,
                  ),
                  onPressed: () => aoMudar(e.copiar(esquerda: !e.esquerda)),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.format_size, size: 18),
                const SizedBox(width: 8),
                const Text('Tamanho'),
                Expanded(
                  child: Slider(
                    value: e.escala,
                    min: 0.8,
                    max: 1.3,
                    divisions: 10,
                    onChanged: (v) => aoMudar(e.copiar(escala: v)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
