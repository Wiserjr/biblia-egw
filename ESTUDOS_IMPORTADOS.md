# Estudos bíblicos interativos — versão 1.9.0

## Catálogo preparado

| Estudo | Páginas | Lições | Fonte |
|---|---:|---:|---|
| Em Paz com Deus | 50 | 8 | PDF oficial |
| Jesus Restaurador da Vida — Mulheres | 128 | 20 + 7 semanas complementares | PDF oficial |
| Jesus Restaurador da Vida | 128 | 20 + 7 semanas complementares | PDF oficial |
| Apocalipse — Revelações de Esperança | 113 | 21 | ZIP oficial |
| Deus Revela Seu Amor | 37 | 18 | PDF oficial |
| Esperança para a Família | 41 | 14 | PDF oficial |
| Guia de Estudos Calebe | 40 | 18 | ZIP oficial |
| Bíblia Fácil — Daniel | 81 | 16 | PDF oficial |

Os oito endereços oficiais estão em `assets/catalogo_estudos.json`. O catálogo
é fechado: PDFs de outras edições precisam de preparação e atualização do app.
O Segredo — quarta temporada saiu do catálogo; arquivos e respostas anteriores
não são apagados. O Calebe usa o endpoint HTTPS equivalente do mesmo bucket S3,
com validação normal de certificado.

Daniel usa o endpoint HTTPS por caminho do mesmo bucket S3 do endereço HTTP
fornecido. A edição de Apocalipse foi baixada e reconferida em 07/10/2026:
o ZIP e seu PDF correspondem aos hashes já cadastrados.

## Uso

Em **Temas e estudos → Estudos bíblicos → Estudos selecionados**, tocar em
**Baixar estudo**. O app mostra progresso, permite cancelar e tentar novamente.
Os ZIPs são preparados automaticamente, escolhendo o PDF pelo SHA-256, sem
extrair caminhos arbitrários. Tamanho e SHA-256 do download e do PDF são
conferidos. Os documentos ficam na pasta de documentos do app e podem ser
abertos sem internet. Também é possível importar uma edição local conferida.

Ao abrir, escolher uma lição no menu superior. As páginas do PDF mantêm seu
visual original. Tocar num espaço para responder ou numa alternativa para
marcar. O botão **Responder** lista as perguntas e atividades da página, com
edição confortável no celular. Há respostas abertas, lacunas, alternativas,
reflexões, decisões e atividades complementares. A conclusão é indicada pelo
usuário; não há gabarito, correção automática ou pontuação.

No guia de Daniel, as 16 lições ficam nas páginas 4–59 e os questionários nas
páginas 61–81. O botão de questionário alterna entre a leitura e os exercícios
da lição. Algumas lições compartilham páginas de questionários; a lição
escolhida é mantida. São 130 perguntas, incluindo três atividades de relacionar
colunas, com um campo de texto por correspondência.
As perguntas digitalizadas aparecem no editor como recortes renderizados do
PDF baixado no aparelho, com alternativas numeradas para seleção. A antiga
promoção impressa no documento não é executada pelo aplicativo.

As referências bíblicas abrem em uma janela sobre o estudo e sobre o editor
da pergunta. A tradução escolhida na Bíblia é respeitada. Intervalos separados
como João 1:1–4 e 14 são consultados separadamente e aparecem juntos, sem incluir
5–13. Fechar a janela mantém a página e o rascunho. Links do PDF e áreas de QR
Codes identificados abrem no navegador; os 40 códigos da edição para mulheres
têm áreas clicáveis. Abrir WhatsApp apenas abre o endereço; não envia mensagens.

## Dados e fidelidade ao original

`assets/estudos_interativos.json` contém somente posições dos campos,
referências, links e intervalos de páginas. Os textos das perguntas e
alternativas são extraídos do PDF no aparelho. Os PDFs, imagens e textos não
são incorporados aos assets nem redistribuídos no GitHub.

Respostas são separadas pelo SHA-256 da edição e pela identidade do campo.
Salvar e voltar pelo botão do aparelho gravam a resposta; Cancelar descarta a
edição em andamento. As respostas e escolhas da primeira lição do piloto são
recuperadas. Perguntas que continuam na página seguinte de Em Paz com Deus
compartilham a mesma resposta. Última página e conclusão das lições são locais.

A exportação JSON reúne respostas atuais e registros anteriores do PDF/piloto.
A importação do JSON e a sincronização desses estudos com a conta ainda não
estão implementadas. A exportação permite guardar e consultar as respostas.

**Defeito do documento oficial:** na página 17 de Deus Revela Seu Amor, o
enunciado 4 está incompleto e os enunciados 5–8 estão ausentes. Os campos são
mantidos e identificados; o aplicativo não inventa o conteúdo que falta.

## Preparação e validação

`ferramentas/indexar_estudos_interativos.py` gera o índice usando as oito
cópias oficiais conferidas. `ferramentas/indexar_qr_estudos.py` complementa os
endereços dos códigos, incluindo os códigos com cores invertidas. As originais
ficam fora do Git, em `ferramentas/cache/estudos/oficiais`.

`ferramentas/indexar_daniel.py` prepara o guia digitalizado usando PyMuPDF,
RapidOCR e numpy. O OCR localiza perguntas, alternativas e referências; seu
texto e suas imagens ficam somente no cache ignorado pelo Git. O índice
distribuído conserva posições e referências numéricas. O editor mostra a
imagem original, sem depender da precisão do texto reconhecido.
As referências reconhecidas nas perguntas de Daniel são consultadas pelo
botão do editor; não se sobrepõem áreas de links aproximadas sobre as imagens.

A validação cobre persistência por edição, migração do piloto, consulta sem
perder rascunhos, salvamento ao voltar, retomada de página, conclusão, intervalos
descontínuos, limites dos campos e presença de atividades em todas as lições.
A extração das áreas foi confrontada com PDFium, considerando as margens de
recorte dos originais, e amostras dos sete projetos gráficos foram renderizadas
com os campos marcados. Testes automatizados não substituem a conferência de
uso em um celular físico.
