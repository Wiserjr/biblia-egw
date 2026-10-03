import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../dados/ajustes.dart';
import '../dados/atualizacao.dart';
import '../dados/biblioteca.dart';
import 'atualizacao_app.dart';
import 'backup.dart';
import 'inicio.dart' show TelaInicio;
import 'texto_biblico.dart';
import 'tema.dart';

class TelaAjustes extends StatefulWidget {
  const TelaAjustes({super.key});

  @override
  State<TelaAjustes> createState() => _TelaAjustesState();
}

class _TelaAjustesState extends State<TelaAjustes> {
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();
  late final Future<int> _espaco = Biblioteca.instancia.espacoUsado();

  @override
  Widget build(BuildContext context) {
    final aj = Ajustes.instancia;
    final t = Theme.of(context);
    final largura = MediaQuery.sizeOf(context).width;
    // No celular em pé o texto já ocupa a tela toda, e não há painel ao lado.
    final larguraAjustavel = largura >= 600;
    final telaLarga = largura >= TelaInicio.larguraDividida;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListenableBuilder(
        listenable: aj,
        builder: (context, _) => ListView(
          children: [
            _titulo(context, 'Leitura'),
            ListTile(
              title: const Text('Tamanho da letra'),
              subtitle: Slider(
                value: aj.tamanhoLetra,
                min: 13,
                max: 34,
                divisions: 21,
                label: aj.tamanhoLetra.round().toString(),
                onChanged: (v) => aj.tamanhoLetra = v,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text.rich(
                TextSpan(
                  children: spansDoTexto(
                    '<J>Eu sou o caminho, e a verdade, e a vida.</J>',
                    estilo: t.textTheme.bodyLarge!.copyWith(
                      fontSize: aj.tamanhoLetra,
                      height: 1.6,
                    ),
                    corJesus: corJesus(context),
                    vermelho: aj.letrasVermelhas,
                  ),
                ),
              ),
            ),
            if (larguraAjustavel)
              ListTile(
                title: const Text('Largura do texto'),
                subtitle: Slider(
                  value: aj.larguraTexto,
                  min: Ajustes.minLarguraTexto,
                  max: 1,
                  divisions: 12,
                  label: '${(aj.larguraTexto * 100).round()}%',
                  onChanged: (v) => aj.larguraTexto = v,
                ),
                trailing: Text('${(aj.larguraTexto * 100).round()}%'),
              ),
            SwitchListTile(
              title: const Text('Palavras de Jesus em vermelho'),
              subtitle: const Text('Nas traduções que as marcam'),
              value: aj.letrasVermelhas,
              onChanged: (v) => aj.letrasVermelhas = v,
            ),
            ListTile(
              title: const Text('Tema'),
              trailing: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                  ),
                ],
                selected: {aj.tema},
                onSelectionChanged: (s) => aj.tema = s.first,
              ),
            ),
            if (telaLarga) ...[
              _titulo(context, 'Painel de estudo'),
              SwitchListTile(
                title: const Text('Mostrar o painel ao lado do texto'),
                subtitle: const Text(
                  'As notas e as referências do versículo tocado. Também abre '
                  'e fecha pelo botão no alto da tela.',
                ),
                value: aj.painelEstudo,
                onChanged: (v) => aj.painelEstudo = v,
              ),
              SwitchListTile(
                title: const Text('Abrir o painel ao tocar num versículo'),
                subtitle: const Text('Quando ele estiver fechado'),
                value: aj.abrirPainelAoTocar,
                onChanged: (v) => aj.abrirPainelAoTocar = v,
              ),
              ListTile(
                title: const Text('Largura do painel'),
                subtitle: Slider(
                  value: aj.larguraPainel,
                  min: Ajustes.minLarguraPainel,
                  max: Ajustes.maxLarguraPainel,
                  divisions: 10,
                  label: '${(aj.larguraPainel * 100).round()}%',
                  onChanged: (v) => aj.larguraPainel = v,
                ),
                trailing: Text('${(aj.larguraPainel * 100).round()}%'),
              ),
            ],
            _titulo(context, 'Estudo'),
            SwitchListTile(
              title: const Text('Mostrar quantos trechos citam cada versículo'),
              subtitle: const Text('O número ao lado do versículo no leitor'),
              value: aj.marcadoresEgw,
              onChanged: (v) => aj.marcadoresEgw = v,
            ),
            SwitchListTile(
              title: const Text('Incluir os pioneiros adventistas'),
              subtitle: const Text(
                'Urias Smith, J. N. Andrews, A. T. Jones e outros',
              ),
              value: aj.mostrarPioneiros,
              onChanged: (v) => aj.mostrarPioneiros = v,
            ),
            FutureBuilder<int>(
              future: _espaco,
              builder: (context, snap) => ListTile(
                title: const Text('Livros baixados'),
                subtitle: Text(
                  snap.hasData ? 'Ocupando ${tamanhoLegivel(snap.data!)}' : '…',
                ),
              ),
            ),
            _titulo(context, 'Seus dados'),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Salvar cópia'),
              subtitle: const Text(
                'Marcações, anotações e plano de leitura num arquivo, para '
                'guardar ou levar a outro aparelho',
              ),
              onTap: () => salvarCopia(context),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restaurar cópia'),
              subtitle: const Text(
                'Junta uma cópia salva ao que já está no app, sem apagar nada',
              ),
              onTap: () => restaurarCopia(context),
            ),
            _titulo(context, 'Aplicativo'),
            if (Atualizacao.suportada)
              ListTile(
                leading: const Icon(Icons.system_update_outlined),
                title: const Text('Procurar atualização'),
                onTap: () => FluxoAtualizacao.verificar(context, manual: true),
              ),
            FutureBuilder<PackageInfo>(
              future: _info,
              builder: (context, snap) => ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Versão do app'),
                subtitle: Text(
                  snap.hasData
                      ? '${snap.data!.version} (${snap.data!.buildNumber})'
                      : '…',
                ),
              ),
            ),
            _titulo(context, 'Fontes e créditos'),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Text(
                '• Traduções da Bíblia: as mesmas do LouvorJA. A Bíblia Livre é '
                'de Diego Santos, Mario Sergio e Marco Teles (CC BY 3.0 BR).\n'
                '• Livros de Ellen G. White e dos pioneiros: e-books do Centro '
                'de Pesquisas Ellen G. White — Brasil (centrowhite.org.br) e da '
                'Adventist Pioneer Library, baixados no aparelho para uso '
                'pessoal. O app guarda só o índice que liga cada versículo ao '
                'parágrafo.\n'
                '• Referências cruzadas e localização dos lugares bíblicos: '
                'OpenBible.info (CC BY 4.0). Contornos dos mapas: Natural '
                'Earth (domínio público).\n'
                '• Introduções, mapas temáticos, índice temático e estudos '
                'bíblicos: escritos para este app.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titulo(BuildContext context, String texto) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      texto,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
