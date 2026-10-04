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

Remove-Item $tmp -Recurse -Force
if ($script:falhas -gt 0) {
    Write-Host "$script:falhas teste(s) falharam."
    exit 1
}
Write-Host 'Todos os testes passaram.'
