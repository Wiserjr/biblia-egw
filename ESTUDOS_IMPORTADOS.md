# Integração inicial de estudos bíblicos

O aplicativo mostra sete estudos selecionados. Seis têm download direto das
fontes oficiais enviadas pelo usuário; Em Paz com Deus permanece sem link
configurado e aceita a edição local. O Segredo — quarta temporada foi retirado
do catálogo, preservando arquivos e respostas já existentes.

O botão **Baixar estudo** guarda o material no diretório de documentos do app.
Quando a fonte é ZIP, o aplicativo seleciona o PDF pela identidade SHA-256,
ignora arquivos extras e não extrai caminhos do pacote no disco. Há progresso,
cancelamento e nova tentativa. Ao terminar, aparece **Abrir estudo**; a leitura
posterior funciona sem internet. A preparação do ZIP acontece fora da thread
da interface. Os downloads usam HTTPS e conferem tamanho e SHA-256 tanto do
arquivo recebido quanto do PDF extraído antes de disponibilizar o estudo.
Se a edição oficial mudar, o aplicativo informa que precisa de atualização.

## Catálogo conferido em 05/10/2026

| Material | Páginas | Download |
|---|---:|---|
| Em Paz com Deus | 50 | Link pendente; importação local |
| Jesus Restaurador da Vida — Mulheres | 128 | PDF oficial |
| Jesus Restaurador da Vida | 128 | PDF oficial; primeira lição interativa |
| Apocalipse — Revelações de Esperança | 113 | ZIP oficial; preparação automática |
| Deus Revela Seu Amor | 37 | PDF oficial |
| Esperança para a Família | 41 | PDF oficial |
| Guia de Estudos Calebe | 40 | ZIP oficial; preparação automática |

Os arquivos de Jesus Restaurador, Mulheres e Apocalipse correspondem às cópias
fornecidas anteriormente. O endereço HTTP do Calebe foi substituído pelo
endpoint HTTPS equivalente do mesmo bucket S3:
`https://s3.amazonaws.com/missaocalebe.org.br/GuiadeEstudosCalebe.zip`.
A forma de subdomínio contendo pontos não passa na validação do certificado;
o endpoint adotado foi baixado e conferido com validação TLS habilitada.

Os PDFs continuam fora dos assets e do Git; não são redistribuídos pelo
projeto. Textos, imagens e leitura vêm dos documentos oficiais guardados no
aparelho. O pacote local de hospedagem preparado anteriormente é histórico e
não é utilizado para os downloads.

## O que foi implementado

Em Temas e estudos → Estudos bíblicos → Estudos selecionados:

- Catálogo de sete edições aprovadas; importação validada pelo PDFium e SHA-256.
- Cópia no diretório de documentos do app; identidade pelo SHA-256 do conteúdo.
- Reimportar o mesmo conteúdo reutiliza o arquivo e suas respostas.
- Leitura do original pelo pdfrx, com retomada da última página.
- Respostas abertas e indicação de página estudada, persistidas localmente.
- Exportação das respostas e marcações em JSON, separada do PDF.

Há um piloto com perguntas individualizadas da primeira lição de Jesus
Restaurador da Vida, descrito abaixo. Não há correção automática, integração das
respostas com a nuvem ou restauração do JSON exportado nesta etapa. A
exportação permite guardar e consultar as respostas fora do aplicativo.
Os PDFs não foram copiados para os assets nem para arquivos versionados.
Não há alteração no banco dos dezesseis estudos existentes.

## Próxima etapa editorial

Para uma experiência por lição, preparar um índice de títulos e páginas,
conferido com cada edição. Para perguntas individualizadas, conferir a
extração de enunciados e alternativas, ligar referências à Bíblia instalada
e distinguir perguntas objetivas de reflexão pessoal. Não inferir um gabarito
para perguntas abertas. Links de vídeos e QR Codes precisam ser verificados.
Conteúdo incorporado à distribuição requer uma licença aplicável ou autorização.

## Conferência manual antes da publicação

No Windows e no Android, baixar os seis materiais pelo catálogo, testar
cancelamento e nova tentativa, conferir abertura offline e importar Em Paz
com Deus. Registrar duas respostas em
páginas distintas, fechar e reabrir, conferir página retomada e respostas,
reimportar o mesmo arquivo e exportar JSON. Conferir também cancelamento do
seletor e PDF inválido. A análise e a suíte existente não substituem esse
teste de interação com o leitor nativo e o seletor de arquivos.

A versão 1.7.0+9 está preparada no código; isso não é uma versão publicada.

Validação realizada: `flutter analyze --no-pub` sem ocorrências;
`flutter test` com 153 testes aprovados e seis ignorados pela suíte;
`git diff --check` nos arquivos da alteração sem problemas. Também foi
exercitada a transferência real dos seis endereços com o downloader do app,
incluindo preparação dos dois ZIPs. O fluxo nativo
de importação/leitura não foi exercitado em um app compilado nesta sessão.
Compilação Windows de teste (`flutter build windows --release`) concluída.
Executável em `build/windows/x64/runner/Release/biblia_estudo.exe`; manter
os demais arquivos dessa pasta junto dele. Não é uma release publicada.

## Piloto da primeira lição

Importar `jesus_restaurador-da-vida.pdf` fornecido em 05/10/2026. A edição
conferida tem SHA-256
`1bacb247dcdce6348ce491573a050b543f5bab2a236498799170419b4269fbd7`.
Ao abrir esse PDF, tocar em **Lição 1 — Jesus e as Escrituras Sagradas**.
Os outros seis materiais do catálogo estão disponíveis no leitor; suas
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
