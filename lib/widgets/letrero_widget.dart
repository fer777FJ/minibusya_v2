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

  @override
  Widget build(BuildContext context) {
    final bgColor = hexToColor(colorHex);
    final txtColor = hexToColor(colorTextoHex);

    return Container(
      width: width ?? 120,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 3,
          ),
        ],
      ),
      child: Text(
        numeroLinea,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
