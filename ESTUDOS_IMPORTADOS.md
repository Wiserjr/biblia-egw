# Integração inicial de estudos bíblicos

O aplicativo mostra um catálogo fechado com os cinco materiais escolhidos pelo
usuário. A edição é identificada pelo SHA-256; PDFs fora do catálogo são
recusados. Arquivos e respostas já existentes não são apagados.

A hospedagem será definida depois. Os endereços em
`assets/catalogo_estudos.json` estão vazios e a tela informa **Download em
preparação**. Enquanto isso, **Adicionar PDF deste catálogo** permite testar
as cinco edições locais. Ainda não há download automático.

O pacote local `C:\Users\WiseJr\Downloads\Estudos-Biblicos-Hospedagem`
contém cinco PDFs, `catalogo.json` e instruções. O PDF do Apocalipse foi
separado do ZIP sem modificar seu conteúdo. Cada entrada registra nome,
tamanho, páginas e SHA-256 para conferir os futuros downloads diretos.
Os originais fornecidos foram preservados; nada foi enviado à nuvem.

Avaliação em 05/10/2026, a partir dos quatro PDFs e do ZIP fornecidos pelo usuário.
Origem: https://downloads.adventistas.org/pt/kits/estudos-biblicos/

| Material | Páginas do PDF | Estrutura observada |
|---|---:|---|
| Em Paz com Deus | 50 | Série de oito estudos; perguntas abertas e comentários |
| Jesus Restaurador da Vida, versão para mulheres | 128 | Vinte estudos; perguntas, atividades e QR Codes |
| Jesus Restaurador da Vida | 128 | Vinte estudos; perguntas abertas e alternativas, atividades e links |
| O Segredo, quarta temporada | 30 | Reflexões sobre Daniel e pausas para discussão |
| Apocalipse — Revelações de Esperança | 113 | Curso com 21 lições; PDF extraído do ZIP |

A extração de texto funcionou nos quatro documentos. Algumas páginas têm
elementos sem texto extraível. A ordem de leitura e a divisão das perguntas
precisam de conferência visual antes de uma conversão em questionários.
As duas edições de Jesus Restaurador têm o mesmo conjunto de títulos no
sumário, mas não devem ser tratadas como arquivos idênticos.

O PDF Em Paz com Deus declara proibição de reprodução total ou parcial sem
autorização escrita do autor e da editora (página 3 do arquivo). As duas
edições de Jesus Restaurador declaram direitos reservados à DSA (página 2).
Disponibilidade para download não foi tratada como licença de redistribuição.

## O que foi implementado

Em Temas e estudos → Estudos bíblicos → Estudos selecionados:

- Catálogo de cinco edições aprovadas; importação validada pelo PDFium e SHA-256.
- Cópia no diretório de documentos do app; identidade pelo SHA-256 do conteúdo.
- Reimportar o mesmo conteúdo reutiliza o arquivo e suas respostas.
- Leitura do original pelo pdfrx, com retomada da última página.
- Respostas abertas e indicação de página estudada, persistidas localmente.
- Exportação das respostas e marcações em JSON, separada do PDF.

Há um piloto com perguntas individualizadas da primeira lição de Jesus
Restaurador da Vida, descrito abaixo. Não há correção automática, integração das
respostas com a nuvem ou restauração do JSON exportado nesta etapa. A
exportação permite guardar e consultar as respostas fora do aplicativo.
Os cinco PDFs não foram copiados para os assets nem para arquivos versionados.
Não há alteração no banco dos dezesseis estudos existentes.

## Próxima etapa editorial

Para uma experiência por lição, preparar um índice de títulos e páginas,
conferido com cada edição. Para perguntas individualizadas, conferir a
extração de enunciados e alternativas, ligar referências à Bíblia instalada
e distinguir perguntas objetivas de reflexão pessoal. Não inferir um gabarito
para perguntas abertas. Links de vídeos e QR Codes precisam ser verificados.
Conteúdo incorporado à distribuição requer uma licença aplicável ou autorização.

## Conferência manual antes da publicação

No Windows e no Android, importar cada PDF, registrar duas respostas em
páginas distintas, fechar e reabrir, conferir página retomada e respostas,
reimportar o mesmo arquivo e exportar JSON. Conferir também cancelamento do
seletor e PDF inválido. A análise e a suíte existente não substituem esse
teste de interação com o leitor nativo e o seletor de arquivos.

