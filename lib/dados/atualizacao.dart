import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Atualização automática do próprio app, no padrão do Louvor JA e do app de
/// recadastramento: ao abrir, o app consulta um manifesto publicado junto com a
/// release e, havendo versão nova, baixa e instala — sempre com a confirmação
/// da pessoa. Ninguém precisa mandar instalador por WhatsApp a cada versão.
///
/// O canal é uma release fixa do GitHub, regravada pelo `publicar.ps1` a cada
/// versão (os instaladores em si ficam na release da versão):
///
///     https://github.com/Wiserjr/biblia-egw/releases/download/biblia-atual/atualizacao-br.com.wisejr.bibliaestudo.json
///
/// Uma release fixa, e não a `latest`: o endereço do manifesto não muda, e a
/// versão só passa a valer quando o manifesto é regravado, depois que os
/// instaladores já estão na release.
///
///     {
///       "applicationId": "br.com.wisejr.bibliaestudo",
///       "versionCode": 3,
///       "versionName": "1.0.2",
///       "apks": { "arm64-v8a": "https://github.com/.../biblia-arm64-v8a.apk", ... },
///       "windows": "https://github.com/.../biblia-windows.zip"
///     }
///
/// Tudo o que vem do manifesto é validado: ele é a porta por onde um programa
/// entra no aparelho, e quem controlar esse arquivo não deve conseguir apontar
/// para outro servidor, outro app, nem pôr texto arbitrário no diálogo.
class Atualizacao {
  Atualizacao._();
  static final Atualizacao instancia = Atualizacao._();

  static const repositorio = 'Wiserjr/biblia-egw';
  static const canal = 'biblia-atual';
  static const pacote = 'br.com.wisejr.bibliaestudo';
  static const _canalNativo = MethodChannel(
    'br.com.wisejr.bibliaestudo/atualizacao',
  );

  /// Nome do executável no zip do Windows (BINARY_NAME em windows/CMakeLists).
  static const executavelWindows = 'biblia_estudo.exe';

  static const _tetoManifesto = 16 * 1024;

  /// Arquivo, na pasta de dados do app, com a versão que o app saiu para
  /// instalar no Windows; a abertura seguinte confere se ela entrou
  /// ([conferirAtualizacaoAnterior]). Arquivo próprio, e não as
  /// preferências: outra janela do app aberta regrava as preferências
  /// inteiras a cada mudança e apagaria a marca.
  static const _arquivoPendente = 'atualizacao-pendente.txt';

  bool _conferiu = false;

  /// O APK tem ~30 MB e o zip do Windows ~40 MB. O teto é contra servidor
  /// comprometido (ou proxy hostil) enchendo o disco.
  static const _tetoArquivo = 250 * 1024 * 1024;

