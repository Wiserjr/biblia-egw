import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biblia_estudo/dados/download_estudos.dart';

void main() {
  final pdf = Uint8List.fromList('%PDF-1.7\nEstudo de teste'.codeUnits);
  Map<String, dynamic> item(Uint8List download, {String formato = 'pdf'}) => {
    'url': 'https://deptos.adventistas.org/estudo.$formato',
    'formato': formato,
    'bytes': pdf.length,
    'sha256': sha256.convert(pdf).toString(),
    'downloadBytes': download.length,
    'downloadSha256': sha256.convert(download).toString(),
  };

  test('ZIP escolhe a edição conhecida e não extrai arquivos adicionais', () {
    final zip = Archive()
      ..addFile(ArchiveFile('pasta/estudo.pdf', pdf.length, pdf))
      ..addFile(ArchiveFile('outro.pdf', 4, [1, 2, 3, 4]))
      ..addFile(ArchiveFile('__MACOSX/._estudo.pdf', 1, [0]));
    final dados = Uint8List.fromList(ZipEncoder().encode(zip));
    expect(
      prepararPdfEstudo({...item(dados, formato: 'zip'), 'dados': dados}),
      pdf,
    );
  });

  test('PDF de outra edição e ZIP sem o PDF previsto são recusados', () {
    final outro = Uint8List.fromList('%PDF-1.7\nOutra edicao'.codeUnits);
    expect(
      () => prepararPdfEstudo({...item(outro), 'dados': outro}),
      throwsFormatException,
    );
    final zip = Archive()
      ..addFile(ArchiveFile('outro.pdf', outro.length, outro));
    final dados = Uint8List.fromList(ZipEncoder().encode(zip));
    expect(
      () => prepararPdfEstudo({...item(dados, formato: 'zip'), 'dados': dados}),
      throwsFormatException,
    );
  });

  test('só aceita HTTPS e as origens oficiais selecionadas', () {
    expect(
      urlEstudoPermitida(Uri.parse('http://deptos.adventistas.org/a.pdf')),
      isFalse,
    );
    expect(urlEstudoPermitida(Uri.parse('https://outro.com/a.pdf')), isFalse);
    expect(
      urlEstudoPermitida(Uri.parse('https://s3.amazonaws.com/outro/a.zip')),
      isFalse,
    );
    expect(
      urlEstudoPermitida(
        Uri.parse(
          'https://s3.amazonaws.com/missaocalebe.org.br/GuiadeEstudosCalebe.zip',
        ),
      ),
      isTrue,
    );
    expect(
      urlEstudoPermitida(
        Uri.parse(
          'https://s3.amazonaws.com/ministeriopessoal.org/downloads/2016/bibliafacil_guiaestudo_daniel.pdf',
        ),
      ),
      isTrue,
    );
    expect(
      urlEstudoPermitida(
        Uri.parse('https://s3.amazonaws.com/ministeriopessoal.org/outro.pdf'),
      ),
      isFalse,
    );
    expect(
      urlEstudoPermitida(
        Uri.parse(
          'http://s3.amazonaws.com/ministeriopessoal.org/downloads/2016/bibliafacil_guiaestudo_daniel.pdf',
        ),
      ),
      isFalse,
    );
  });

  group('transferência', () {
    late Directory pasta;
    late HttpServer servidor;
    late HttpClient cliente;
    late DownloadEstudos download;
    late Uint8List resposta;
    setUp(() async {
      pasta = await Directory.systemTemp.createTemp('estudos-test-');
      servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      cliente = HttpClient();
      resposta = pdf;
      servidor.listen((pedido) async {
        pedido.response.contentLength = resposta.length;
        pedido.response.add(resposta);
        await pedido.response.close();
      });
      download = DownloadEstudos(
        abrir: (_) async {
          final pedido = await cliente.getUrl(
            Uri.parse('http://127.0.0.1:${servidor.port}/'),
          );
          return pedido.close();
        },
      );
    });
    tearDown(() async {
      cliente.close(force: true);
      await servidor.close(force: true);
      await pasta.delete(recursive: true);
    });

    test('download validado fica disponível e não deixa temporários', () async {
      final progresso = <double?>[];
      final arquivo = await download.baixar(
        item(pdf),
        pasta,
        progresso: progresso.add,
        cancelado: () => false,
      );
      expect(await arquivo.readAsBytes(), pdf);
      expect(await pasta.list().length, 1);
      expect(progresso, contains(1.0));
    });

    test('edição alterada não é instalada e limpa o download', () async {
      resposta = Uint8List.fromList(pdf)..[pdf.length - 1] = 0;
      await expectLater(
        download.baixar(
          item(pdf),
          pasta,
          progresso: (_) {},
          cancelado: () => false,
        ),
        throwsFormatException,
      );
      expect(await pasta.list().length, 0);
    });

    test('cancelar remove o parcial e permite tentar novamente', () async {
      await expectLater(
        download.baixar(
          item(pdf),
          pasta,
          progresso: (_) {},
          cancelado: () => true,
        ),
        throwsA(isA<EstudoDownloadCancelado>()),
      );
      expect(await pasta.list().length, 0);
      final arquivo = await download.baixar(
        item(pdf),
        pasta,
        progresso: (_) {},
        cancelado: () => false,
      );
      expect(await arquivo.readAsBytes(), pdf);
    });
  });
}
