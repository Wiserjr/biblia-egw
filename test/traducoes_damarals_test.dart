import 'dart:io';

import 'package:archive/archive.dart';
import 'package:biblia_estudo/dados/banco.dart';
import 'package:biblia_estudo/dados/biblia.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporario;
  setUpAll(() async {
    sqfliteFfiInit();
    temporario = await Directory.systemTemp.createTemp('traducoes_');
    final arquivo = File('${temporario.path}/biblia.db');
    await arquivo.writeAsBytes(
      const GZipDecoder().decodeBytes(
        await File('assets/biblia.db.gz').readAsBytes(),
      ),
    );
    Banco.instancia.biblia = await databaseFactoryFfi.openDatabase(
      arquivo.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
  });
  tearDownAll(() async {
    await Banco.instancia.biblia.close();
    await temporario.delete(recursive: true);
  });
  test('21 traduções embarcadas, IDs antigos e capítulos das novas', () async {
    final biblia = Biblia.instancia;
    final versoes = await biblia.versoes();
    expect(versoes, hasLength(21));
    expect(versoes.first.sigla, 'ARA');
    expect(versoes.first.id, 2);
    for (final v in versoes.where((v) => v.id >= 16)) {
      final caps = await Banco.instancia.biblia.rawQuery(
        'SELECT livro, capitulo FROM versiculo WHERE versao=? GROUP BY livro, capitulo',
        [v.id],
      );
      expect(caps, hasLength(1189), reason: v.sigla);
      expect(await biblia.capitulo(v.id, 1, 1), isNotEmpty);
      expect(await biblia.capitulo(v.id, 66, 22), isNotEmpty);
      expect(await biblia.buscar(v.id, 'Deus'), isNotEmpty);
    }
  });
  test('A Mensagem cobre Gn 1:2 sem duplicar o grupo na leitura', () async {
    final biblia = Biblia.instancia;
    final capitulo = await biblia.capitulo(23, 1, 1);
    expect(capitulo.first.numero, 1);
    final comparacao = await biblia.comparar(1, 1, 2);
    expect(
      comparacao.singleWhere((v) => v.$1.sigla == 'MENS').$2,
      startsWith('1-2 '),
    );
    final referencia = await biblia.intervalo(23, 1, 1002, 1002);
    expect(referencia, hasLength(1));
    expect(referencia.single.$2, 1);
    expect(await biblia.intervalo(23, 1, 1001, 1002), hasLength(1));
  });
}
