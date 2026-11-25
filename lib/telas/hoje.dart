import 'package:flutter/material.dart';

import '../dados/ajustes.dart';
import '../dados/biblia.dart';
import '../dados/caminhada.dart';
import '../dados/estudo.dart';
import '../dados/guia_biblioteca.dart';
import '../dados/meditacao.dart';
import '../dados/modelos.dart';
import '../dados/plano.dart';
import '../dados/referencias.dart';
import '../dados/versiculo_do_dia.dart';
import 'caminhada.dart';
import 'cartao_versiculo.dart';
import 'guia_biblioteca.dart';
import 'oracao.dart';
import 'plano.dart';

/// O versículo do dia, com o texto na tradução [versao], ou null.
Future<({Posicao inicio, int ate, String texto})?> versiculoDeHoje(
  Versao versao, [
  DateTime? dia,
]) async {
  final ref = await VersiculoDoDia.de(dia ?? DateTime.now());
  if (ref == null) return null;
  final versos = await Biblia.instancia.capitulo(
    versao.id,
    ref.livro,
    ref.capitulo,
  );
  final texto = versos
      .where((v) => v.numero >= ref.versiculo && v.numero <= ref.ate)
      .map((v) => textoPuro(v.texto).trim())
      .join(' ');
  if (texto.isEmpty) return null;
  return (
    inicio: Posicao(ref.livro, ref.capitulo, ref.versiculo),
    ate: ref.ate,
    texto: texto,
  );
}

/// "Hoje": um roteiro curto para o dia, com o versículo do dia, a leitura da
/// Bíblia, a meditação matinal de Ellen G. White e um momento de oração.
///
/// Devolve (pelo Navigator) a posição a abrir no leitor.
class TelaHoje extends StatefulWidget {
  const TelaHoje({super.key, required this.versao, this.carregarMeditacao});

  final Versao versao;

  /// Para os testes: os livros de meditação e seus capítulos.
  final Future<(Map<int, Obra>, List<CapituloObra>)> Function()?
  carregarMeditacao;

  @override
  State<TelaHoje> createState() => _TelaHojeState();
}

class _TelaHojeState extends State<TelaHoje> {
  late final _versiculo = versiculoDeHoje(widget.versao);
  late final _meditacoes = (widget.carregarMeditacao ?? _carregar)();

  static Future<(Map<int, Obra>, List<CapituloObra>)> _carregar() async {
    final obras = await Estudo.instancia.obras();
    final caps = <CapituloObra>[];
    for (final id in obrasMeditacao) {
      if (obras.containsKey(id)) {
        caps.addAll(await Estudo.instancia.capitulosObras(obra: id));
      }
    }
    return (
      {
        for (final id in obrasMeditacao)
          if (obras[id] != null) id: obras[id]!,
      },
      caps,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoje'),
        actions: [
          IconButton(
            tooltip: 'Sua caminhada',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaCaminhada()),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Ajustes.instancia,
        builder: (context, _) {
          final aj = Ajustes.instancia;
          final feitos = [
            aj.versiculoDoDiaVisto,
            aj.leuNoDia(hoje),
            aj.meditacaoLidaHoje,
            aj.oreiHoje,
          ].where((x) => x).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            children: [
              _Cabecalho(dia: hoje, feitos: feitos),
              const SizedBox(height: 8),
              _CartaoVersiculo(versao: widget.versao, versiculo: _versiculo),
              const _CartaoLeitura(),
              _CartaoMeditacao(dados: _meditacoes),
              const _CartaoOracao(),
            ],
          );
        },
      ),
    );
  }
}

const _diasSemana = [
  'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', //
  'Sexta-feira', 'Sábado', 'Domingo',
];

