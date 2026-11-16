import 'package:flutter/material.dart';

import '../dados/ajustes.dart';
import '../dados/leitura_voz.dart';
import '../dados/referencias.dart';

/// Barra no pé do leitor enquanto a voz lê o capítulo: onde está, pausar e
/// continuar, velocidade, timer para dormir e parar.
class BarraVoz extends StatelessWidget {
  const BarraVoz({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LeituraVoz.instancia,
      builder: (context, _) {
        final voz = LeituraVoz.instancia;
        final cap = voz.capitulo;
        if (cap == null) return const SizedBox.shrink();
        final v = voz.versiculo;
        final t = Theme.of(context);
        final velocidade = Ajustes.instancia.velocidadeVoz;
        return Material(
          color: t.colorScheme.secondaryContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
              child: Row(
                children: [
                  IconButton(
                    tooltip: voz.pausada ? 'Continuar' : 'Pausar',
                    icon: Icon(
                      voz.pausada
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                    ),
                    onPressed: voz.pausada ? voz.continuar : voz.pausar,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${voz.pausada ? 'Pausado' : 'Lendo'} '
                          '${Referencias.nome(cap.livro)} ${cap.capitulo}'
                          '${v != null && v > 0 ? ':$v' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.bodyMedium,
                        ),
                        if (voz.timerLigado)
                          Text(
                            _descreverTimer(voz),
                            style: t.textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _escolherVelocidade(context),
                    child: Text('${_numero(velocidade)}×'),
                  ),
                  IconButton(
                    tooltip: 'Timer para dormir',
                    isSelected: voz.timerLigado,
                    icon: const Icon(Icons.bedtime_outlined),
                    selectedIcon: const Icon(Icons.bedtime),
                    onPressed: () => _escolherTimer(context),
                  ),
                  IconButton(
                    tooltip: 'Parar',
                    icon: const Icon(Icons.stop_rounded),
                    onPressed: voz.parar,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _numero(double v) {
    final s = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toString().replaceAll(RegExp(r'0+$'), '');
    return s.replaceAll('.', ',');
  }

  static String _descreverTimer(LeituraVoz voz) {
    if (voz.pararNoFimDoCapitulo) return 'Para no fim do capítulo';
    final ate = voz.timerAte;
    if (ate == null) return '';
    final h = ate.hour.toString().padLeft(2, '0');
    final m = ate.minute.toString().padLeft(2, '0');
    return 'Para às $h:$m';
  }

  Future<void> _escolherVelocidade(BuildContext context) async {
    final atual = Ajustes.instancia.velocidadeVoz;
    final v = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Velocidade da voz')),
            for (final op in LeituraVoz.velocidades)
              ListTile(
                leading: Icon(
                  op == atual ? Icons.check : null,
                  color: Theme.of(c).colorScheme.primary,
                ),
                title: Text(op == 1 ? '1× (normal)' : '${_numero(op)}×'),
                onTap: () => Navigator.pop(c, op),
              ),
          ],
        ),
      ),
    );
    if (v != null) await LeituraVoz.instancia.mudarVelocidade(v);
  }

  Future<void> _escolherTimer(BuildContext context) async {
    final voz = LeituraVoz.instancia;
    const opcoes = [15, 30, 45, 60];
    final op = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Timer para dormir'),
              subtitle: Text('A voz para sozinha.'),
            ),
            for (final m in opcoes)
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('Daqui a $m minutos'),
                onTap: () => Navigator.pop(c, '$m'),
              ),
            ListTile(
              leading: const Icon(Icons.last_page),
              title: const Text('No fim do capítulo'),
              onTap: () => Navigator.pop(c, 'fim'),
            ),
            if (voz.timerLigado)
              ListTile(
                leading: const Icon(Icons.timer_off_outlined),
                title: const Text('Desligar o timer'),
                onTap: () => Navigator.pop(c, 'desligar'),
              ),
          ],
        ),
      ),
    );
    switch (op) {
      case null:
        return;
      case 'fim':
        voz.pararNoFim();
      case 'desligar':
        voz.marcarTimer(null);
      default:
        voz.marcarTimer(Duration(minutes: int.parse(op)));
    }
  }
}
