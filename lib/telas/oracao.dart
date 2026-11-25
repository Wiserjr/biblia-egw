import 'package:flutter/material.dart';

import '../dados/ajustes.dart';
import '../dados/lembrete.dart';
import '../dados/oracao.dart';

/// "25/11/2026".
String dataCurta(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

/// A lista de oração: pedidos, respondidas e arquivados.
class TelaOracao extends StatelessWidget {
  const TelaOracao({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Ajustes.instancia,
      builder: (context, _) {
        final todas = Ajustes.instancia.oracoes;
        final ativas = [
          for (final o in todas)
            if (o.ativa) o,
        ];
        final respondidas = [
          for (final o in todas)
            if (o.respondida) o,
        ]..sort((a, b) => b.respondidaEm!.compareTo(a.respondidaEm!));
        final arquivadas = [
          for (final o in todas)
            if (o.arquivada && !o.respondida) o,
        ];
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Lista de oração'),
              actions: [
                if (Lembrete.suportado)
                  IconButton(
                    tooltip: 'Lembrete de oração',
                    isSelected: Ajustes.instancia.lembreteOracao,
                    icon: const Icon(Icons.notifications_none),
                    selectedIcon: const Icon(Icons.notifications_active),
                    onPressed: () => _lembrete(context),
                  ),
              ],
              bottom: TabBar(
                tabs: [
                  Tab(text: 'Pedidos (${ativas.length})'),
                  Tab(text: 'Respondidas (${respondidas.length})'),
                  const Tab(text: 'Arquivados'),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Novo pedido'),
              onPressed: () => editarOracao(context),
            ),
            body: TabBarView(
              children: [
                _Lista(
                  oracoes: ativas,
                  vazio:
                      'Nenhum pedido ainda.\n\nToque em "Novo pedido" para '
                      'guardar pelo que você quer orar: por alguém, por uma '
                      'decisão, por uma necessidade.',
                ),
                _Lista(
                  oracoes: respondidas,
                  vazio:
                      'Quando Deus responder um pedido, marque-o como '
                      'respondido. Ele fica aqui, para lembrar o que Deus '
                      'já fez.',
                ),
                _Lista(
                  oracoes: arquivadas,
                  vazio: 'Pedidos que você arquivar ficam aqui.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _lembrete(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => const SafeArea(child: LembreteOracao()),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.oracoes, required this.vazio});

  final List<Oracao> oracoes;
  final String vazio;

  @override
  Widget build(BuildContext context) {
    if (oracoes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(vazio, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: oracoes.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _ItemOracao(oracao: oracoes[i]),
    );
  }
}

class _ItemOracao extends StatelessWidget {
  const _ItemOracao({required this.oracao});

  final Oracao oracao;

  @override
  Widget build(BuildContext context) {
    final o = oracao;
    final t = Theme.of(context);
    final linhas = <String>[
      if (o.detalhes != null) o.detalhes!,
      if (o.respondida)
        'Respondida em ${dataCurta(DateTime.fromMillisecondsSinceEpoch(o.respondidaEm!))}'
            '${o.resposta == null ? '' : ': ${o.resposta}'}'
      else
        'Desde ${dataCurta(o.criadaEm)}',
    ];
    return ListTile(
      leading: Icon(
        o.respondida
            ? Icons.check_circle
            : o.arquivada
            ? Icons.archive_outlined
            : Icons.favorite_border,
        color: o.respondida ? t.colorScheme.primary : null,
      ),
      title: Text(o.texto),
      subtitle: Text(linhas.join('\n')),
      isThreeLine: linhas.length > 1,
      onTap: () => editarOracao(context, o),
      trailing: PopupMenuButton<String>(
        tooltip: 'Mais opções',
        onSelected: (op) => _acao(context, op),
        itemBuilder: (_) => [
          if (!o.respondida)
            const PopupMenuItem(
              value: 'respondida',
              child: ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('Deus respondeu'),
              ),
            )
          else
            const PopupMenuItem(
              value: 'pendente',
              child: ListTile(
                leading: Icon(Icons.undo),
                title: Text('Voltar para os pedidos'),
              ),
            ),
          if (!o.respondida)
            PopupMenuItem(
              value: o.arquivada ? 'desarquivar' : 'arquivar',
              child: ListTile(
                leading: Icon(
                  o.arquivada
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                title: Text(
                  o.arquivada ? 'Voltar para os pedidos' : 'Arquivar',
                ),
              ),
            ),
          const PopupMenuItem(
            value: 'apagar',
            child: ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('Apagar'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acao(BuildContext context, String op) async {
    final aj = Ajustes.instancia;
    final o = oracao;
    switch (op) {
      case 'respondida':
        final resposta = await _perguntarResposta(context);
        if (resposta == null) return;
        aj.salvarOracao(
          o.copiar(
            respondidaEm: DateTime.now().millisecondsSinceEpoch,
            resposta: resposta,
            arquivada: false,
          ),
        );
      case 'pendente':
        aj.salvarOracao(o.copiar(semResposta: true, arquivada: false));
      case 'arquivar':
        aj.salvarOracao(o.copiar(arquivada: true));
      case 'desarquivar':
        aj.salvarOracao(o.copiar(arquivada: false));
      case 'apagar':
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Apagar o pedido?'),
            content: Text(
              '"${o.texto}" sai da lista, também nos outros aparelhos da sua '
              'conta.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Apagar'),
              ),
            ],
          ),
        );
        if (ok == true) aj.apagarOracao(o);
    }
  }

  /// O que a pessoa quer registrar sobre a resposta ('' se nada), ou null se
  /// cancelar.
  Future<String?> _perguntarResposta(BuildContext context) {
    final campo = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Deus respondeu'),
        content: TextField(
          controller: campo,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Como foi? (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, campo.text),
            child: const Text('Marcar como respondida'),
          ),
        ],
      ),
    );
  }
}

/// Cria um pedido novo ou edita [oracao].
Future<void> editarOracao(BuildContext context, [Oracao? oracao]) async {
  final texto = TextEditingController(text: oracao?.texto);
  final detalhes = TextEditingController(text: oracao?.detalhes);
  final resposta = TextEditingController(text: oracao?.resposta);
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(c).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            oracao == null ? 'Novo pedido' : 'Pedido',
            style: Theme.of(c).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: texto,
            autofocus: oracao == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Pelo que orar',
              hintText: 'Ex.: a saúde da minha mãe',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: detalhes,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Detalhes, um versículo (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (oracao?.respondida ?? false) ...[
            const SizedBox(height: 12),
            TextField(
              controller: resposta,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Como Deus respondeu',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || texto.text.trim().isEmpty) return;
  final agora = DateTime.now().millisecondsSinceEpoch;
  Ajustes.instancia.salvarOracao(
    oracao == null
        ? Oracao(
            id: agora,
            texto: texto.text.trim(),
            detalhes: detalhes.text.trim().isEmpty
                ? null
                : detalhes.text.trim(),
            atualizado: agora,
          )
        : Oracao(
            id: oracao.id,
            texto: texto.text.trim(),
            detalhes: detalhes.text.trim().isEmpty
                ? null
                : detalhes.text.trim(),
            atualizado: agora,
            respondidaEm: oracao.respondidaEm,
            resposta: resposta.text.trim().isEmpty
                ? null
                : resposta.text.trim(),
            arquivada: oracao.arquivada,
          ),
  );
}

/// Liga o lembrete diário de oração e escolhe a hora.
class LembreteOracao extends StatelessWidget {
  const LembreteOracao({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Ajustes.instancia,
      builder: (context, _) {
        final aj = Ajustes.instancia;
        final m = aj.lembreteOracaoMinutos;
        final hora = TimeOfDay(hour: m ~/ 60, minute: m % 60);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Lembrete de oração'),
              subtitle: const Text('Um aviso por dia, com os seus pedidos'),
              value: aj.lembreteOracao,
              onChanged: (v) => _ligar(context, v),
            ),
            if (aj.lembreteOracao)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text('Todo dia às ${hora.format(context)}'),
                subtitle: const Text('Toque para mudar a hora'),
                onTap: () => _mudarHora(context, hora),
              ),
          ],
        );
      },
    );
  }

  Future<void> _mudarHora(BuildContext context, TimeOfDay atual) async {
    final h = await showTimePicker(
      context: context,
      initialTime: atual,
      helpText: 'Hora do lembrete de oração',
    );
    if (h == null) return;
    Ajustes.instancia.lembreteOracaoMinutos = h.hour * 60 + h.minute;
    await Lembrete.instancia.atualizar();
  }

  Future<void> _ligar(BuildContext context, bool v) async {
    if (v) {
      final msg = ScaffoldMessenger.of(context);
      if (!await Lembrete.instancia.pedirPermissao()) {
        msg.showSnackBar(
          const SnackBar(
            content: Text(
              'Sem permissão para notificações. Libere nas configurações do '
              'celular, em Apps > Bíblia de Estudo > Notificações.',
            ),
          ),
        );
        return;
      }
    }
    Ajustes.instancia.lembreteOracao = v;
    await Lembrete.instancia.atualizar();
  }
}
