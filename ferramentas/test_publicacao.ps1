# Testes das conferencias do publicar.ps1 (ferramentas\publicacao.ps1), com
# git, gh e as perguntas simulados: nada aqui toca o GitHub.
#
#     powershell -ExecutionPolicy Bypass -File ferramentas\test_publicacao.ps1
#     pwsh -File ferramentas/test_publicacao.ps1        (Linux/macOS)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'publicacao.ps1')

# --- simulacoes ---
$script:ramo = 'main'
$script:mudancas = @()
$script:prs = '[]'
$script:pullFalha = $false
$script:checkoutFalha = $false
$script:chamadas = New-Object System.Collections.ArrayList

# Um array passado a um programa vira varios argumentos; aqui, tambem. Um
# argumento com espaco sai entre aspas, para nao se confundir com varios.
function Juntar($lista) {
    $partes = @($lista | ForEach-Object { $_ }) |
        ForEach-Object { if ("$_" -match '\s') { "'$_'" } else { "$_" } }
    return (@($partes) -join ' ')
}

function git {
    [void]$script:chamadas.Add("git $(Juntar $args)")
    $global:LASTEXITCODE = 0
    switch ($args[0]) {
        'rev-parse' { $script:ramo }
        'status' { $script:mudancas }
        'pull' { if ($script:pullFalha) { $global:LASTEXITCODE = 1 } }
        'checkout' { if ($script:checkoutFalha) { $global:LASTEXITCODE = 1 } }
    }
}

function GhFalso {
    [void]$script:chamadas.Add("gh $(Juntar $args)")
    $global:LASTEXITCODE = 0
    if ($args[0] -eq 'pr' -and $args[1] -eq 'list') { $script:prs }
}

function Simular([string]$ramo = 'main', $mudancas = @(), [string]$prs = '[]') {
    $script:ramo = $ramo
    $script:mudancas = $mudancas
    $script:prs = $prs
    $script:pullFalha = $false
    $script:checkoutFalha = $false
    $script:chamadas.Clear()
}

function Respostas([string[]]$lista) {
    $fila = New-Object System.Collections.Queue
    foreach ($r in $lista) { $fila.Enqueue($r) }
    return { param($texto) $fila.Dequeue() }.GetNewClosure()
}

# --- mini estrutura de testes ---
$script:falhas = 0
function Teste([string]$nome, [scriptblock]$corpo) {
    try {
        & $corpo | Out-Null
        Write-Host "ok    $nome"
    } catch {
        $script:falhas++
        Write-Host "FALHA $nome`n      $($_.Exception.Message)"
    }
}
function Deve-Falhar([scriptblock]$corpo, [string]$trecho) {
    try { & $corpo | Out-Null } catch {
        if ($_.Exception.Message -notlike "*$trecho*") {
            throw "falhou com outra mensagem: $($_.Exception.Message)"
        }
        return
    }
    throw "deveria ter falhado ($trecho)"
}
function Igual($esperado, $obtido) {
    if ("$esperado" -ne "$obtido") { throw "esperado '$esperado', veio '$obtido'" }
}

# --- Sincronizar-Main ---
Teste 'fora do main: recusa' {
    Simular -ramo 'claude/x'
    Deve-Falhar { Sincronizar-Main -gh 'GhFalso' -repo 'a/b' } 'git checkout main'
}

Teste 'alteracoes por salvar: recusa e lista os arquivos' {
    Simular -mudancas @(' M pubspec.yaml')
    Deve-Falhar { Sincronizar-Main -gh 'GhFalso' -repo 'a/b' } 'pubspec.yaml'
}

