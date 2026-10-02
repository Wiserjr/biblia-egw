import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'biblia.dart';
import 'modelos.dart';
import 'referencias.dart';

/// Leitura do capítulo em voz alta, com a voz do próprio aparelho (funciona
/// sem internet quando a voz em português está instalada).
///
/// Lê versículo a versículo, e [versiculo] diz qual está sendo lido, para o
/// leitor acompanhar.
class LeituraVoz extends ChangeNotifier {
  LeituraVoz._();
  static final LeituraVoz instancia = LeituraVoz._();

  static bool get suportada => Platform.isAndroid || Platform.isWindows;

  FlutterTts? _tts;

  /// Capítulo em leitura, ou null se parada.
  Posicao? get capitulo => _capitulo;
  Posicao? _capitulo;

  /// Versículo sendo lido agora (0 enquanto anuncia o capítulo).
  int? get versiculo => _versiculo;
  int? _versiculo;

  bool get lendo => _capitulo != null;

  /// Incrementado a cada início e parada: uma leitura antiga que ainda está
  /// no meio do laço percebe que foi substituída e para.
  int _rodada = 0;

  Future<FlutterTts> _motor() async {
    final existente = _tts;
    if (existente != null) return existente;
    final tts = FlutterTts();
    await tts.awaitSpeakCompletion(true);
    await tts.setLanguage('pt-BR');
    return _tts = tts;
  }

  /// Lê o capítulo inteiro na tradução [versaoId]. Termina sozinha no fim do
  /// capítulo, ou quando [parar] é chamada.
  Future<void> ler(int versaoId, int livro, int cap) async {
    await parar();
    final rodada = ++_rodada;
    _capitulo = Posicao(livro, cap);
    _versiculo = 0;
    notifyListeners();
    try {
      final tts = await _motor();
      final versiculos = await Biblia.instancia.capitulo(versaoId, livro, cap);
      if (rodada != _rodada) return;
      await tts.speak('${Referencias.nome(livro)}, capítulo $cap.');
      for (final v in versiculos) {
        if (rodada != _rodada) return;
        _versiculo = v.numero;
        notifyListeners();
        await tts.speak(textoFalado(v.texto));
      }
    } finally {
      if (rodada == _rodada) {
        _capitulo = null;
        _versiculo = null;
        notifyListeners();
      }
    }
  }

  Future<void> parar() async {
    if (!lendo) return;
    _rodada++;
    _capitulo = null;
    _versiculo = null;
    notifyListeners();
    await _tts?.stop();
  }
}

/// O texto do versículo sem a marcação (`<J>`, `<i>`), que a voz leria.
@visibleForTesting
String textoFalado(String texto) => texto
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
