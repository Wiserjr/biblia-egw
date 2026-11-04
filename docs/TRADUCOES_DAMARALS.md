# Traduções de damarals/biblias

Fonte: https://github.com/damarals/biblias

Revisão: `08bfb8f3d569e5a8dd53a0ebefafda416eb066d7`.

## O que vai no app e o que é baixado

A coleção tem nove versões que não estavam no catálogo do Louvor JA. Só as
duas de domínio público vão no banco embarcado (`assets/biblia.db.gz`):

| Sigla | ID | Versão | Situação |
|---|:---:|---|---|
| TB | 20 | Tradução Brasileira | embarcada (domínio público) |
| ALM1911 | 21 | Almeida 1911 | embarcada (domínio público) |
| AS21 | 16 | Almeida Século 21 (Vida Nova) | download a pedido |
| JFAA | 17 | Almeida Atualizada (editora não informada) | download a pedido |
| KJF | 18 | King James Fiel (BVBooks) | download a pedido |
| NBV | 19 | Nova Bíblia Viva (Mundo Cristão) | download a pedido |
| OL | 22 | O Livro (Biblica) | download a pedido |
| MENS | 23 | A Mensagem (Editora Vida) | download a pedido |
| VFL | 24 | Versão Fácil de Ler (Bible League International) | download a pedido |

As sete protegidas por direitos autorais estiveram embarcadas só na 1.11.0.
Desde a 1.12.0 o app não as distribui: na lista de traduções, "Mais
traduções" abre a tela onde a pessoa baixa a que quiser, livro a livro, de
`raw.githubusercontent.com/damarals/biblias/<revisão>/data/canonical/`. O
download usa a mesma revisão fixada acima e as mesmas conferências do
importador (66 livros, todos os capítulos, versículos não vazios e sem
repetição) e só grava quando tudo chegou, numa transação. O texto fica num
banco gravável próprio do aparelho, `traducoes_extras.db`, que as atualizações
do app não tocam (lib/dados/traducoes_extras.dart). Os IDs são os mesmos da
1.11.0, então preferências e marcações antigas voltam a valer depois do
download.

Baixar da coleção pública não torna o uso autorizado pela editora: a tela
avisa isso e manda conferir a permissão. O app só deixa de ser quem
distribui o texto.

Para reproduzir a importação das duas embarcadas sobre o banco atual (o
script também remove do banco qualquer uma das sete, se ainda estiver lá):

```
python ferramentas/importar_damarals.py
```

O construtor completo `ferramentas/construir_biblia.py` também chama essa
importação depois de gerar as traduções do Louvor JA. O checkout fica no
cache ignorado pelo Git. A importação valida 66 livros, todos os capítulos,
textos não vazios, chaves únicas e integridade SQLite antes de substituir
o arquivo compactado. Metadados da fonte são preservados na tabela `info`.

A Mensagem usa trechos agrupados; os 13.055 registros não correspondem a
13.055 versículos isolados. A numeração e o texto não são artificialmente
expandidos. A comparação procura também o trecho que abrange o versículo.
As demais versões também podem ter diferenças de numeração e omissões.
Cinco rótulos de intervalo de MENS estão invertidos na fonte: 1Cr 21:29,
2Cr 35:26, At 27:12, Jn 4:7 e Lc 11:32. Os textos são mantidos, mas esses
rótulos não geram associações automáticas com outros versículos.

O mantenedor informa que há textos truncados na origem e publica listas
de suspeitas em `data/worklist/`. A validação estrutural não comprova
fidelidade editorial; não corrigimos nem completamos textos por inferência.
As novas fontes não recebem marcações de palavras de Jesus criadas pelo app.

O código da coleção tem licença MIT (Daniel Amaral, 2022–2026). O catálogo
da fonte identifica TB e ALM1911 como domínio público e as demais adições
como protegidas por direitos autorais de suas editoras. A licença do código
não constitui autorização editorial para os textos. Por isso, desde a
1.12.0, só TB e ALM1911 vão no app, e as outras sete ficam no download a
pedido descrito acima.