Teste 'arquivos que a compilacao regera: desfaz e segue' {
    Simular -mudancas @(
        ' M windows/flutter/generated_plugin_registrant.cc',
        ' M windows/flutter/generated_plugin_registrant.h',
        ' M windows/flutter/generated_plugins.cmake')
    Sincronizar-Main -gh 'GhFalso' -repo 'a/b' -perguntar (Respostas @())
    Igual ('git checkout HEAD windows/flutter/generated_plugin_registrant.cc ' +
        'windows/flutter/generated_plugin_registrant.h windows/flutter/generated_plugins.cmake') `
        @($script:chamadas | Where-Object { $_ -like 'git checkout*' })[0]
    Igual 'git pull --ff-only origin main' $script:chamadas[-1]
}

Teste 'arquivos gerados que nao voltam: recusa antes do pull' {
    Simular -mudancas @(' M windows/flutter/generated_plugins.cmake')
    $script:checkoutFalha = $true
    Deve-Falhar { Sincronizar-Main -gh 'GhFalso' -repo 'a/b' -perguntar (Respostas @()) } 'desfazer os arquivos gerados'
    if ($script:chamadas -like 'git pull*') { throw 'fez o pull mesmo assim' }
}

Teste 'arquivo gerado junto com outra alteracao: recusa so pela outra' {
    Simular -mudancas @(' M windows/flutter/generated_plugins.cmake', ' M lib/main.dart')
    try {
        Sincronizar-Main -gh 'GhFalso' -repo 'a/b' -perguntar (Respostas @())
        throw 'deveria ter recusado'
    } catch {
        $msg = $_.Exception.Message
        if ($msg -notlike '*lib/main.dart*') { throw "recusou com outra mensagem: $msg" }
        if ($msg -like '*generated_plugins*') { throw "listou o arquivo gerado: $msg" }
    }
    if ($script:chamadas -like 'git pull*') { throw 'fez o pull com alteracao por salvar' }
}

Teste 'arquivo com nome parecido fora de windows/flutter: recusa' {
    Simular -mudancas @(' M lib/generated_plugins.cmake')
    Deve-Falhar { Sincronizar-Main -gh 'GhFalso' -repo 'a/b' } 'lib/generated_plugins.cmake'
}

Teste 'sem PR aberto: so faz o pull' {
    Simular
    Sincronizar-Main -gh 'GhFalso' -repo 'a/b' -perguntar (Respostas @())
    Igual 'git pull --ff-only origin main' $script:chamadas[-1]
    if ($script:chamadas -like 'gh pr merge*') { throw 'mesclou sem PR' }
}

Teste 'PR em rascunho aceito: tira do rascunho, mescla e depois faz o pull' {
    Simular -prs '[{"number":5,"title":"Mais opcoes","isDraft":true}]'
    Sincronizar-Main -gh 'GhFalso' -repo 'a/b' -perguntar (Respostas @('s'))
    $gh = @($script:chamadas | Where-Object { $_ -like 'gh pr *' -and $_ -notlike 'gh pr list*' })
    Igual 'gh pr ready 5 --repo a/b' $gh[0]
    Igual 'gh pr merge 5 --repo a/b --merge' $gh[1]
    Igual 'git pull --ff-only origin main' $script:chamadas[-1]
}

Teste 'dois PRs: so o aceito e mesclado' {
    Simular -prs '[{"number":5,"title":"A","isDraft":false},{"number":6,"title":"B","isDraft":false}]'
    Sincronizar-Main -gh 'GhFalso' -repo 'a/b' -perguntar (Respostas @('N', 'sim')) 3>$null
    $mesclados = @($script:chamadas | Where-Object { $_ -like 'gh pr merge*' })
    Igual 1 $mesclados.Count
    Igual 'gh pr merge 6 --repo a/b --merge' $mesclados[0]
}

Teste 'pull que nao avanca direto: recusa' {
    Simular
    $script:pullFalha = $true
    Deve-Falhar { Sincronizar-Main -gh 'GhFalso' -repo 'a/b' -perguntar (Respostas @()) } 'commits diferentes'
}

# --- Ler-Versao ---
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) "publicacao-$PID"
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
function Pubspec([string]$linha) {
    $f = Join-Path $tmp 'pubspec.yaml'
    Set-Content -Path $f -Value "name: x`n$linha`n"
    return $f
}

Teste 'le nome e numero da versao' {
    $v = Ler-Versao (Pubspec 'version: 1.2.0+3')
    Igual '1.2.0' $v.nome
    Igual 3 $v.codigo
}
Teste 'versao sem numero depois do +: recusa' {
    Deve-Falhar { Ler-Versao (Pubspec 'version: 1.2.0') } 'depois do +'
}

# --- Conferir-Versao ---
$publicado = [pscustomobject]@{ versionName = '1.1.0'; versionCode = 2 }

Teste 'mesma versao ja publicada: recusa' {
    Deve-Falhar { Conferir-Versao '1.1.0' 2 $publicado $true $false } '-Republicar'
}
Teste 'mesma versao com -Republicar: aceita' {
    Conferir-Versao '1.1.0' 2 $publicado $true $true
}
Teste 'release apagada mas manifesto na mesma versao: recusa' {
    Deve-Falhar { Conferir-Versao '1.1.0' 2 $publicado $false $false } 'ja esta publicada'
}
Teste 'versao nova com numero maior: aceita' {
    Conferir-Versao '1.2.0' 3 $publicado $false $false
}
Teste 'versao nova com o mesmo numero depois do +: recusa' {
    Deve-Falhar { Conferir-Versao '1.2.0' 2 $publicado $false $false } 'Suba o numero'
}
Teste 'primeira publicacao (sem manifesto): aceita' {
    Conferir-Versao '1.0.0' 1 $null $false $false
}

# --- Conferir-Notas ---
Teste 'notas que falam da versao: aceita' {
    $f = Join-Path $tmp 'NOTAS.md'
    Set-Content -Path $f -Value "## Novidades da 1.2.0`n"
    Conferir-Notas $f '1.2.0'
}
Teste 'notas de outra versao: recusa' {
    $f = Join-Path $tmp 'NOTAS.md'
    Set-Content -Path $f -Value "## Novidades da 1.1.0`n"
    Deve-Falhar { Conferir-Notas $f '1.2.0' } 'nao fala da versao 1.2.0'
}

