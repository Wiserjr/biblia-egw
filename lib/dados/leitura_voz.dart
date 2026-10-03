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

  /// Se está lendo um trecho avulso (ver [falar]).
  bool get falandoTrecho => _falandoTrecho;
  bool _falandoTrecho = false;

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

  /// Lê o capítulo na tradução [versaoId], do versículo [aPartirDe] em
  /// diante (do começo, se null). Termina sozinha no fim do capítulo, ou
  /// quando [parar] é chamada.
  Future<void> ler(int versaoId, int livro, int cap, {int? aPartirDe}) async {
    await parar();
    final rodada = ++_rodada;
    _capitulo = Posicao(livro, cap);
    _versiculo = 0;
    notifyListeners();
    try {
      final tts = await _motor();
      final versiculos = await Biblia.instancia.capitulo(versaoId, livro, cap);
      if (rodada != _rodada) return;
      await tts.speak(
        aPartirDe == null
            ? '${Referencias.nome(livro)}, capítulo $cap.'
            : '${Referencias.nome(livro)} $cap, versículo $aPartirDe.',
      );
      for (final v in versiculos) {
        if (rodada != _rodada) return;
        if (aPartirDe != null && v.numero < aPartirDe) continue;
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

  /// Lê um trecho avulso (o que foi selecionado num livro, por exemplo).
  Future<void> falar(String texto) async {
    await parar();
    final rodada = ++_rodada;
    _falandoTrecho = true;
    notifyListeners();
    try {
      final tts = await _motor();
      for (final parte in partesFaladas(textoFalado(texto))) {
        if (rodada != _rodada) return;
        await tts.speak(parte);
      }
    } finally {
      if (rodada == _rodada) {
        _falandoTrecho = false;
        notifyListeners();
      }
    }
  }

  Future<void> parar() async {
    if (!lendo && !_falandoTrecho) return;
    _rodada++;
    _capitulo = null;
    _versiculo = null;
    _falandoTrecho = false;
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

/// [texto] em partes de até [max] caracteres, cortadas no fim de uma frase
/// (ou, se não houver, num espaço). O Android recusa falar mais de 4.000
/// caracteres de uma vez, e o flutter_tts nunca avisa que terminou o que foi
/// recusado.
@visibleForTesting
List<String> partesFaladas(String texto, {int max = 3500}) {
  final partes = <String>[];
  var resto = texto.trim();
  while (resto.length > max) {
    final janela = resto.substring(0, max);
    var corte = janela.lastIndexOf(RegExp(r'[.!?;:]\s'));
    if (corte >= max ~/ 2) {
      corte += 1; // inclui a pontuação
    } else {
      corte = janela.lastIndexOf(' ');
      if (corte <= 0) corte = max;
    }
    partes.add(resto.substring(0, corte).trim());
    resto = resto.substring(corte).trim();
  }
  if (resto.isNotEmpty) partes.add(resto);
  return partes;
}
