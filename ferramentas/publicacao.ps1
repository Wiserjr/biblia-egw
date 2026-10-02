# Conferencias do publicar.ps1, num arquivo proprio para poderem ser testadas
# (ferramentas/test_publicacao.ps1). Mensagens sem acento: o Windows
# PowerShell 5.1 le este arquivo como ANSI.
#
# A regra que elas garantem:
#   1. Publicar so do main, sem alteracoes por salvar nesta pasta.
#   2. PR aberto no GitHub: perguntar se entra (e mesclar) antes de publicar.
#   3. Trazer o main do GitHub (git pull) antes de compilar.
#   4. Versao nova = pubspec com versao maior E as novidades dela em
#      NOTAS_DA_VERSAO.md. Republicar a mesma versao so com -Republicar.

# Deixa o main desta pasta igual ao do GitHub, mesclando antes os PRs abertos
# que a pessoa aprovar. $perguntar recebe o texto da pergunta e devolve a
# resposta (Read-Host no uso normal; outra coisa nos testes).
function Sincronizar-Main {
    param(
        [string]$gh,
        [string]$repo,
        [scriptblock]$perguntar = { param($texto) Read-Host $texto }
    )

    $ramo = git rev-parse --abbrev-ref HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Esta pasta nao e um repositorio git.' }
    if ("$ramo".Trim() -ne 'main') {
        throw "Esta pasta esta no ramo '$ramo'. Publique do main: git checkout main"
    }

    $mudancas = @(git status --porcelain --untracked-files=no)
    if ($LASTEXITCODE -ne 0) { throw 'git status falhou.' }
    if ($mudancas.Count -gt 0) {
        throw ("Ha alteracoes nao salvas nesta pasta:`n  " + ($mudancas -join "`n  ") +
            "`nGuarde com 'git stash' (ou desfaca) e rode de novo.")
    }

    # O gh responde em UTF-8; sem isto, os acentos dos titulos saem trocados
    # no Windows PowerShell 5.1.
    # (Sem console de verdade, trocar a codificacao falha; ai fica como esta.)
    $codificacao = [Console]::OutputEncoding
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }
    try {
        $json = & $gh pr list --repo $repo --state open --base main --json 'number,title,isDraft'
    } finally {
        try { [Console]::OutputEncoding = $codificacao } catch { }
    }
    if ($LASTEXITCODE -ne 0) { throw 'Nao consegui listar os PRs abertos (gh pr list).' }
    # No PowerShell 5.1 o ConvertFrom-Json entrega a lista inteira como um
    # objeto so; no 7, item a item (e nada para "[]"). Assim funciona nos dois.
    $lista = "$json" | ConvertFrom-Json
    $prs = @(@($lista) | Where-Object { $null -ne $_ })
    foreach ($pr in $prs) {
        $resposta = & $perguntar ("PR #$($pr.number) aberto: $($pr.title)`n" +
            'Mesclar e incluir nesta versao? (S/N)')
        if ("$resposta".Trim() -match '^[sSyY]') {
            if ($pr.isDraft) {
                & $gh pr ready $pr.number --repo $repo
                if ($LASTEXITCODE -ne 0) { throw "Nao consegui tirar o PR #$($pr.number) do rascunho." }
            }
            & $gh pr merge $pr.number --repo $repo --merge
            if ($LASTEXITCODE -ne 0) {
                throw "Nao consegui mesclar o PR #$($pr.number). Veja no GitHub se ha conflito."
            }
            Write-Output "PR #$($pr.number) mesclado."
        } else {
            Write-Warning "O PR #$($pr.number) fica de fora desta versao."
        }
    }

    Write-Output 'Trazendo o main do GitHub...'
    git pull --ff-only origin main
    if ($LASTEXITCODE -ne 0) {
        throw ('O main desta pasta e o do GitHub tem commits diferentes. ' +
            "Rode 'git pull origin main', resolva o que o git pedir e rode de novo.")
    }
}

# Le "version: 1.2.0+3" do pubspec.yaml.
function Ler-Versao([string]$pubspec = 'pubspec.yaml') {
    $linha = Select-String -Path $pubspec -Pattern '^version:\s*(.+)$' | Select-Object -First 1
    if (-not $linha) { throw "Nao achei a linha version: no $pubspec" }
    $partes = $linha.Matches[0].Groups[1].Value.Trim().Split('+')
    if ($partes.Count -lt 2 -or $partes[1] -notmatch '^\d+$') {
        throw 'O version: do pubspec precisa do numero depois do + (ex.: 1.0.1+2).'
    }
    $codigo = [int]$partes[1]
    # Com --split-per-abi o Flutter soma 1000 x arquitetura a este numero; os
    # apps comparam so a base, que por isso tem de ficar abaixo de 1000.
    if ($codigo -ge 1000) { throw "O numero depois do + passou de 999 ($codigo)." }
    return [pscustomobject]@{ nome = $partes[0]; codigo = $codigo }
}

# Recusa publicar uma versao que nao seja nova, a menos que se peca para
# republicar a mesma. $publicado e o manifesto que os apps leem hoje (ou null).
function Conferir-Versao {
    param(
        [string]$versao,
        [int]$codigo,
        $publicado,
        [bool]$releaseExiste,
        [bool]$republicar
    )
    $mesma = $releaseExiste -or ($publicado -and $publicado.versionName -eq $versao)
    if ($mesma -and -not $republicar) {
        throw ("A versao $versao ja esta publicada, e o pubspec.yaml continua nela. " +
            'Para lancar uma versao nova, ela precisa estar no pubspec (normalmente vem ' +
            'no PR, que este script oferece mesclar). Para so refazer os arquivos da ' +
            'mesma versao, rode com -Republicar.')
    }
    if ($publicado -and $publicado.versionName -ne $versao -and $codigo -le [int]$publicado.versionCode) {
        throw ("A versao publicada ($($publicado.versionName)) ja tem versionCode " +
            "$($publicado.versionCode). Suba o numero depois do + no pubspec.")
    }
}

# As notas da release precisam falar da versao que sai.
function Conferir-Notas([string]$arquivo, [string]$versao) {
    if (-not (Test-Path $arquivo)) { throw "Falta $arquivo (as notas da release)." }
    $texto = [System.IO.File]::ReadAllText((Resolve-Path $arquivo))
    if (-not $texto.Contains($versao)) {
        throw ("$arquivo nao fala da versao $versao. Escreva no topo dele o que ha " +
            'de novo nesta versao e rode de novo.')
    }
}