# --- compilacao Windows ---
# Uma pasta como a que o Flutter deixa em build\windows\x64: o cache do CMake
# e o app compilado. Criada com .NET e caminho absoluto, para os colchetes de
# um nome nao virarem curinga.
function PastaCompilacao([string]$nome = 'x64', [string]$gerador = 'Visual Studio 18 2026') {
    $p = [System.IO.Path]::Combine($tmp, $nome)
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
    $ids = [System.IO.Path]::Combine($p, 'CMakeFiles', '4.2.0')
    $release = [System.IO.Path]::Combine($p, 'runner', 'Release')
    [void][System.IO.Directory]::CreateDirectory($ids)
    [void][System.IO.Directory]::CreateDirectory($release)
    # A linha da instancia vem antes de proposito: a leitura nao pode pega-la.
    [System.IO.File]::WriteAllText([System.IO.Path]::Combine($p, 'CMakeCache.txt'),
        ("CMAKE_GENERATOR_INSTANCE:INTERNAL=C:/Program Files/Microsoft Visual Studio/18/Community`n" +
         "CMAKE_GENERATOR:INTERNAL=$gerador`n" +
         "CMAKE_GENERATOR_PLATFORM:INTERNAL=x64`n"))
    [System.IO.File]::WriteAllText([System.IO.Path]::Combine($ids, 'CMakeCXXCompiler.cmake'), 'x')
    [System.IO.File]::WriteAllText([System.IO.Path]::Combine($release, 'biblia_estudo.exe'), 'x')
    return $p
}
function Sumiu([string]$p) { if (Test-Path -LiteralPath $p) { throw "ficou $p" } }
function Ficou([string]$p) { if (-not (Test-Path -LiteralPath $p)) { throw "apagou $p" } }

