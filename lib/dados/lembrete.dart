import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdados;
import 'package:timezone/timezone.dart' as tz;

import 'ajustes.dart';
import 'plano.dart';

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

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _iniciado = false;

  Future<bool> _iniciar() async {
    if (_iniciado) return true;
    tzdados.initializeTimeZones();
    final ok = await _plugin.initialize(
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

  static String _texto(PlanoLeitura plano, DateTime dia) {
    if (!plano.porData) return '${plano.nome}: abra a leitura de hoje.';
    final d = plano.diaDe(dia);
    return '${plano.nome}: ${descreverLeitura(plano.leituraDoDia(d))}.';
  }
}
