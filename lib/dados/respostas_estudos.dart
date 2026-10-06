import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Respostas separadas por edição e campo; mantém o PDF original intacto.
class RespostasEstudos {
  RespostasEstudos(this.prefs, this.hash);
  final SharedPreferences prefs;
  final String hash;
  String get prefixo => 'estudo_interativo_${hash}_';

  String texto(Map campo) =>
      prefs.getString('$prefixo${campo['id']}') ??
      (campo['legadoResposta'] != null
          ? prefs.getString(
              'piloto_${hash}_licao1_resposta_${campo['legadoResposta']}',
            )
          : null) ??
      '';

  List<int> escolhas(Map campo) {
    final salvo = prefs.getString('$prefixo${campo['id']}');
    if (salvo != null) return (jsonDecode(salvo) as List).cast<int>();
    final antigo = campo['legadoEscolha'] == null
        ? null
        : prefs.getInt(
            'piloto_${hash}_licao1_escolha_${campo['legadoEscolha']}',
          );
    return antigo == null ? [] : [antigo];
  }

  Future<void> salvarTexto(Map campo, String valor) async {
    if (!await prefs.setString('$prefixo${campo['id']}', valor)) {
      throw StateError('Não foi possível salvar a resposta.');
    }
  }

  Future<void> salvarEscolhas(Map campo, List<int> valor) async {
    if (!await prefs.setString('$prefixo${campo['id']}', jsonEncode(valor))) {
      throw StateError('Não foi possível salvar as alternativas.');
    }
  }

  bool respondida(Map pergunta) => (pergunta['respostas'] as List).any(
    (c) => c['tipo'] == 'alternativas'
        ? escolhas(c as Map).isNotEmpty
        : texto(c as Map).trim().isNotEmpty,
  );

  bool concluida(int numero) =>
      prefs.getBool('${prefixo}licao_${numero}_concluida') ??
      (numero == 1 ? prefs.getBool('piloto_${hash}_licao1_concluida') : null) ??
      false;

  Future<void> concluir(int numero, bool valor) async {
    if (!await prefs.setBool('${prefixo}licao_${numero}_concluida', valor)) {
      throw StateError('Não foi possível salvar a conclusão da lição.');
    }
  }

  Map<String, Object?> exportar() => {
    for (final chave in prefs.getKeys())
      if (chave.startsWith(prefixo) ||
          chave.startsWith('piloto_${hash}_') ||
          chave.startsWith('estudo_pdf_${hash}_'))
        chave: prefs.get(chave),
  };
}