Teste 'gerador do CMake: le o da pasta' {
    Igual 'Visual Studio 18 2026' (Ler-GeradorCMake (PastaCompilacao))
}
Teste 'gerador do CMake sem compilacao anterior: nada' {
    if ($null -ne (Ler-GeradorCMake (Join-Path $tmp 'nao-existe'))) { throw 'leu algo' }
}
Teste 'gerador do CMake sem a linha do gerador: nada' {
    $p = PastaCompilacao 'semgerador'
    [System.IO.File]::WriteAllText((Join-Path $p 'CMakeCache.txt'), "CMAKE_GENERATOR_INSTANCE:INTERNAL=x`n")
    if ($null -ne (Ler-GeradorCMake $p)) { throw 'leu algo' }
}
Teste 'compilacao Windows anterior: apaga a pasta inteira e so ela' {
    $vizinha = PastaCompilacao 'arm64'
    $p = PastaCompilacao
    Limpar-CompilacaoWindows $p -pausa 0
    Sumiu $p
    Ficou (Join-Path $vizinha 'CMakeCache.txt')
}
Teste 'sem compilacao anterior: nao faz nada' {
    Limpar-CompilacaoWindows (Join-Path $tmp 'nao-existe') -pausa 0
}
Teste 'arquivos somente leitura: apaga mesmo assim' {
    $p = PastaCompilacao
    Set-ItemProperty -LiteralPath (Join-Path $p 'CMakeCache.txt') -Name IsReadOnly -Value $true
    Set-ItemProperty -LiteralPath (Join-Path $p 'runner\Release\biblia_estudo.exe') -Name IsReadOnly -Value $true
    Limpar-CompilacaoWindows $p -pausa 0
    Sumiu $p
}
Teste 'pasta com colchetes no nome: apaga a certa e so ela' {
    $vizinha = PastaCompilacao 'x1'
    $p = PastaCompilacao 'x[1]'
    Limpar-CompilacaoWindows $p -pausa 0
    Sumiu $p
    Ficou (Join-Path $vizinha 'CMakeCache.txt')
    $p = PastaCompilacao 'w[1]'
    Limpar-CompilacaoWindows $p -pausa 0
    Sumiu $p
}
Teste 'arquivo preso por um instante: tenta de novo e apaga' {
    $p = PastaCompilacao
    $script:vezes = 0
    $apagar = {
        param($caminho)
        $script:vezes++
        if ($script:vezes -eq 1) { throw 'The process cannot access the file' }
        Remove-Item -LiteralPath $caminho -Recurse -Force -ErrorAction Stop
    }
    Limpar-CompilacaoWindows $p -apagar $apagar -pausa 0
    Sumiu $p
    Igual 2 $script:vezes
}
Teste 'arquivo sempre preso: recusa dizendo o que fechar, sem compilar' {
    $p = PastaCompilacao
    $script:vezes = 0
    $apagar = { param($caminho) $script:vezes++; throw 'The process cannot access the file' }
    Deve-Falhar { Limpar-CompilacaoWindows $p -apagar $apagar -pausa 0 } 'Feche o app'
    Igual 3 $script:vezes
    # A mensagem traz o erro do Windows, que diz qual arquivo esta preso.
    Deve-Falhar { Limpar-CompilacaoWindows $p -apagar $apagar -pausa 0 } 'cannot access the file'
    Ficou $p
}
Teste 'app aberto da pasta (so no Windows): recusa dizendo o que fechar' {
    if ([System.Environment]::OSVersion.Platform -ne 'Win32NT') { return }   # no Linux, arquivo aberto se apaga
    $p = PastaCompilacao
    $exe = Join-Path $p 'runner\Release\biblia_estudo.exe'
    $aberto = [System.IO.File]::Open($exe, 'Open', 'Read', 'None')
    try {
        Deve-Falhar { Limpar-CompilacaoWindows $p -pausa 0 } 'Feche o app'
    } finally {
        $aberto.Close()
    }
}
Teste 'mesmo Visual Studio: sem aviso' {
    if ($null -ne (Descrever-TrocaVisualStudio 'Visual Studio 18 2026' 'Visual Studio 18 2026')) { throw 'avisou' }
}
Teste 'primeira compilacao: sem aviso' {
    if ($null -ne (Descrever-TrocaVisualStudio $null 'Visual Studio 18 2026')) { throw 'avisou' }
}
Teste 'Visual Studio mais antigo que o anterior: avisa e manda ver o Installer' {
    $aviso = Descrever-TrocaVisualStudio 'Visual Studio 18 2026' 'Visual Studio 17 2022'
    if ($aviso -notlike '*compilado com Visual Studio 17 2022*usou Visual Studio 18 2026*') { throw "aviso: $aviso" }
    if ($aviso -notlike '*Visual Studio Installer*') { throw "sem o Installer: $aviso" }
}
Teste 'Visual Studio mais novo que o anterior: so informa' {
    $aviso = Descrever-TrocaVisualStudio 'Visual Studio 17 2022' 'Visual Studio 18 2026'
    if ($aviso -notlike '*compilado com Visual Studio 18 2026*') { throw "aviso: $aviso" }
    if ($aviso -like '*Installer*') { throw "mandou ver o Installer: $aviso" }
}

