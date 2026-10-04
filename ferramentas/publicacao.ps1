# Conferencias do publicar.ps1, num arquivo proprio para poderem ser testadas
# (ferramentas/test_publicacao.ps1). Mensagens sem acento: o Windows
# PowerShell 5.1 le este arquivo como ANSI.
#
# A regra que elas garantem:
#   1. Publicar so do main, sem alteracoes por salvar nesta pasta (as que a
#      compilacao faz nos arquivos gerados pelo Flutter sao desfeitas).
#   2. PR aberto no GitHub: perguntar se entra (e mesclar) antes de publicar.
#   3. Trazer o main do GitHub (git pull) antes de compilar.
#   4. Versao nova = pubspec com versao maior E as novidades dela em
#      NOTAS_DA_VERSAO.md. Republicar a mesma versao so com -Republicar.
#   5. Compilar o Windows do zero, com o Visual Studio que o Flutter escolher
#      na hora, e avisar quando ele mudar; se a compilacao falhar por falta do
#      ATL do C++ nesse Visual Studio, dizer o que instalar.

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
    # O Flutter regrava os registros de plugins a cada compilacao (no Windows,
    # com diferencas so dele); o conteudo vem do pubspec. Voltar ao do git nao
    # perde nada, e o git pull pode precisar atualiza-los.
    $geradosPeloFlutter = '^(windows|linux)/flutter/generated_plugin(s\.cmake|_registrant\.(cc|h))$'
    $gerados = @($mudancas | Where-Object { "$_".Length -gt 3 -and "$_".Substring(3) -match $geradosPeloFlutter })
    if ($gerados.Count -gt 0) {
        $caminhos = @($gerados | ForEach-Object { "$_".Substring(3) })
        git checkout HEAD $caminhos
        if ($LASTEXITCODE -ne 0) { throw 'Nao consegui desfazer os arquivos gerados pelo Flutter.' }
        Write-Output ('Desfeitas as mudancas da ultima compilacao em: ' + ($caminhos -join ', '))
        $mudancas = @($mudancas | Where-Object { $gerados -notcontains $_ })
    }
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

# O gerador do CMake (o Visual Studio) com que a pasta de compilacao Windows
# foi configurada, como "Visual Studio 18 2026"; $null se ela nao foi.
function Ler-GeradorCMake([string]$pasta = 'build\windows\x64') {
    $cache = Join-Path $pasta 'CMakeCache.txt'
    if (-not (Test-Path -LiteralPath $cache)) { return $null }
    $linha = Select-String -LiteralPath $cache -Pattern '^CMAKE_GENERATOR:INTERNAL=(.+)$' |
        Select-Object -First 1
    if (-not $linha) { return $null }
    return $linha.Matches[0].Groups[1].Value.Trim()
}

# Apaga a pasta da compilacao Windows anterior (build\windows\x64), para o
# Flutter compilar do zero. A cada compilacao o Flutter escolhe o Visual
# Studio de novo (o mais novo que esteja completo e com C++) e passa ao CMake
# o gerador dele; se a escolha muda de um dia para o outro (uma atualizacao
# do Visual Studio pela metade, um reinicio pendente), o CMake recusa a pasta
# configurada com o outro: "Does not match the generator used previously".
# Apagar a pasta inteira, e nao so o CMakeCache.txt, tambem garante que o zip
# (runner\Release) leve so arquivos desta compilacao, de um Visual Studio so.
# $apagar recebe o caminho e apaga (Remove-Item no uso normal; outra coisa
# nos testes). O antivirus ou o indexador as vezes seguram um arquivo por um
# instante; por isso tenta mais de uma vez.
function Limpar-CompilacaoWindows {
    param(
        [string]$pasta = 'build\windows\x64',
        [scriptblock]$apagar = { param($p) Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop },
        [int]$tentativas = 3,
        [int]$pausa = 2
    )
    $erro = ''
    for ($i = 1; $i -le $tentativas; $i++) {
        if (-not (Test-Path -LiteralPath $pasta)) { return }
        try {
            & $apagar $pasta
        } catch {
            $erro = $_.Exception.Message
            if ($i -lt $tentativas -and $pausa -gt 0) { Start-Sleep -Seconds $pausa }
        }
    }
    if (Test-Path -LiteralPath $pasta) {
        throw ("Nao consegui apagar ${pasta}: $erro`n" +
            'Feche o app (biblia_estudo.exe) e o Visual Studio, se estiverem abertos ' +
            'dessa pasta, e rode de novo.')
    }
}

