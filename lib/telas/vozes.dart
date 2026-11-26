import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/ajustes.dart';
import '../dados/leitura_voz.dart';
import '../dados/vozes.dart';

/// O nome da voz escolhida para a linha de Ajustes.
String descreverVozEscolhida() {
  final v = Ajustes.instancia.vozEscolhida;
  if (v == null) return 'A padrão do aparelho';
  final nome = nomeDaVoz(VozTts(nome: v.$1, local: v.$2), const []);
  return nome == 'Voz' ? 'Escolhida por você' : nome;
}

/// Escolher a voz que lê a Bíblia, ouvindo uma amostra de cada uma.
class TelaVozes extends StatefulWidget {
  const TelaVozes({super.key, this.carregar});

  /// Para os testes: as vozes, sem perguntar ao aparelho.
  final Future<List<VozTts>> Function()? carregar;

  @override
  State<TelaVozes> createState() => _TelaVozesState();
}

class _TelaVozesState extends State<TelaVozes> {
  late Future<List<VozTts>> _vozes = _buscar();

  Future<List<VozTts>> _buscar() =>
      (widget.carregar ?? LeituraVoz.instancia.vozes)();

  static const _canal = MethodChannel('br.com.wisejr.bibliaestudo/atualizacao');

  Future<void> _baixarVozes() async {
    var abriu = false;
    try {
      abriu = await _canal.invokeMethod<bool>('baixarVozes') ?? false;
    } catch (_) {}
    if (!mounted) return;
    if (!abriu) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Abra as configurações do Android, procure "Saída de texto para '
            'voz" e instale as vozes em português.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    LeituraVoz.instancia.parar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voz da leitura'),
        actions: [
          IconButton(
            tooltip: 'Procurar de novo',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _vozes = _buscar()),
          ),
        ],
      ),
      body: FutureBuilder<List<VozTts>>(
        future: _vozes,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final vozes = snap.data ?? const <VozTts>[];
          return ListenableBuilder(
            listenable: Ajustes.instancia,
            builder: (context, _) {
              final escolhida = Ajustes.instancia.vozEscolhida;
              bool eh(VozTts? v) => v == null
                  ? escolhida == null
                  : escolhida?.$1 == v.nome && escolhida?.$2 == v.local;
              Widget item(VozTts? v) => ListTile(
                leading: Icon(
                  eh(v) ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: eh(v) ? t.colorScheme.primary : null,
                ),
                title: Text(
                  v == null ? 'Padrão do aparelho' : nomeDaVoz(v, vozes),
                ),
                subtitle: Text(
                  v == null
                      ? 'A que está nos ajustes do sistema'
                      : detalheDaVoz(v),
                ),
                trailing: const Icon(Icons.play_circle_outline),
                onTap: () => LeituraVoz.instancia.ouvirAmostra(v),
              );
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Toque numa voz para ouvir uma amostra. A última que '
                      'você tocar fica sendo a voz da leitura.'
                      '${vozes.any((v) => v.internet) ? ' As vozes "mais naturais" são geradas pelo Google e precisam de internet; sem ela, o aparelho usa uma voz comum.' : ''}',
                      style: t.textTheme.bodyMedium,
                    ),
                  ),
                  item(null),
                  for (final v in vozes) item(v),
                  if (vozes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'O aparelho não informou nenhuma voz em português. '
                        'A leitura usa a voz padrão.',
                      ),
                    ),
                  if (Platform.isAndroid) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: const Text('Baixar mais vozes'),
                      subtitle: const Text(
                        'No motor de voz do Google, escolha Português (Brasil) '
                        'e baixe as vozes. Depois volte e toque em ↻.',
                      ),
                      onTap: _baixarVozes,
                    ),
                  ],
                  if (Platform.isWindows)
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Mais vozes no Windows'),
                      subtitle: Text(
                        'Em Configurações → Hora e idioma → Fala, adicione '
                        'vozes de Português (Brasil).',
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
