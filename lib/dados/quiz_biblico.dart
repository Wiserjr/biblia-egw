import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

class PerguntaQuiz {
  PerguntaQuiz(
    this.id,
    this.texto,
    this.resposta,
    this.nivel,
    this.alternativas,
    this.referencias,
  );
  final String id, texto, resposta;
  final int nivel;
  final List<String> alternativas;
  final List<List<int>> referencias;
  Map<String, dynamic> toJson() => {
    'id': id,
    'texto': texto,
    'resposta': resposta,
    'nivel': nivel,
    'alternativas': alternativas,
    'referencias': referencias,
  };
  factory PerguntaQuiz.fromJson(Map<String, dynamic> j) => PerguntaQuiz(
    j['id'],
    j['texto'],
    j['resposta'],
    j['nivel'],
    List<String>.from(j['alternativas']),
    (j['referencias'] as List).map((r) => List<int>.from(r)).toList(),
  );
}

/// Somente conteúdo textual da cópia pessoal; nunca executa recursos do EPUB.
Map<String, dynamic> importarQuiz(Map<String, dynamic> entrada) {
  final bytes = entrada['bytes'] as Uint8List;
  final indice = entrada['indice'] as Map<String, dynamic>;
  if (bytes.length > 20 * 1024 * 1024 ||
      sha256.convert(bytes).toString() != indice['sha256Epub']) {
    throw const FormatException(
      'Selecione a edição de Curiosidades e Testes Bíblicos usada neste quiz. O arquivo escolhido não corresponde à edição cadastrada.',
    );
  }
  final zip = ZipDecoder().decodeBytes(bytes);
  if (zip.files.fold<int>(0, (n, f) => n + f.size) > 50 * 1024 * 1024) {
    throw const FormatException('O EPUB ultrapassa o limite de importação.');
  }
  final entidades = {
    'nbsp': '160',
    'ndash': '8211',
    'mdash': '8212',
    'lsquo': '8216',
    'rsquo': '8217',
    'ldquo': '8220',
    'rdquo': '8221',
    'hellip': '8230',
    'copy': '169',
  };
  final documentos = <int, XmlDocument>{};
  String texto(XmlElement e) =>
      e.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
  for (var i = 5; i <= 133; i++) {
    final f = zip.findFile('OEBPS/Text/Curiosidades_Miolo-$i.xhtml');
    if (f == null) continue;
    var s = utf8.decode(f.content);
    s = s.replaceAllMapped(
      RegExp(r'&([A-Za-z]+);'),
      (m) => entidades.containsKey(m[1]) ? '&#${entidades[m[1]]};' : m[0]!,
    );
    documentos[i] = XmlDocument.parse(s);
  }
  Map<int, String> numeros(int i) {
    final result = <int, String>{};
    for (final p in documentos[i]!.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'p',
    )) {
      final m = RegExp(r'^(\d+)\.\s*(.*)').firstMatch(texto(p));
      if (m != null) result[int.parse(m[1]!)] = m[2]!;
    }
    return result;
  }

  final perguntas = <Map<String, dynamic>>[];
  for (final item in indice['perguntas'] as List) {
    final cap = item['capitulo'] as int, numero = item['numero'] as int;
    final original = numeros(cap + 53)[numero]!;
    final resposta = original
        .replaceFirst(RegExp(r'\s*\([^)]*\)\.?$'), '')
        .replaceFirst(RegExp(r'\.$'), '')
        .trim();
    final alternativas = <String>[
      resposta,
      ...List<String>.from(item['distratores']),
    ];
    if (alternativas.toSet().length != 4) {
      throw const FormatException('Alternativas inconsistentes.');
    }
    perguntas.add(
      PerguntaQuiz(
        item['id'],
        numeros(cap)[numero]!,
        resposta,
        item['dificuldade'],
        alternativas,
        (item['referencias'] as List).map((r) => List<int>.from(r)).toList(),
      ).toJson(),
    );
  }
  final secoes = <Map<String, dynamic>>[];
  for (final entry in documentos.entries) {
    final i = entry.key;
    if ([31, 63, 84, 116].contains(i)) continue;
    final elementos = entry.value.descendants.whereType<XmlElement>();
    final titulos = elementos
        .where((e) => e.name.local == 'h1')
        .map(texto)
        .where((s) => s.isNotEmpty)
        .toList();
    final paragrafos = elementos
        .where(
          (e) =>
              ['p', 'tr'].contains(e.name.local) &&
              !e.ancestors.whereType<XmlElement>().any(
                (a) =>
                    ['table', 'script', 'style'].contains(a.name.local) &&
                    e.name.local != 'tr',
              ),
        )
        .map(texto)
        .where((s) => s.isNotEmpty)
        .toList();
    secoes.add({
      'titulo': titulos.isEmpty ? 'Seção $i' : titulos.join(' — '),
      'grupo': i < 31
          ? 'Curiosidades'
          : i < 63
          ? 'Testes'
          : i < 84
          ? 'Pesquisas'
          : 'Gabaritos',
      'paragrafos': paragrafos,
    });
  }
  return {
    'hash': indice['sha256Epub'],
    'perguntas': perguntas,
    'secoes': secoes,
  };
}

class PartidaQuiz {
  PartidaQuiz(this.banco, {Random? random}) : random = random ?? Random() {
    proxima();
  }
  final List<PerguntaQuiz> banco;
  final Random random;
  static const premios = [
    1000,
    2000,
    3000,
    5000,
    10000,
    20000,
    30000,
    40000,
    50000,
    75000,
    100000,
    200000,
    300000,
    500000,
    1000000,
  ];
  final usados = <String>{};
  late PerguntaQuiz atual;
  List<String> opcoes = [];
  Set<String> ocultas = {};
  int acertos = 0, pulos = 3, resultado = 0;
  bool terminou = false, respondeu = false, acertou = false, usouMetade = false;
  int get pontos => acertos == 0 ? 0 : premios[acertos - 1];
  int get garantidos => acertos >= 10
      ? premios[9]
      : acertos >= 5
      ? premios[4]
      : 0;
  void proxima() {
    if (terminou) return;
    final candidatos =
        banco
            .where((p) => p.nivel == acertos ~/ 5 + 1 && !usados.contains(p.id))
            .toList()
          ..shuffle(random);
    if (candidatos.isEmpty) throw StateError('Não há perguntas suficientes.');
    atual = candidatos.first;
    usados.add(atual.id);
    opcoes = [...atual.alternativas]..shuffle(random);
    ocultas = {};
    respondeu = false;
  }

  void confirmar(String resposta) {
    if (terminou ||
        respondeu ||
        !opcoes.contains(resposta) ||
        ocultas.contains(resposta)) {
      return;
    }
    respondeu = true;
    acertou = resposta == atual.resposta;
    if (acertou) {
      acertos++;
      if (acertos == 15) {
        terminou = true;
        resultado = pontos;
      }
    } else {
      terminou = true;
      resultado = garantidos;
    }
  }

  void parar() {
    if (!terminou) {
      terminou = true;
      resultado = pontos;
    }
  }

  void pular() {
    if (!terminou && !respondeu && pulos > 0) {
      pulos--;
      proxima();
    }
  }

  void metade() {
    if (terminou || respondeu || usouMetade) return;
    final erradas = opcoes.where((o) => o != atual.resposta).toList()
      ..shuffle(random);
    ocultas = erradas.take(2).toSet();
    usouMetade = true;
  }
}
