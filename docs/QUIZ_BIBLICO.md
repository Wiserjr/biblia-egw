# Desafio Bíblico — 1.10.0

Entrada: Temas e estudos → Estudos bíblicos → Desafio Bíblico — Rumo ao Milhão.

O usuário importa a edição pessoal de **Curiosidades e Testes Bíblicos**, Rafael Escandón, Casa Publicadora Brasileira. O EPUB original não é alterado. O texto importado fica no diretório de suporte do aplicativo, em `quiz_cpb_pessoal.json`, sem sincronização ou inclusão na cópia de segurança geral. Para outro aparelho, importe o EPUB novamente.

O índice público contém o hash da edição, localizadores, referências bíblicas e três alternativas editoriais por pergunta. Não contém o livro, suas imagens, enunciados ou gabaritos. A importação exige SHA-256 `cf012e84074a4d1dc96d36789dc1f80cae988e64c8f20b76b42d834388306a19`. Outra edição precisa de um índice próprio; o aplicativo recusa o arquivo antes de descompactá-lo.

O leitor oferece 125 seções de conteúdo textual, com busca e filtros por curiosidades, testes, pesquisas e gabaritos. Imagens e diagramação não são reproduzidas. As afirmações do leitor pertencem ao autor; a seleção de 180 questões, os distratores e os três níveis são preparação editorial para o jogo. As referências podem ser consultadas na tradução escolhida no aplicativo depois de responder.

São 15 rodadas, sem cronômetro: cinco por nível, sem repetição na partida. Há três pulos e uma ajuda meio a meio. Acertos nas rodadas 5 e 10 garantem 10.000 e 75.000 pontos. Parar conserva os pontos atuais; errar encerra com os garantidos. O milhão é uma pontuação virtual. Uma partida nova começa do zero; o recorde fica no aparelho.

O banco tem 180 questões, sessenta por nível. O histórico local conta cada exibição, inclusive pulos, e prioriza a menor contagem dentro do nível. São doze partidas completas de quinze perguntas antes de reutilizar uma questão, quando não há pulos. Partidas encerradas cedo consomem mais perguntas dos níveis iniciais; cada nível recicla independentemente depois de percorrido. O histórico persiste entre aberturas do aplicativo. Importações antigas de sessenta perguntas são atualizadas a partir do texto já salvo, sem exigir o EPUB novamente.

Validação da cópia pessoal, sem fixture distribuída:

```powershell
$env:BIBLIA_TEST_QUIZ_EPUB='C:\caminho\Curiosidades e testes bíblicos.epub'
flutter test test/quiz_biblico_test.dart --no-pub
```

Os testes verificam 180 questões, sessenta por nível, 125 seções, confirmações únicas, checkpoints, limite das ajudas e telas de 360 e 1100 pixels. Testes de widgets não substituem a instalação em aparelho Android ou a execução do pacote distribuído de Windows.
