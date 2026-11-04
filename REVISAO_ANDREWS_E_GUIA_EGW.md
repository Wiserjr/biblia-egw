# Revisão Andrews e guia da biblioteca EGW

Preparação local da versão 1.8.0+10, em 6 de outubro de 2026.

## Fontes e cobertura

A comparação parte das 66 introduções de `ferramentas/introducoes.json` e do
banco distribuído em `assets/estudo.db.gz`. As introduções já ofereciam autor,
data, local, destinatários, tema, versículo-chave, esboço, mensagem, Cristo e
orientação para leitura em EGW. A principal oportunidade era acrescentar
contexto e instruções para ler cada gênero literário, acompanhados de fontes.

Foram consultados os PDFs locais fornecidos pelo usuário:

- `andrews-bible-commentary-angel-manuel-rodriguez-gen-edit_compress.pdf`:
  1.180 páginas de arquivo, cobrindo Gênesis a Malaquias. As páginas numeradas
  do comentário diferem das páginas do arquivo em 22 páginas nas introduções
  consultadas. Por exemplo: Gênesis, p. 138 impressa, é a página 160 do PDF;
  Isaías, p. 834 impressa, é a página 856 do PDF.
- `711938916-Isaiah-Andrews-Study-Bible.pdf`: 25 páginas de arquivo. A
  introdução ocupa as primeiras duas, com referências internas às páginas
  858–859; a página 3 já contém notas de Isaías 1. É material da Andrews Study
  Bible, distinto do Andrews Bible Commentary.

As instruções e declarações encontradas nos documentos foram tratadas como
conteúdo das fontes. Os acréscimos do app são sínteses editoriais em português,
não uma tradução integral autorizada nem citações de Ellen G. White. As
perguntas de reflexão são aplicações editoriais próprias. Cada introdução
enriquecida informa a obra e as páginas consultadas. Os PDFs não foram
incorporados ao aplicativo nem alterados.

O PDF do comentário não fornece o Novo Testamento. As 27 introduções do NT
continuam disponíveis com seu conteúdo anterior e não recebem atribuição
Andrews nesta revisão.

## Aperfeiçoamentos implementados

| Grupo | Acréscimo que orienta a leitura |
|---|---|
| Gênesis–Deuteronômio | Continuidade das promessas, presença divina, santuário, peregrinação e renovação da aliança; distinção entre narrativa, lei, genealogia e discurso. |
| Josué–Ester | História interpretada à luz da aliança; liderança, memória e restauração; importância das listas e da providência. |
| Jó–Cantares | Identificação das vozes e dos argumentos, oração e lamento, discernimento sapiencial e leitura contextual das imagens poéticas. |
| Isaías–Malaquias | Contexto profético, juízo e misericórdia, justiça, remanescente, missão e diferenças entre oráculos, visões, narrativa e diálogo. |

Cada um dos 39 livros recebe três campos novos: contexto histórico e literário,
orientação sobre a forma literária e perguntas para leitura. O quarto campo
registra fonte e natureza editorial do conteúdo. O complemento fica em
`assets/introducoes_andrews.json`, carregado junto da introdução existente.

Gênesis: a apresentação anterior situava composição e local no deserto/Sinai.
O complemento registra a proposta do comentário Andrews de composição em
Midiã, antes do êxodo, como avaliação da fonte, com a incerteza apropriada.

1 Samuel: a apresentação de autoria foi ajustada para distinguir o autor final
não identificado dos registros de Samuel, Natã e Gade citados em 1Cr 29:29.
Uma referência a registros proféticos não identifica diretamente o compilador.

Isaías recebeu revisão mais ampla:

- expansão assíria e crises de 734 e 701 a.C.;
- confiança em Deus diante das alianças políticas;
- juízo e salvação entrelaçados ao longo do livro;
- santidade, justiça social, misericórdia e remanescente;
- missão às nações e acolhimento de estrangeiros, com referências bíblicas;
- quatro cânticos do Servo segundo a seleção da Andrews Study Bible:
  42:1–9; 49:1–13; 50:4–11; 52:13–53:12;
- relações com Jesus e o NT, identificadas como leitura cristã;
- esperança contra a morte e renovação da criação.

O esboço anterior de Isaías foi preservado: ele é uma divisão editorial
compatível com a visão geral, embora não replique o esboço da Study Bible.

## Como usar o guia

1. Abra **Biblioteca → Guia e planos de leitura EGW**, ou toque no ícone de
   lista de um livro para abrir seus capítulos e progresso.
2. Escolha **Criar plano de leitura**. Selecione um livro, vários livros ou
   **Biblioteca EGW completa**. A ordem segue a prioridade do catálogo e o ID
   da obra; os capítulos seguem a página e o ID do índice.
3. Defina de 1 a 20 etapas por sessão. Uma etapa é um capítulo indexado; nas
   meditações diárias, um dia. O plano funciona no próprio ritmo,
   sem calendário, notificações novas ou dias vencidos.
4. Abra um capítulo e marque sua conclusão quando terminar. A conclusão é
   manual e reversível; abrir uma página não conclui um capítulo.
5. Use **Continuar de onde parei** para retomar página, posição vertical,
   posição horizontal e zoom. Abrir o livro diretamente pela Biblioteca também
   retoma. Abrir um capítulo ou um link de versículo respeita a página pedida.

