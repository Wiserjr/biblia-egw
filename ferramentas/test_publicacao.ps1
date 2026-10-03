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

Remove-Item $tmp -Recurse -Force
if ($script:falhas -gt 0) {
    Write-Host "$script:falhas teste(s) falharam."
    exit 1
}
Write-Host 'Todos os testes passaram.'
