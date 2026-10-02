import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../dados/ajustes.dart';

/// Salva marcações, anotações e o plano de leitura num arquivo escolhido pela
/// pessoa (no celular, pode ser o Google Drive), para levar a outro aparelho
/// ou guardar antes de reinstalar o app.
Future<void> salvarCopia(BuildContext context) async {
  final msg = ScaffoldMessenger.of(context);
  final dados = Ajustes.instancia.exportar();
  final hoje = DateTime.now();
  final nome =
      'biblia-estudo-${hoje.year}-${_dois(hoje.month)}-${_dois(hoje.day)}.json';
  try {
    final destino = await FilePicker.saveFile(
      dialogTitle: 'Salvar cópia das marcações e anotações',
      fileName: nome,
      bytes: utf8.encode(const JsonEncoder.withIndent(' ').convert(dados)),
      mimeType: 'application/json',
    );
    if (destino == null) return;
    final m = (dados['marcacoes'] as Map).length;
    final a = (dados['anotacoes'] as Map).length;
    msg.showSnackBar(
      SnackBar(
        content: Text(
          'Cópia salva: $m ${m == 1 ? 'marcação' : 'marcações'} e '
          '$a ${a == 1 ? 'anotação' : 'anotações'}.',
        ),
      ),
    );
  } catch (e) {
    msg.showSnackBar(
      SnackBar(content: Text('Não foi possível salvar a cópia: $e')),
    );
  }
}

/// Abre uma cópia salva por [salvarCopia] e junta ao que já está no app.
Future<void> restaurarCopia(BuildContext context) async {
  final msg = ScaffoldMessenger.of(context);
  try {
    final arquivo = await FilePicker.pickFile(
      dialogTitle: 'Abrir cópia das marcações e anotações',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (arquivo == null) return;
    final texto = utf8.decode(await arquivo.readAsBytes());
    final Object? dados;
    try {
      dados = jsonDecode(texto);
    } on FormatException {
      throw const FormatException(
        'Este arquivo não é uma cópia da Bíblia de Estudo.',
      );
    }
    final r = Ajustes.instancia.importar(dados);
    String n(int q, String um, String varios) => '$q ${q == 1 ? um : varios}';
    final partes = [
      n(r.marcacoes, 'marcação', 'marcações'),
      n(r.anotacoes, 'anotação', 'anotações'),
      if (r.realces > 0)
        n(r.realces, 'realce nos livros', 'realces nos livros'),
    ];
    final lista = partes.length == 2
        ? partes.join(' e ')
        : '${partes[0]}, ${partes[1]} e ${partes[2]}';
    msg.showSnackBar(
      SnackBar(
        content: Text(
          'Cópia restaurada: $lista. Nada do que já estava no app foi apagado.',
        ),
      ),
    );
  } on FormatException catch (e) {
    msg.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    msg.showSnackBar(
      SnackBar(content: Text('Não foi possível abrir a cópia: $e')),
    );
  }
}

String _dois(int n) => n.toString().padLeft(2, '0');