# Um Visual Studio de mentira, com os conjuntos de ferramentas do C++ em
# VC\Tools\MSVC; os de $comAtl com o atlbase.h. $padrao e o conteudo de
# Microsoft.VCToolsVersion.default.txt ($null: sem o arquivo).
function VisualStudio([string]$nome, [string[]]$versoes, [string[]]$comAtl = @(), $padrao = $null) {
    $vs = [System.IO.Path]::Combine($tmp, 'vs', $nome)
    if (Test-Path -LiteralPath $vs) { Remove-Item -LiteralPath $vs -Recurse -Force }
    foreach ($v in $versoes) {
        $inc = [System.IO.Path]::Combine($vs, 'VC', 'Tools', 'MSVC', $v, 'include')
        [void][System.IO.Directory]::CreateDirectory($inc)
        if ($comAtl -contains $v) {
            $atl = [System.IO.Path]::Combine($vs, 'VC', 'Tools', 'MSVC', $v, 'atlmfc', 'include')
            [void][System.IO.Directory]::CreateDirectory($atl)
            [System.IO.File]::WriteAllText([System.IO.Path]::Combine($atl, 'atlbase.h'), 'x')
        }
    }
    if ($null -ne $padrao) {
        $aux = [System.IO.Path]::Combine($vs, 'VC', 'Auxiliary', 'Build')
        [void][System.IO.Directory]::CreateDirectory($aux)
        [System.IO.File]::WriteAllText([System.IO.Path]::Combine($aux, 'Microsoft.VCToolsVersion.default.txt'), $padrao)
    }
    return $vs
}
# A pasta de compilacao configurada com o Visual Studio em $vs ($instancia: a
# linha como o CMake grava, se for outra).
function CompiladoCom([string]$vs, [string]$instancia = $vs) {
    $p = PastaCompilacao
    [System.IO.File]::WriteAllText([System.IO.Path]::Combine($p, 'CMakeCache.txt'),
        ("CMAKE_GENERATOR:INTERNAL=Visual Studio 17 2022`n" +
         "CMAKE_GENERATOR_INSTANCE:INTERNAL=$instancia`n"))
    return $p
}

