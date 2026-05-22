// lib/models/ruta_model.dart
import 'package:latlong2/latlong.dart';

/// Representa una línea de transporte (sindicato de minibuses)
class RutaModel {
  final String id;
  final String sindicato;       // "Eduardo Avaroa", "Villa San Antonio", etc.
  final String numeroLinea;     // "102", "273", etc.
  final String origen;          // "Plaza Tejada Sorzano"
  final String destino;         // "El Alto - Villa Dolores"
  final String colorHex;        // Color del letrero "#FF0000"
  final String colorTextoHex;   // Color del texto del letrero
  final double tarifaNormal;    // en Bolivianos
  final double tarifaEstudiantil;
  final double tarifaNocturna;
  final String horarioInicio;   // "05:30"
  final String horarioFin;      // "22:00"
  final List<String> tiposVehiculo; // ["Minibús", "Trufi"]
  final List<ParadaModel> paradas;
  final List<LatLng> coordenadas;   // Trazado completo de la ruta
  final String? letreroImagePath;   // path al asset del letrero

  const RutaModel({
    required this.id,
    required this.sindicato,
    required this.numeroLinea,
    required this.origen,
    required this.destino,
    required this.colorHex,
    required this.colorTextoHex,
    required this.tarifaNormal,
    required this.tarifaEstudiantil,
    required this.tarifaNocturna,
    required this.horarioInicio,
    required this.horarioFin,
    required this.tiposVehiculo,
    required this.paradas,
    required this.coordenadas,
    this.letreroImagePath,
  });

  factory RutaModel.fromJson(Map<String, dynamic> json) {
    return RutaModel(
      id: json['id'] as String,
      sindicato: json['sindicato'] as String,
      numeroLinea: json['numero_linea'] as String,
      origen: json['origen'] as String,
      destino: json['destino'] as String,
      colorHex: json['color_hex'] as String? ?? '#0D47A1',
      colorTextoHex: json['color_texto_hex'] as String? ?? '#FFFFFF',
      tarifaNormal: (json['tarifa_normal'] as num).toDouble(),
      tarifaEstudiantil: (json['tarifa_estudiantil'] as num).toDouble(),
      tarifaNocturna: (json['tarifa_nocturna'] as num).toDouble(),
      horarioInicio: json['horario_inicio'] as String? ?? '05:30',
      horarioFin: json['horario_fin'] as String? ?? '22:00',
      tiposVehiculo: List<String>.from(json['tipos_vehiculo'] as List),
      paradas: (json['paradas'] as List)
          .map((p) => ParadaModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      coordenadas: (json['coordenadas'] as List)
          .map((c) => LatLng(
                (c['lat'] as num).toDouble(),
                (c['lng'] as num).toDouble(),
              ))
          .toList(),
      letreroImagePath: json['letrero_image_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sindicato': sindicato,
        'numero_linea': numeroLinea,
        'origen': origen,
        'destino': destino,
        'color_hex': colorHex,
        'color_texto_hex': colorTextoHex,
        'tarifa_normal': tarifaNormal,
        'tarifa_estudiantil': tarifaEstudiantil,
        'tarifa_nocturna': tarifaNocturna,
        'horario_inicio': horarioInicio,
        'horario_fin': horarioFin,
        'tipos_vehiculo': tiposVehiculo,
        'paradas': paradas.map((p) => p.toJson()).toList(),
        'coordenadas': coordenadas
            .map((c) => {'lat': c.latitude, 'lng': c.longitude})
            .toList(),
        'letrero_image_path': letreroImagePath,
      };
}

/// Una parada específica en la ruta
class ParadaModel {
  final String id;
  final String nombre;
  final double lat;
  final double lng;
  final bool esTerminal;
  final int ordenEnRuta;

  const ParadaModel({
    required this.id,
    required this.nombre,
    required this.lat,
    required this.lng,
    required this.esTerminal,
    required this.ordenEnRuta,
  });

  LatLng get latLng => LatLng(lat, lng);

  factory ParadaModel.fromJson(Map<String, dynamic> json) {
    return ParadaModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      esTerminal: json['es_terminal'] as bool? ?? false,
      ordenEnRuta: json['orden_en_ruta'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'lat': lat,
        'lng': lng,
        'es_terminal': esTerminal,
        'orden_en_ruta': ordenEnRuta,
      };
}

/// Reporte comunitario enviado por usuarios
class ReporteModel {
  final String id;
  final TipoReporte tipo;
  final double lat;
  final double lng;
  final String? descripcion;
  final DateTime timestamp;
  final String? rutaAfectadaId;

  const ReporteModel({
    required this.id,
    required this.tipo,
    required this.lat,
    required this.lng,
    this.descripcion,
    required this.timestamp,
    this.rutaAfectadaId,
  });

  LatLng get latLng => LatLng(lat, lng);
}

enum TipoReporte {
  bloqueo,
  desvio,
  rutaModificada,
  feria,
}

extension TipoReporteExtension on TipoReporte {
  String get label {
    switch (this) {
      case TipoReporte.bloqueo:
        return 'Bloqueo';
      case TipoReporte.desvio:
        return 'Desvío';
      case TipoReporte.rutaModificada:
        return 'Ruta Modificada';
      case TipoReporte.feria:
        return 'Feria';
    }
  }

  String get emoji {
    switch (this) {
      case TipoReporte.bloqueo:
        return '🚧';
      case TipoReporte.desvio:
        return '↪️';
      case TipoReporte.rutaModificada:
        return '🔄';
      case TipoReporte.feria:
        return '🏪';
    }
  }
}
