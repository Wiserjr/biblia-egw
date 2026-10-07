import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dados/quiz_biblico.dart';
import '../dados/quiz_migracao.dart';
import 'versiculos_flutuantes.dart';

class TelaQuizBiblico extends StatefulWidget {
  const TelaQuizBiblico({super.key});
  @override
  State<TelaQuizBiblico> createState() => _TelaQuizBiblicoState();
}

class _TelaQuizBiblicoState extends State<TelaQuizBiblico> {
  Map<String, dynamic>? livro;
  bool ocupado = true;
  String? erro;
  int recorde = 0;
  Future<File> arquivo() async => File(
    '${(await getApplicationSupportDirectory()).path}/quiz_cpb_pessoal.json',
  );
  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    try {
      final f = await arquivo();
      var dados = await f.exists()
          ? jsonDecode(await f.readAsString()) as Map<String, dynamic>
          : null;
      if (dados != null) {
        final indice = jsonDecode(
          await rootBundle.loadString('assets/quiz_indice_cpb.json'),
        ) as Map<String, dynamic>;
        final atualizado = atualizarBancoQuiz(dados, indice);
        if (!identical(atualizado, dados)) {
          await f.writeAsString(jsonEncode(atualizado), flush: true);
          dados = atualizado;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          livro = dados;
          recorde = prefs.getInt('quiz_cpb_recorde') ?? 0;
        });
      }
    } catch (_) {
      erro = 'Não foi possível ler o livro importado. Importe novamente sua cópia.';
    }
    if (mounted) setState(() => ocupado = false);
  }

  Future<void> importar() async {
    try {
      final escolha = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['epub'],
      );
      if (escolha == null) return;
      setState(() {
        ocupado = true;
        erro = null;
      });
      final escolhido = escolha;
      if ((await escolhido.length() ?? 0) > 20 * 1024 * 1024) {
        throw const FormatException('Selecione um EPUB de até 20 MB.');
      }
      final bytes = await escolhido.readAsBytes();
      final indice = jsonDecode(
        await rootBundle.loadString('assets/quiz_indice_cpb.json'),
      ) as Map<String, dynamic>;
      final dados = await compute(importarQuiz, {
        'bytes': bytes,
        'indice': indice,
      });
      final f = await arquivo();
      await f.parent.create(recursive: true);
      final temporario = File('${f.path}.tmp');
      await temporario.writeAsString(jsonEncode(dados), flush: true);
      // A validação termina antes de substituir a importação anterior.
      await temporario.copy(f.path);
      await temporario.delete();
      if (mounted) setState(() => livro = dados);
    } catch (e) {
      if (mounted) {
        setState(
          () => erro = e is FormatException
              ? e.message
              : 'Não foi possível importar o EPUB. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> jogar() async {
    final perguntas = (livro!['perguntas'] as List)
        .map((p) => PerguntaQuiz.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    final prefs = await SharedPreferences.getInstance();
    final chave = 'quiz_cpb_historico_${livro!['hash']}';
    Map<String, int> historico;
    try {
      historico = Map<String, int>.from(
        jsonDecode(prefs.getString(chave) ?? '{}'),
      );
    } catch (_) {
      historico = {};
    }
    var gravacao = Future<void>.value();
    final partida = PartidaQuiz(
      perguntas,
      historico: historico,
      aoExibir: (_) {
        final copia = jsonEncode(historico);
        gravacao = gravacao.then((_) async {
          await prefs.setString(chave, copia);
        });
      },
    );
    if (!mounted) return;
    final pontos = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => TelaPartidaQuiz(partida: partida)),
    );
    await gravacao;
    if (pontos != null && pontos > recorde) {
      await (await SharedPreferences.getInstance()).setInt(
        'quiz_cpb_recorde',
        pontos,
      );
      if (mounted) setState(() => recorde = pontos);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Desafio Bíblico')),
    body: ocupado
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    size: 72,
                    color: Colors.amber,
                  ),
                  Text(
                    'Rumo ao Milhão',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '15 rodadas de perguntas bíblicas, quatro alternativas e até 1 milhão de pontos. A pontuação é virtual; não há prêmio em dinheiro.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Curiosidades e Testes Bíblicos • Rafael Escandón • Casa Publicadora Brasileira. Importe sua cópia pessoal do EPUB para consultar o conteúdo textual e liberar as perguntas. O arquivo original é preservado e o material importado fica neste aparelho.',
                  ),
                  if (erro != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        erro!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: importar,
                    icon: const Icon(Icons.file_open_outlined),
                    label: Text(
                      livro == null
                          ? 'Importar meu EPUB'
                          : 'Importar novamente',
                    ),
                  ),
                  if (livro != null) ...[
                    FilledButton.icon(
                      onPressed: jogar,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Começar o desafio'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TelaInformacoesQuiz(
                            secoes: List<Map<String, dynamic>>.from(
                              livro!['secoes'],
                            ),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Curiosidades, testes e pesquisas'),
                    ),
                    Text(
                      'Melhor resultado: ${formatarPontos(recorde)} pontos',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Como jogar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Escolha uma alternativa e confirme. A dificuldade aumenta a cada cinco acertos. Você pode pular três perguntas e usar “Meio a meio” uma vez. As rodadas 5 e 10 garantem 10 mil e 75 mil pontos. Ao errar, recebe a pontuação garantida; ao parar, conserva os pontos conquistados. Não há limite de tempo. Uma nova partida começa do zero.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'O desafio usa 180 perguntas selecionadas. O histórico neste aparelho prioriza as questões menos vistas em cada nível, inclusive as puladas, e permanece entre partidas. O leitor conserva o texto do autor; imagens e diagramação do EPUB não são reproduzidas. Confira as referências bíblicas ao estudar.',
                  ),
                ],
              ),
            ),
          ),
  );
}

