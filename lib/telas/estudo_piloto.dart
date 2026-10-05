import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dados/modelos.dart';
import '../dados/referencias.dart';
import 'navegacao.dart';
import 'licao_original.dart';

const hashEstudoPiloto =
    '1bacb247dcdce6348ce491573a050b543f5bab2a236498799170419b4269fbd7';

/// O índice contém só posições e referências; enunciados vêm do PDF pessoal.
class TelaEstudoPiloto extends StatefulWidget {
  const TelaEstudoPiloto({
    super.key,
    required this.arquivo,
    required this.prefs,
    this.carregarTexto,
  });
  final File arquivo;
  final SharedPreferences prefs;
  final Future<String> Function()? carregarTexto;
  @override
  State<TelaEstudoPiloto> createState() => _TelaEstudoPilotoState();
}

class _TelaEstudoPilotoState extends State<TelaEstudoPiloto> {
  late final _dados = _carregar();
  final _campos = <TextEditingController>[];
  final _escolhas = <int, int>{};
  Map? _indice;
  bool _salvando = false;
  bool _permitirSaida = false;
  String get _prefixo => 'piloto_${hashEstudoPiloto}_licao1';

  Future<(String, List<dynamic>)> _carregar() async {
    final textoOriginal = await (widget.carregarTexto?.call() ?? _textoPdf());
    final indice = jsonDecode(
      await rootBundle.loadString('assets/estudo_piloto.json', cache: false),
    ) as Map;
    final texto = textoOriginal
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .join(' ');
    _indice = indice;
    final perguntas = indice['perguntas'] as List;
    if (!mounted) return (texto, perguntas);
    for (var i = 0; i < perguntas.length; i++) {
      final q = perguntas[i] as Map;
      texto.substring(q['inicio'] as int, q['fim'] as int);
      _campos.add(
        TextEditingController(
          text: widget.prefs.getString('${_prefixo}_resposta_$i') ?? '',
        ),
      );
      final escolha = widget.prefs.getInt('${_prefixo}_escolha_$i');
      if (escolha != null) _escolhas[i] = escolha;
    }
    for (var i = 8; i < 12; i++) {
      _campos.add(
        TextEditingController(
          text: widget.prefs.getString('${_prefixo}_resposta_$i') ?? '',
        ),
      );
    }
    return (texto, perguntas);
  }

  Future<String> _textoPdf() async {
    final hash = await sha256.bind(widget.arquivo.openRead()).first;
    if (hash.toString() != hashEstudoPiloto) {
      throw StateError('Esta edição do PDF não corresponde ao índice');
    }
    final pdf = await PdfDocument.openFile(widget.arquivo.path);
    try {
      final texto = await pdf.pages[5].loadText();
      if (texto == null) throw StateError('Página sem texto');
      return texto.fullText;
    } finally {
      await pdf.dispose();
    }
  }

  Future<bool> _salvar({bool concluir = false}) async {
    setState(() => _salvando = true);
    try {
      for (var i = 0; i < _campos.length; i++) {
        if (!await widget.prefs.setString(
          '${_prefixo}_resposta_$i',
          _campos[i].text,
        )) {
          throw StateError('Falha ao salvar');
        }
        if (_escolhas[i] != null &&
            !await widget.prefs.setInt(
              '${_prefixo}_escolha_$i',
              _escolhas[i]!,
            )) {
          throw StateError('Falha ao salvar');
        }
      }
      if (concluir &&
          !await widget.prefs.setBool('${_prefixo}_concluida', true)) {
        throw StateError('Falha ao concluir');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              concluir
                  ? 'Lição concluída e respostas salvas.'
                  : 'Respostas salvas. Você pode continuar depois.',
            ),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    for (final c in _campos) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _permitirSaida || _campos.isEmpty,
    onPopInvokedWithResult: (saiu, resultado) async {
      if (saiu || _salvando) return;
      if (await _salvar() && mounted) {
        setState(() => _permitirSaida = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      backgroundColor: const Color(0xFFEAEFF2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        title: const Text('Jesus e as Escrituras Sagradas'),
      ),
      body: FutureBuilder<(String, List<dynamic>)>(
        future: _dados,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text('Não foi possível ler a lição nesta edição do PDF.'),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return LicaoOriginal(
            arquivo: widget.arquivo,
            indice: _indice!,
            campos: _campos,
            escolhas: _escolhas,
            salvando: _salvando,
            concluida: widget.prefs.getBool('${_prefixo}_concluida') ?? false,
            semImagem: widget.carregarTexto != null,
            aoEscolher: (i, j) => setState(() => _escolhas[i] = j),
            aoSalvar: _salvar,
            aoConcluir: () => _salvar(concluir: true),
            aoReferencia: (refs) async {
              if (!await _salvar() || !context.mounted) return;
              final List? ref;
              if (refs.length > 1) {
                ref = await showDialog<List>(
                  context: context,
                  builder: (context) => SimpleDialog(
                    title: const Text('Ler na Bíblia'),
                    children: [
                      for (final r in refs)
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(context, r),
                          child: Text(
                            Referencias.formatar(
                              r[0] as int,
                              r[1] as int,
                              r[2] as int,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              } else {
                ref = refs.first as List;
              }
              if (ref == null || !context.mounted) return;
              setState(() => _permitirSaida = true);
              await WidgetsBinding.instance.endOfFrame;
              if (!context.mounted) return;
              irParaVersiculo(
                context,
                Posicao(
                  ref[0] as int,
                  (ref[1] as int) ~/ 1000,
                  (ref[1] as int) % 1000,
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
