import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../dados/ajustes.dart';
import '../dados/atualizacao.dart';
import '../dados/biblioteca.dart';
import '../dados/leitura_voz.dart';
import '../dados/lembrete.dart';
import '../dados/nuvem.dart';
import 'atualizacao_app.dart';
import 'backup.dart';
import 'conta.dart';
import 'inicio.dart' show TelaInicio;
import 'largura_texto.dart' show larguraMinimaParaAjuste;
import 'texto_biblico.dart';
import 'tema.dart';
import 'vozes.dart';

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
    // No celular em pé o texto ocupa a tela toda (o ajuste não vale ali), e
    // não há painel ao lado.
    final larguraAjustavel = largura >= larguraMinimaParaAjuste;
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
                      height: aj.espacoLinhas,
                      fontFamily: aj.letraSerifa ? familiaSerifa() : null,
                    ),
                    corJesus: corJesus(context),
                    vermelho: aj.letrasVermelhas,
                  ),
                ),
              ),
            ),
            ListTile(
              title: const Text('Espaço entre as linhas'),
              subtitle: Slider(
                value: aj.espacoLinhas,
                min: Ajustes.minEspacoLinhas,
                max: Ajustes.maxEspacoLinhas,
                divisions: 12,
                label: aj.espacoLinhas.toStringAsFixed(1).replaceAll('.', ','),
                onChanged: (v) => aj.espacoLinhas = v,
              ),
              trailing: TextButton(
                onPressed: aj.espacoLinhas == Ajustes.espacoLinhasPadrao
                    ? null
                    : () => aj.espacoLinhas = Ajustes.espacoLinhasPadrao,
                child: const Text('Padrão'),
              ),
            ),
            SwitchListTile(
              title: const Text('Letra com serifa'),
              subtitle: const Text('Como a de livro impresso'),
              value: aj.letraSerifa,
              onChanged: (v) => aj.letraSerifa = v,
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
            SwitchListTile(
              title: const Text('Papel sépia'),
              subtitle: const Text(
                'No tema claro, um fundo amarelado que cansa menos a vista',
              ),
              value: aj.papelSepia,
              onChanged: (v) => aj.papelSepia = v,
            ),
            SwitchListTile(
              title: const Text('Pouca luz'),
              subtitle: const Text(
                'No tema escuro, fundo preto e letra mais suave, para ler '
                'no escuro',
              ),
              value: aj.poucaLuz,
              onChanged: (v) => aj.poucaLuz = v,
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
            if (LeituraVoz.suportada) ...[
              _titulo(context, 'Ouvir o capítulo'),
              SwitchListTile(
                title: const Text('Narração com voz neural (ARA)'),
                subtitle: const Text(
                  'Na ARA, ouve uma voz bem mais natural, tocada pela '
                  'internet (cerca de 20 MB por hora). Sem internet, ou nos '
                  'livros ainda não narrados, lê a voz do aparelho.',
                ),
                value: aj.narracaoNeural,
                onChanged: (v) => aj.narracaoNeural = v,
              ),
              ListTile(
                title: const Text('Voz'),
                subtitle: Text(descreverVozEscolhida()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TelaVozes()),
                ),
              ),
              ListTile(
                title: const Text('Velocidade da voz'),
                trailing: DropdownButton<double>(
                  value: LeituraVoz.velocidades.contains(aj.velocidadeVoz)
                      ? aj.velocidadeVoz
                      : 1.0,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final v in LeituraVoz.velocidades)
                      DropdownMenuItem(
                        value: v,
                        child: Text(
                          '${v.toString().replaceAll(RegExp(r'\.0$'), '').replaceAll('.', ',')}×',
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) LeituraVoz.instancia.mudarVelocidade(v);
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('Seguir para o próximo capítulo'),
                subtitle: const Text(
                  'Ao fim do capítulo, a voz continua no seguinte',
                ),
                value: aj.vozContinua,
                onChanged: (v) => aj.vozContinua = v,
              ),
            ],
            if (Lembrete.suportado) ...[
              _titulo(context, 'Versículo do dia'),
              SwitchListTile(
                title: const Text('Aviso do versículo do dia'),
                subtitle: const Text(
                  'Uma notificação por dia com o versículo, na tradução que '
                  'você usa',
                ),
                value: aj.avisoVersiculoDoDia,
                onChanged: (v) => _ligarAvisoVersiculo(context, v),
              ),
              if (aj.avisoVersiculoDoDia)
                ListTile(
                  title: Text('Às ${_hora(aj.avisoVersiculoMinutos)}'),
                  subtitle: const Text('Toque para mudar a hora'),
                  onTap: () => _mudarHoraVersiculo(context),
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
            ListenableBuilder(
              listenable: Nuvem.instancia,
              builder: (context, _) {
                final n = Nuvem.instancia;
                return ListTile(
                  leading: Icon(
                    n.conectada
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_outlined,
                  ),
                  title: Text(
                    n.conectada ? 'Conta: ${n.email}' : 'Entrar ou criar conta',
                  ),
                  subtitle: Text(
                    n.conectada
                        ? situacaoDaNuvem(n)
                        : 'Guarde marcações, anotações e o plano na nuvem e '
                              'use no celular e no PC',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TelaConta()),
                  ),
                );
              },
            ),
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

  static String _hora(int minutos) =>
      '${(minutos ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutos % 60).toString().padLeft(2, '0')}';

  Future<void> _ligarAvisoVersiculo(BuildContext context, bool v) async {
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
    Ajustes.instancia.avisoVersiculoDoDia = v;
    await Lembrete.instancia.atualizar();
  }

  Future<void> _mudarHoraVersiculo(BuildContext context) async {
    final m = Ajustes.instancia.avisoVersiculoMinutos;
    final h = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      helpText: 'Hora do versículo do dia',
    );
    if (h == null) return;
    Ajustes.instancia.avisoVersiculoMinutos = h.hour * 60 + h.minute;
    await Lembrete.instancia.atualizar();
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
