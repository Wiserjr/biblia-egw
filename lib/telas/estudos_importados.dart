import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'estudo_piloto.dart';

/// PDFs escolhidos pela pessoa. Os originais não fazem parte da distribuição.
class TelaEstudosImportados extends StatefulWidget {
  const TelaEstudosImportados({super.key});

  @override
  State<TelaEstudosImportados> createState() => _TelaEstudosImportadosState();
}

class _TelaEstudosImportadosState extends State<TelaEstudosImportados> {
  List<File>? _arquivos;
  bool _importando = false;
  String? _erro;
  List<Map<String, dynamic>> _catalogo = [];

  Future<Directory> _pasta() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/estudos_importados').create(recursive: true);
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final dados = jsonDecode(
        await rootBundle.loadString('assets/catalogo_estudos.json'),
      ) as Map;
      _catalogo = [
        for (final item in dados['estudos'] as List)
          Map<String, dynamic>.from(item as Map),
      ];
      final pasta = await _pasta();
      final lista = await pasta
          .list()
          .where((f) => f is File && f.path.endsWith('.pdf'))
          .cast<File>()
          .toList();
      lista.sort((a, b) => a.path.compareTo(b.path));
      if (mounted) {
        setState(() {
          _arquivos = lista;
          _erro = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível abrir os estudos: $e');
      }
    }
  }

