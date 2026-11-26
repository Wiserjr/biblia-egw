import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'ajustes.dart';
import 'biblia.dart';
import 'lembrete.dart';
import 'modelos.dart';
import 'referencias.dart';
import 'vozes.dart';

/// Leitura do capítulo em voz alta, com a voz do próprio aparelho (funciona
/// sem internet quando a voz em português está instalada).
///
/// Lê versículo a versículo, e [versiculo] diz qual está sendo lido, para o
/// leitor acompanhar. Com [Ajustes.vozContinua], ao fim do capítulo segue
/// para o próximo. Dá para pausar, mudar a velocidade e marcar um timer para
/// dormir. No Android, enquanto lê, uma notificação "Lendo..." (um serviço
/// em primeiro plano) mantém a voz com a tela apagada, com Pausar e Parar.
class LeituraVoz extends ChangeNotifier {
  LeituraVoz._();
  static final LeituraVoz instancia = LeituraVoz._();

  static bool get suportada => Platform.isAndroid || Platform.isWindows;

  FlutterTts? _tts;

  /// Capítulo em leitura (ou pausado), ou null se parada.
  Posicao? get capitulo => _capitulo;
  Posicao? _capitulo;

  /// Versículo sendo lido agora (0 enquanto anuncia o capítulo).
  int? get versiculo => _versiculo;
  int? _versiculo;

  bool get lendo => _capitulo != null;

  /// Parada no meio do capítulo, pronta para [continuar].
  bool get pausada => _pausada;
  bool _pausada = false;

  int? _versao;

  /// Se está lendo um trecho avulso (ver [falar]).
  bool get falandoTrecho => _falandoTrecho;
  bool _falandoTrecho = false;

  /// Incrementado a cada início e parada: uma leitura antiga que ainda está
  /// no meio do laço percebe que foi substituída e para.
  int _rodada = 0;

  // --- timer para dormir ---

  Timer? _timer;

  /// Quando o timer para dormir vai parar a voz, ou null.
  DateTime? get timerAte => _timerAte;
  DateTime? _timerAte;

  /// O timer para no fim do capítulo em leitura.
  bool get pararNoFimDoCapitulo => _pararNoFim;
  bool _pararNoFim = false;

  bool get timerLigado => _timerAte != null || _pararNoFim;

  /// Para a voz daqui a [duracao]; null desliga o timer.
  void marcarTimer(Duration? duracao) {
    _timer?.cancel();
    _timer = null;
    _timerAte = null;
    _pararNoFim = false;
    if (duracao != null) {
      _timerAte = DateTime.now().add(duracao);
      _timer = Timer(duracao, () {
        _timer = null;
        _timerAte = null;
        parar();
      });
    }
    notifyListeners();
  }

  /// O timer para dormir para a voz no fim do capítulo.
  void pararNoFim() {
    marcarTimer(null);
    _pararNoFim = true;
    notifyListeners();
  }

  // --- velocidade ---

  static const velocidades = [0.75, 1.0, 1.25, 1.5, 2.0];

  /// Muda a velocidade; vale a partir do próximo versículo.
  Future<void> mudarVelocidade(double v) async {
    Ajustes.instancia.velocidadeVoz = v;
    notifyListeners();
    await _tts?.setSpeechRate(taxaDaVelocidade(v));
  }

  Future<FlutterTts> _motor() async {
    final existente = _tts;
    if (existente != null) return existente;
    final tts = FlutterTts();
    await tts.awaitSpeakCompletion(true);
    await tts.setLanguage('pt-BR');
    await tts.setSpeechRate(taxaDaVelocidade(Ajustes.instancia.velocidadeVoz));
    await _aplicarVoz(tts);
    return _tts = tts;
  }

  // --- voz ---

  /// As vozes em português do aparelho, a melhor primeiro.
  Future<List<VozTts>> vozes() async {
    try {
      final tts = await _motor();
      return vozesEmPortugues(await tts.getVoices);
    } catch (_) {
      return const [];
    }
  }

