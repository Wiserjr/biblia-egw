import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// As ações que outros apps do celular oferecem para um texto selecionado
/// (Traduzir, Perguntar ao Claude, dicionários…). Só existem no Android.
bool get acoesDoSistemaDisponiveis => Platform.isAndroid;

/// Mostra as ações de texto dos outros apps para [texto].
Future<void> mostrarMaisAcoes(BuildContext context, String texto) async {
  final msg = ScaffoldMessenger.of(context);
  final servico = DefaultProcessTextService();
  List<ProcessTextAction> acoes;
  try {
    acoes = await servico.queryTextActions();
  } on PlatformException {
    acoes = const [];
  } on MissingPluginException {
    acoes = const [];
  }
  if (!context.mounted) return;
  if (acoes.isEmpty) {
    msg.showSnackBar(
      const SnackBar(
        content: Text('Nenhum outro app do celular oferece ações de texto.'),
      ),
    );
    return;
  }
  acoes.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  final escolhida = await showModalBottomSheet<ProcessTextAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(c).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final a in acoes)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(a.label),
                onTap: () => Navigator.pop(c, a),
              ),
          ],
        ),
      ),
    ),
  );
  if (escolhida == null) return;
  try {
    await servico.processTextAction(escolhida.id, texto, true);
  } on PlatformException catch (e) {
    msg.showSnackBar(
      SnackBar(content: Text('Não foi possível abrir: ${e.message ?? e}')),
    );
  }
}
