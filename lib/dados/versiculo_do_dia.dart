import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Uma passagem do calendário do versículo do dia.
class ReferenciaDoDia {
  const ReferenciaDoDia({
    required this.dia,
    required this.livro,
    required this.capitulo,
    required this.versiculo,
    required this.ate,
  });

  /// Dia do ano, de 1 a 366.
  final int dia;

  /// De 1 (Gênesis) a 66 (Apocalipse).
  final int livro;

  final int capitulo;

  /// Primeiro versículo da passagem.
  final int versiculo;

  /// Último versículo. Igual a [versiculo] quando a passagem é de um só.
  final int ate;

  factory ReferenciaDoDia.doMapa(Map<String, Object?> m) => ReferenciaDoDia(
    dia: m['dia']! as int,
    livro: m['livro']! as int,
    capitulo: m['capitulo']! as int,
    versiculo: m['versiculo']! as int,
    ate: m['ate']! as int,
  );
}

/// Calendário do versículo do dia, o mesmo do Louvor JA.
///
/// O arquivo em `assets/versiculo_do_dia.json` guarda só as **referências**
/// (livro, capítulo e versículos de cada um dos 366 dias), nunca o texto.
/// Quem escolheu as passagens foi a YouVersion; o calendário foi buscado uma
/// vez no PC pelo `ferramentas/votd.py` do Louvor JA. O texto sai do banco
/// offline, na tradução que a pessoa estiver usando: sem rede e sem chave de
/// API dentro do app.
class VersiculoDoDia {
  const VersiculoDoDia._();

  static const _asset = 'assets/versiculo_do_dia.json';

  static Map<int, ReferenciaDoDia>? _calendario;

  /// Dia do ano de [d], de 1 a 366. Só a data conta: a hora erraria um dia
  /// nas viradas de horário de verão.
  static int diaDoAno(DateTime d) =>
      DateTime.utc(
        d.year,
        d.month,
        d.day,
      ).difference(DateTime.utc(d.year, 1, 1)).inDays +
      1;

  static Future<Map<int, ReferenciaDoDia>> _carregar() async {
    final pronto = _calendario;
    if (pronto != null) return pronto;

    var mapa = <int, ReferenciaDoDia>{};
    try {
      final bruto = jsonDecode(await rootBundle.loadString(_asset));
      final dias = (bruto as Map<String, Object?>)['dias'] as List<Object?>;
      mapa = {
        for (final d in dias.cast<Map<String, Object?>>())
          d['dia']! as int: ReferenciaDoDia.doMapa(d),
      };
    } catch (e) {
      // Sem o calendário, o versículo do dia simplesmente não aparece.
      debugPrint('versiculo do dia indisponivel: $e');
    }

    _calendario = mapa;
    return mapa;
  }

  static Future<ReferenciaDoDia?> de(DateTime data) async =>
      (await _carregar())[diaDoAno(data)];

  static Future<ReferenciaDoDia?> hoje() => de(DateTime.now());
}
