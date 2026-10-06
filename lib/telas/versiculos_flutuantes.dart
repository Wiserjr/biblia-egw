import 'package:flutter/material.dart';

import '../dados/ajustes.dart';
import '../dados/biblia.dart';
import '../dados/modelos.dart';
import '../dados/referencias.dart';
import '../dados/temas.dart';
import 'tema.dart';
import 'texto_biblico.dart';

class LeituraFlutuante {
  const LeituraFlutuante(this.versao, this.trechos, {this.vermelho = true});
  final Versao versao;
  final List<List<(int, int, String)>> trechos;
  final bool vermelho;
}

Future<void> mostrarVersiculosFlutuantes(BuildContext context, List refs) =>
    showDialog<void>(
      context: context,
      builder: (_) => VersiculosFlutuantes(
        passagens: [
          for (final r in refs) Passagem(r[0] as int, r[1] as int, r[2] as int),
        ],
      ),
    );

/// Consulta as faixas separadamente: João 1:1–4 e 14 não inclui 5–13.
class VersiculosFlutuantes extends StatefulWidget {
  const VersiculosFlutuantes({
    super.key,
    required this.passagens,
    this.carregar,
  });
  final List<Passagem> passagens;
  final Future<LeituraFlutuante> Function()? carregar;
  @override
  State<VersiculosFlutuantes> createState() => _VersiculosFlutuantesState();
}

class _VersiculosFlutuantesState extends State<VersiculosFlutuantes> {
  late Future<LeituraFlutuante> _dados = _carregar();
  Future<LeituraFlutuante> _carregar() async {
    if (widget.carregar != null) return widget.carregar!();
    final biblia = Biblia.instancia;
    final versoes = await biblia.versoes();
    final versao = versoes.firstWhere(
      (v) => v.id == Ajustes.instancia.versao,
      orElse: () => versoes.firstWhere(
        (v) => v.sigla == 'ARA',
        orElse: () => versoes.first,
      ),
    );
    return LeituraFlutuante(
      versao,
      await Future.wait([
        for (final p in widget.passagens)
          biblia.intervalo(versao.id, p.livro, p.ini, p.fim, limite: 10000),
      ]),
      vermelho: Ajustes.instancia.letrasVermelhas,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: 720,
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined, color: t.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Leitura bíblica',
                      style: t.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Voltar ao estudo',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<LeituraFlutuante>(
                future: _dados,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Não foi possível carregar os versículos.',
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _dados = _carregar()),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    );
                  }
                  final dados = snap.data;
                  if (dados == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    children: [
                      Text(
                        '${dados.versao.sigla} • ${dados.versao.nome}',
                        style: t.textTheme.labelLarge?.copyWith(
                          color: t.colorScheme.primary,
                        ),
                      ),
                      for (var i = 0; i < widget.passagens.length; i++) ...[
                        const SizedBox(height: 20),
                        Text(
                          Referencias.formatar(
                            widget.passagens[i].livro,
                            widget.passagens[i].ini,
                            widget.passagens[i].fim,
                          ),
                          style: t.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (dados.trechos[i].isEmpty)
                          const Text(
                            'Esta passagem não está disponível nesta tradução.',
                          ),
                        for (final (cap, verso, texto) in dados.trechos[i])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        '${cap == widget.passagens[i].ini ~/ 1000 ? '$verso' : '$cap:$verso'}  ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: t.colorScheme.primary,
                                    ),
                                  ),
                                  ...spansDoTexto(
                                    texto,
                                    estilo: t.textTheme.bodyLarge!.copyWith(
                                      height: 1.6,
                                    ),
                                    corJesus: corJesus(context),
                                    vermelho: dados.vermelho,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Voltar ao estudo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
