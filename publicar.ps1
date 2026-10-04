# Bíblia de Estudo: compila Android e Windows, envia os commits e publica a
# release no GitHub, com o manifesto da atualizacao automatica.
#
# A versao vem do `version:` do pubspec.yaml. Para lancar a 1.0.1, suba a
# versao no pubspec (o numero depois do + TAMBEM), escreva as novidades em
# NOTAS_DA_VERSAO.md e rode este script.
#
# O que o script faz sozinho, nesta ordem (ver ferramentas\publicacao.ps1):
#   1. Confere que esta pasta esta no main, sem alteracoes por salvar (as que
#      a compilacao faz nos arquivos gerados pelo Flutter, ele desfaz).
#   2. Lista os PRs abertos no GitHub e pergunta, um a um, se entram nesta
#      versao; os que entram, ele mescla.
#   3. Traz o main do GitHub (git pull).
#   4. Recusa publicar de novo uma versao ja publicada (a menos que se use
#      -Republicar) e recusa notas que nao falem da versao.
#   5. Testa, compila (o Windows do zero), publica a release e, por ultimo,
#      avisa os apps.
#
# Pre-requisitos, uma vez:
#     & "C:\Program Files\GitHub CLI\gh.exe" auth login
#     Visual Studio com "Desenvolvimento para desktop com C++" (build Windows)
#
# Depois, na raiz deste repositorio:
#     powershell -ExecutionPolicy Bypass -File publicar.ps1
#
# Opcoes:
#     -Republicar    refaz os arquivos de uma versao ja publicada (mesmo numero)
#     -SemCompilar   republica o que ja esta em build\publicar\
#     -SemTestes     pula analyze e testes (nao recomendado)
#     -SoAndroid     nao compila nem publica o Windows
#
# ATUALIZACAO AUTOMATICA (lib/dados/atualizacao.dart):
#   - O manifesto vai para uma release fixa, "biblia-atual", que este script
#     regrava a cada versao (por ultimo, depois dos instaladores).
#   - Os apps instalados consultam
#       releases/download/biblia-atual/atualizacao-br.com.wisejr.bibliaestudo.json
#   - Suba o numero depois do + a cada release: e ele que os apps comparam, e
#     o script recusa publicar se ele nao crescer.
#   - Assine sempre com a MESMA chave (android\key.properties; ver README), ou
#     a atualizacao nao entra por cima da versao instalada.

param(
    [switch]$Republicar,
    [switch]$SemCompilar,
    [switch]$SemTestes,
    [switch]$SoAndroid
)

$ErrorActionPreference = 'Stop'
$gh = 'C:\Program Files\GitHub CLI\gh.exe'
$flutter = Join-Path $env:USERPROFILE 'flutter\bin\flutter.bat'
$apk = 'build\app\outputs\flutter-apk'
$compilacaoWindows = 'build\windows\x64'
$windows = "$compilacaoWindows\runner\Release"
$saida = 'build\publicar'
$repo = 'Wiserjr/biblia-egw'
$id = 'br.com.wisejr.bibliaestudo'
$canal = 'biblia-atual'
$prefixo = 'biblia'
$abis = @('arm64-v8a', 'armeabi-v7a', 'x86_64')

# gh avisa "release not found" pelo stderr. No Windows PowerShell 5.1, com
# ErrorActionPreference = 'Stop', qualquer saida de erro de um programa externo
# vira erro fatal, mesmo redirecionada. Aqui a falta da release e esperada (e a
# primeira publicacao), entao a consulta roda com 'Continue'.
function Existe-Release([string]$nome) {
    $ErrorActionPreference = 'Continue'
    & $gh release view $nome --repo $repo --json tagName 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}

if (-not (Test-Path $gh)) { throw "gh nao encontrado em $gh" }
if (-not (Test-Path 'pubspec.yaml')) { throw 'Rode na raiz do repositorio (pubspec.yaml nao encontrado).' }
. (Join-Path $PSScriptRoot 'ferramentas\publicacao.ps1')

