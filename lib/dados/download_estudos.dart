import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Downloads das edições selecionadas, diretamente dos servidores de origem.
class DownloadEstudos {
  DownloadEstudos({this.abrir});

  // Permite exercitar a transferência com servidor local nos testes.
  final Future<HttpClientResponse> Function(Uri)? abrir;

  Future<File> baixar(
    Map<String, dynamic> estudo,
    Directory pasta, {
    required void Function(double?) progresso,
    required bool Function() cancelado,
  }) async {
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    final destino = File('${pasta.path}/${estudo['sha256']}.pdf');
    final parcial = File('${destino.path}.download');
    final pronto = File('${destino.path}.preparando');
    try {
      if (await destino.exists()) return destino;
      await pasta.create(recursive: true);
      final url = Uri.parse(estudo['url'] as String);
      if (!urlEstudoPermitida(url)) {
        throw const FormatException('Endereço do estudo não permitido.');
      }
      final resposta = await (abrir?.call(url) ?? _abrir(cliente, url));
      final esperado = estudo['downloadBytes'] as int;
      if (resposta.statusCode != 200 ||
          (resposta.contentLength >= 0 && resposta.contentLength != esperado)) {
        throw const FormatException(
          'O arquivo oficial mudou ou está indisponível. Procure uma atualização do aplicativo.',
        );
      }
      final saida = parcial.openWrite();
      var recebidos = 0;
      try {
        await for (final dados in resposta.timeout(
          const Duration(seconds: 30),
        )) {
          if (cancelado()) throw const EstudoDownloadCancelado();
          recebidos += dados.length;
          if (recebidos > esperado) {
            throw const FormatException('O arquivo oficial mudou de tamanho.');
          }
          saida.add(dados);
          progresso(recebidos / esperado);
        }
        await saida.flush();
      } finally {
        await saida.close();
      }
      if (cancelado()) throw const EstudoDownloadCancelado();
      if (recebidos != esperado) {
        throw const FormatException('Download incompleto. Tente novamente.');
      }
      final hash = await sha256.bind(parcial.openRead()).first;
      if (hash.toString() != estudo['downloadSha256']) {
        throw const FormatException(
          'Esta edição mudou no site oficial. Procure uma atualização do aplicativo.',
        );
      }
      progresso(null);
      final pdf = await compute(prepararPdfEstudo, {
        'dados': await parcial.readAsBytes(),
        'formato': estudo['formato'],
        'bytes': estudo['bytes'],
        'sha256': estudo['sha256'],
      });
      if (cancelado()) throw const EstudoDownloadCancelado();
      await pronto.writeAsBytes(pdf, flush: true);
      await pronto.rename(destino.path);
      return destino;
    } on SocketException {
      throw const FormatException(
        'Sem conexão. Confira a internet e tente novamente.',
      );
    } on TimeoutException {
      throw const FormatException('A conexão demorou demais. Tente novamente.');
    } finally {
      cliente.close(force: true);
      for (final arquivo in [parcial, pronto]) {
        if (await arquivo.exists()) await arquivo.delete();
      }
    }
  }

  Future<HttpClientResponse> _abrir(HttpClient cliente, Uri url) async {
    for (var i = 0; i < 5; i++) {
      if (!urlEstudoPermitida(url)) {
        throw const FormatException(
          'Redirecionamento fora da origem permitida.',
        );
      }
      final pedido = await cliente.getUrl(url);
      pedido.followRedirects = false;
      final resposta = await pedido.close().timeout(
        const Duration(seconds: 30),
      );
      if (!resposta.isRedirect) return resposta;
      final proximo = resposta.headers.value(HttpHeaders.locationHeader);
      await resposta.drain<void>().timeout(const Duration(seconds: 30));
      if (proximo == null) break;
      url = url.resolve(proximo);
    }
    throw const FormatException(
      'Não foi possível localizar o arquivo oficial.',
    );
  }
}

bool urlEstudoPermitida(Uri url) =>
    url.scheme == 'https' &&
    !url.hasPort &&
    url.userInfo.isEmpty &&
    (url.host == 'deptos.adventistas.org' ||
        url.host == 'deptos.adventistas.org.s3.amazonaws.com' ||
        (url.host == 's3.amazonaws.com' &&
            (url.path.startsWith('/missaocalebe.org.br/') ||
                url.path ==
                    '/ministeriopessoal.org/downloads/2016/bibliafacil_guiaestudo_daniel.pdf')));

/// Escolhe o PDF pela edição conhecida, sem extrair caminhos do ZIP no disco.
Uint8List prepararPdfEstudo(Map<String, dynamic> entrada) {
  final dados = entrada['dados'] as Uint8List;
  final tamanho = entrada['bytes'] as int;
  final hash = entrada['sha256'] as String;
  bool confere(List<int> pdf) =>
      pdf.length == tamanho &&
      pdf.length >= 5 &&
      String.fromCharCodes(pdf.take(5)) == '%PDF-' &&
      sha256.convert(pdf).toString() == hash;
  if (entrada['formato'] == 'pdf') {
    if (confere(dados)) return dados;
  } else if (entrada['formato'] == 'zip') {
    final zip = ZipDecoder().decodeBytes(dados);
    try {
      for (final arquivo in zip) {
        if (!arquivo.isFile ||
            arquivo.isSymbolicLink ||
            arquivo.name.startsWith('__MACOSX/') ||
            !arquivo.name.toLowerCase().endsWith('.pdf') ||
            arquivo.size != tamanho) {
          continue;
        }
        final pdf = arquivo.readBytes();
        if (pdf != null && confere(pdf)) return Uint8List.fromList(pdf);
      }
    } finally {
      zip.clear();
    }
  }
  throw const FormatException(
    'O PDF não corresponde à edição preparada para este estudo.',
  );
}

class EstudoDownloadCancelado implements Exception {
  const EstudoDownloadCancelado();
}
