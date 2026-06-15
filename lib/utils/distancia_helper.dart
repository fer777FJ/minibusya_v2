// lib/utils/distancia_helper.dart
import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/ruta_model.dart';

/// Calcula la distancia en metros entre dos puntos usando la fórmula de Haversine.
double distanciaMetros(LatLng a, LatLng b) {
  const R = 6371000.0; // Radio de la Tierra en metros
  final lat1 = a.latitude * pi / 180;
  final lat2 = b.latitude * pi / 180;
  final dLat = (b.latitude - a.latitude) * pi / 180;
  final dLon = (b.longitude - a.longitude) * pi / 180;

  final sinLat = sin(dLat / 2);
  final sinLon = sin(dLon / 2);

  final h =
      sinLat * sinLat + cos(lat1) * cos(lat2) * sinLon * sinLon;
  return R * 2 * atan2(sqrt(h), sqrt(1 - h));
}

/// Resultado del cálculo del punto destino para la navegación.
class PuntoDestino {
  /// Coordenada del punto más cercano (en la polilínea o en una parada).
  final LatLng punto;

  /// Distancia en metros desde el usuario hasta el punto.
  final double distanciaM;

  /// Nombre descriptivo del punto (nombre de parada o "Punto en ruta").
  final String nombre;

  /// true si es una parada oficial (teleférico), false si es punto en polilínea.
  final bool esParadaOficial;

  const PuntoDestino({
    required this.punto,
    required this.distanciaM,
    required this.nombre,
    required this.esParadaOficial,
  });
}

/// Determina el punto destino de navegación según el tipo de ruta:
/// - Teleférico → parada oficial más cercana
/// - Resto → punto más cercano en la polilínea completa
PuntoDestino calcularPuntoDestino({
  required LatLng usuario,
  required RutaModel ruta,
}) {
  final esTeleferico = ruta.tiposVehiculo.contains('Teleferico');

  if (esTeleferico || ruta.paradas.isEmpty) {
    // ── TELEFÉRICO: ir a la estación oficial más cercana ──────────────
    ParadaModel? mejorParada;
    double mejorDist = double.infinity;

    for (final p in ruta.paradas) {
      final d = distanciaMetros(usuario, p.latLng);
      if (d < mejorDist) {
        mejorDist = d;
        mejorParada = p;
      }
    }

    if (mejorParada != null) {
      return PuntoDestino(
        punto: mejorParada.latLng,
        distanciaM: mejorDist,
        nombre: mejorParada.nombre,
        esParadaOficial: true,
      );
    }
  }

  // ── RUTAS NORMALES: punto más cercano en la polilínea ────────────────
  LatLng? mejorPunto;
  double mejorDist = double.infinity;

  final coords = ruta.coordenadas;
  for (int i = 0; i < coords.length - 1; i++) {
    final candidato = _proyectarPuntoEnSegmento(usuario, coords[i], coords[i + 1]);
    final d = distanciaMetros(usuario, candidato);
    if (d < mejorDist) {
      mejorDist = d;
      mejorPunto = candidato;
    }
  }

  // Fallback: si solo hay un punto en coordenadas
  if (mejorPunto == null && coords.isNotEmpty) {
    mejorPunto = coords.first;
    mejorDist = distanciaMetros(usuario, mejorPunto);
  }

  return PuntoDestino(
    punto: mejorPunto ?? usuario,
    distanciaM: mejorDist,
    nombre: 'Punto más cercano en la Línea ${ruta.numeroLinea}',
    esParadaOficial: false,
  );
}

/// Proyecta el punto [p] sobre el segmento [a]–[b] y devuelve el punto
/// más cercano en ese segmento (puede ser [a], [b] o un punto intermedio).
LatLng _proyectarPuntoEnSegmento(LatLng p, LatLng a, LatLng b) {
  final ax = a.longitude;
  final ay = a.latitude;
  final bx = b.longitude;
  final by = b.latitude;
  final px = p.longitude;
  final py = p.latitude;

  final dx = bx - ax;
  final dy = by - ay;
  final len2 = dx * dx + dy * dy;

  if (len2 == 0) return a; // segmento degenerado (a == b)

  // Parámetro t en [0,1] del punto más cercano sobre el segmento
  final t = ((px - ax) * dx + (py - ay) * dy) / len2;
  final tClamped = t.clamp(0.0, 1.0);

  return LatLng(ay + tClamped * dy, ax + tClamped * dx);
}

/// Formatea metros a texto legible (m o km).
String formatearDistancia(double metros) {
  if (metros < 1000) {
    return '${metros.round()} m';
  }
  return '${(metros / 1000).toStringAsFixed(1)} km';
}
