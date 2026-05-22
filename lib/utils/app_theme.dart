// lib/utils/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // ─── Paleta MiniBus Ya ─────────────────────────────────────────────────────
  static const Color azulPrimario = Color(0xFF0D47A1);   // Barras de navegación
  static const Color azulSecundario = Color(0xFF1976D2); // Botones secundarios
  static const Color amarilloAccent = Color(0xFFFFC107); // FAB, CTAs, banners
  static const Color rojoAlerta = Color(0xFFD32F2F);     // Bloqueos, alertas
  static const Color verdeOk = Color(0xFF388E3C);        // Confirmaciones
  static const Color naranjaDesvio = Color(0xFFF57C00);  // Desvíos
  static const Color blancoFondo = Color(0xFFF5F5F5);    // Fondos de cards
  static const Color grisTexto = Color(0xFF616161);      // Texto secundario
  static const Color negro = Color(0xFF212121);          // Texto principal

  static ThemeData get tema => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: azulPrimario,
          primary: azulPrimario,
          secondary: amarilloAccent,
          error: rojoAlerta,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: azulPrimario,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: amarilloAccent,
          foregroundColor: negro,
        ),
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: azulPrimario,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      );
}

/// Convierte un hex string "#FF0000" a Color
Color hexToColor(String hex) {
  final hexClean = hex.replaceAll('#', '');
  return Color(int.parse('FF$hexClean', radix: 16));
}
