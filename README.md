# Bíblia de Estudo — com Ellen G. White e os pioneiros

App para **Android e Windows** que junta, em cada versículo:

- o texto em **12 traduções** (ARA, NAA, ARC, ACF, NVI, NVT, NTLH, KJA, ACRF,
  ARIB e as duas edições da Bíblia Livre), com as palavras de Jesus em
  vermelho e comparação lado a lado;
- os **trechos de Ellen G. White** que citam o versículo — 95 livros —, e os
  capítulos que narram a passagem ("Este capítulo é baseado em Mateus 4:1-11");
- os **pioneiros adventistas** (11 livros), entre eles *Daniel e Apocalipse*
  de Urias Smith, ligado **versículo a versículo**;
- **citações do Antigo Testamento no Novo** (e a recíproca), **passagens
  paralelas** (sinóticos; Samuel/Reis/Crônicas) e **referências cruzadas**
  ordenadas por relevância;
- **introdução a cada livro**: autor, data, local, tema, versículo-chave,
  esboço, mensagem, Cristo no livro e onde Ellen G. White trata dele;
- **introduções Andrews em português**: contexto, orientação literária e
  perguntas nos 39 livros do Antigo Testamento, com fonte e página. Isaías
  recebe uma síntese ampliada a partir de dois PDFs fornecidos. São textos
  editoriais, identificados como sínteses, com perguntas de aplicação próprias.
  Dez introduções também recebem esboços e explicações adicionais a partir das
  digitalizações em português da Bíblia de Estudo Andrews fornecidas pelo usuário;
- **guia de leitura da biblioteca EGW**: plano por livro, seleção de livros
  ou pelos 95 livros do catálogo, com metas por sessão. Conclusão de capítulos,
  retomada de página, posição e zoom e progresso na cópia de segurança. Os
  30 livros sem sumário indexado entram como leitura integral, explicitamente
  indicada; o plano e os lugares são locais, sem sincronização pela conta;
- **notas de estudo** em toda a Bíblia: 3.571 notas nos 1.189 capítulos (ver
  *Notas*, abaixo);
- **mapas**: 18 mapas temáticos (Abraão, Êxodo, conquista, reinos, Elias e
  Eliseu, impérios de Daniel, exílio, Palestina de Jesus, as três viagens de
  Paulo e a viagem a Roma, as sete igrejas) e 1.156 lugares bíblicos com nome
  em português; cada versículo mostra num minimapa os lugares que cita;
- **guia sinótico dos evangelhos**: 173 episódios em ordem cronológica, com
  a passagem de Mateus, Marcos, Lucas e João lado a lado, e o capítulo de
  *O Desejado de Todas as Nações* ou de *Parábolas de Jesus* que narra cada
  um; nos evangelhos, o painel de estudo mostra o episódio nos outros três;
- **índice temático**: 50 temas em 6 categorias (Deus, criação, salvação,
  vida cristã, igreja, profecia), com versículos e os capítulos de Ellen G.
  White que mais os citam;
- **estudos bíblicos**: 16 estudos em perguntas e respostas, com a resposta
  escondida até tocar;
- **sete estudos em PDF selecionados**: catálogo fechado das edições aprovadas,
  com sete downloads oficiais, preparação automática de ZIPs, leitura offline
  e interação por pergunta em 119 lições e 14 semanas complementares,
  respostas e conclusão de lições salvas no aparelho, retomada da última página
  e exportação das respostas. Veja [ESTUDOS_IMPORTADOS.md](ESTUDOS_IMPORTADOS.md);
- marcações com cores, anotações, busca por referência ou por palavras;
- **planos de leitura**, entre eles o **Reavivados por Sua Palavra** no
  mesmo capítulo que a igreja (um capítulo por dia desde 17/04/2025; o app
  calcula o capítulo pela data, sem internet), com a leitura de hoje no alto
  do leitor, calendário, comentário do dia no site e lembrete diário;
- **versículo do dia** (o calendário do Louvor JA, só referências; o texto
  sai do banco na tradução escolhida) e **versículo em imagem**: o cartão
  quadrado do Louvor JA, com 21 fotos escolhidas pelo assunto do versículo,
  para compartilhar ou salvar em PNG 1080×1080;
- **atualização automática** no Android e no Windows.

No celular, tocar num versículo abre o painel de estudo por baixo; no PC (ou
tablet deitado), o painel fica à direita, como as notas de uma Bíblia de
estudo aberta. Ali ele abre e fecha pelo botão no alto da tela, e a
divisória entre o texto e o painel se arrasta para mudar a largura.

