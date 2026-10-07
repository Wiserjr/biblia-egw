import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Endereço configurado por cada pessoa, sem URL distribuída no aplicativo.
class AtalhoEpubPessoal extends StatefulWidget {
  const AtalhoEpubPessoal({super.key, this.abrir});
  final Future<bool> Function(Uri)? abrir;
  static const chave = 'atalho_epub_pessoal';
  @override
  State<AtalhoEpubPessoal> createState() => _AtalhoEpubPessoalState();
}

Uri? enderecoEpubPessoal(String valor) {
  final uri = Uri.tryParse(valor.trim());
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}

class _AtalhoEpubPessoalState extends State<AtalhoEpubPessoal> {
  String? endereco;
  bool carregando = true;
  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final salvo = prefs.getString(AtalhoEpubPessoal.chave);
    if (mounted) {
      setState(() {
        endereco = salvo != null && enderecoEpubPessoal(salvo) != null
            ? salvo
            : null;
        carregando = false;
      });
    }
  }

  Future<void> editar() async {
    var valor = endereco ?? '';
    final formulario = GlobalKey<FormState>();
    final novo = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Meu link de download'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formulario,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cole o link da sua cópia do livro. O endereço fica salvo neste aparelho.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: valor,
                  onChanged: (s) => valor = s,
                  keyboardType: TextInputType.url,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(labelText: 'Link HTTPS'),
                  validator: (s) => enderecoEpubPessoal(s ?? '') == null
                      ? 'Informe um endereço HTTPS válido.'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (endereco != null)
            TextButton(
              onPressed: () => Navigator.pop(c, ''),
              child: const Text('Remover'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formulario.currentState!.validate()) {
                Navigator.pop(c, valor.trim());
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (novo == null) return;
    final prefs = await SharedPreferences.getInstance();
    final salvo = novo.isEmpty
        ? await prefs.remove(AtalhoEpubPessoal.chave)
        : await prefs.setString(AtalhoEpubPessoal.chave, novo);
    if (!mounted) return;
    if (salvo) {
      setState(() => endereco = novo.isEmpty ? null : novo);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar o link. Tente novamente.'),
        ),
      );
    }
  }

  Future<void> baixar() async {
    try {
      final uri = enderecoEpubPessoal(endereco!);
      final abriu =
          uri != null &&
          await (widget.abrir?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!abriu) throw StateError('Não abriu');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir o navegador. Confira o link pessoal.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (endereco != null) ...[
        OutlinedButton.icon(
          onPressed: baixar,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Baixar meu EPUB'),
        ),
        Text(
          'Depois do download, use “Importar meu EPUB” para selecionar o arquivo.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      TextButton.icon(
        onPressed: carregando ? null : editar,
        icon: const Icon(Icons.link),
        label: Text(
          endereco == null
              ? 'Adicionar link pessoal de download'
              : 'Editar meu link de download',
        ),
      ),
    ],
  );
}
