import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Capítulo indexado no PDF; id 0 representa o livro sem sumário indexado.
/// A página conta a partir de zero.
class CapituloObra {
  const CapituloObra(this.id, this.obra, this.titulo, this.pagina);
  final int id;
  final int obra;
  final String titulo;
  final int pagina;
  bool get leituraIntegral => id == 0;

  String get chave => '$obra:$id';
}

class LugarObra {
  const LugarObra(
    this.pagina,
    this.fracao,
    this.edicao,
    this.atualizadoEm, {
    this.zoom = 1,
    this.horizontal = 0.5,
  });
  final int pagina;

  /// Posição vertical do centro da tela dentro da página, entre 0 e 1.
  final double fracao;
  final String edicao;
  final int atualizadoEm;
  final double zoom;
  final double horizontal;

  Map<String, Object> paraMapa() => {
    'pagina': pagina,
    'fracao': fracao,
    'edicao': edicao,
    'atualizadoEm': atualizadoEm,
    'zoom': zoom,
    'horizontal': horizontal,
  };

  static LugarObra? deMapa(Object? valor) {
    if (valor is! Map) return null;
    final p = valor['pagina'], f = valor['fracao'];
    final e = valor['edicao'], a = valor['atualizadoEm'];
    final z = valor['zoom'] ?? 1, x = valor['horizontal'] ?? 0.5;
    if (p is! int ||
        p < 0 ||
        f is! num ||
        !f.isFinite ||
        f < 0 ||
        f > 1 ||
        e is! String ||
        a is! int ||
        a < 0 ||
        z is! num ||
        !z.isFinite ||
        z <= 0 ||
        z > 100 ||
        x is! num ||
        !x.isFinite ||
        x < 0 ||
        x > 1) {
      return null;
    }
    return LugarObra(
      p,
      f.toDouble(),
      e,
      a,
      zoom: z.toDouble(),
      horizontal: x.toDouble(),
    );
  }
}

/// Progresso independente do plano bíblico e dos arquivos PDF.
/// Apagar um download não apaga os capítulos concluídos nem o lugar salvo.
class GuiaBiblioteca extends ChangeNotifier {
  GuiaBiblioteca();
  static final instancia = GuiaBiblioteca();
  static const chavePreferencia = 'guiaBiblioteca';
  SharedPreferences? _preferencias;
  final _concluidos = <String>{};
  final _lugares = <int, LugarObra>{};
  List<int> _plano = [];
  int _meta = 1;

  Future<void> carregar() async {
    _preferencias = await SharedPreferences.getInstance();
    _concluidos.clear();
    _lugares.clear();
    _plano = [];
    _meta = 1;
    final texto = _preferencias!.getString(chavePreferencia);
    if (texto != null) {
      try {
        _ler(jsonDecode(texto));
      } on FormatException {
        /* Preserva o arquivo inválido. */
      }
    }
  }

  bool concluido(CapituloObra c) => _concluidos.contains(c.chave);
  LugarObra? lugar(int obra) => _lugares[obra];
  List<int> get plano => List.unmodifiable(_plano);
  int get meta => _meta;

  Future<void> marcar(CapituloObra c, bool lido) async {
    if (lido) {
      _concluidos.add(c.chave);
    } else {
      _concluidos.remove(c.chave);
    }
    await _salvar();
  }

  Future<void> guardarLugar(int obra, LugarObra lugar) async {
    if (obra < 1 || LugarObra.deMapa(lugar.paraMapa()) == null) return;
    _lugares[obra] = lugar;
    await _salvar();
  }

  Future<void> iniciarPlano(Iterable<int> obras, int capitulosPorSessao) async {
    _plano = obras.where((id) => id > 0).toSet().toList();
    _meta = capitulosPorSessao.clamp(1, 20);
    await _salvar();
  }

  Future<void> encerrarPlano() async {
    _plano = [];
    await _salvar();
  }

  List<CapituloObra> pendentes(Iterable<CapituloObra> capitulos) {
    final porObra = <int, List<CapituloObra>>{};
    for (final c in capitulos) {
      (porObra[c.obra] ??= []).add(c);
    }
    return [
      for (final id in _plano)
        for (final c in porObra[id] ?? <CapituloObra>[])
          if (!concluido(c)) c,
    ];
  }

  Map<String, Object> exportar() => {
    'concluidos': _concluidos.toList()..sort(),
    'lugares': {
      for (final e in _lugares.entries) '${e.key}': e.value.paraMapa(),
    },
    'plano': _plano,
    'meta': _meta,
  };

  /// A restauração soma conclusões e só substitui um lugar por um mais recente.
  /// Outro plano ativo neste aparelho é preservado.
  void importar(Object? dados) {
    _ler(dados);
    if (_preferencias != null) {
      _preferencias!.setString(chavePreferencia, jsonEncode(exportar()));
    }
    notifyListeners();
  }

  void _ler(Object? dados) {
    if (dados is! Map) return;
    final cs = dados['concluidos'];
    if (cs is List) {
      for (final c in cs) {
        if (c is String && RegExp(r'^[1-9]\d*:(0|[1-9]\d*)$').hasMatch(c)) {
          _concluidos.add(c);
        }
      }
    }
    final ls = dados['lugares'];
    if (ls is Map) {
      for (final e in ls.entries) {
        final id = int.tryParse('${e.key}');
        final lugar = LugarObra.deMapa(e.value);
        if (id == null || id < 1 || lugar == null) continue;
        final atual = _lugares[id];
        if (atual == null || lugar.atualizadoEm > atual.atualizadoEm) {
          _lugares[id] = lugar;
        }
      }
    }
    final pl = dados['plano'];
    if (_plano.isEmpty && pl is List) {
      _plano = pl.whereType<int>().where((id) => id > 0).toSet().toList();
      final m = dados['meta'];
      if (m is int) _meta = m.clamp(1, 20);
    }
  }

  Future<void> _salvar() async {
    final prefs = _preferencias;
    if (prefs == null) throw StateError('O guia ainda não foi carregado.');
    final ok = await prefs.setString(chavePreferencia, jsonEncode(exportar()));
    if (!ok) throw StateError('Não foi possível salvar o progresso.');
    notifyListeners();
  }
}