  /// Passa a ler com [voz] (null volta à padrão do aparelho); vale a partir
  /// do próximo versículo.
  Future<void> escolherVoz(VozTts? voz) async {
    Ajustes.instancia.vozEscolhida = voz == null ? null : (voz.nome, voz.local);
    notifyListeners();
    final tts = _tts;
    if (tts != null) await _aplicarVoz(tts);
  }

  /// Lê a frase de amostra com [voz], que fica escolhida.
  Future<void> ouvirAmostra(VozTts? voz) async {
    await escolherVoz(voz);
    await falar(amostraDeVoz);
  }

  Future<void> _aplicarVoz(FlutterTts tts) async {
    final v = Ajustes.instancia.vozEscolhida;
    try {
      if (v != null) {
        await tts.setVoice({'name': v.$1, 'locale': v.$2});
        return;
      }
      await tts.clearVoice();
    } catch (_) {
      // O Windows não tem clearVoice: escolher o idioma volta à voz padrão.
    }
    if (v == null) await tts.setLanguage('pt-BR');
  }

  /// Lê o capítulo na tradução [versaoId], do versículo [aPartirDe] em
  /// diante (do começo, se null). Com [Ajustes.vozContinua], segue pelos
  /// capítulos seguintes; senão termina no fim do capítulo. Para quando
  /// [parar] ou [pausar] é chamada.
  Future<void> ler(int versaoId, int livro, int cap, {int? aPartirDe}) async {
    await _interromper();
    final rodada = ++_rodada;
    _versao = versaoId;
    _pausada = false;
    _capitulo = Posicao(livro, cap);
    _versiculo = 0;
    notifyListeners();
    _escutarNotificacao();
    var terminou = false;
    try {
      final tts = await _motor();
      await tts.setSpeechRate(
        taxaDaVelocidade(Ajustes.instancia.velocidadeVoz),
      );
      var l = livro;
      var c = cap;
      var desde = aPartirDe;
      while (true) {
        if (rodada != _rodada) return;
        _capitulo = Posicao(l, c);
        _versiculo = 0;
        notifyListeners();
        await _mostrarNotificacao();
        final versiculos = await Biblia.instancia.capitulo(versaoId, l, c);
        if (rodada != _rodada) return;
        await tts.speak(
          desde == null
              ? '${Referencias.nome(l)}, capítulo $c.'
              : '${Referencias.nome(l)} $c, versículo $desde.',
        );
        for (final v in versiculos) {
          if (rodada != _rodada) return;
          if (desde != null && v.numero < desde) continue;
          _versiculo = v.numero;
          notifyListeners();
          await tts.speak(textoFalado(v.texto));
        }
        if (rodada != _rodada) return;
        final prox = proximoCapitulo(l, c);
        if (!Ajustes.instancia.vozContinua || _pararNoFim || prox == null) {
          terminou = true;
          return;
        }
        (l, c) = (prox.livro, prox.capitulo);
        desde = null;
      }
    } finally {
      if (rodada == _rodada && (terminou || !_pausada)) {
        _limpar();
      }
    }
  }

  /// Para no versículo em leitura, guardando o lugar para [continuar].
  Future<void> pausar() async {
    if (!lendo || _pausada) return;
    _rodada++;
    _pausada = true;
    notifyListeners();
    await _tts?.stop();
    await _mostrarNotificacao();
  }

  /// Continua a leitura pausada a partir do versículo em que parou.
  Future<void> continuar() async {
    final cap = _capitulo;
    final versao = _versao;
    if (!_pausada || cap == null || versao == null) return;
    final v = _versiculo;
    await ler(
      versao,
      cap.livro,
      cap.capitulo,
      aPartirDe: v == null || v < 1 ? null : v,
    );
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
    _limpar();
    await _tts?.stop();
  }

  /// Interrompe o que estiver lendo sem desligar o timer (que vale para a
  /// leitura nova também).
  Future<void> _interromper() async {
    _rodada++;
    _falandoTrecho = false;
    await _tts?.stop();
  }

  void _limpar() {
    _capitulo = null;
    _versiculo = null;
    _pausada = false;
    _falandoTrecho = false;
    _timer?.cancel();
    _timer = null;
    _timerAte = null;
    _pararNoFim = false;
    notifyListeners();
    _esconderNotificacao();
  }

