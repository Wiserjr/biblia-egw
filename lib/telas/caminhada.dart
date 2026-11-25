import 'package:flutter/material.dart';

import '../dados/ajustes.dart';
import '../dados/caminhada.dart';
import '../dados/referencias.dart';

/// Sua caminhada: sequência de dias, os últimos dias, capítulos lidos por
/// livro e as medalhas.
class TelaCaminhada extends StatelessWidget {
  const TelaCaminhada({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sua caminhada')),
      body: ListenableBuilder(
        listenable: Ajustes.instancia,
        builder: (context, _) {
          final aj = Ajustes.instancia;
          final c = aj.caminhada;
          final hoje = DateTime.now();
          final ganhas = c.ganhas();
          final porLivro = capitulosPorLivro(c.capitulos);
          final lidos = porLivro.values.fold(0, (a, b) => a + b);
          final todas = Caminhada.todas();
          final gerais = [
            for (final m in todas)
              if (!m.id.startsWith('livro-')) m,
          ];
          final livros = [
            for (final m in todas)
              if (m.id.startsWith('livro-')) m,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Numero(
                    icone: Icons.local_fire_department,
                    cor: Colors.deepOrange,
                    valor: '${sequenciaAtual(c.dias, hoje)}',
                    rotulo: 'dias seguidos',
                  ),
                  _Numero(
                    icone: Icons.star_outline,
                    valor: '${c.melhor}',
                    rotulo: 'melhor sequência',
                  ),
                  _Numero(
                    icone: Icons.calendar_month,
                    valor: '${c.dias.length}',
                    rotulo: 'dias de leitura',
                  ),
                  _Numero(
                    icone: Icons.menu_book,
                    valor: '$lidos',
                    rotulo: 'de 1.189 capítulos',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _UltimosDias(dias: c.dias, hoje: hoje),
              const SizedBox(height: 8),
              Text(
                'Conta como dia de leitura abrir um capítulo da Bíblia e '
                'ficar nele meio minuto, ouvi-lo ou marcar a leitura do plano.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _Titulo('Medalhas (${ganhas.length} de ${todas.length})'),
              _Grade(medalhas: gerais, ganhas: ganhas),
              const SizedBox(height: 16),
              _Titulo(
                'Livros lidos (${livros.where((m) => ganhas.contains(m.id)).length} de 66)',
              ),
              for (var l = 1; l <= 66; l++)
                _ProgressoLivro(livro: l, lidos: porLivro[l] ?? 0),
            ],
          );
        },
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Numero extends StatelessWidget {
  const _Numero({
    required this.icone,
    required this.valor,
    required this.rotulo,
    this.cor,
  });

  final IconData icone;
  final String valor;
  final String rotulo;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icone, color: cor ?? t.colorScheme.primary, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(valor, style: t.textTheme.titleLarge),
                    Text(rotulo, style: t.textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// As últimas cinco semanas, com os dias de leitura marcados.
class _UltimosDias extends StatelessWidget {
  const _UltimosDias({required this.dias, required this.hoje});

  final Set<String> dias;
  final DateTime hoje;

  static const _letras = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    // Começa na segunda-feira de quatro semanas atrás.
    final inicio = DateTime(
      hoje.year,
      hoje.month,
      hoje.day - (hoje.weekday - 1) - 28,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Titulo('Últimas semanas'),
        Row(
          children: [
            for (final l in _letras)
              Expanded(
                child: Center(child: Text(l, style: t.textTheme.labelSmall)),
              ),
          ],
        ),
        for (var semana = 0; semana < 5; semana++)
          Row(
            children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: _Dia(
                    dia: DateTime(
                      inicio.year,
                      inicio.month,
                      inicio.day + semana * 7 + d,
                    ),
                    hoje: hoje,
                    dias: dias,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Dia extends StatelessWidget {
  const _Dia({required this.dia, required this.hoje, required this.dias});

  final DateTime dia;
  final DateTime hoje;
  final Set<String> dias;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final futuro = DateTime(
      dia.year,
      dia.month,
      dia.day,
    ).isAfter(DateTime(hoje.year, hoje.month, hoje.day));
    final leu = dias.contains(diaIso(dia));
    final eHoje = diaIso(dia) == diaIso(hoje);
    return Padding(
      padding: const EdgeInsets.all(3),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: leu ? t.colorScheme.primary : null,
            border: eHoje
                ? Border.all(color: t.colorScheme.primary, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '${dia.day}',
            style: t.textTheme.labelSmall?.copyWith(
              color: leu
                  ? t.colorScheme.onPrimary
                  : futuro
                  ? t.disabledColor
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _Grade extends StatelessWidget {
  const _Grade({required this.medalhas, required this.ganhas});

  final List<Medalha> medalhas;
  final Set<String> ganhas;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in medalhas)
          _MedalhaVista(medalha: m, ganha: ganhas.contains(m.id)),
      ],
    );
  }
}

class _MedalhaVista extends StatelessWidget {
  const _MedalhaVista({required this.medalha, required this.ganha});

  final Medalha medalha;
  final bool ganha;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Tooltip(
      message: medalha.descricao,
      triggerMode: TooltipTriggerMode.tap,
      child: SizedBox(
        width: 100,
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: ganha
                  ? t.colorScheme.tertiaryContainer
                  : t.colorScheme.surfaceContainerHighest,
              child: Icon(
                ganha ? medalha.icone : Icons.lock_outline,
                color: ganha
                    ? t.colorScheme.onTertiaryContainer
                    : t.disabledColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              medalha.titulo,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: t.textTheme.labelSmall?.copyWith(
                color: ganha ? null : t.disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressoLivro extends StatelessWidget {
  const _ProgressoLivro({required this.livro, required this.lidos});

  final int livro;
  final int lidos;

  @override
  Widget build(BuildContext context) {
    final total = Referencias.capitulos[livro - 1];
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              Referencias.nome(livro),
              style: t.textTheme.bodyMedium?.copyWith(
                fontWeight: lidos >= total ? FontWeight.bold : null,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: lidos / total,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '$lidos/$total',
              textAlign: TextAlign.end,
              style: t.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mostra as medalhas que a pessoa acabou de ganhar.
void avisarMedalhas(
  ScaffoldMessengerState mensageiro,
  NavigatorState navegador,
  List<Medalha> novas,
) {
  if (novas.isEmpty) return;
  final nomes = novas.map((m) => m.titulo).join(', ');
  mensageiro.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              novas.length == 1
                  ? 'Nova medalha: $nomes'
                  : 'Novas medalhas: $nomes',
            ),
          ),
        ],
      ),
      action: SnackBarAction(
        label: 'Ver',
        onPressed: () => navegador.push(
          MaterialPageRoute(builder: (_) => const TelaCaminhada()),
        ),
      ),
    ),
  );
}
