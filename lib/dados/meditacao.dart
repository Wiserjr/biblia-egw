import 'guia_biblioteca.dart';

/// As meditações diárias de Ellen G. White na biblioteca (uma por dia do
/// ano, com a data no título do capítulo: "Luz para meu caminho, 1 de
/// Janeiro"). Ids da tabela `obra` do estudo.db.
const obrasMeditacao = [
  75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, //
];

const _meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', //
  'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

final _data = RegExp(
  r'[,.]?\s*(\d{1,2})[ºo°]?\s+de\s+([a-zç]+)\s*\.?$',
  caseSensitive: false,
);

/// Dia e mês da data no fim do título, ou null.
({int dia, int mes})? dataDoTitulo(String titulo) {
  final m = _data.firstMatch(titulo.trim());
  if (m == null) return null;
  final mes = _meses.indexOf(m.group(2)!.toLowerCase()) + 1;
  final dia = int.parse(m.group(1)!);
  if (mes == 0 || dia < 1 || dia > 31) return null;
  return (dia: dia, mes: mes);
}

/// O título sem a data do fim: "Luz para meu caminho".
String tituloSemData(String titulo) {
  final m = _data.firstMatch(titulo.trim());
  if (m == null || dataDoTitulo(titulo) == null) return titulo.trim();
  return titulo.trim().substring(0, m.start).trim();
}

/// A meditação de [dia] entre os [capitulos] de um livro de meditações.
///
/// Vale o capítulo com a data de hoje no título. Se nenhum tiver (título
/// trocado no sumário do PDF, 29 de fevereiro num livro de 365 dias), fica o
/// que vem depois do capítulo da véspera, procurando até uma semana atrás.
CapituloObra? meditacaoDoDia(List<CapituloObra> capitulos, DateTime dia) {
  if (capitulos.isEmpty) return null;
  final ordem = [...capitulos]..sort((a, b) => a.pagina.compareTo(b.pagina));
  // Um título com o mês errado ("O Consolador, 2 de Fevereiro" no lugar de
  // 2 de janeiro) repete uma data: vale o capítulo mais perto de onde a data
  // cairia no livro.
  int? achar(DateTime d) {
    final doAno = DateTime.utc(
      d.year,
      d.month,
      d.day,
    ).difference(DateTime.utc(d.year)).inDays;
    final esperado = doAno * ordem.length / 366;
    int? melhor;
    for (var i = 0; i < ordem.length; i++) {
      final data = dataDoTitulo(ordem[i].titulo);
      if (data == null || data.dia != d.day || data.mes != d.month) continue;
      if (melhor == null || (i - esperado).abs() < (melhor - esperado).abs()) {
        melhor = i;
      }
    }
    return melhor;
  }

  final hoje = achar(dia);
  if (hoje != null) return ordem[hoje];
  for (var atras = 1; atras <= 7; atras++) {
    final antes = achar(DateTime(dia.year, dia.month, dia.day - atras));
    if (antes != null) {
      final i = antes + atras;
      return ordem[i < ordem.length ? i : ordem.length - 1];
    }
  }
  return null;
}
