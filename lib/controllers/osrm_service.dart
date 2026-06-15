// lib/controllers/osrm_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Servicio para obtener rutas a pie usando la API pública de OSRM.
/// Documentación: https://project-osrm.org/docs/v5.24.0/api/
///
/// IMPORTANTE: requiere conexión a internet. Verificar antes de llamar.
class OsrmService {
  static const String _baseUrl = 'https://router.project-osrm.org/route/v1';

  /// Solicita una ruta a pie desde [origen] hasta [destino].
  /// Devuelve la lista de puntos de la polilínea o null si falla.
  static Future<List<LatLng>?> rutaAPie({
    required LatLng origen,
    required LatLng destino,
  }) async {
    try {
      // OSRM espera: lng,lat (NO lat,lng)
      final url = Uri.parse(
        '$_baseUrl/foot/'
        '${origen.longitude},${origen.latitude};'
        '${destino.longitude},${destino.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ OSRM error ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Verificar que hay rutas disponibles
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      // Extraer coordenadas de la geometría GeoJSON
      final geometry = routes[0]['geometry'] as Map<String, dynamic>;
      final coordsList = geometry['coordinates'] as List;

      return coordsList
          .map((c) => LatLng(
                (c[1] as num).toDouble(), // lat es el índice 1 en GeoJSON
                (c[0] as num).toDouble(), // lng es el índice 0 en GeoJSON
              ))
          .toList();
    } catch (e) {
      debugPrint('❌ Error al llamar OSRM: $e');
      return null;
    }
  }
}
