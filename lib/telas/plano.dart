import 'package:flutter/material.dart';

import '../dados/ajustes.dart';
import '../dados/modelos.dart';
import '../dados/plano.dart';

/// Plano de leitura: a leitura de hoje (o primeiro dia ainda não lido), o
/// progresso e a lista de todos os dias. Tocar num capítulo abre o leitor.
class TelaPlano extends StatelessWidget {
  const TelaPlano({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Ajustes.instancia,
      builder: (context, _) {
        final plano = PlanoLeitura.porId(Ajustes.instancia.plano);
        return Scaffold(
          appBar: AppBar(
            title: Text(plano?.nome ?? 'Plano de leitura'),
            actions: [
              if (plano != null)
                PopupMenuButton<String>(
                  onSelected: (_) => _encerrar(context),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'encerrar',
                      child: Text('Trocar ou encerrar o plano'),
                    ),
                  ],
                ),
            ],
          ),
          body: plano == null
              ? const _EscolherPlano()
              : _Progresso(plano: plano),
        );
      },
    );
  }

  Future<void> _encerrar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Encerrar o plano?'),
        content: const Text(
          'O progresso deste plano será apagado. Depois você pode escolher '
          'outro plano ou começar este de novo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (ok == true) Ajustes.instancia.encerrarPlano();
  }
}

class _EscolherPlano extends StatelessWidget {
  const _EscolherPlano();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Escolha um plano. A cada dia, o app mostra o que ler e você marca '
          'como lido. Se atrasar, o plano continua de onde você parou.',
          style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor),
        ),
        const SizedBox(height: 12),
        for (final p in PlanoLeitura.todos)
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: Text(p.nome),
              subtitle: Text('${p.descricao}\n${p.dias} dias'),
              isThreeLine: true,
              onTap: () => Ajustes.instancia.iniciarPlano(p.id),
            ),
          ),
      ],
    );
  }
}

class _Progresso extends StatelessWidget {
  const _Progresso({required this.plano});

  final PlanoLeitura plano;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final aj = Ajustes.instancia;
    final lidos = aj.diasLidos;
    final leituras = plano.leituras;
    final feitos = lidos.where((d) => d < plano.dias).length;
    int? hoje;
    for (var d = 0; d < plano.dias; d++) {
      if (!lidos.contains(d)) {
        hoje = d;
        break;
      }
    }

    void abrir(Posicao p) => Navigator.pop(context, p);

    return ListView.builder(
      itemCount: plano.dias + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: feitos / plano.dias),
                const SizedBox(height: 8),
                Text(
                  '$feitos de ${plano.dias} dias lidos '
                  '(${(100 * feitos / plano.dias).floor()}%)',
                  style: t.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (hoje == null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.celebration_outlined),
                      title: const Text('Plano concluído!'),
                      subtitle: Text('Você leu ${plano.nome.toLowerCase()}.'),
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Leitura de hoje · dia ${hoje + 1}',
                            style: t.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(descreverLeitura(leituras[hoje])),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final c in leituras[hoje])
                                ActionChip(
                                  label: Text(descreverLeitura([c])),
                                  onPressed: () => abrir(c),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text('Marcar como lido'),
                              onPressed: () => aj.marcarDia(hoje!, true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text('Todos os dias', style: t.textTheme.titleSmall),
              ],
            ),
          );
        }
        final d = i - 1;
        return CheckboxListTile(
          value: lidos.contains(d),
          onChanged: (v) => aj.marcarDia(d, v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('Dia ${d + 1}'),
          subtitle: Text(descreverLeitura(leituras[d])),
          secondary: IconButton(
            tooltip: 'Abrir',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => abrir(leituras[d].first),
          ),
        );
      },
    );
  }
}