  final _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 30)
    ..userAgent = 'BibliaDeEstudo-atualizacao';

  static bool get suportada => Platform.isAndroid || Platform.isWindows;

  Uri get urlManifesto => Uri.parse(
    'https://github.com/$repositorio/releases/download/$canal/'
    'atualizacao-$pacote.json',
  );

  /// Consulta o manifesto e devolve a atualização, ou `null` se o app já está
  /// na versão publicada. Lança [FalhaAtualizacao] quando não dá para saber.
  Future<InfoAtualizacao?> consultar() async {
    if (!suportada) return null;
    final String pacoteInstalado;
    final int instalada;
    final List<String> abis;
    if (Platform.isAndroid) {
      pacoteInstalado = (await PackageInfo.fromPlatform()).packageName;
      instalada = await _canalNativo.invokeMethod<int>('versaoInstalada') ?? 0;
      abis = (await _canalNativo.invokeListMethod<String>('abis')) ?? const [];
    } else {
      // No Windows não há "pacote"; o identificador é o do app Android, que
      // é o que o manifesto declara.
      pacoteInstalado = pacote;
      instalada =
          int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
      abis = const [];
    }

    final corpo = await _get(urlManifesto, teto: _tetoManifesto);
    final Object? json;
    try {
      // O PowerShell 5 grava UTF-8 com BOM se não for impedido.
      final texto = utf8.decode(corpo);
      json = jsonDecode(texto.startsWith('﻿') ? texto.substring(1) : texto);
    } on FormatException {
      throw const FalhaAtualizacao('O manifesto da atualização é inválido.');
    }
    if (json is! Map<String, dynamic>) {
      throw const FalhaAtualizacao('O manifesto da atualização é inválido.');
    }
    return interpretarManifesto(
      json,
      pacote: pacoteInstalado,
      versaoInstalada: instalada,
      abis: abis,
      windows: Platform.isWindows,
    );
  }

  Future<File> _destino() async {
    final dir = await getTemporaryDirectory();
    return File(
      p.join(
        dir.path,
        Platform.isWindows ? 'biblia-atualizacao.zip' : 'atualizacao.apk',
      ),
    );
  }

  /// Baixa para o cache, num `.parcial` renomeado só no fim.
  Future<void> baixar(
    InfoAtualizacao info, {
    void Function(int recebidos, int total)? aoProgredir,
    CancelToken? cancelamento,
  }) async {
    final destino = await _destino();
    final parcial = File('${destino.path}.parcial');
    if (await destino.exists()) await destino.delete();

    final resp = await _abrir(info.arquivo);
    final total = resp.contentLength;
    if (total > _tetoArquivo) {
      await resp.drain<void>();
      throw const FalhaAtualizacao(
        'O arquivo da atualização é maior do que o esperado.',
      );
    }
    if ((resp.headers.contentType?.mimeType ?? '').startsWith('text/')) {
      await resp.drain<void>();
      throw const FalhaAtualizacao(
        'O servidor devolveu uma página em vez da atualização. '
        'Tente mais tarde.',
      );
    }

    final saida = parcial.openWrite();
    var recebidos = 0;
    try {
      await for (final pedaco in resp) {
        if (cancelamento?.cancelado ?? false) throw const DownloadCancelado();
        recebidos += pedaco.length;
        if (recebidos > _tetoArquivo) {
          throw const FalhaAtualizacao(
            'O arquivo da atualização é maior do que o esperado.',
          );
        }
        saida.add(pedaco);
        aoProgredir?.call(recebidos, total);
      }
      await saida.flush();
      await saida.close();
    } catch (e) {
      await saida.close();
      if (await parcial.exists()) await parcial.delete();
      if (e is DownloadCancelado || e is FalhaAtualizacao) rethrow;
      throw const FalhaAtualizacao(
        'O download foi interrompido. Confira a conexão e tente de novo.',
      );
    }
    if (total > 0 && recebidos != total) {
      await parcial.delete();
      throw const FalhaAtualizacao(
        'O download foi interrompido antes de terminar. Tente de novo.',
      );
    }
    await parcial.rename(destino.path);
  }

  /// Confere o arquivo baixado e instala.
  ///
  /// A conferência repete, no arquivo de verdade, o que o manifesto prometeu:
  /// mesmo app e a versão anunciada.
  Future<void> instalar(InfoAtualizacao info) async {
    if (Platform.isWindows) return _instalarWindows(info);
    final pacoteInstalado = (await PackageInfo.fromPlatform()).packageName;
    final apk = await _canalNativo.invokeMapMethod<String, Object?>(
      'conferirApk',
    );
    if (apk == null) {
      throw const FalhaAtualizacao(
        'O arquivo da atualização chegou corrompido. Tente de novo.',
      );
    }
    final codigo = apk['versionCode'];
    if (apk['pacote'] != pacoteInstalado ||
        codigo is! int ||
        versaoBase(codigo) != info.versionCode) {
      throw const FalhaAtualizacao(
        'O arquivo baixado não corresponde a esta atualização.',
      );
    }
    await _canalNativo.invokeMethod<bool>('instalar');
  }

  /// No Windows: extrai o zip numa pasta temporária, confere, e deixa um
  /// script que espera o app fechar, copia os arquivos por cima da instalação
  /// e abre a versão nova. Os dados (livros baixados, marcações) ficam em
  /// AppData, fora da pasta do programa, e não são tocados.
  Future<void> _instalarWindows(InfoAtualizacao info) async {
    final zip = await _destino();
    final instalacao = File(Platform.resolvedExecutable).parent;
    if (!await _gravavel(instalacao)) {
      throw const FalhaAtualizacao(
        'Sem permissão para gravar na pasta do programa. Mova a pasta do app '
        'para dentro da sua pasta de usuário e tente de novo.',
      );
    }
    final base = Directory(p.join(zip.parent.path, 'biblia-atualizacao'));
    if (await base.exists()) await base.delete(recursive: true);
    final novo = Directory(p.join(base.path, 'novo'));
    await novo.create(recursive: true);
    try {
      await extractFileToDisk(zip.path, novo.path);
    } catch (_) {
      throw const FalhaAtualizacao(
        'O arquivo da atualização chegou corrompido. Tente de novo.',
      );
    }
    // Conferência: o executável certo e a versão anunciada.
    final exe = File(p.join(novo.path, executavelWindows));
    final versao = File(p.join(novo.path, 'versao.json'));
    if (!await exe.exists() || !await versao.exists()) {
      throw const FalhaAtualizacao(
        'O arquivo baixado não corresponde a esta atualização.',
      );
    }
    try {
      final v = jsonDecode(await versao.readAsString());
      if (v is! Map ||
          v['applicationId'] != pacote ||
          v['versionCode'] != info.versionCode) {
        throw const FormatException();
      }
    } on FormatException {
      throw const FalhaAtualizacao(
        'O arquivo baixado não corresponde a esta atualização.',
      );
    }

    final script = File(p.join(base.path, 'atualizar.cmd'));
    await script.writeAsString(scriptWindows, flush: true);
    // O script roda com console escondido (o modo normal do Process.start), e
    // os programas que ele chama usam o mesmo console. Num processo
    // "detached" cada um abria uma janela própria, e no Windows 11 o
    // `tasklist | find` da versão antiga ficava preso para sempre.
    //
    // Os caminhos vão em variáveis de ambiente, e não no texto do script:
    // assim acento e espaço no nome da pasta não quebram nada.
    final pendente = await _pendente();
    await pendente.writeAsString('${info.versionCode}', flush: true);
    try {
      await Process.start(
        Platform.environment['ComSpec'] ?? 'cmd.exe',
        // `.\` e não só o nome: com NoDefaultCurrentDirectoryInExePath o cmd
        // não procura na pasta atual. `/e:on` liga as extensões mesmo que o
        // registro as desligue (o script usa `set /a`).
        ['/d', '/e:on', '/c', r'.\atualizar.cmd'],
        workingDirectory: base.path,
        environment: variaveisScriptWindows(
          pid: pid,
          origem: novo.path,
          destino: instalacao.path,
          emUso: p.basename(Platform.resolvedExecutable),
        ),
      );
    } catch (_) {
      await pendente.delete();
      rethrow;
    }
    // Encerra na hora, sem a rotina de saída: se algum plugin travar ao
    // fechar, o processo continuaria vivo prendendo os arquivos. O
    // `exit` só roda se o Windows recusar.
    Process.killPid(pid);
    exit(0);
  }

  Future<File> _pendente() async => File(
    p.join((await getApplicationSupportDirectory()).path, _arquivoPendente),
  );

  /// Na abertura, diz como terminou a atualização que o app saiu para
  /// instalar no Windows, ou `null` se não havia nenhuma. Só a primeira
  /// chamada de cada abertura confere.
  ///
  /// Também apaga os temporários (o zip e a pasta extraída, mais de 100 MB).
  /// Isso desarma, de quebra, os scripts da 1.4.0 e anteriores que tenham
  /// ficado presos na janela "find": o cmd relê o arquivo a cada linha, e
  /// sem ele para em vez de copiar a versão velha por cima desta.
  Future<({bool concluida, String versao})?>
  conferirAtualizacaoAnterior() async {
    if (!Platform.isWindows || _conferiu) return null;
    _conferiu = true;
    await _limparTemporarios();
    final arquivo = await _pendente();
    if (!await arquivo.exists()) return null;
    final pendente = int.tryParse((await arquivo.readAsString()).trim());
    await arquivo.delete();
    if (pendente == null) return null;
    final info = await PackageInfo.fromPlatform();
    return (
      concluida: (int.tryParse(info.buildNumber) ?? 0) >= pendente,
      versao: info.version,
    );
  }

  Future<void> _limparTemporarios() async {
    try {
      final zip = await _destino();
      final base = Directory(p.join(zip.parent.path, 'biblia-atualizacao'));
      if (await zip.exists()) await zip.delete();
      if (await base.exists()) await base.delete(recursive: true);
    } catch (_) {
      // Fica para a próxima atualização, que apaga a pasta antes de usar.
    }
  }

  Future<bool> _gravavel(Directory dir) async {
    final teste = File(p.join(dir.path, '.teste-gravacao'));
    try {
      await teste.writeAsString('x');
      await teste.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Se o Android ainda não deixa este app instalar atualizações.
  Future<bool> precisaLiberarFonte() async {
    if (!Platform.isAndroid) return false;
    return await _canalNativo.invokeMethod<bool>('precisaLiberarFonte') ??
        false;
  }

  /// Abre a tela da permissão e diz, na volta, se ela foi concedida.
  Future<bool> liberarFonte() async =>
      await _canalNativo.invokeMethod<bool>('liberarFonte') ?? false;

  Future<List<int>> _get(Uri url, {required int teto}) async {
    final resp = await _abrir(url).timeout(const Duration(seconds: 15));
    final corpo = <int>[];
    await for (final pedaco in resp.timeout(const Duration(seconds: 15))) {
      corpo.addAll(pedaco);
      if (corpo.length > teto) {
        throw const FalhaAtualizacao('O manifesto da atualização é inválido.');
      }
    }
    return corpo;
  }

  /// Abre a URL seguindo redirecionamentos só para os hosts do GitHub.
  Future<HttpClientResponse> _abrir(Uri url) async {
    var atual = url;
    for (var saltos = 0; saltos < 5; saltos++) {
      if (!hostPermitido(atual)) {
        throw const FalhaAtualizacao(
          'A atualização aponta para um endereço não permitido.',
        );
      }
      final HttpClientResponse resp;
      try {
        final req = await _http.getUrl(atual);
        req.followRedirects = false;
        resp = await req.close();
      } on SocketException {
        throw const FalhaAtualizacao(
          'Sem conexão para consultar a atualização.',
        );
      } on HttpException {
        throw const FalhaAtualizacao(
          'Sem conexão para consultar a atualização.',
        );
      }
      if (resp.isRedirect) {
        final destino = resp.headers.value(HttpHeaders.locationHeader);
        await resp.drain<void>();
        if (destino == null) break;
        atual = atual.resolve(destino);
        continue;
      }
      if (resp.statusCode == HttpStatus.notFound) {
        await resp.drain<void>();
        throw const FalhaAtualizacao('Não há atualização publicada.');
      }
      if (resp.statusCode != HttpStatus.ok) {
        await resp.drain<void>();
        throw FalhaAtualizacao(
          'O servidor da atualização não respondeu (${resp.statusCode}).',
        );
      }
      return resp;
    }
    throw const FalhaAtualizacao('Redirecionamento demais na atualização.');
  }
}

/// Uma versão publicada mais nova que a instalada.
class InfoAtualizacao {
  const InfoAtualizacao({
    required this.versionCode,
    required this.versionName,
    required this.arquivo,
  });

  /// Versão-base, sem o acréscimo por arquitetura (ver [versaoBase]).
  final int versionCode;
  final String versionName;

  /// O APK (Android) ou o zip (Windows).
  final Uri arquivo;
}

class FalhaAtualizacao implements Exception {
  const FalhaAtualizacao(this.motivo);
  final String motivo;
  @override
  String toString() => motivo;
}

class DownloadCancelado implements Exception {
  const DownloadCancelado();
}

class CancelToken {
  bool cancelado = false;
  void cancelar() => cancelado = true;
}

/// A versão-base de um versionCode. Com `--split-per-abi` o Flutter soma
/// 1000 × a arquitetura ao número do pubspec (o `+3` vira 1003, 2003, 4003);
/// o manifesto publica a base, e a comparação é sempre entre bases.
int versaoBase(int versionCode) => versionCode % 1000;

/// Se [url] está num host do GitHub por onde a release é servida.
bool hostPermitido(Uri url) =>
    url.scheme == 'https' &&
    !url.hasPort &&
    url.userInfo.isEmpty &&
    const {
      'github.com',
      'objects.githubusercontent.com',
      'release-assets.githubusercontent.com',
    }.contains(url.host);

final _caminhoApk = RegExp(
  '^/${RegExp.escape(Atualizacao.repositorio)}/releases/download/'
  r'[A-Za-z0-9._-]+/[A-Za-z0-9._-]+\.apk$',
);

final _caminhoZip = RegExp(
  '^/${RegExp.escape(Atualizacao.repositorio)}/releases/download/'
  r'[A-Za-z0-9._-]+/[A-Za-z0-9._-]+\.zip$',
);

final _formatoVersao = RegExp(r'^[0-9]{1,4}(\.[0-9]{1,4}){0,3}$');

bool _linkValido(Object? link, RegExp caminho) {
  final url = link is String ? Uri.tryParse(link) : null;
  return url != null &&
      hostPermitido(url) &&
      url.host == 'github.com' &&
      !url.hasQuery &&
      !url.hasFragment &&
      !url.path.contains('..') &&
      caminho.hasMatch(url.path);
}

/// Valida o manifesto e devolve a atualização, ou `null` se não há versão nova.
///
/// - **applicationId igual ao do app**: sem isso, o manifesto de um app
///   ofereceria o instalador de outro.
/// - **Link só para uma release deste repositório**, em https, sem porta,
///   usuário, query ou fragmento.
/// - **versionName só com números e pontos**: ele vai direto para o diálogo;
///   sem formato exigido, alguém escreveria ali "APAGUE E REINSTALE O APP".
/// - **Instalador para este aparelho**: a arquitetura, na ordem de preferência
///   que o Android informa, ou o zip do Windows.
InfoAtualizacao? interpretarManifesto(
  Map<String, dynamic> json, {
  required String pacote,
  required int versaoInstalada,
  required List<String> abis,
  bool windows = false,
}) {
  if (json['applicationId'] != pacote) {
    throw const FalhaAtualizacao('O manifesto é de outro aplicativo.');
  }
  final codigo = json['versionCode'];
  final nome = json['versionName'];
  if (codigo is! int || codigo <= 0 || codigo >= 1000) {
    throw const FalhaAtualizacao('Versão com formato inválido.');
  }
  if (nome is! String || !_formatoVersao.hasMatch(nome)) {
    throw const FalhaAtualizacao('Versão com formato inválido.');
  }

  if (windows) {
    final link = json['windows'];
    if (link == null) {
      throw const FalhaAtualizacao(
        'A atualização não tem versão para Windows.',
      );
    }
    if (!_linkValido(link, _caminhoZip)) {
      throw const FalhaAtualizacao('Link de atualização inválido.');
    }
    if (codigo <= versaoInstalada) return null;
    return InfoAtualizacao(
      versionCode: codigo,
      versionName: nome,
      arquivo: Uri.parse(link as String),
    );
  }

  final apks = json['apks'];
  if (apks is! Map<String, dynamic>) {
    throw const FalhaAtualizacao('O manifesto da atualização é inválido.');
  }
  if (codigo <= versaoBase(versaoInstalada)) return null;

  for (final abi in abis) {
    final link = apks[abi];
    if (link == null) continue;
    if (!_linkValido(link, _caminhoApk)) {
      throw const FalhaAtualizacao('Link de atualização inválido.');
    }
    return InfoAtualizacao(
      versionCode: codigo,
      versionName: nome,
      arquivo: Uri.parse(link as String),
    );
  }
  throw const FalhaAtualizacao(
    'A atualização não tem versão para este aparelho.',
  );
}

/// As variáveis que o app passa ao [scriptWindows].
///
/// - `BIBLIA_PID`: o processo do app que está fechando.
/// - `BIBLIA_ORIGEM`: a pasta com a versão nova, já extraída e conferida.
/// - `BIBLIA_DESTINO`: a pasta do programa.
/// - `BIBLIA_EM_USO`: o executável que está rodando, que prende os arquivos.
/// - `BIBLIA_EXE`: o executável a abrir no fim.
Map<String, String> variaveisScriptWindows({
  required int pid,
  required String origem,
  required String destino,
  required String emUso,
}) => {
  'BIBLIA_PID': '$pid',
  'BIBLIA_ORIGEM': origem,
  // Na raiz de um disco a pasta é `D:\`, e o robocopy lê `"D:\"` como
  // aspas escapadas; `D:\.` é a mesma pasta.
  'BIBLIA_DESTINO': destino.endsWith(r'\') ? '$destino.' : destino,
  'BIBLIA_EM_USO': emUso,
  'BIBLIA_EXE': Atualizacao.executavelWindows,
};

/// O script que troca os arquivos depois que o app fecha (Windows).
///
/// Sem caminho nenhum no texto: tudo vem das variáveis de
/// [variaveisScriptWindows]. O cmd lê o arquivo na página de código do
/// console, e um caminho com acento gravado em UTF-8 chegaria trocado.
///
/// 1. Espera o executável soltar: enquanto o app roda, o Windows não deixa
///    abri-lo para gravar. O teste usa só comandos do próprio cmd. A versão
///    1.4.0 e anteriores usavam `tasklist | find`, que ficava preso para
///    sempre no Windows 11.
/// 2. Passados uns 10 segundos, encerra à força o processo do app (o filtro
///    pelo nome do executável evita matar outro programa que tenha herdado o
///    número). Passados uns 30, desiste da cópia: outra janela do app está
///    aberta, e a abertura seguinte avisa que a atualização não terminou.
/// 3. Copia com robocopy, que tenta de novo arquivos ainda presos (códigos
///    de 0 a 7 são sucesso; negativo é robocopy que caiu), com uma nova
///    tentativa. O executável vai por último, e só se o resto entrou: uma
///    cópia pela metade deixa o executável velho, e a abertura seguinte vê
///    a versão antiga e avisa que a atualização não terminou.
/// 4. Reabre o app.
///
/// `ping` é a pausa de 1 segundo: o `timeout` falha quando a entrada do
/// script não é um teclado, e aqui ela não é.
const scriptWindows =
    '@echo off\r\n'
    'setlocal EnableExtensions DisableDelayedExpansion\r\n'
    'set "ALVO=%BIBLIA_DESTINO%\\%BIBLIA_EM_USO%"\r\n'
    'set /a N=0\r\n'
    ':espera\r\n'
    '2>NUL (\r\n'
    '  >>"%ALVO%" (call )\r\n'
    ') && goto copiar\r\n'
    'set /a N+=1\r\n'
    'if %N% EQU 10 taskkill /F /FI "PID eq %BIBLIA_PID%" /FI "IMAGENAME eq %BIBLIA_EM_USO%" >NUL 2>&1\r\n'
    'if %N% GEQ 30 goto abrir\r\n'
    'ping -n 2 127.0.0.1 >NUL\r\n'
    'goto espera\r\n'
    ':copiar\r\n'
    'set /a T=0\r\n'
    ':copiar_de_novo\r\n'
    'set /a T+=1\r\n'
    'robocopy "%BIBLIA_ORIGEM%" "%BIBLIA_DESTINO%" /E /XF "%BIBLIA_EXE%" /R:5 /W:1 /NFL /NDL /NJH /NJS /NP >NUL\r\n'
    'set R=%ERRORLEVEL%\r\n'
    'if %R% GEQ 0 if %R% LSS 8 goto exe\r\n'
    'if %T% GEQ 2 goto abrir\r\n'
    'ping -n 3 127.0.0.1 >NUL\r\n'
    'goto copiar_de_novo\r\n'
    ':exe\r\n'
    'robocopy "%BIBLIA_ORIGEM%" "%BIBLIA_DESTINO%" "%BIBLIA_EXE%" /R:5 /W:1 /NFL /NDL /NJH /NJS /NP >NUL\r\n'
    ':abrir\r\n'
    'start "" /D "%BIBLIA_DESTINO%" "%BIBLIA_DESTINO%\\%BIBLIA_EXE%"\r\n'
    'endlocal\r\n';
