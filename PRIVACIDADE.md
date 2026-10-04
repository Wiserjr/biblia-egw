# Política de privacidade da Bíblia de Estudo

Última atualização: 4 de outubro de 2026.

## Sem conta

O app funciona sem conta. Sem conta, marcações, anotações, realces nos livros
e o plano de leitura ficam só no seu aparelho.

Mesmo sem conta, o app usa a internet para baixar os livros de Ellen G. White
(do site do Centro de Pesquisas Ellen G. White) e para ver se há versão nova
(no GitHub). Essas consultas não levam dados seus.

## Com conta

Quem cria uma conta (em *Ajustes → Seus dados → Entrar ou criar conta*) guarda
na nuvem:

- o e-mail e a senha da conta;
- as marcações e anotações nos versículos;
- os realces nos livros, com o trecho realçado e a sua nota;
- o plano de leitura em andamento e os dias lidos.

Os livros baixados e os ajustes de leitura (letra, tema, tradução) não vão
para a nuvem.

Esses dados servem só para aparecerem nos seus outros aparelhos. O app não
tem anúncios e não usa os dados para mais nada.

### Onde ficam

No Firebase, do Google: a conta no Firebase Authentication e o resto no Cloud
Firestore, em São Paulo (região `southamerica-east1`). A senha fica guardada
pelo Firebase de forma que nem o app nem o responsável por ele conseguem lê-la.

Pelo app, cada conta só lê e grava os próprios dados. O responsável pelo app
administra o projeto no Firebase e, por isso, tem acesso técnico a esses
dados.

### Excluir

Em *Ajustes → Seus dados → Conta → Excluir conta e dados na nuvem*, a conta e
tudo o que ela guarda na nuvem são apagados na hora. O que está no aparelho
continua lá.

## Dúvidas

Abra uma issue em <https://github.com/Wiserjr/biblia-egw/issues>.
