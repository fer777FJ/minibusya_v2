// lib/utils/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Notificador global para el tema de la aplicación
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  // ─── Paleta Clara (Azul Clásico) ───────────────────────────────────────────
  static const Color azulPrimarioClaro = Color(0xFF0D47A1);
  static const Color azulSecundarioClaro = Color(0xFF1976D2);
  static const Color amarilloAccentClaro = Color(0xFFFFC107);

  // ─── Paleta Oscura (Naranja y Negro Premium) ───────────────────────────────
  static const Color naranjaPrimario = Color(0xFFFF6D00); // Naranja vibrante
  static const Color naranjaSecundario = Color(0xFFFF9100); // Naranja más claro para acentos
  static const Color negroPrimario = Color(0xFF1E1E1E);    // Negro mate para AppBar, Drawer y fondos
  static const Color negroOscuro = Color(0xFF121212);      // Negro puro

  // Alias de compatibilidad para no romper código existente
  static const Color azulPrimario = azulPrimarioClaro;       
  static const Color azulSecundario = azulSecundarioClaro;       
  static const Color amarilloAccent = amarilloAccentClaro;   
  static const Color rojoAlerta = Color(0xFFD32F2F);     // Bloqueos, alertas
  static const Color verdeOk = Color(0xFF388E3C);        // Confirmaciones
  static const Color naranjaDesvio = Color(0xFFE65100);  // Desvíos
  static const Color blancoFondo = Color(0xFFF5F5F5);    // Fondos de cards
  static const Color grisTexto = Color(0xFF616161);      // Texto secundario
  static const Color negro = Color(0xFF212121);          // Texto principal/negro

  // TEMA CLARO
  static ThemeData get temaClaro => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: azulPrimarioClaro,
          primary: azulPrimarioClaro,
          secondary: amarilloAccentClaro,
          error: rojoAlerta,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: azulPrimarioClaro,
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
          backgroundColor: amarilloAccentClaro,
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
            backgroundColor: azulPrimarioClaro,
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

  // TEMA OSCURO (Naranja y Negro)
  static ThemeData get temaOscuro => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: negroOscuro,
        colorScheme: const ColorScheme.dark(
          primary: naranjaPrimario,
          secondary: naranjaSecundario,
          error: rojoAlerta,
          surface: negroPrimario,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return naranjaPrimario;
            }
            return Colors.white30;
          }),
          checkColor: WidgetStateProperty.all(Colors.white),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return naranjaPrimario;
            }
            return Colors.grey[400];
          }),
          trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return naranjaPrimario.withOpacity(0.5);
            }
            return Colors.grey[800];
          }),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: negroPrimario,
          foregroundColor: naranjaPrimario,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: naranjaPrimario),
          actionsIconTheme: IconThemeData(color: naranjaPrimario),
          titleTextStyle: TextStyle(
            color: naranjaPrimario,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: naranjaPrimario,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: negroPrimario,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: naranjaPrimario,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: negroPrimario,
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

  // Para compatibilidad
  static ThemeData get tema => temaClaro;
}

/// Convierte un hex string "#FF0000" a Color
Color hexToColor(String hex) {
  final hexClean = hex.replaceAll('#', '');
  return Color(int.parse('FF$hexClean', radix: 16));
}