# Texto do aviso quando o Windows saiu compilado com outro Visual Studio que o
# da compilacao anterior, ou $null. Se o de agora e mais antigo, o mais novo
# deixou de servir ao Flutter (ver Limpar-CompilacaoWindows).
function Descrever-TrocaVisualStudio([string]$antes, [string]$agora) {
    if (-not $antes -or -not $agora -or $antes -eq $agora) { return $null }
    $texto = "O Windows saiu compilado com $agora; a compilacao anterior usou $antes."
    $numero = { param($g) if ($g -match '^Visual Studio (\d+) ') { [int]$Matches[1] } else { 0 } }
    if ((& $numero $agora) -lt (& $numero $antes)) {
        $texto += (' O Flutter usa o Visual Studio estavel mais novo que esteja completo e com C++. ' +
            'Abra o Visual Studio Installer: o mais novo pode estar com atualizacao pela ' +
            'metade, pedindo reparo ou reinicio do PC. (flutter doctor -v mostra qual ele usa.)')
    }
    return $texto
}

# Depois de uma compilacao Windows que falhou: se o Visual Studio que o CMake
# usou (CMAKE_GENERATOR_INSTANCE, a pasta dele) nao tem o ATL do C++, devolve
# o que instalar; senao, $null. O plugin das notificacoes (o lembrete diario)
# inclui atlbase.h, e sem o ATL o erro do compilador (C1083) nao diz o que
# falta. Confere o conjunto de ferramentas padrao do Visual Studio, que e o
# que o MSBuild usa; sem o arquivo que o indica, aceita qualquer um.
function Descrever-FaltaAtl([string]$pasta = 'build\windows\x64') {
    $cache = Join-Path $pasta 'CMakeCache.txt'
    if (-not (Test-Path -LiteralPath $cache)) { return $null }
    $linha = Select-String -LiteralPath $cache -Pattern '^CMAKE_GENERATOR_INSTANCE:INTERNAL=(.+)$' |
        Select-Object -First 1
    if (-not $linha) { return $null }
    # Pode vir como "C:/caminho,version=17.14.1".
    $vs = $linha.Matches[0].Groups[1].Value.Split(',')[0].Trim()
    $msvc = Join-Path $vs 'VC\Tools\MSVC'
    if (-not (Test-Path -LiteralPath $msvc)) { return $null }
    $versoes = @(Get-ChildItem -LiteralPath $msvc -Directory | ForEach-Object { $_.Name })
    $padrao = Join-Path $vs 'VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt'
    if (Test-Path -LiteralPath $padrao) {
        $texto = Get-Content -LiteralPath $padrao -TotalCount 1
        if ($texto) { $versoes = @("$texto".Trim()) }
    }
    foreach ($v in $versoes) {
        if (Test-Path -LiteralPath (Join-Path $msvc "$v\atlmfc\include\atlbase.h")) { return $null }
    }
    return ("Falta o ATL do C++ no Visual Studio usado ($vs); o lembrete diario precisa " +
        "dele (atlbase.h). Abra o Visual Studio Installer, clique em Modificar nesse " +
        "Visual Studio e, em Componentes individuais, marque 'ATL do C++ para as " +
        "Ferramentas de Build ... mais recentes (x86 e x64)'. Depois rode de novo.")
}
