import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Texto que chega de outro app no Android: selecionado e enviado por
/// "Abrir na Bíblia" (no menu de seleção de texto) ou compartilhado com a
/// Bíblia de Estudo. Ver MainActivity.kt.
class TextoRecebido {
  const TextoRecebido._();

  static const _canal = MethodChannel('br.com.wisejr.bibliaestudo/texto');

  static bool get suportado => !kIsWeb && Platform.isAndroid;

  /// Chama [aoReceber] com o texto que abriu o app e com cada um que chegar
  /// depois, com o app aberto.
  static void ouvir(void Function(String texto) aoReceber) {
    if (!suportado) return;
    _canal.setMethodCallHandler((c) async {
      final t = c.arguments;
      if (c.method == 'texto' && t is String && t.trim().isNotEmpty) {
        aoReceber(t);
      }
    });
    _canal
        .invokeMethod<String>('inicial')
        .then((t) {
          if (t != null && t.trim().isNotEmpty) aoReceber(t);
        })
        .catchError((Object e) {
          debugPrint('texto recebido: $e');
        });
  }
}