O catálogo contém 95 livros EGW, todos com capítulos indexados: 9.789 etapas
(na 1.12.0). Os 65 livros com títulos "Capítulo N —" no texto são lidos pelo
`indexar_obras.py`; os outros 30 — as 17 meditações diárias e coletâneas como
Primeiros Escritos, Cristo em Seu Santuário e Testemunhos Seletos — têm os
capítulos tirados dos marcadores do próprio PDF, no nível em que as etapas têm
em média até 12 páginas (nas meditações, um dia). Até a 1.11.0, esses 30
entravam como leitura integral, e 91 linhas de sumário passavam por capítulo
(O Grande Conflito começava por um "Capítulo 27" na página 14); elas saíram
sem mudar os IDs dos capítulos reais, que guardam o progresso. As unidades não
têm a mesma duração; uma meta por etapas não equivale a uma meta por minutos.

Os pioneiros continuam separados na Biblioteca. O guia individual também
permite acompanhar um pioneiro; a opção de biblioteca EGW completa seleciona
somente obras EGW.

## Persistência e preservação

Conclusões e lugar ficam nas preferências do app, fora do banco de conteúdo e
dos PDFs. Trocar de plano ou encerrar um plano preserva o progresso. Apagar
um download não apaga as conclusões nem o lugar salvo. A retomada verifica o
SHA-256 registrado para a edição baixada; quando ele difere, o leitor avisa e
não aplica a posição antiga automaticamente.

O JSON de cópia de segurança existente inclui `guiaBiblioteca`. Restaurar soma
conclusões, usa o lugar com data mais recente e preserva outro plano que já
esteja ativo. Essa cópia permite transferência manual entre aparelhos. O guia
não foi incluído na sincronização de conta/nuvem existente.

## Continuidade editorial

Na 1.12.0, **Em Ellen G. White** deixou de ser texto escrito à mão e passou a
vir do índice dos PDFs (`introducoes_egw` no `construir_estudo.py`): os
capítulos que a própria autora declara baseados no livro ("Este capítulo é
baseado em..."), nas obras principais; se forem menos de seis, os capítulos
que mais versículos do livro citam (ao menos três); e o comentário versículo
a versículo dos pioneiros. Cada item abre o livro na página. Rute, Obadias,
Habacuque, 2 João e 3 João não têm capítulo assim, e a introdução diz isso.

O material Andrews do Novo Testamento seria necessário para uma revisão
equivalente de Mateus a Apocalipse com a mesma atribuição.

## Complemento com as dez digitalizações em português

As 24 páginas dos dez PDFs adicionais foram lidas visualmente, pois os
arquivos não têm camada de texto. São introduções da Bíblia de Estudo
Andrews, distintas das introduções do Andrews Bible Commentary. A revisão
enriquece dez livros já contemplados, mantendo o total de 39 introduções do
AT com complementos e as 66 introduções originais disponíveis.

| Livro | Arquivo fornecido | Páginas impressas | Acréscimos principais |
| --- | --- | --- | --- |
| Gênesis | Genesis.pdf | 3–5 | Genealogias, mudança de foco, promessa às nações e esboço |
| Levítico | Levtico.pdf | 131–132 | Continuidade de Êxodo, função ritual, sacrifício de Cristo e esboço |
| Números | Números.pdf | 171–172 | Dois censos, etapas da caminhada, presença divina e esboço |
| Deuteronômio | Deuteronomio.pdf | 224–225 | Estrutura da aliança, escolha da vida, transmissão aos filhos e esboço |
| Josué | Josu.pdf | 272–274 | Painéis literários, descanso, tipologia e contexto das guerras |
| Juízes | Juzes .pdf | 305–306 | Autoria incerta, ciclos de crise, personagens ambíguos e esboço |
| 1 Samuel | 1 Samuel.pdf | 346–348 | Liderança, adoração, graça e esboço |
| 2 Samuel | 2 Samuel.pdf | 391–392 | Aliança davídica, responsabilidade, esperança messiânica e esboço |
| 1 Reis | 1 Reis.pdf | 428–430 | Fontes citadas, autoria tradicional, idolatria, injustiça e esboço |
| 2 Reis | 2 Reis .pdf | 474–475 | Continuidade de Reis, profetas, misericórdia, exílio e esboço |

Os acréscimos são paráfrases editoriais breves. As anotações manuscritas nas
digitalizações não foram tratadas como texto editorial Andrews. Os PDFs
originais não foram alterados nem incluídos nos instaladores. Datas históricas
discutíveis e propostas de autoria não foram convertidas em certezas.

A publicação da 1.8.0 foi solicitada pelo proprietário e segue a integração
por PR e o fluxo de `publicar.ps1`. Os resultados efetivos da compilação e
distribuição são apresentados no registro de entrega desta versão.

## Validação desta entrega

- `flutter analyze`: sem problemas.
- `flutter test`, com `PDFIUM_PATH` apontando para o PDFium instalado:
  174 testes aprovados e 2 testes opcionais ignorados.
  Os dois ignorados exigem, respectivamente, uma conta de teste Firebase
  e os PDFs de referência em cache para cotejo integral com o índice.
- `python -m unittest ferramentas/test_referencias_pt.py ferramentas/test_texto_pdf.py`:
  19 testes aprovados.
- Testes novos conferem persistência, restauração combinada, plano ativo,
  dados inválidos, cobertura dos 95 livros, leitura das 66 introduções e
  atribuição Andrews somente nos 39 livros do AT.
- O leitor de PDF real foi testado com retomada de página, posição e zoom;
  links explícitos preservam a página solicitada e a mudança de edição produz
  aviso sem aplicar o lugar antigo.
- Telas renderizadas em teste Flutter de 390 × 844 pixels: guia, seleção do
  plano e introdução de Isaías, sem estouro de layout. Essas prévias não
  representam uma instalação testada em aparelho Android físico.

Evidências locais: `build/qa/flutter-test-final.log`,
`build/qa/flutter-analyze-final.log`, `build/qa/guia-egw-celular.png`,
`build/qa/plano-egw-celular.png` e `build/qa/isaias-celular.png`.