## Números

| | |
|---|---|
| Ligações versículo → parágrafo de Ellen G. White e pioneiros | 43.281 |
| Parágrafos indexados | 31.877 em 106 livros |
| Capítulos "baseados em" (narrativa da passagem) | 451 |
| Seções de comentário versículo a versículo (Urias Smith) | 273 |
| Referências cruzadas (OpenBible.info, ≥ 3 votos) | 213.579 |
| Citações AT ↔ NT detectadas | 368 (+ 284 alusões) |
| Passagens paralelas | 799 |
| Lugares bíblicos com coordenadas | 1.156, citados em 8.368 versículos |
| Mapas temáticos | 18 |
| Temas / estudos bíblicos | 50 / 16 |
| Guia sinótico | 173 episódios; 139 ligados a capítulos de Ellen G. White |
| Notas de estudo | 3.571, em todos os 1.189 capítulos |

## Como os livros de Ellen G. White entram sem serem redistribuídos

Os e-books do [Centro de Pesquisas Ellen G. White](https://centrowhite.org.br/downloads/ebooks/)
e da [Adventist Pioneer Library](https://centrowhite.org.br/downloads/ebooks-apl/)
são gratuitos, mas a licença deles é **de uso pessoal e proíbe
redistribuir**. Por isso o app **não leva o texto de nenhum livro**:

1. No PC, `ferramentas/indexar_obras.py` baixa os PDFs, lê cada um com o
   PDFium e acha toda citação bíblica ("Mateus 4:2-4", "1 João 3:2",
   "Apocalipse 3:7, 8"). Para cada parágrafo que cita, guarda **só a posição**:
   página do PDF e intervalo de caracteres.
2. O app leva esse índice (4 MB). Quando a pessoa quer ler um trecho, o app
   baixa o PDF **do próprio site do Centro White**, para o aparelho dela —
   o mesmo download que faria pelo navegador — e recorta o parágrafo ali.
3. O leitor de PDF do app (pdfrx) usa o **mesmo PDFium** do indexador; o
   teste `test/indice_test.dart` confere que os dois recortam exatamente o
   mesmo parágrafo.

Se o Centro White trocar um PDF por outra edição, o app percebe (cada livro
tem tamanho e SHA-256 registrados) e passa a achar o parágrafo pela própria
citação nas páginas vizinhas. Para voltar à posição exata, rode o indexador
de novo e publique uma versão.

> Antes de divulgar amplamente, vale pedir ao Centro White uma confirmação
> de que esse uso (índice + download pelo próprio usuário) está de acordo com
> eles. Se autorizarem a redistribuição, dá para embutir os textos e o app
> funciona sem baixar nada.

## Estrutura

```
lib/dados/      bancos, consultas, PDFs, atualização
  lib/telas/      leitor, painel de estudo, biblioteca, busca, ajustes
  android/        app Android (Kotlin: instalador da atualização)
  windows/        app Windows
  assets/         biblia.db.gz (texto) e estudo.db.gz (estudo)
  ferramentas/    scripts Python que geram os dois bancos
  test/           testes (Dart); ferramentas/test_*.py (Python)
```

Até outubro de 2026 o app morava na pasta `biblia/` do repositório
[Wiserjr/louvorja](https://github.com/Wiserjr/louvorja); o histórico dos
commits veio junto na separação. Do Louvor JA ele ainda reaproveita as
traduções: o `construir_biblia.py` baixa o `assets/louvorja_pt.db.gz` daquele
repositório para `ferramentas/cache/` (ou recebe o caminho do arquivo).

## Ferramentas (gerar os bancos)

```bash
pip install pypdfium2           # e anthropic, para as notas
python ferramentas/construir_biblia.py   # texto, a partir do catálogo do Louvor JA (baixa)
python ferramentas/indexar_obras.py      # baixa os 106 PDFs (~155 MB) e indexa
pip install shapely pyshp
python ferramentas/construir_mapas.py    # lugares (OpenBible) e contornos (Natural Earth)
python ferramentas/construir_estudo.py   # junta tudo em assets/estudo.db.gz
```

Os PDFs e o índice intermediário ficam em `ferramentas/cache/` (fora do git).

Para acrescentar um livro: inclua-o em `ferramentas/obras.py` (arquivo, sigla,
prioridade) e rode os dois últimos comandos.

As introduções estão em `ferramentas/introducoes.json` — texto escrito para
este app, fácil de revisar e corrigir. Do mesmo jeito:

- `ferramentas/mapas.json`: os mapas temáticos (título, período, descrição,
  lugares e rotas, pelos identificadores do OpenBible). Para um mapa novo,
  acrescente uma entrada e rode `construir_mapas.py` — ele recusa lugar
  desconhecido ou referência ilegível.
- `ferramentas/sinotico.json`: a harmonia dos evangelhos, por período. O
  capítulo de Ellen G. White de cada episódio é achado pelo "Este capítulo é
  baseado em..." do próprio livro — só a ligação declarada por ela conta.
- `ferramentas/temas.json`: temas e estudos bíblicos. Toda referência é
  conferida contra o texto da ARA no `construir_estudo.py`. As leituras de
  Ellen G. White de cada tema são calculadas: os capítulos que citam mais
  versículos do tema.

O nome em português de cada lugar é descoberto no próprio texto da ARA (a
palavra que mais se repete nos versículos do lugar e mais se parece com o nome
em inglês); as exceções estão em `NOMES`, no `construir_mapas.py`.

### Notas de estudo

Toda a Bíblia tem notas: 3.571, em todos os 1.189 capítulos dos 66 livros,
escritas para o app em `ferramentas/notas/NN-livro.txt`, num formato simples
de revisar:

```
# 4
1-2 | O Espírito conduziu Jesus ao deserto...
```

O `construir_estudo.py` confere que cada versículo existe e que toda
citação do tipo "O Desejado, cap. 12" ou "Parábolas de Jesus, cap. 2, "A
sementeira da verdade"" aponta para um capítulo que existe no índice (e, com
título, que o título bate). Para acrescentar ou corrigir uma nota, edite o
arquivo do livro e rode o `construir_estudo.py`, ou, sem os PDFs em
`ferramentas/cache/`, o `ferramentas/atualizar_notas.py`, que troca só as notas
no banco atual, com as mesmas conferências. O gerador abaixo só escreve
notas para capítulos que ainda não têm nenhuma.

`ferramentas/gerar_notas.py` escreve notas curtas por versículo com a API do
Claude, no estilo das Bíblias de estudo: contexto histórico, sentido das
palavras no original, ligação com outras passagens e com os trechos de Ellen
G. White indexados para o capítulo (citados pela sigla e página, sem
inventar). Um pedido por capítulo, pela Batches API (metade do preço).

```bash
export ANTHROPIC_API_KEY=...
python ferramentas/gerar_notas.py --simular --livros 43   # vê o pedido e os tokens
python ferramentas/gerar_notas.py --livros 40-43          # evangelhos primeiro
python ferramentas/construir_estudo.py
```

O app avisa, junto de cada nota, que ela é gerada por IA. **Revise antes de
publicar**, a começar pelos livros que mais serão lidos.

## Testes

```bash
flutter test
python -m unittest ferramentas/test_referencias_pt.py ferramentas/test_texto_pdf.py
```

O teste de paridade PDFium (Python) × pdfrx (app) roda quando os PDFs estão
em `ferramentas/cache/pdf` e `PDFIUM_PATH` aponta para um `libpdfium`, por
exemplo o do pypdfium2:

```bash
PDFIUM_PATH=$(python -c "import pypdfium2_raw,os;print(os.path.join(os.path.dirname(pypdfium2_raw.__file__),'libpdfium.so'))") flutter test
```

## Contas na nuvem

Com uma conta (Ajustes → Seus dados), marcações, anotações, realces nos livros
e o plano de leitura vão para o Firebase e aparecem nos outros aparelhos. Sem
conta, nada sai do aparelho. Código em `lib/dados/nuvem.dart` e
`lib/telas/conta.dart`; política em [PRIVACIDADE.md](PRIVACIDADE.md).

- Projeto Firebase `biblia-de-estudo-d2ce1`, do dono do app (login por e-mail
  e senha; Firestore em `southamerica-east1`). A chave da API em `nuvem.dart`
  não é senha: só diz qual é o projeto.
- O app fala com o Firebase pela API web (REST), igual no Android e no
  Windows, sem os kits nativos (o do Windows é beta).
- Cada marcação, anotação, realce e o plano são um documento em
  `usuarios/{uid}/itens/{chave}`, com o valor em JSON, `apagado` quando a
  pessoa apaga e `atualizado` (hora do servidor). O app traz só o que mudou
  desde a última vez e manda o que mudou no aparelho alguns segundos depois de
  cada mudança.
- Na primeira vez que a pessoa entra num aparelho, o que está nele se junta ao
  que está na nuvem, sem apagar nada (as regras do Restaurar cópia).
- As regras do Firestore (no console, Firestore → Regras) deixam cada conta
  ler e gravar só os próprios dados:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /usuarios/{uid}/{documento=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

O teste com o Firebase de verdade cria uma conta, sincroniza dois "aparelhos"
e exclui a conta no fim; só roda quando pedido:

```bash
FIREBASE_TESTE=1 flutter test test/nuvem_firebase_test.dart
```

## Atualização automática

Mesma regra dos outros apps: o app consulta um manifesto ao abrir e, havendo
versão nova, baixa e instala com a confirmação da pessoa. Também em
*Ajustes → Procurar atualização*.

- **Android**: APK por arquitetura, entregue ao `PackageInstaller`
  (`android/.../Atualizador.kt`, igual ao do Louvor JA).
- **Windows**: o app baixa o zip da release, confere (`versao.json` dentro
  dele), deixa um script (`scriptWindows` em `lib/dados/atualizacao.dart`) e
  se encerra. O script espera o `.exe` soltar (encerra o app à força depois
  de uns 10 segundos), copia os arquivos por cima e abre a versão nova, que
  avisa se a troca deu certo. Os dados (livros baixados, marcações) ficam em
  `AppData`, fora da pasta do programa. Até a 1.4.0 o script esperava com
  `tasklist | find`, que trava no Windows 11; quem tem essas versões
  reinicia o PC (o que fecha os scripts presos) e instala a 1.4.1 à mão uma
  vez. Ao abrir, a 1.4.1 apaga os temporários da atualização, o que também
  desarma algum script antigo que ainda esteja preso. Distribua o zip para ser extraído numa pasta do
  usuário (ex.: `%LOCALAPPDATA%\Biblia de Estudo`), não em *Arquivos de
  Programas*, onde o app não tem permissão de gravar.

Cada versão sai numa release `biblia-vX.Y.Z`, e o manifesto numa release
fixa, `biblia-atual`, regravada por último:

```
https://github.com/Wiserjr/biblia-egw/releases/download/biblia-atual/atualizacao-br.com.wisejr.bibliaestudo.json
```

### Publicar uma versão

**Regra:** uma versão nova só existe quando o `main` do GitHub tem a versão
nova no `pubspec.yaml` (o número depois do `+` também maior) e as novidades
dela no topo de `NOTAS_DA_VERSAO.md`. Isso normalmente vem num PR; publicar
antes de mesclar o PR publica de novo a versão antiga.

No PC com Windows, na raiz do repositório, rode só:

```powershell
powershell -ExecutionPolicy Bypass -File publicar.ps1
```

O script cuida do resto, nesta ordem, e para com uma explicação se algo não
estiver certo:

1. Confere que a pasta está no `main` e sem alterações por salvar. As
   mudanças que a compilação faz nos arquivos gerados pelo Flutter
   (`windows/flutter/generated_*`) ele mesmo desfaz.
2. Mostra cada PR aberto no GitHub e pergunta se ele entra nesta versão
   (S/N); os que entram, ele mescla.
3. Traz o `main` do GitHub (`git pull`). Se isso trouxer uma versão nova do
   próprio script, ele pede para rodar de novo.
4. Recusa publicar uma versão que já está publicada, e recusa notas que não
   falem da versão.
5. Analisa, testa, compila Android e Windows, publica a release e, por
   último, avisa os apps instalados.

Para refazer os arquivos de uma versão já publicada (mesmo número), use
`-Republicar`. As conferências têm testes próprios, sem tocar o GitHub:

```powershell
powershell -ExecutionPolicy Bypass -File ferramentas\test_publicacao.ps1
```

### Chave de assinatura

A atualização só entra por cima se o APK novo tiver **a mesma chave** do
instalado. Crie a chave **antes da primeira distribuição** e guarde cópia fora
do PC:

```powershell
keytool -genkey -v -keystore $env:USERPROFILE\biblia-estudo.jks -keyalg RSA -keysize 2048 -validity 10000 -alias biblia
```

e `android\key.properties` (fora do git):

```
storeFile=C:\\Users\\<voce>\\biblia-estudo.jks
storePassword=...
keyAlias=biblia
keyPassword=...
```

Sem ela, o release sai assinado com a chave de debug do PC que compilou.