Teste 'falha no Windows, Visual Studio sem ATL: diz o que instalar' {
    $vs = VisualStudio 'sem' @('14.44.35207') @() "14.44.35207`r`n"
    $texto = Descrever-FaltaAtl (CompiladoCom $vs)
    if ($texto -notlike "*ATL do C++*$vs*Visual Studio Installer*Componentes individuais*") { throw "texto: $texto" }
}
Teste 'falha no Windows, Visual Studio com ATL: nada a dizer' {
    $vs = VisualStudio 'com' @('14.44.35207') @('14.44.35207') "14.44.35207`r`n"
    if ($null -ne (Descrever-FaltaAtl (CompiladoCom $vs))) { throw 'disse que falta' }
}
Teste 'ATL so num conjunto de ferramentas antigo: o padrao e que vale' {
    $vs = VisualStudio 'antigo' @('14.38.33130', '14.44.35207') @('14.38.33130') '14.44.35207'
    if ($null -eq (Descrever-FaltaAtl (CompiladoCom $vs))) { throw 'nao disse que falta' }
}
Teste 'sem o arquivo do conjunto padrao: qualquer um com ATL serve' {
    $vs = VisualStudio 'semPadrao' @('14.38.33130', '14.44.35207') @('14.38.33130')
    if ($null -ne (Descrever-FaltaAtl (CompiladoCom $vs))) { throw 'disse que falta' }
    $vs = VisualStudio 'semPadrao2' @('14.44.35207')
    if ($null -eq (Descrever-FaltaAtl (CompiladoCom $vs))) { throw 'nao disse que falta' }
}
Teste 'arquivo do conjunto padrao vazio: qualquer um serve' {
    $vs = VisualStudio 'vazio' @('14.44.35207') @('14.44.35207') ''
    if ($null -ne (Descrever-FaltaAtl (CompiladoCom $vs))) { throw 'disse que falta' }
}
Teste 'instancia gravada com a versao junto: usa so o caminho' {
    $vs = VisualStudio 'comVersao' @('14.44.35207') @() '14.44.35207'
    if ($null -eq (Descrever-FaltaAtl (CompiladoCom $vs "$vs,version=17.14.36414.22"))) { throw 'nao disse que falta' }
}
Teste 'falha sem cache, sem instancia ou com o Visual Studio sumido: nada a dizer' {
    if ($null -ne (Descrever-FaltaAtl (Join-Path $tmp 'nao-existe'))) { throw 'sem cache' }
    $p = PastaCompilacao
    [System.IO.File]::WriteAllText((Join-Path $p 'CMakeCache.txt'), "CMAKE_GENERATOR:INTERNAL=Visual Studio 17 2022`n")
    if ($null -ne (Descrever-FaltaAtl $p)) { throw 'sem instancia' }
    if ($null -ne (Descrever-FaltaAtl (CompiladoCom (Join-Path $tmp 'vs-sumiu')))) { throw 'sumido' }
}

# --- chave de assinatura ---
# Uma pasta android\app de mentira e o key.properties ao lado dela.
function PastaAndroid([string]$nome) {
    $p = [System.IO.Path]::Combine($tmp, 'chave', $nome)
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
    [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine($p, 'app'))
    return $p
}
function Escrever([string]$arquivo, [string[]]$linhas) {
    [System.IO.File]::WriteAllText($arquivo, (($linhas -join "`n") + "`n"))
}
# Faz o papel do keytool: so cria o arquivo da chave.
$geradorFalso = {
    param($kt, $chave, $senha, $nome)
    $script:geradas++
    [System.IO.File]::WriteAllText($chave, 'chave')
    'saida do keytool'
}

