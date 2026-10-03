import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dados/ajustes.dart';
import '../dados/lembrete.dart';
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
              : plano.porData
              ? _ProgressoPorData(plano: plano)
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
    if (ok == true) {
      Ajustes.instancia.encerrarPlano();
      Lembrete.instancia.atualizar();
    }
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
            color: p.porData ? t.colorScheme.secondaryContainer : null,
            child: ListTile(
              leading: Icon(
                p.porData ? Icons.groups_outlined : Icons.event_note_outlined,
              ),
              title: Text(p.nome),
              subtitle: Text(
                p.porData
                    ? '${p.descricao}\nHoje: '
                          '${descreverLeitura(p.leituraDoDia(p.diaDe(DateTime.now())))}'
                    : '${p.descricao}\n${p.dias} dias',
              ),
              isThreeLine: true,
              onTap: () => p.porData
                  ? _comecarPorData(context, p)
                  : Ajustes.instancia.iniciarPlano(p.id),
            ),
          ),
      ],
    );
  }

  /// No Reavivados, quem já vinha lendo com a igreja pode marcar de uma vez
  /// os capítulos deste ciclo até ontem.
  Future<void> _comecarPorData(BuildContext context, PlanoLeitura p) async {
    final hoje = p.diaDe(DateTime.now());
    final ciclo = p.inicioDoCiclo(hoje);
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(p.nome),
        content: Text(
          'Hoje a leitura é ${descreverLeitura(p.leituraDoDia(hoje))}. '
          'Você já vinha lendo o ${p.nome} desde '
          '${dataPorExtenso(p.dataDe(ciclo))}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sim, marcar os anteriores'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Começar hoje'),
          ),
        ],
      ),
    );
    if (r == null) return;
    Ajustes.instancia.iniciarPlano(
      p.id,
      comecou: r ? ciclo : hoje,
      lidosAntes: r ? [for (var d = ciclo; d < hoje; d++) d] : const [],
    );
    Lembrete.instancia.atualizar();
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
                const _LembreteDiario(),
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

const _meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', //
  'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

/// "3 de outubro de 2026".
String dataPorExtenso(DateTime d) =>
    '${d.day} de ${_meses[d.month - 1]} de ${d.year}';

/// Página do dia no site do Reavivados por Sua Palavra: os comentários
/// daquele capítulo (texto, vídeo e áudio).
Uri comentarioDoDia(DateTime d) {
  String dois(int n) => n.toString().padLeft(2, '0');
  return Uri.parse(
    'https://reavivadosporsuapalavra.org/${d.year}/${dois(d.month)}/${dois(d.day)}/',
  );
}

final _programaRadio = Uri.parse(
  'https://www.novotempo.com/programa/reavivadosporsuapalavraradio/',
);

