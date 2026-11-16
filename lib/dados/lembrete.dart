import 'dart:io';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdados;
import 'package:timezone/timezone.dart' as tz;

import 'ajustes.dart';
import 'biblia.dart';
import 'plano.dart';
import 'referencias.dart';
import 'versiculo_do_dia.dart';

/// Nome da porta pela qual um botão da notificação "Lendo..." (Pausar,
/// Parar), tocado com o app em segundo plano, chega à voz.
const portaControleVoz = 'biblia_controle_voz';

/// Botão de uma notificação tocado com o app fora da tela. O plugin roda
/// isto num isolate à parte; se o app estiver aberto (a voz lendo), o pedido
/// segue pela porta [portaControleVoz].
@pragma('vm:entry-point')
void aoResponderNotificacaoNoFundo(NotificationResponse r) {
  final acao = r.actionId;
  if (acao == null) return;
  IsolateNameServer.lookupPortByName(portaControleVoz)?.send(acao);
}

/// Lembrete diário do plano de leitura, na hora que a pessoa escolher.
///
/// No Android é uma notificação que se repete todo dia sozinha. No Windows
/// não existe notificação repetida, então o app marca os próximos
/// [_diasWindows] dias a cada abertura; quem passar mais que isso sem abrir o
/// app no PC deixa de receber o lembrete ali até abrir de novo.
///
/// A hora é guardada em UTC, sem fuso: o Brasil não tem horário de verão
/// desde 2019, então "7h daqui" é sempre a mesma hora UTC. Em país com
/// horário de verão o lembrete adiantaria ou atrasaria uma hora nessa época.
class Lembrete {
  Lembrete._();
  static final Lembrete instancia = Lembrete._();

  static bool get suportado =>
      !kIsWeb && (Platform.isAndroid || Platform.isWindows);

  static const _diasWindows = 7;
  static const _canal = 'lembrete_plano';
  static const _canalVersiculo = 'versiculo_do_dia';

  /// Avisos do versículo do dia marcados à frente (ids 101 em diante): cada
  /// um com o texto do seu dia, renovados a cada abertura do app.
  static const _diasVersiculo = 14;
  static const _idVersiculo = 101;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _iniciado = false;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// Recebe o botão tocado numa notificação com o app aberto ("pausar",
  /// "parar" da voz).
  void Function(String acao)? aoAcao;

  Future<bool> iniciar() => _iniciar();