Teste 'key.properties: le como o Java (barra dupla vira uma, barra sozinha some)' {
    $a = PastaAndroid 'ler'
    $f = Join-Path $a 'key.properties'
    Escrever $f @('# comentario', 'storeFile=C:\\Users\\WiseJr\\biblia.jks', 'keyAlias : biblia', 'outro=C:\Users')
    $p = Ler-Chave $f
    Igual 'C:\Users\WiseJr\biblia.jks' $p['storeFile']
    Igual 'biblia' $p['keyAlias']
    Igual 'C:Users' $p['outro']
    if ($null -ne (Ler-Chave (Join-Path $a 'nao-existe'))) { throw 'leu algo' }
}
Teste 'sem key.properties: recusa e diz como criar a chave' {
    $a = PastaAndroid 'sem'
    Deve-Falhar { Conferir-Chave (Join-Path $a 'key.properties') (Join-Path $a 'app') } '-NovaChave'
}
Teste 'key.properties sem storeFile: recusa' {
    $a = PastaAndroid 'semstore'
    $f = Join-Path $a 'key.properties'
    Escrever $f @('storePassword=x', 'keyAlias=biblia', 'keyPassword=x')
    Deve-Falhar { Conferir-Chave $f (Join-Path $a 'app') } 'storeFile'
}
Teste 'chave sumiu do lugar: recusa dizendo onde ela deveria estar' {
    $a = PastaAndroid 'sumiu'
    $f = Join-Path $a 'key.properties'
    $chave = Join-Path $a 'biblia-estudo.jks'
    Escrever $f @("storeFile=$($chave.Replace('\', '/'))", 'storePassword=x', 'keyAlias=biblia', 'keyPassword=x')
    Deve-Falhar { Conferir-Chave $f (Join-Path $a 'app') } "nao esta em $($chave.Replace('\', '/'))"
    Deve-Falhar { Conferir-Chave $f (Join-Path $a 'app') } '-NovaChave'
    # Uma pasta com o nome da chave nao e a chave.
    [void][System.IO.Directory]::CreateDirectory($chave)
    Deve-Falhar { Conferir-Chave $f (Join-Path $a 'app') } 'nao esta em'
}
Teste 'chave no lugar: aceita, inclusive com caminho relativo a android\app' {
    $a = PastaAndroid 'certa'
    $f = Join-Path $a 'key.properties'
    [System.IO.File]::WriteAllText((Join-Path $a 'biblia-estudo.jks'), 'chave')
    Escrever $f @('storeFile=../biblia-estudo.jks', 'storePassword=x', 'keyAlias=biblia', 'keyPassword=x')
    $c = Conferir-Chave $f (Join-Path $a 'app')
    if (-not (Test-Path -LiteralPath $c)) { throw "devolveu $c" }
    Escrever $f @('storeFile=../biblia-estudo.jks', 'storePassword=x', 'keyAlias=biblia')
    Deve-Falhar { Conferir-Chave $f (Join-Path $a 'app') } 'keyPassword'
}
Teste 'senha nova: 48 letras e numeros, outra a cada vez' {
    $s1 = Nova-Senha
    $s2 = Nova-Senha
    if ($s1 -notmatch '^[0-9a-f]{48}$') { throw "senha: $s1" }
    if ($s1 -eq $s2) { throw 'repetiu' }
}
Teste 'keytool: acha no lugar indicado; sem nenhum, diz onde procurar' {
    $kt = Join-Path (PastaAndroid 'kt') 'keytool.exe'
    [System.IO.File]::WriteAllText($kt, 'x')
    Igual $kt (Achar-Keytool @((Join-Path $tmp 'nao-existe.exe'), $kt) $false)
    Deve-Falhar { Achar-Keytool @((Join-Path $tmp 'nao-existe.exe')) $false } 'flutter doctor -v'
}
Teste 'chave nova sem key.properties: cria, aponta e deixa copia na pasta da chave' {
    $a = PastaAndroid 'nova'
    $f = Join-Path $a 'key.properties'
    $pasta = Join-Path $a 'Chave da Biblia'
    $script:geradas = 0
    $c = Criar-Chave -pasta $pasta -arquivo $f -pastaApp (Join-Path $a 'app') -keytool 'kt' -gerar $geradorFalso
    Igual 1 $script:geradas
    if ($c -isnot [string]) { throw "devolveu mais que o caminho: $c" }
    Igual (Join-Path $pasta 'biblia-estudo.jks') $c
    Igual $c (Conferir-Chave $f (Join-Path $a 'app')).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $p = Ler-Chave $f
    if ($p['storeFile'] -match '\\') { throw "barra invertida: $($p['storeFile'])" }
    if ($p['storePassword'] -notmatch '^[0-9a-f]{48}$') { throw 'sem senha' }
    Igual $p['storePassword'] $p['keyPassword']
    Igual 'biblia' $p['keyAlias']
    Igual ((Get-Content -LiteralPath $f) -join '|') ((Get-Content -LiteralPath (Join-Path $pasta 'key.properties')) -join '|')
}
Teste 'chave nova com a antiga em ordem: recusa sem criar nada' {
    $a = PastaAndroid 'emordem'
    $f = Join-Path $a 'key.properties'
    [System.IO.File]::WriteAllText((Join-Path $a 'antiga.jks'), 'chave')
    Escrever $f @('storeFile=../antiga.jks', 'storePassword=x', 'keyAlias=biblia', 'keyPassword=x')
    $script:geradas = 0
    Deve-Falhar { Criar-Chave -pasta (Join-Path $a 'nova') -arquivo $f -pastaApp (Join-Path $a 'app') -keytool 'kt' -gerar $geradorFalso } 'nao crio outra'
    Igual 0 $script:geradas
    Igual 'storeFile=../antiga.jks' (Get-Content -LiteralPath $f -TotalCount 1)
}
Teste 'chave nova quando a antiga sumiu: guarda o key.properties antigo na pasta nova' {
    $a = PastaAndroid 'perdida'
    $f = Join-Path $a 'key.properties'
    Escrever $f @('storeFile=C:/sumiu/biblia-estudo.jks', 'storePassword=antiga', 'keyAlias=biblia', 'keyPassword=antiga')
    $pasta = Join-Path $a 'nova'
    $null = Criar-Chave -pasta $pasta -arquivo $f -pastaApp (Join-Path $a 'app') -keytool 'kt' -gerar $geradorFalso
    Igual 'antiga' (Ler-Chave (Join-Path $pasta 'key.properties.antiga'))['storePassword']
    if ((Ler-Chave $f)['storePassword'] -eq 'antiga') { throw 'nao trocou' }
}
Teste 'chave nova onde ja ha um arquivo de chave: recusa sem apagar' {
    $a = PastaAndroid 'jaexiste'
    $pasta = Join-Path $a 'nova'
    [void][System.IO.Directory]::CreateDirectory($pasta)
    [System.IO.File]::WriteAllText((Join-Path $pasta 'biblia-estudo.jks'), 'outra')
    $script:geradas = 0
    Deve-Falhar { Criar-Chave -pasta $pasta -arquivo (Join-Path $a 'key.properties') -pastaApp (Join-Path $a 'app') -keytool 'kt' -gerar $geradorFalso } 'Ja existe'
    Igual 0 $script:geradas
    Igual 'outra' ([System.IO.File]::ReadAllText((Join-Path $pasta 'biblia-estudo.jks')))
}
Teste 'keytool falhou: o key.properties fica como estava' {
    $a = PastaAndroid 'falhou'
    $f = Join-Path $a 'key.properties'
    Escrever $f @('storeFile=C:/sumiu/biblia-estudo.jks', 'storePassword=antiga', 'keyAlias=biblia', 'keyPassword=antiga')
    $falha = { param($kt, $chave, $senha, $nome) throw 'O keytool falhou (codigo 1).' }
    Deve-Falhar { Criar-Chave -pasta (Join-Path $a 'nova') -arquivo $f -pastaApp (Join-Path $a 'app') -keytool 'kt' -gerar $falha } 'keytool falhou'
    Igual 'antiga' (Ler-Chave $f)['storePassword']
}
Teste 'chave nova com o keytool de verdade (se houver): abre com a senha gravada' {
    $kt = $null
    try { $kt = Achar-Keytool } catch { return }
    $a = PastaAndroid 'real'
    $f = Join-Path $a 'key.properties'
    $c = Criar-Chave -pasta (Join-Path $a 'Chave da Biblia') -arquivo $f -pastaApp (Join-Path $a 'app') -keytool $kt
    if ($c -isnot [string]) { throw "devolveu mais que o caminho: $c" }
    $p = Ler-Chave $f
    $ErrorActionPreference = 'Continue'
    $lista = & $kt -list -keystore $c -storepass $p['storePassword'] 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $lista -notmatch 'biblia') { throw "keytool -list: $lista" }
}

Remove-Item $tmp -Recurse -Force
if ($script:falhas -gt 0) {
    Write-Host "$script:falhas teste(s) falharam."
    exit 1
}
Write-Host 'Todos os testes passaram.'
