# Traduções de damarals/biblias

Fonte: https://github.com/damarals/biblias

Revisão: `08bfb8f3d569e5a8dd53a0ebefafda416eb066d7`.

Importação do JSON canônico de AS21, JFAA, KJF, NBV, TB, ALM1911, OL,
MENS e VFL. IDs estáveis 16–24. As doze traduções anteriores conservam seus
IDs, textos e ordem. As nove adicionais aparecem depois delas.

O aplicativo compartilha este banco entre Android e Windows. A atualização
do número da versão faz o banco embarcado substituir a cópia de leitura;
marcações e preferências continuam separadas.

Para reproduzir a importação sobre o banco atual:

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
não constitui autorização editorial para os textos. A integração local
não equivale a publicação de uma release nem à verificação dessas autorizações.