& $gh auth status
if ($LASTEXITCODE -ne 0) { throw 'Autentique primeiro: gh auth login' }

# --- main igual ao do GitHub, com os PRs que entram nesta versao ---
$scripts = @('publicar.ps1', 'ferramentas\publicacao.ps1')
$antes = $scripts | ForEach-Object { (Get-FileHash $_).Hash }
Sincronizar-Main -gh $gh -repo $repo
$depois = $scripts | ForEach-Object { (Get-FileHash $_).Hash }
if (Compare-Object $antes $depois) {
    throw 'O git pull trouxe uma versao nova deste script. Rode-o de novo.'
}

# --- versao ---
$v = Ler-Versao 'pubspec.yaml'
$versao = $v.nome
$codigo = $v.codigo
$tag = "biblia-v$versao"
Write-Output "Versao do pubspec: $versao (versionCode $codigo)  ->  tag $tag"

# --- versao publicada ---
# Publicar com o numero de uma versao anterior deixa todo mundo sem
# atualizacao, em silencio; publicar de novo a mesma versao so troca os
# arquivos dela, e so com -Republicar.
$publicado = $null
try {
    $publicado = Invoke-RestMethod "https://github.com/$repo/releases/download/$canal/atualizacao-$id.json"
} catch {
    # Primeira publicacao, ou sem rede.
}
Conferir-Versao -versao $versao -codigo $codigo -publicado $publicado `
    -releaseExiste (Existe-Release $tag) -republicar $Republicar.IsPresent
$notas = 'NOTAS_DA_VERSAO.md'
Conferir-Notas $notas $versao

# --- qualidade ---
if (-not $SemTestes) {
    Write-Output ''
    Write-Output 'Analisando...'
    & $flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze falhou. Corrija antes de publicar.' }
    Write-Output 'Rodando os testes...'
    & $flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Os testes falharam. Corrija antes de publicar.' }
    python -m unittest ferramentas\test_referencias_pt.py ferramentas\test_texto_pdf.py
    if ($LASTEXITCODE -ne 0) { throw 'Os testes das ferramentas falharam.' }
}

foreach ($a in @('assets\biblia.db.gz', 'assets\estudo.db.gz')) {
    if (-not (Test-Path $a)) { throw "Falta $a. Veja o README (ferramentas)." }
}

# --- assinatura ---
if (-not (Test-Path 'android\key.properties')) {
    Write-Warning ('Sem android\key.properties: os APKs saem com a chave de debug deste PC. ' +
        'Publicar de outro PC quebra a atualizacao automatica de todo mundo. Ver README, "Chave de assinatura".')
}

# --- compilacao ---
if (-not $SemCompilar) {
    if (Test-Path $saida) { Remove-Item $saida -Recurse -Force }
    New-Item -ItemType Directory -Path $saida | Out-Null
    if (-not $SoAndroid) {
        # O Windows compila do zero: o Flutter escolhe o Visual Studio a cada
        # compilacao, e o CMake recusa a pasta configurada com outro (ver
        # Limpar-CompilacaoWindows). Apaga ja, antes do Android, para que um
        # arquivo preso pare o script logo no comeco.
        $geradorAntes = Ler-GeradorCMake $compilacaoWindows
        Limpar-CompilacaoWindows $compilacaoWindows
    }

    Write-Output ''
    Write-Output 'Compilando Android...'
    & $flutter build apk --release --split-per-abi
    if ($LASTEXITCODE -ne 0) { throw 'A compilacao Android falhou.' }
    foreach ($abi in $abis) {
        Copy-Item "$apk\app-$abi-release.apk" "$saida\$prefixo-$abi.apk"
    }

    if (-not $SoAndroid) {
        Write-Output ''
        Write-Output 'Compilando Windows (do zero)...'
        & $flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw 'A compilacao Windows falhou.' }
        $aviso = Descrever-TrocaVisualStudio $geradorAntes (Ler-GeradorCMake $compilacaoWindows)
        if ($aviso) { Write-Warning $aviso }
        # versao.json no zip: o app confere, antes de trocar os arquivos, que
        # o zip baixado e deste app e da versao anunciada.
        $v = [ordered]@{ applicationId = $id; versionCode = $codigo; versionName = $versao }
        [System.IO.File]::WriteAllText((Join-Path (Resolve-Path $windows) 'versao.json'),
            ($v | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))
        $zip = Join-Path (Resolve-Path $saida) "$prefixo-windows.zip"
        if (Test-Path $zip) { Remove-Item $zip }
        Compress-Archive -Path "$windows\*" -DestinationPath $zip
    }
}

# --- manifesto da atualizacao automatica ---
$arquivos = @()
$links = [ordered]@{}
foreach ($abi in $abis) {
    $nome = "$prefixo-$abi.apk"
    if (-not (Test-Path "$saida\$nome")) { throw "APK ausente: $saida\$nome. Rode sem -SemCompilar." }
    $arquivos += "$saida\$nome"
    $links[$abi] = "https://github.com/$repo/releases/download/$tag/$nome"
}
$manifesto = [ordered]@{
    applicationId = $id
    versionCode   = $codigo
    versionName   = $versao
    apks          = $links
}
if (Test-Path "$saida\$prefixo-windows.zip") {
    $arquivos += "$saida\$prefixo-windows.zip"
    $manifesto.windows = "https://github.com/$repo/releases/download/$tag/$prefixo-windows.zip"
} elseif ($publicado -and $publicado.windows) {
    Write-Warning 'Esta versao sai sem Windows: quem usa no PC continua na versao anterior.'
}
$caminhoManifesto = Join-Path (Resolve-Path $saida) "atualizacao-$id.json"
# Sem BOM: o PowerShell 5 poe um, e JSON com BOM e rejeitado por muitos leitores.
[System.IO.File]::WriteAllText($caminhoManifesto, ($manifesto | ConvertTo-Json -Depth 3),
    (New-Object System.Text.UTF8Encoding $false))

# --- commits ---
Write-Output ''
Write-Output 'Enviando os commits...'
git push origin main
if ($LASTEXITCODE -ne 0) { throw 'git push falhou.' }

# --- release da versao ---
if (-not (Existe-Release $tag)) {
    Write-Output "Criando a release $tag..."
    & $gh release create $tag $arquivos $caminhoManifesto --repo $repo `
        --title "Biblia de Estudo $versao" --notes-file $notas
} else {
    Write-Output "Release $tag ja existe; substituindo os arquivos..."
    & $gh release upload $tag $arquivos $caminhoManifesto --repo $repo --clobber
    & $gh release edit $tag --repo $repo --notes-file $notas
}
if ($LASTEXITCODE -ne 0) { throw 'Falha ao publicar a release.' }

# --- canal da atualizacao ---
# O manifesto vai por ULTIMO: se algo acima falhar, os apps continuam vendo a
# versao anterior, cujos arquivos existem.
if (-not (Existe-Release $canal)) {
    & $gh release create $canal $caminhoManifesto --repo $repo --prerelease --latest=false `
        --title 'Biblia de Estudo - canal de atualizacao' `
        --notes 'Manifesto lido pelos apps instalados. Os instaladores estao nas releases biblia-v*.'
} else {
    & $gh release upload $canal $caminhoManifesto --repo $repo --clobber
}
if ($LASTEXITCODE -ne 0) { throw 'Falha ao publicar o manifesto da atualizacao.' }

Write-Output ''
Write-Output 'Pronto:'
& $gh release view $tag --repo $repo --json url -q .url
Write-Output 'Quem ja tem o app instalado recebe esta versao sozinho, ao abrir o app.'
