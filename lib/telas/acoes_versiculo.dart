import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../dados/ajustes.dart';
import '../dados/biblia.dart';
import '../dados/leitura_voz.dart';
import '../dados/memorizar.dart';
import '../dados/modelos.dart';
import '../dados/referencias.dart';
import 'acoes_texto.dart';
import 'cartao_versiculo.dart';

String textoParaCompartilhar(Posicao p, String texto, Versao versao) =>
    '“${textoPuro(texto).trim()}”\n'
    '${Referencias.nome(p.livro)} ${p.capitulo}:${p.versiculo} (${versao.sigla})';

/// Menu de um versículo: copiar, compartilhar, marcar com cor, anotar, ouvir
/// dali em diante e (no Android) mandar para os outros apps do celular.
Future<void> mostrarAcoesVersiculo(
  BuildContext context,
  Posicao p,
  String texto,
  Versao versao,
) async {
  final ref = '${Referencias.nome(p.livro)} ${p.capitulo}:${p.versiculo}';
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(ref, style: Theme.of(c).textTheme.titleMedium),
            ),
            BarraMarcacao(posicao: p),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copiar'),
              onTap: () {
                Clipboard.setData(
                  ClipboardData(text: textoParaCompartilhar(p, texto, versao)),
                );
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Versículo copiado.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Compartilhar'),
              onTap: () {
                Navigator.pop(c);
                SharePlus.instance.share(
                  ShareParams(text: textoParaCompartilhar(p, texto, versao)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Imagem para compartilhar'),
              onTap: () {
                Navigator.pop(c);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CartaoVersiculo(
                      inicio: p,
                      ate: p.versiculo!,
                      texto: textoPuro(texto).trim(),
                      sigla: versao.sigla,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Anotar'),
              onTap: () {
                Navigator.pop(c);
                editarAnotacao(context, p);
              },
            ),
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('Etiquetas'),
              subtitle: _resumoEtiquetas(p),
              onTap: () {
                Navigator.pop(c);
                editarEtiquetas(context, p);
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology_outlined),
              title: Text(
                Ajustes.instancia.memorizacao(
                          p.livro,
                          p.capitulo,
                          p.versiculo!,
                        ) ==
                        null
                    ? 'Memorizar'
                    : 'Já está em Memorizar versículos',
              ),
              onTap: () {
                Navigator.pop(c);
                adicionarParaMemorizar(context, p);
              },
            ),
            if (LeituraVoz.suportada)
              ListTile(
                leading: const Icon(Icons.volume_up_outlined),
                title: const Text('Ouvir a partir daqui'),
                onTap: () {
                  Navigator.pop(c);
                  LeituraVoz.instancia.ler(
                    versao.id,
                    p.livro,
                    p.capitulo,
                    aPartirDe: p.versiculo,
                  );
                },
              ),
            if (acoesDoSistemaDisponiveis)
              ListTile(
                leading: const Icon(Icons.more_horiz),
                title: const Text('Mais (traduzir, outros apps…)'),
                onTap: () {
                  Navigator.pop(c);
                  mostrarMaisAcoes(
                    context,
                    textoParaCompartilhar(p, texto, versao),
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}

/// As cores de marcação, e "sem cor".
class BarraMarcacao extends StatelessWidget {
  const BarraMarcacao({super.key, required this.posicao});
  final Posicao posicao;

  @override
  Widget build(BuildContext context) {
    final aj = Ajustes.instancia;
    final p = posicao;
    return ListenableBuilder(
      listenable: aj,
      builder: (context, _) {
        final atual = aj.marcacao(p.livro, p.capitulo, p.versiculo!);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              for (var i = 0; i < coresMarcacao.length; i++)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => aj.marcar(
                      p.livro,
                      p.capitulo,
                      p.versiculo!,
                      atual == i ? null : i,
                    ),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: coresMarcacao[i].withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: atual == i
                            ? Border.all(
                                width: 2.5,
                                color: Theme.of(context).colorScheme.onSurface,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              if (atual != null)
                IconButton(
                  tooltip: 'Tirar marcação',
                  icon: const Icon(Icons.format_color_reset_outlined),
                  onPressed: () =>
                      aj.marcar(p.livro, p.capitulo, p.versiculo!, null),
                ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> editarAnotacao(BuildContext context, Posicao p) async {
  final aj = Ajustes.instancia;
  final ctrl = TextEditingController(
    text: aj.anotacao(p.livro, p.capitulo, p.versiculo!) ?? '',
  );
  final salvar = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(
        'Anotação — ${Referencias.nome(p.livro)} ${p.capitulo}:${p.versiculo}',
      ),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 8,
          minLines: 3,
          decoration: const InputDecoration(
            hintText: 'Escreva o que este versículo diz a você…',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
  if (salvar == true) aj.anotar(p.livro, p.capitulo, p.versiculo!, ctrl.text);
  ctrl.dispose();
}

Widget? _resumoEtiquetas(Posicao p) {
  final e = Ajustes.instancia.etiquetas(p.livro, p.capitulo, p.versiculo!);
  return e.isEmpty ? null : Text(e.join(', '));
}

/// Põe o versículo [p] na lista de Memorizar versículos (se ainda não
/// estiver) e avisa.
void adicionarParaMemorizar(BuildContext context, Posicao p) {
  final aj = Ajustes.instancia;
  final ref = '${Referencias.nome(p.livro)} ${p.capitulo}:${p.versiculo}';
  final msg = ScaffoldMessenger.of(context);
  if (aj.memorizacao(p.livro, p.capitulo, p.versiculo!) != null) {
    msg.showSnackBar(
      SnackBar(content: Text('$ref já está em Memorizar versículos.')),
    );
    return;
  }
  final agora = DateTime.now().millisecondsSinceEpoch;
  aj.salvarMemorizacao(
    Memorizacao(
      livro: p.livro,
      capitulo: p.capitulo,
      versiculo: p.versiculo!,
      ate: p.versiculo!,
      criada: agora,
      atualizado: agora,
    ),
  );
  msg.showSnackBar(
    SnackBar(content: Text('$ref entrou em Memorizar versículos, no menu.')),
  );
}

/// Escolhe as etiquetas do versículo [p]: as que já existem, com um toque, ou
/// uma nova.
Future<void> editarEtiquetas(BuildContext context, Posicao p) async {
  final aj = Ajustes.instancia;
  final escolhidas = {
    for (final e in aj.etiquetas(p.livro, p.capitulo, p.versiculo!))
      e.toLowerCase(): e,
  };
  final todas = {
    for (final e in [...aj.nomesEtiquetas, ...escolhidas.values])
      e.toLowerCase(): e,
  };
  final nova = TextEditingController();
  final salvar = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) {
        void adicionar() {
          final t = nova.text.trim();
          if (t.isEmpty) return;
          setState(() {
            todas.putIfAbsent(t.toLowerCase(), () => t);
            escolhidas[t.toLowerCase()] = todas[t.toLowerCase()]!;
            nova.clear();
          });
        }

        final nomes = Ajustes.limparEtiquetas(todas.values);
        return AlertDialog(
          title: Text(
            'Etiquetas — ${Referencias.nome(p.livro)} ${p.capitulo}:${p.versiculo}',
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (nomes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Etiquetas juntam versículos por assunto: '
                        '"Promessas", "Família", "Para pregar"...',
                      ),
                    ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final e in nomes)
                        FilterChip(
                          label: Text(e),
                          selected: escolhidas.containsKey(e.toLowerCase()),
                          onSelected: (sim) => setState(() {
                            if (sim) {
                              escolhidas[e.toLowerCase()] = e;
                            } else {
                              escolhidas.remove(e.toLowerCase());
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nova,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Nova etiqueta',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: 'Adicionar',
                        icon: const Icon(Icons.add),
                        onPressed: adicionar,
                      ),
                    ),
                    onSubmitted: (_) => adicionar(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                adicionar();
                Navigator.pop(c, true);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    ),
  );
  if (salvar == true) {
    aj.definirEtiquetas(p.livro, p.capitulo, p.versiculo!, escolhidas.values);
  }
  nova.dispose();
}