A versão 1.7.0+9 está preparada no código; isso não é uma versão publicada.

Validação realizada: `flutter analyze --no-pub` sem ocorrências;
`flutter test` com 146 testes aprovados e seis ignorados pela suíte;
`git diff --check` nos arquivos da alteração sem problemas. O fluxo nativo
de importação/leitura não foi exercitado em um app compilado nesta sessão.
Compilação Windows de teste (`flutter build windows --debug`) concluída.
Executável em `build/windows/x64/runner/Debug/biblia_estudo.exe`; manter
os demais arquivos dessa pasta junto dele. Não é uma release publicada.

## Piloto da primeira lição

Importar `jesus_restaurador-da-vida.pdf` fornecido em 05/10/2026. A edição
conferida tem SHA-256
`1bacb247dcdce6348ce491573a050b543f5bab2a236498799170419b4269fbd7`.
Ao abrir esse PDF, tocar em **Lição 1 — Jesus e as Escrituras Sagradas**.
Os outros quatro materiais do catálogo estão disponíveis no leitor; suas
lições interativas ainda precisam ser preparadas.

O arquivo `assets/estudo_piloto.json` guarda apenas posições de caracteres
na página 6 e referências bíblicas. O texto é extraído e normalizado no
aparelho pelo PDFium. Há quatro perguntas com três alternativas cada e
quatro abertas. A pergunta 7 conserva suas duas partes. João 1:1–4 e 1:14
aparecem como duas referências. As oito perguntas e doze alternativas
foram conferidas no texto extraído e na imagem da página original.

Respostas, escolhas e conclusão são locais. Há salvamento explícito e ao
voltar; abrir uma referência salva primeiro e mostra uma janela sobre a lição.
Para continuar, reabrir o PDF e a lição. A exportação do leitor inclui os
dados da lição em `licao1`. Não existe correção ou pontuação automática.
A introdução, as perguntas e a atividade adicional agora aparecem na mesma
tela: páginas 5, 6 e 7 renderizadas do PDF importado. Os controles são
sobrepostos nas coordenadas conferidas do original. O papel permanece claro
mesmo quando o aplicativo usa tema escuro. Há zoom e rolagem horizontal em
telas pequenas para preservar a composição e a leitura.

Também são editáveis as duas reflexões, nome e data da página 6. As respostas
anteriores continuam com suas mesmas chaves. As anotações opcionais antigas
das perguntas de alternativas permanecem guardadas e exportáveis.

Links extraídos das anotações do PDF, com áreas clicáveis sobre o original e
botões de acesso ao fim da lição:

- Introdução: https://vimeo.com/520686211
- Recapitulação: https://vimeo.com/520686319
- Evidências: https://ntplay.com/evidencias
- WhatsApp: https://api.whatsapp.com/send?phone=5561981690215&text=sua%20mensagem

Em 05/10/2026, os dois endereços do Vimeo foram identificados nos títulos
das páginas consultadas. Evidências não pôde ser verificado pela ferramenta
web; permanece o endereço do original. O botão WhatsApp apenas abre o
endereço; não envia mensagens. Entidades HTML do endereço foram decodificadas.

A interface foi renderizada em teste visual com as imagens locais das páginas
originais, incluindo escolhas selecionadas e uma resposta de exemplo. Isso
confere a composição e a sobreposição, mas não substitui o teste manual no
Windows e Android. Há teste de abertura do endereço WhatsApp após salvamento.

## Leitura bíblica flutuante

A janela mantém o estudo montado e sua rolagem. Exibe a tradução selecionada
no aplicativo, os números dos versículos e a formatação das palavras de Jesus.
Cada intervalo é consultado separadamente; João 1:1–4 e 1:14 aparecem em duas
seções na mesma janela, sem incluir 5–13. O texto longo tem rolagem própria.
Pode ser fechada pelo X, por Voltar ao estudo, pelo retorno do aparelho ou
tocando fora da janela. Falhas de consulta permitem tentar novamente.

Testes com banco SQLite verificam a tradução selecionada, os intervalos
descontínuos, a passagem ausente e a permanência do estudo ao fechar.
