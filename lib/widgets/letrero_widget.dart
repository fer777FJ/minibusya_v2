// lib/widgets/letrero_widget.dart
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Replica visual del letrero físico de un minibús paceño.
/// Muestra el número de línea y el destino con los colores del sindicato.
class LetreroWidget extends StatelessWidget {
  final String numeroLinea;
  final String destino;
  final String colorHex;
  final String colorTextoHex;
  final double? width;
  final double? height;

  const LetreroWidget({
    super.key,
    required this.numeroLinea,
    required this.destino,
    required this.colorHex,
    required this.colorTextoHex,
    this.width,
    this.height,
  });

  /// Calcula el color de texto con contraste suficiente sobre el fondo.
  /// Si el color de texto del JSON es muy claro Y el fondo también es claro,
  /// fuerza negro. Si el texto es muy oscuro Y el fondo también es oscuro, fuerza blanco.
  Color _resolverColorTexto(Color bg, Color txt) {
    final luminanceBg = bg.computeLuminance();
    final luminanceTxt = txt.computeLuminance();
    // Contraste mínimo: si texto claro sobre fondo claro → negro
    if (luminanceTxt > 0.7 && luminanceBg > 0.5) return Colors.black87;
    // Contraste mínimo: si texto oscuro sobre fondo oscuro → blanco
    if (luminanceTxt < 0.1 && luminanceBg < 0.2) return Colors.white;
    return txt;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = hexToColor(colorHex);
    final txtColor = _resolverColorTexto(bgColor, hexToColor(colorTextoHex));

    return Container(
      width: width ?? 140,
      height: height ?? 56,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black26, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Número de línea — grande y en negrita
          Text(
            numeroLinea,
            style: TextStyle(
              color: txtColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          // Destino — más pequeño
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              destino.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: txtColor.withOpacity(0.9),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Versión compacta para usar como marcador en el mapa
class LetreroMiniWidget extends StatelessWidget {
  final String numeroLinea;
  final String colorHex;

  const LetreroMiniWidget({
    super.key,
    required this.numeroLinea,
    required this.colorHex,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = hexToColor(colorHex);
    // Contraste automático: fondo claro → texto negro, fondo oscuro → texto blanco
    final luminance = bgColor.computeLuminance();
    final txtColor = luminance > 0.5 ? Colors.black87 : Colors.white;
    final borderColor = luminance > 0.5 ? Colors.black26 : Colors.white;

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 3,
          ),
        ],
      ),
      child: Text(
        numeroLinea,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: txtColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