  Future<void> _importar() async {
    setState(() => _importando = true);
    try {
      final escolhido = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (escolhido == null) return;
      final bytes = await escolhido.readAsBytes();
      // Valida antes de colocar na biblioteca; arquivo inválido não fica salvo.
      final documento = await PdfDocument.openData(bytes);
      await documento.dispose();
      final id = sha256.convert(bytes).toString();
      if (!_catalogo.any((e) => e['sha256'] == id)) {
        throw const FormatException(
          'Este PDF não corresponde a uma edição do catálogo. Selecione um dos cinco arquivos preparados.',
        );
      }
      final pasta = await _pasta();
      final destino = File('${pasta.path}/$id.pdf');
      if (!await destino.exists()) {
        await destino.writeAsBytes(bytes, flush: true);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('estudo_pdf_nome_$id', escolhido.name);
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível importar o PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  Widget _cartaoCatalogo(Map<String, dynamic> item) {
    final id = item['sha256'] as String;
    final arquivos = _arquivos!.where(
      (f) => f.uri.pathSegments.last == '$id.pdf',
    );
    final arquivo = arquivos.isEmpty ? null : arquivos.first;
    final titulo = item['titulo'] as String;
    final tamanho = ((item['bytes'] as int) / 1024 / 1024).toStringAsFixed(1);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${item['paginas']} páginas • $tamanho MB'),
            Text(
              item['pilotoInterativo'] == true
                  ? 'Leitura do PDF e primeira lição interativa'
                  : 'Leitura do PDF • interação por lição ainda em preparação',
            ),
            const SizedBox(height: 12),
            if (arquivo != null)
              FilledButton.icon(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TelaEstudoImportado(
                        arquivo: arquivo,
                        id: id,
                        nome: titulo,
                        prefs: prefs,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.menu_book),
                label: const Text('Abrir estudo'),
              )
            else
              const Row(
                children: [
                  Icon(Icons.cloud_download_outlined, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('Download em preparação')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Estudos bíblicos selecionados')),
    body: _erro != null
        ? Center(child: Text(_erro!))
        : _arquivos == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Estudos selecionados',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cinco materiais escolhidos para este aplicativo. Os downloads serão ativados quando a hospedagem estiver definida. Arquivos já adicionados podem ser abertos sem internet.',
              ),
              const SizedBox(height: 16),
              for (final item in _catalogo) _cartaoCatalogo(item),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _importando ? null : _importar,
                icon: const Icon(Icons.file_open_outlined),
                label: Text(
                  _importando ? 'Adicionando…' : 'Adicionar PDF deste catálogo',
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Opção provisória para os arquivos já baixados. São aceitas somente as edições preparadas dos cinco estudos. Respostas e arquivos ficam neste aparelho.',
                ),
              ),
            ],
          ),
  );
}

class TelaEstudoImportado extends StatefulWidget {
  const TelaEstudoImportado({
    super.key,
    required this.arquivo,
    required this.id,
    required this.nome,
    required this.prefs,
  });
  final File arquivo;
  final String id;
  final String nome;
  final SharedPreferences prefs;

  @override
  State<TelaEstudoImportado> createState() => _TelaEstudoImportadoState();
}

class _TelaEstudoImportadoState extends State<TelaEstudoImportado> {
  final _controle = PdfViewerController();
  late int _pagina = widget.prefs.getInt('estudo_pdf_pagina_${widget.id}') ?? 1;
  int _total = 0;
  String get _chave => 'estudo_pdf_${widget.id}_$_pagina';

  Future<void> _responder() async {
    final chave =
        _chave; // A resposta pertence à página aberta no momento do toque.
    final pagina = _pagina;
    final campo = TextEditingController(
      text: widget.prefs.getString('${chave}_resposta') ?? '',
    );
    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Respostas — página $pagina'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: campo,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'Registre as respostas numeradas e suas reflexões.',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    final texto = campo.text;
    // O diálogo ainda pode estar encerrando sua animação.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    campo.dispose();
    if (salvar == true) {
      final ok = await widget.prefs.setString('${chave}_resposta', texto);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Respostas salvas neste aparelho.'
                  : 'Não foi possível salvar as respostas.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _exportar() async {
    try {
      final dados = <String, Object>{
        'estudo': widget.nome,
        'sha256': widget.id,
        'licao1': {
          for (final chave in widget.prefs.getKeys())
            if (chave.startsWith('piloto_${widget.id}_licao1_'))
              chave: widget.prefs.get(chave),
        },
        'pagina': _pagina,
        'paginas': {
          for (var i = 1; i <= _total; i++)
            '$i': {
              'resposta':
                  widget.prefs.getString(
                    'estudo_pdf_${widget.id}_${i}_resposta',
                  ) ??
                  '',
              'estudada':
                  widget.prefs.getBool(
                    'estudo_pdf_${widget.id}_${i}_concluida',
                  ) ??
                  false,
            },
        },
      };
      await FilePicker.saveFile(
        fileName: 'respostas-estudo.json',
        bytes: utf8.encode(const JsonEncoder.withIndent('  ').convert(dados)),
        mimeType: 'application/json',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível exportar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.nome),
      actions: [
        IconButton(
          onPressed: _total == 0 ? null : _exportar,
          tooltip: 'Exportar respostas',
          icon: const Icon(Icons.save_alt),
        ),
      ],
    ),
    body: Column(
      children: [
        if (widget.id == hashEstudoPiloto)
          ListTile(
            title: const Text('Lição 1 — Jesus e as Escrituras Sagradas'),
            subtitle: const Text('Responder às oito perguntas'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TelaEstudoPiloto(
                  arquivo: widget.arquivo,
                  prefs: widget.prefs,
                ),
              ),
            ),
          ),
        Expanded(
          child: PdfViewer.file(
            widget.arquivo.path,
            controller: _controle,
            initialPageNumber: _pagina,
            params: PdfViewerParams(
              onViewerReady: (documento, controle) {
                if (mounted) setState(() => _total = documento.pages.length);
              },
              onPageChanged: (pagina) {
                if (pagina == null || !mounted) return;
                setState(() => _pagina = pagina);
                widget.prefs.setInt('estudo_pdf_pagina_${widget.id}', pagina);
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Página $_pagina / $_total'),
                TextButton.icon(
                  onPressed: _total == 0 ? null : _responder,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Minhas respostas'),
                ),
                FilterChip(
                  label: const Text('Página estudada'),
                  selected:
                      widget.prefs.getBool('${_chave}_concluida') ?? false,
                  onSelected: _total == 0
                      ? null
                      : (valor) async {
                          await widget.prefs.setBool(
                            '${_chave}_concluida',
                            valor,
                          );
                          if (mounted) setState(() {});
                        },
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
