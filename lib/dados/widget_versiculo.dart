import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'ajustes.dart';
import 'biblia.dart';
import 'caminhada.dart';
import 'lembrete.dart';
import 'versiculo_do_dia.dart';

/// O widget do versículo do dia na tela inicial do Android
/// (android/app/src/main/kotlin/.../VersiculoWidget.kt).
///
/// O widget não abre o banco da Bíblia: a cada abertura do app, o texto dos
/// próximos [dias] dias vai para ele, na tradução escolhida, e ele mostra o
/// do dia. Quem passar duas semanas sem abrir o app vê um convite para abrir.
class WidgetVersiculo {
  const WidgetVersiculo._();

  static const dias = 14;
  static const _nome = 'br.com.wisejr.bibliaestudo.VersiculoWidget';

  /// Endereço que o toque no widget abre: a tela Hoje.
  static final toque = Uri.parse('bibliaestudo://hoje');

  static bool get suportado => !kIsWeb && Platform.isAndroid;

  /// Grava os versículos dos próximos dias e redesenha o widget.
  static Future<void> atualizar() async {
    if (!suportado) return;
    try {
      final versoes = await Biblia.instancia.versoes();
      if (versoes.isEmpty) return;
      final versao = versoes.firstWhere(
        (v) => v.id == Ajustes.instancia.versao,
        orElse: () => versoes.first,
      );
      final hoje = DateTime.now();
      final porDia = <String, Object>{};
      for (var i = 0; i < dias; i++) {
        final d = DateTime(hoje.year, hoje.month, hoje.day + i);
        final r = await VersiculoDoDia.de(d);
        if (r == null) continue;
        final caps = await Biblia.instancia.capitulo(
          versao.id,
          r.livro,
          r.capitulo,
        );
        final t = textoAvisoVersiculo(r, caps.map((v) => (v.numero, v.texto)));
        if (t == null) continue;
        porDia[diaIso(d)] = {
          'ref':
              '${t.titulo.replaceFirst('Versículo do dia · ', '')} '
              '(${versao.sigla})',
          'texto': t.corpo,
        };
      }
      await HomeWidget.saveWidgetData<String>('versiculos', jsonEncode(porDia));
      await HomeWidget.updateWidget(qualifiedAndroidName: _nome);
    } catch (e) {
      // Sem widget na tela, ou plugin indisponível: nada a fazer.
      debugPrint('widget do versiculo: $e');
    }
  }

  /// Chama [abrirHoje] quando o app abre (ou volta) por um toque no widget.
  static void aoTocar(void Function() abrirHoje) {
    if (!suportado) return;
    void ver(Uri? uri) {
      if (uri != null && uri.scheme == toque.scheme) abrirHoje();
    }

    HomeWidget.initiallyLaunchedFromHomeWidget().then(ver, onError: (_) {});
    HomeWidget.widgetClicked.listen(ver, onError: (_) {});
  }
}