Future<void> _abrirSite(BuildContext context, Uri url) async {
  final msg = ScaffoldMessenger.of(context);
  try {
    if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  msg.showSnackBar(
    const SnackBar(content: Text('Não foi possível abrir o navegador.')),
  );
}

/// Plano que segue o calendário (Reavivados por Sua Palavra): o capítulo de
/// hoje, os atrasados, o calendário do mês e o progresso do ciclo.
class _ProgressoPorData extends StatefulWidget {
  const _ProgressoPorData({required this.plano});

  final PlanoLeitura plano;

  @override
  State<_ProgressoPorData> createState() => _ProgressoPorDataState();
}

class _ProgressoPorDataState extends State<_ProgressoPorData> {
  late DateTime _mes = () {
    final h = DateTime.now();
    return DateTime.utc(h.year, h.month);
  }();

  PlanoLeitura get plano => widget.plano;

  void _abrir(Posicao p) => Navigator.pop(context, p);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final aj = Ajustes.instancia;
    final lidos = aj.diasLidos;
    final hoje = plano.diaDe(DateTime.now());
    final ciclo = plano.inicioDoCiclo(hoje);
    final feitos = lidos.where((d) => d >= ciclo && d < ciclo + plano.dias);
    final nFeitos = feitos.length;
    final atrasados = diasAtrasados(
      plano,
      lidos,
      hoje,
      comecou: aj.planoComecou,
    );
    final seguidos = diasSeguidos(lidos, hoje);
    final capHoje = plano.leituraDoDia(hoje);
    final lidoHoje = lidos.contains(hoje);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hoje, ${dataPorExtenso(plano.dataDe(hoje))}',
                  style: t.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  descreverLeitura(capHoje),
                  style: t.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Toque nos versículos para ver o que Ellen G. White '
                  'escreveu sobre eles.',
                  style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Ler'),
                      onPressed: () => _abrir(capHoje.first),
                    ),
                    OutlinedButton.icon(
                      icon: Icon(lidoHoje ? Icons.check_circle : Icons.check),
                      label: Text(lidoHoje ? 'Lido' : 'Marcar como lido'),
                      onPressed: () => aj.marcarDia(hoje, !lidoHoje),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.forum_outlined),
                      label: const Text('Comentário do dia'),
                      onPressed: () => _abrirSite(
                        context,
                        comentarioDoDia(plano.dataDe(hoje)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (atrasados.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.history),
              title: Text(
                atrasados.length == 1
                    ? '1 capítulo ficou para trás'
                    : '${atrasados.length} capítulos ficaram para trás',
              ),
              subtitle: const Text('Leia quando puder e marque aqui.'),
              shape: const Border(),
              children: [
                for (final d in atrasados.reversed.take(60))
                  CheckboxListTile(
                    value: false,
                    onChanged: (_) => aj.marcarDia(d, true),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(descreverLeitura(plano.leituraDoDia(d))),
                    subtitle: Text(dataPorExtenso(plano.dataDe(d))),
                    secondary: IconButton(
                      tooltip: 'Abrir',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _abrir(plano.leituraDoDia(d).first),
                    ),
                  ),
                if (atrasados.length > 1)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextButton(
                      onPressed: () => aj.marcarDias(atrasados, true),
                      child: const Text('Marcar todos como lidos'),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        LinearProgressIndicator(value: nFeitos / plano.dias),
        const SizedBox(height: 8),
        Text(
          'Ciclo ${plano.dataDe(ciclo).year} a '
          '${plano.dataDe(ciclo + plano.dias - 1).year}: '
          '$nFeitos de ${plano.dias} capítulos lidos'
          '${seguidos > 1 ? ' · $seguidos dias seguidos' : ''}',
          style: t.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _Calendario(
          plano: plano,
          mes: _mes,
          hoje: hoje,
          lidos: lidos,
          comecou: aj.planoComecou ?? ciclo,
          aoMudarMes: (m) => setState(() => _mes = m),
          aoTocar: (d) => _dia(context, d),
        ),
        const SizedBox(height: 8),
        const _LembreteDiario(),
        ListTile(
          leading: const Icon(Icons.radio_outlined),
          title: const Text('Programa no rádio Novo Tempo'),
          subtitle: const Text('Um capítulo por dia, com o Pr. Valdeci Júnior'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => _abrirSite(context, _programaRadio),
        ),
      ],
    );
  }

  Future<void> _dia(BuildContext context, int d) async {
    final aj = Ajustes.instancia;
    final lido = aj.diasLidos.contains(d);
    final caps = plano.leituraDoDia(d);
    final hoje = plano.diaDe(DateTime.now());
    final op = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(descreverLeitura(caps)),
              subtitle: Text(dataPorExtenso(plano.dataDe(d))),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Ler'),
              onTap: () => Navigator.pop(c, 'ler'),
            ),
            if (d <= hoje)
              ListTile(
                leading: Icon(lido ? Icons.remove_done : Icons.check),
                title: Text(lido ? 'Desmarcar' : 'Marcar como lido'),
                onTap: () => Navigator.pop(c, 'marcar'),
              ),
            if (d <= hoje)
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const Text('Comentário do dia'),
                onTap: () => Navigator.pop(c, 'comentario'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (op) {
      case 'ler':
        _abrir(caps.first);
      case 'marcar':
        aj.marcarDia(d, !lido);
      case 'comentario':
        _abrirSite(context, comentarioDoDia(plano.dataDe(d)));
    }
  }
}

/// Um mês do plano: lidos com o fundo da cor do tema, os que ficaram para
/// trás em vermelho claro, hoje com contorno.
class _Calendario extends StatelessWidget {
  const _Calendario({
    required this.plano,
    required this.mes,
    required this.hoje,
    required this.lidos,
    required this.comecou,
    required this.aoMudarMes,
    required this.aoTocar,
  });

  final PlanoLeitura plano;

  /// Primeiro dia do mês mostrado (UTC).
  final DateTime mes;
  final int hoje;
  final Set<int> lidos;
  final int comecou;
  final ValueChanged<DateTime> aoMudarMes;
  final ValueChanged<int> aoTocar;

  static const _semana = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final diasNoMes = DateTime.utc(mes.year, mes.month + 1, 0).day;
    final vazios = mes.weekday % 7; // domingo primeiro
    final primeiro = plano.diaDe(mes);
    final ciclo = plano.inicioDoCiclo(hoje);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mês anterior',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () =>
                      aoMudarMes(DateTime.utc(mes.year, mes.month - 1)),
                ),
                Expanded(
                  child: Text(
                    '${_meses[mes.month - 1]} de ${mes.year}',
                    textAlign: TextAlign.center,
                    style: t.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Próximo mês',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () =>
                      aoMudarMes(DateTime.utc(mes.year, mes.month + 1)),
                ),
              ],
            ),
            Row(
              children: [
                for (final s in _semana)
                  Expanded(
                    child: Text(
                      s,
                      textAlign: TextAlign.center,
                      style: t.textTheme.labelSmall?.copyWith(
                        color: t.hintColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.1,
              children: [
                for (var i = 0; i < vazios; i++) const SizedBox.shrink(),
                for (var n = 1; n <= diasNoMes; n++)
                  () {
                    final d = primeiro + n - 1;
                    final lido = lidos.contains(d);
                    final atrasado =
                        !lido && d < hoje && d >= comecou && d >= ciclo;
                    return Padding(
                      padding: const EdgeInsets.all(2),
                      child: Material(
                        color: lido
                            ? cs.primaryContainer
                            : atrasado
                            ? cs.errorContainer.withValues(alpha: 0.5)
                            : Colors.transparent,
                        shape: d == hoje
                            ? CircleBorder(
                                side: BorderSide(color: cs.primary, width: 2),
                              )
                            : const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => aoTocar(d),
                          child: Center(
                            child: Text(
                              '$n',
                              style: t.textTheme.bodySmall?.copyWith(
                                fontWeight: d == hoje ? FontWeight.bold : null,
                                color: d > hoje ? t.hintColor : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Liga o lembrete diário e escolhe a hora.
class _LembreteDiario extends StatelessWidget {
  const _LembreteDiario();

  @override
  Widget build(BuildContext context) {
    if (!Lembrete.suportado) return const SizedBox.shrink();
    final aj = Ajustes.instancia;
    final m = aj.lembreteMinutos;
    final hora = TimeOfDay(hour: m ~/ 60, minute: m % 60);
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Lembrete diário'),
          subtitle: const Text('Um aviso por dia na hora que você escolher'),
          value: aj.lembrete,
          onChanged: (v) => _ligar(context, v),
        ),
        if (aj.lembrete)
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text('Todo dia às ${hora.format(context)}'),
            subtitle: const Text('Toque para mudar a hora'),
            onTap: () => _mudarHora(context, hora),
          ),
      ],
    );
  }

  Future<void> _mudarHora(BuildContext context, TimeOfDay atual) async {
    final h = await showTimePicker(
      context: context,
      initialTime: atual,
      helpText: 'Hora do lembrete',
    );
    if (h == null) return;
    Ajustes.instancia.lembreteMinutos = h.hour * 60 + h.minute;
    await Lembrete.instancia.atualizar();
  }

  Future<void> _ligar(BuildContext context, bool v) async {
    final aj = Ajustes.instancia;
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
    aj.lembrete = v;
    await Lembrete.instancia.atualizar();
  }
}