String formatarPontos(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]}.',
);

class TelaPartidaQuiz extends StatefulWidget {
  const TelaPartidaQuiz({super.key, required this.partida});
  final PartidaQuiz partida;
  @override
  State<TelaPartidaQuiz> createState() => _TelaPartidaQuizState();
}

class _TelaPartidaQuizState extends State<TelaPartidaQuiz> {
  String? selecionada;
  PartidaQuiz get p => widget.partida;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: p.terminou,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) {
        if (p.terminou) {
          final prefs = await SharedPreferences.getInstance();
          if (p.resultado > (prefs.getInt('quiz_cpb_recorde') ?? 0)) {
            await prefs.setInt('quiz_cpb_recorde', p.resultado);
          }
        }
        return;
      }
      final sair = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Encerrar a partida?'),
          content: const Text('Você conserva os pontos já conquistados.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Continuar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Encerrar'),
            ),
          ],
        ),
      );
      if (sair == true && mounted) setState(p.parar);
    },
    child: Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff101a35),
        cardTheme: const CardThemeData(color: Color(0xff202f51)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff101a35),
          foregroundColor: Color(0xfff5f6fa),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      // O contexto interno lê o tema do quiz, inclusive para estilos explícitos.
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Rumo ao Milhão')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '${formatarPontos(p.pontos)} pontos • ${p.acertos} acertos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Garantidos: ${formatarPontos(p.garantidos)} • Rodada ${p.acertos == 15
                        ? 15
                        : p.respondeu && p.acertou
                        ? p.acertos
                        : p.acertos + 1}/15',
                  ),
                  const SizedBox(height: 20),
                  if (!p.terminou || p.respondeu) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          p.atual.texto,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                    for (final o in p.opcoes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: OutlinedButton(
                          onPressed:
                              p.respondeu || p.terminou || p.ocultas.contains(o)
                              ? null
                              : () => setState(() => selecionada = o),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(18),
                            backgroundColor: selecionada == o
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            foregroundColor: selecionada == o
                                ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                : Theme.of(context).colorScheme.primary,
                          ),
                          child: Text(
                            p.ocultas.contains(o)
                                ? 'Alternativa eliminada'
                                : '${String.fromCharCode(65 + p.opcoes.indexOf(o))}. $o',
                          ),
                        ),
                      ),
                  ],
                  if (!p.respondeu && !p.terminou) ...[
                    FilledButton(
                      onPressed: selecionada == null
                          ? null
                          : () => setState(() => p.confirmar(selecionada!)),
                      child: const Text('Confirmar resposta'),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: p.usouMetade
                              ? null
                              : () => setState(() {
                                  p.metade();
                                  if (p.ocultas.contains(selecionada)) {
                                    selecionada = null;
                                  }
                                }),
                          child: const Text('Meio a meio'),
                        ),
                        OutlinedButton(
                          onPressed: p.pulos == 0
                              ? null
                              : () => setState(() {
                                  p.pular();
                                  selecionada = null;
                                }),
                          child: Text('Pular (${p.pulos})'),
                        ),
                        TextButton(
                          onPressed: () => setState(p.parar),
                          child: const Text('Parar e conservar pontos'),
                        ),
                      ],
                    ),
                  ],
                  if (p.respondeu) ...[
                    const SizedBox(height: 12),
                    Text(
                      p.acertou
                          ? 'Resposta correta!'
                          : 'A resposta correta é: ${p.atual.resposta}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text(
                      'Fonte: Curiosidades e Testes Bíblicos, Rafael Escandón (CPB).',
                    ),
                    TextButton.icon(
                      onPressed: () => mostrarVersiculosFlutuantes(
                        context,
                        p.atual.referencias,
                      ),
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Conferir na Bíblia'),
                    ),
                    if (!p.terminou)
                      FilledButton(
                        onPressed: () => setState(() {
                          p.proxima();
                          selecionada = null;
                        }),
                        child: const Text('Próxima rodada'),
                      ),
                  ],
                  if (p.terminou) ...[
                    const SizedBox(height: 20),
                    Text(
                      p.acertos == 15
                          ? 'Você chegou ao milhão!'
                          : 'Partida encerrada',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text('Resultado: ${formatarPontos(p.resultado)} pontos'),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, p.resultado),
                      child: const Text('Voltar ao desafio'),
                    ),
                  ],
                  ExpansionTile(
                    title: const Text('Escada de pontos'),
                    children: [
                      for (var i = 14; i >= 0; i--)
                        ListTile(
                          dense: true,
                          title: Text('Rodada ${i + 1}'),
                          trailing: Text(
                            formatarPontos(PartidaQuiz.premios[i]),
                          ),
                          leading: Icon(
                            i < p.acertos
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class TelaInformacoesQuiz extends StatefulWidget {
  const TelaInformacoesQuiz({super.key, required this.secoes});
  final List<Map<String, dynamic>> secoes;
  @override
  State<TelaInformacoesQuiz> createState() => _TelaInformacoesQuizState();
}

class _TelaInformacoesQuizState extends State<TelaInformacoesQuiz> {
  String filtro = '', grupo = 'Todos';
  @override
  Widget build(BuildContext context) {
    final secoes = widget.secoes
        .where(
          (s) =>
              (grupo == 'Todos' || grupo == s['grupo']) &&
              '${s['titulo']} ${(s['paragrafos'] as List).join(' ')}'
                  .toLowerCase()
                  .contains(filtro.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Curiosidades e testes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar no livro',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (s) => setState(() => filtro = s),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final g in [
                  'Todos',
                  'Curiosidades',
                  'Testes',
                  'Pesquisas',
                  'Gabaritos',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(g),
                      selected: grupo == g,
                      onSelected: (_) => setState(() => grupo = g),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: secoes.length,
              itemBuilder: (c, i) {
                final s = secoes[i];
                return ExpansionTile(
                  key: ValueKey('${s['grupo']}-${s['titulo']}-$i'),
                  title: Text(s['titulo']),
                  subtitle: Text(s['grupo']),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectionArea(
                        child: Text((s['paragrafos'] as List).join('\n\n')),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