/// Data, sequência de dias e quantos passos de hoje já foram feitos.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.dia, required this.feitos});

  final DateTime dia;
  final int feitos;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final seq = sequenciaAtual(Ajustes.instancia.diasDeLeitura, dia);
    return Card(
      color: t.colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TelaCaminhada()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_diasSemana[dia.weekday - 1]}, '
                      '${dataPorExtenso(dia)}',
                      style: t.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feitos == 4
                          ? 'Tudo feito hoje. Deus abençoe o seu dia!'
                          : '$feitos de 4 feitos hoje',
                      style: t.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: feitos / 4,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 32,
                    color: seq > 0 ? Colors.deepOrange : t.disabledColor,
                  ),
                  Text('$seq', style: t.textTheme.titleLarge),
                  Text(
                    seq == 1 ? 'dia' : 'dias',
                    style: t.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Um passo do dia: título com o sinal de feito e o conteúdo.
class _Passo extends StatelessWidget {
  const _Passo({
    required this.icone,
    required this.titulo,
    required this.feito,
    required this.children,
  });

  final IconData icone;
  final String titulo;
  final bool feito;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, color: t.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(titulo, style: t.textTheme.titleMedium)),
                if (feito)
                  Tooltip(
                    message: 'Feito hoje',
                    child: Icon(
                      Icons.check_circle,
                      color: t.colorScheme.primary,
                    ),
                  )
                else
                  Icon(Icons.circle_outlined, color: t.disabledColor),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _CartaoVersiculo extends StatelessWidget {
  const _CartaoVersiculo({required this.versao, required this.versiculo});

  final Versao versao;
  final Future<({Posicao inicio, int ate, String texto})?> versiculo;

  @override
  Widget build(BuildContext context) {
    final aj = Ajustes.instancia;
    return FutureBuilder(
      future: versiculo,
      builder: (context, snap) {
        final v = snap.data;
        return _Passo(
          icone: Icons.wb_sunny_outlined,
          titulo: 'Versículo do dia',
          feito: aj.versiculoDoDiaVisto,
          children: [
            if (v == null)
              Text(
                snap.connectionState == ConnectionState.done
                    ? 'O versículo de hoje não está disponível.'
                    : 'Carregando…',
              )
            else ...[
              Text(
                v.texto,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 4),
              Text(
                '${referenciaDaPassagem(v.inicio, v.ate)} (${versao.sigla})',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Ver como imagem'),
                    onPressed: () async {
                      aj.marcarVersiculoDoDiaVisto();
                      final p = await Navigator.push<Posicao>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CartaoVersiculo(
                            titulo: 'Versículo do dia',
                            inicio: v.inicio,
                            ate: v.ate,
                            texto: v.texto,
                            sigla: versao.sigla,
                            podeAbrir: true,
                          ),
                        ),
                      );
                      if (p != null && context.mounted) {
                        Navigator.pop(context, p);
                      }
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Abrir na Bíblia'),
                    onPressed: () {
                      aj.marcarVersiculoDoDiaVisto();
                      Navigator.pop(context, v.inicio);
                    },
                  ),
                  if (!aj.versiculoDoDiaVisto)
                    TextButton(
                      onPressed: aj.marcarVersiculoDoDiaVisto,
                      child: const Text('Li'),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A leitura da Bíblia de hoje: a do plano, ou continuar de onde parou.
class _CartaoLeitura extends StatelessWidget {
  const _CartaoLeitura();

  @override
  Widget build(BuildContext context) {
    final aj = Ajustes.instancia;
    final pl = PlanoLeitura.porId(aj.plano);
    final leitura = aj.leituraHoje();
    final ultima = aj.ultimaPosicao;
    return _Passo(
      icone: Icons.menu_book_outlined,
      titulo: 'Leitura da Bíblia',
      feito: aj.leuNoDia(DateTime.now()),
      children: [
        if (pl == null) ...[
          Text(
            'Continue de onde parou: '
            '${Referencias.nome(ultima.livro)} ${ultima.capitulo}.',
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Continuar'),
                onPressed: () => Navigator.pop(context, ultima),
              ),
              TextButton(
                onPressed: () => _abrirPlano(context),
                child: const Text('Escolher um plano de leitura'),
              ),
            ],
          ),
        ] else if (leitura == null) ...[
          Text('${pl.nome}: a leitura de hoje já foi feita.'),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => _abrirPlano(context),
                child: const Text('Ver o plano'),
              ),
              if (pl.id == PlanoLeitura.reavivados.id)
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Comentário do dia'),
                  onPressed: () =>
                      abrirSite(context, comentarioDoDia(DateTime.now())),
                ),
            ],
          ),
        ] else ...[
          Text(leitura.rotulo),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Ler'),
                onPressed: () =>
                    Navigator.pop(context, leitura.capitulos.first),
              ),
              TextButton(
                onPressed: () => aj.marcarDia(leitura.dia, true),
                child: const Text('Marcar como lida'),
              ),
              if (pl.id == PlanoLeitura.reavivados.id)
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Comentário do dia'),
                  onPressed: () =>
                      abrirSite(context, comentarioDoDia(DateTime.now())),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _abrirPlano(BuildContext context) async {
    final p = await Navigator.push<Posicao>(
      context,
      MaterialPageRoute(builder: (_) => const TelaPlano()),
    );
    if (p != null && context.mounted) Navigator.pop(context, p);
  }
}

/// A meditação matinal do livro escolhido, com a data de hoje.
class _CartaoMeditacao extends StatelessWidget {
  const _CartaoMeditacao({required this.dados});

  final Future<(Map<int, Obra>, List<CapituloObra>)> dados;

  @override
  Widget build(BuildContext context) {
    final aj = Ajustes.instancia;
    return FutureBuilder(
      future: dados,
      builder: (context, snap) {
        final d = snap.data;
        final obra = d?.$1[aj.meditacaoObra];
        final cap = obra == null
            ? null
            : meditacaoDoDia([
                for (final c in d!.$2)
                  if (c.obra == obra.id) c,
              ], DateTime.now());
        return _Passo(
          icone: Icons.wb_twilight,
          titulo: 'Meditação matinal',
          feito: aj.meditacaoLidaHoje,
          children: [
            if (d == null)
              const Text('Carregando…')
            else if (obra == null) ...[
              const Text(
                'Ellen G. White escreveu meditações para cada dia do ano. '
                'Escolha um dos livros para ler a de hoje.',
              ),
              TextButton.icon(
                icon: const Icon(Icons.library_books_outlined),
                label: const Text('Escolher o livro'),
                onPressed: () => _escolher(context, d.$1),
              ),
            ] else ...[
              if (cap == null)
                Text('${obra.titulo}: meditação de hoje não encontrada.')
              else ...[
                Text(
                  tituloSemData(cap.titulo),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(obra.titulo, style: Theme.of(context).textTheme.bodySmall),
              ],
              Wrap(
                spacing: 8,
                children: [
                  if (cap != null)
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.auto_stories_outlined),
                      label: const Text('Ler'),
                      onPressed: () async {
                        final abriu = await lerObra(
                          context,
                          obra,
                          pagina: cap.pagina,
                        );
                        if (abriu) aj.marcarMeditacaoLida();
                      },
                    ),
                  TextButton(
                    onPressed: () => _escolher(context, d.$1),
                    child: const Text('Trocar o livro'),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _escolher(BuildContext context, Map<int, Obra> obras) async {
    final atual = Ajustes.instancia.meditacaoObra;
    final id = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (c, rolagem) => ListView(
          controller: rolagem,
          children: [
            const ListTile(
              title: Text('Livro de meditações'),
              subtitle: Text(
                'Uma meditação por dia. O livro é baixado na primeira '
                'leitura.',
              ),
            ),
            for (final o in obras.values)
              ListTile(
                leading: Icon(o.id == atual ? Icons.check : null),
                title: Text(o.titulo),
                onTap: () => Navigator.pop(c, o.id),
              ),
          ],
        ),
      ),
    );
    if (id != null) Ajustes.instancia.meditacaoObra = id;
  }
}

/// Um momento de oração, com os pedidos da lista.
class _CartaoOracao extends StatelessWidget {
  const _CartaoOracao();

  @override
  Widget build(BuildContext context) {
    final aj = Ajustes.instancia;
    final ativos = aj.oracoes.where((o) => o.ativa).toList();
    return _Passo(
      icone: Icons.volunteer_activism_outlined,
      titulo: 'Oração',
      feito: aj.oreiHoje,
      children: [
        if (ativos.isEmpty)
          const Text(
            'Termine com uma oração. Na lista de oração você guarda os seus '
            'pedidos e marca os que Deus respondeu.',
          )
        else ...[
          const Text('Seus pedidos:'),
          for (final o in ativos.take(5))
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Text('• ${o.texto}'),
            ),
          if (ativos.length > 5)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Text('e mais ${ativos.length - 5}'),
            ),
        ],
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonalIcon(
              icon: Icon(aj.oreiHoje ? Icons.check : Icons.favorite_border),
              label: Text(aj.oreiHoje ? 'Orei hoje' : 'Marcar: orei hoje'),
              onPressed: () => aj.oreiHoje = !aj.oreiHoje,
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaOracao()),
              ),
              child: const Text('Lista de oração'),
            ),
          ],
        ),
      ],
    );
  }
}
