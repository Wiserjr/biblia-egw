# Bíblia de Estudo: regras do repositório

App Flutter (Android e Windows). O dono publica do próprio PC com
`publicar.ps1`; veja "Publicar uma versão" no README.

## Versões e publicação

- Um PR que deve sair numa versão nova sobe o `version:` do `pubspec.yaml`
  (o nome e o número depois do `+`) e escreve as novidades no topo de
  `NOTAS_DA_VERSAO.md`, citando o número da versão. O `publicar.ps1` recusa
  notas que não citem a versão e recusa publicar de novo uma versão já
  publicada sem `-Republicar`.
- A versão nova só existe depois que o PR está no `main`. Ao entregar um PR
  com versão nova, diga ao dono para rodar `publicar.ps1` e responder **S**
  quando ele perguntar por aquele PR. Nunca diga que a versão nova sai antes
  disso.
- Mesclar PR só quando o dono pedir (ou pelo próprio `publicar.ps1`, que
  pergunta).
- As conferências do script ficam em `ferramentas/publicacao.ps1`, com
  testes em `ferramentas/test_publicacao.ps1`. Mudou o script, rode os
  testes (`pwsh -File ferramentas/test_publicacao.ps1`).
- Mensagens dos `.ps1` sem acento: o Windows PowerShell 5.1 lê os arquivos
  como ANSI. Nada de sintaxe só do PowerShell 7 (`?:`, `??`, `&&`).
- Todas as versões são assinadas com a mesma chave (`android/key.properties`,
  só no PC do dono), senão a atualização automática quebra.

## Testes

- `flutter analyze` e `flutter test` antes de enviar.
- Os testes do leitor de PDF com o PDFium de verdade só rodam com
  `PDFIUM_PATH` apontando para um `libpdfium.so` (o do pacote Python
  `pypdfium2_raw` serve).
- Ferramentas em Python: `python -m unittest ferramentas/test_referencias_pt.py
  ferramentas/test_texto_pdf.py` (precisam do `pypdfium2`).