  // --- notificação "Lendo..." (Android) ---

  static const _idNotificacao = 900;
  static const _canal = 'ouvir_capitulo';
  ReceivePort? _porta;

  /// Liga os botões da notificação: com o app em segundo plano eles chegam
  /// pela porta [portaControleVoz]; com o app aberto, por [Lembrete.aoAcao].
  void _escutarNotificacao() {
    if (!Platform.isAndroid || _porta != null) return;
    final porta = ReceivePort();
    IsolateNameServer.removePortNameMapping(portaControleVoz);
    IsolateNameServer.registerPortWithName(porta.sendPort, portaControleVoz);
    porta.listen((m) {
      if (m is String) acao(m);
    });
    _porta = porta;
    Lembrete.instancia.aoAcao = acao;
  }

  /// Botão da notificação: "pausar", "continuar" ou "parar".
  void acao(String a) {
    switch (a) {
      case 'pausar':
        pausar();
      case 'continuar':
        continuar();
      case 'parar':
        parar();
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => Lembrete
      .instancia
      .plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  bool _servicoLigado = false;

  Future<void> _mostrarNotificacao() async {
    final cap = _capitulo;
    if (!Platform.isAndroid || cap == null) return;
    try {
      if (!await Lembrete.instancia.iniciar()) return;
      final android = _android;
      if (android == null) return;
      final detalhes = AndroidNotificationDetails(
        _canal,
        'Ouvir o capítulo',
        channelDescription:
            'Aparece enquanto a voz lê, com os botões Pausar e Parar.',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        onlyAlertOnce: true,
        showWhen: false,
        playSound: false,
        enableVibration: false,
        actions: [
          AndroidNotificationAction(
            _pausada ? 'continuar' : 'pausar',
            _pausada ? 'Continuar' : 'Pausar',
            cancelNotification: false,
          ),
          const AndroidNotificationAction('parar', 'Parar'),
        ],
      );
      final titulo =
          '${_pausada ? 'Pausado' : 'Lendo'}: '
          '${Referencias.nome(cap.livro)} ${cap.capitulo}';
      if (_servicoLigado) {
        await Lembrete.instancia.plugin.show(
          id: _idNotificacao,
          title: titulo,
          body: 'Bíblia de Estudo',
          notificationDetails: NotificationDetails(android: detalhes),
        );
      } else {
        await android.startForegroundService(
          id: _idNotificacao,
          title: titulo,
          body: 'Bíblia de Estudo',
          notificationDetails: detalhes,
          startType: AndroidServiceStartType.startNotSticky,
          foregroundServiceTypes: {
            AndroidServiceForegroundType.foregroundServiceTypeMediaPlayback,
          },
        );
        _servicoLigado = true;
      }
    } catch (e) {
      // Sem a notificação a voz continua, só não segue com a tela apagada.
      debugPrint('Notificacao da voz: $e');
    }
  }

  Future<void> _esconderNotificacao() async {
    if (!Platform.isAndroid || !_servicoLigado) return;
    _servicoLigado = false;
    try {
      await _android?.stopForegroundService();
      await Lembrete.instancia.plugin.cancel(id: _idNotificacao);
    } catch (e) {
      debugPrint('Notificacao da voz: $e');
    }
  }
}

/// O capítulo depois de [livro] [cap], na ordem da Bíblia; null depois de
/// Apocalipse 22.
Posicao? proximoCapitulo(int livro, int cap) {
  if (cap < Referencias.capitulos[livro - 1]) return Posicao(livro, cap + 1);
  if (livro < 66) return Posicao(livro + 1, 1);
  return null;
}

/// A taxa que o flutter_tts recebe para a [velocidade] (1 = normal). No
/// Android e no Windows o plugin trata 0,5 como a fala normal: no Android ele
/// dobra o valor; no Windows soma 0,5.
@visibleForTesting
double taxaDaVelocidade(double velocidade) {
  final v = velocidade.clamp(0.5, 2.0);
  if (!kIsWeb && Platform.isWindows) return (v - 0.5).clamp(0.0, 1.5);
  return v / 2;
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
