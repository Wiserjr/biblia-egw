# Integração inicial de estudos bíblicos

Avaliação em 05/10/2026, a partir dos quatro PDFs fornecidos pelo usuário.
Origem: https://downloads.adventistas.org/pt/kits/estudos-biblicos/

| Material | Páginas do PDF | Estrutura observada |
|---|---:|---|
| Em Paz com Deus | 50 | Série de oito estudos; perguntas abertas e comentários |
| Jesus Restaurador da Vida, versão para mulheres | 128 | Vinte estudos; perguntas, atividades e QR Codes |
| Jesus Restaurador da Vida | 128 | Vinte estudos; perguntas abertas e alternativas, atividades e links |
| O Segredo, quarta temporada | 30 | Reflexões sobre Daniel e pausas para discussão |

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

Em Temas e estudos → Estudos bíblicos → Meus estudos em PDF:

- Importação de PDF escolhido pelo usuário, validado pelo PDFium.
- Cópia no diretório de documentos do app; identidade pelo SHA-256 do conteúdo.
- Reimportar o mesmo conteúdo reutiliza o arquivo e suas respostas.
- Leitura do original pelo pdfrx, com retomada da última página.
- Respostas abertas e indicação de página estudada, persistidas localmente.
- Exportação das respostas e marcações em JSON, separada do PDF.

Há um piloto com perguntas individualizadas da primeira lição de Jesus
Restaurador da Vida, descrito abaixo. Não há correção automática, integração das
respostas com a nuvem ou restauração do JSON exportado nesta etapa. A
exportação permite guardar e consultar as respostas fora do aplicativo.
Os quatro PDFs não foram copiados para os assets nem para arquivos versionados.
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
`flutter test` com 143 testes aprovados e seis ignorados pela suíte;
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
Outras edições continuam disponíveis no leitor, sem aplicar este índice.

O arquivo `assets/estudo_piloto.json` guarda apenas posições de caracteres
na página 6 e referências bíblicas. O texto é extraído e normalizado no
aparelho pelo PDFium. Há quatro perguntas com três alternativas cada e
quatro abertas. A pergunta 7 conserva suas duas partes. João 1:1–4 e 1:14
aparecem como duas referências. As oito perguntas e doze alternativas
foram conferidas no texto extraído e na imagem da página original.

Respostas, escolhas e conclusão são locais. Há salvamento explícito e ao
voltar; abrir uma referência salva primeiro e retorna ao leitor da Bíblia.
Para continuar, reabrir o PDF e a lição. A exportação do leitor inclui os
dados da lição em `licao1`. Não existe correção ou pontuação automática.
A introdução e a atividade adicional continuam nas páginas 5 e 7 do PDF.
