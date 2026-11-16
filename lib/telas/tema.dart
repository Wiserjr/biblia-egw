import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Azul-noite com papel claro: sóbrio para leitura longa, e o vermelho das
/// palavras de Jesus continua distinguível nos dois temas.
const _semente = Color(0xFF2F4A73);

ThemeData temaClaro() {
  final cores = ColorScheme.fromSeed(
    seedColor: _semente,
    surface: const Color(0xFFFBF8F2),
  );
  return _base(cores);
}

ThemeData temaEscuro() {
  final cores = ColorScheme.fromSeed(
    seedColor: _semente,
    brightness: Brightness.dark,
  );
  return _base(cores);
}

/// Tema claro com papel sépia: fundo amarelado, que cansa menos a vista.
ThemeData temaSepia() {
  final cores = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7A5A2F),
    surface: const Color(0xFFF4ECD8),
  ).copyWith(onSurface: const Color(0xFF3B2F22));
  return _base(cores);
}

/// Tema escuro de pouca luz: fundo preto e letra cinza-clara, sem branco
/// forte, para ler no escuro.
ThemeData temaPoucaLuz() {
  final cores =
      ColorScheme.fromSeed(
        seedColor: _semente,
        brightness: Brightness.dark,
        surface: Colors.black,
      ).copyWith(
        onSurface: const Color(0xFFB8B2A7),
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0D0D0D),
        surfaceContainer: const Color(0xFF121212),
        surfaceContainerHigh: const Color(0xFF181818),
        surfaceContainerHighest: const Color(0xFF1E1E1E),
      );
  return _base(cores);
}

/// Família da letra com serifa no texto da Bíblia: a "serif" do Android
/// (Noto Serif) e a Georgia do Windows.
String? familiaSerifa() {
  if (kIsWeb) return 'serif';
  return Platform.isWindows ? 'Georgia' : 'serif';
}

ThemeData _base(ColorScheme cores) => ThemeData(
  colorScheme: cores,
  useMaterial3: true,
  appBarTheme: AppBarTheme(
    backgroundColor: cores.surface,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 1,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: cores.surfaceContainerLow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: cores.outlineVariant.withValues(alpha: 0.6)),
    ),
    margin: const EdgeInsets.symmetric(vertical: 4),
  ),
);

/// Cor das palavras de Jesus.
Color corJesus(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFFF8A80)
    : const Color(0xFFB71C1C);

/// Cor de destaque do material de Ellen G. White.
Color corEgw(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFFFCC80)
    : const Color(0xFF8D5A00);