  Future<bool> _iniciar() async {
    if (_iniciado) return true;
    tzdados.initializeTimeZones();
    final ok = await _plugin.initialize(
      onDidReceiveNotificationResponse: (r) {
        final acao = r.actionId;
        if (acao != null) aoAcao?.call(acao);
      },
      onDidReceiveBackgroundNotificationResponse: aoResponderNotificacaoNoFundo,
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notificacao'),
        windows: WindowsInitializationSettings(
          appName: 'Bíblia de Estudo',
          appUserModelId: 'br.com.wisejr.BibliaDeEstudo',
          guid: '6f1d7c52-3b8e-4e0a-9a51-2c9d4b7e8f30',
        ),
      ),
    );
    _iniciado = ok ?? false;
    return _iniciado;
  }

  /// Pede ao Android 13+ a permissão de mostrar notificações. Devolve false
  /// se a pessoa negar.
  Future<bool> pedirPermissao() async {
    if (!suportado || !await _iniciar()) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  /// Refaz o agendamento conforme os ajustes: chamado ao abrir o app e
  /// sempre que o lembrete, a hora ou o plano mudam.
  Future<void> atualizar() async {
    if (!suportado) return;
    try {
      if (!await _iniciar()) return;
      await _atualizarVersiculoDoDia();
      for (var id = 1; id <= _diasWindows; id++) {
        await _plugin.cancel(id: id);
      }
      final aj = Ajustes.instancia;
      final plano = PlanoLeitura.porId(aj.plano);
      if (!aj.lembrete || plano == null) return;

      const detalhes = NotificationDetails(
        android: AndroidNotificationDetails(
          _canal,
          'Lembrete do plano de leitura',
          channelDescription: 'Um aviso por dia, na hora escolhida.',
        ),
      );
      final agora = DateTime.now();
      final minutos = aj.lembreteMinutos;
      DateTime noDia(DateTime d) =>
          DateTime(d.year, d.month, d.day, minutos ~/ 60, minutos % 60);
      var proximo = noDia(agora);
      if (!proximo.isAfter(agora)) {
        proximo = noDia(agora.add(const Duration(days: 1)));
      }

      if (Platform.isAndroid) {
        await _plugin.zonedSchedule(
          id: 1,
          title: 'Hora da leitura',
          body: '${plano.nome}: abra a leitura de hoje.',
          scheduledDate: tz.TZDateTime.from(proximo, tz.UTC),
          notificationDetails: detalhes,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        return;
      }

      // Windows: um aviso por dia, já com o capítulo do dia.
      for (var i = 0; i < _diasWindows; i++) {
        final quando = noDia(proximo.add(Duration(days: i)));
        await _plugin.zonedSchedule(
          id: i + 1,
          title: 'Hora da leitura',
          body: _texto(plano, quando),
          scheduledDate: tz.TZDateTime.from(quando, tz.UTC),
          notificationDetails: detalhes,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      // Um lembrete que falha não pode impedir o app de abrir.
      debugPrint('Lembrete: $e');
    }
  }

  /// Marca os avisos do versículo do dia dos próximos [_diasVersiculo] dias,
  /// já com o texto na tradução escolhida (o Android não muda o texto de uma
  /// notificação que se repete). Quem passar duas semanas sem abrir o app
  /// deixa de receber o aviso até abrir de novo.
  Future<void> _atualizarVersiculoDoDia() async {
    for (var i = 0; i < _diasVersiculo; i++) {
      await _plugin.cancel(id: _idVersiculo + i);
    }
    final aj = Ajustes.instancia;
    if (!aj.avisoVersiculoDoDia) return;
    final versoes = await Biblia.instancia.versoes();
    if (versoes.isEmpty) return;
    final versao = versoes
        .firstWhere((v) => v.id == aj.versao, orElse: () => versoes.first)
        .id;

    const detalhes = NotificationDetails(
      android: AndroidNotificationDetails(
        _canalVersiculo,
        'Versículo do dia',
        channelDescription: 'O versículo do dia, na hora escolhida.',
        styleInformation: BigTextStyleInformation(''),
      ),
    );
    final agora = DateTime.now();
    final minutos = aj.avisoVersiculoMinutos;
    var primeiro = DateTime(
      agora.year,
      agora.month,
      agora.day,
      minutos ~/ 60,
      minutos % 60,
    );
    if (!primeiro.isAfter(agora)) {
      primeiro = primeiro.add(const Duration(days: 1));
    }
    for (var i = 0; i < _diasVersiculo; i++) {
      final d = primeiro.add(Duration(days: i));
      final quando = DateTime(
        d.year,
        d.month,
        d.day,
        minutos ~/ 60,
        minutos % 60,
      );
      final r = await VersiculoDoDia.de(quando);
      if (r == null) continue;
      final caps = await Biblia.instancia.capitulo(versao, r.livro, r.capitulo);
      final texto = textoAvisoVersiculo(
        r,
        caps.map((v) => (v.numero, v.texto)),
      );
      if (texto == null) continue;
      await _plugin.zonedSchedule(
        id: _idVersiculo + i,
        title: texto.titulo,
        body: texto.corpo,
        scheduledDate: tz.TZDateTime.from(quando, tz.UTC),
        notificationDetails: detalhes,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static String _texto(PlanoLeitura plano, DateTime dia) {
    if (!plano.porData) return '${plano.nome}: abra a leitura de hoje.';
    final d = plano.diaDe(dia);
    return '${plano.nome}: ${descreverLeitura(plano.leituraDoDia(d))}.';
  }
}

/// Título ("Versículo do dia · João 3:16") e texto do aviso do versículo do
/// dia, a partir dos versículos do capítulo; null se o capítulo não tiver os
/// versículos da passagem.
@visibleForTesting
({String titulo, String corpo})? textoAvisoVersiculo(
  ReferenciaDoDia r,
  Iterable<(int, String)> versiculos,
) {
  final partes = [
    for (final (n, t) in versiculos)
      if (n >= r.versiculo && n <= r.ate)
        t
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
  ];
  if (partes.isEmpty) return null;
  final ref =
      '${Referencias.nome(r.livro)} ${r.capitulo}:${r.versiculo}'
      '${r.ate > r.versiculo ? '-${r.ate}' : ''}';
  return (titulo: 'Versículo do dia · $ref', corpo: partes.join(' '));
}
