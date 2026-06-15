// lib/controllers/rutas_controller.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../models/ruta_model.dart';

/// Controlador principal de rutas.
/// Carga los JSONs desde assets (sin internet) y maneja la lógica de búsqueda.
class RutasController {
  // Singleton
  static final RutasController _instance = RutasController._internal();
  factory RutasController() => _instance;
  RutasController._internal();

  List<RutaModel> _todasLasRutas = [];
  bool _cargado = false;

  /// Lista de archivos JSON en assets/rutas/ — agrega aquí cada sindicato
  static const List<String> _archivosRutas = [
    'assets/rutas/linea_001.json',
    'assets/rutas/linea_101_t.json',
    'assets/rutas/linea_105_5.json',
    'assets/rutas/linea_112.json',
    'assets/rutas/linea_127_t.json',
    'assets/rutas/linea_273_villa_san_antonio.json',
    'assets/rutas/linea_280.json',
    'assets/rutas/linea_281.json',
    'assets/rutas/linea_282.json',
    'assets/rutas/linea_283.json',
    'assets/rutas/linea_284.json',
    'assets/rutas/linea_451.json',
    'assets/rutas/linea_600_t.json',
    'assets/rutas/linea_600.json',
    'assets/rutas/linea_621.json',
    'assets/rutas/linea_635.json',
    'assets/rutas/linea_657.json',
    'assets/rutas/linea_685_t.json',
    'assets/rutas/linea_751_el_alto.json',
    'assets/rutas/linea_752.json',
    'assets/rutas/linea_771.json',
    'assets/rutas/linea_782.json',
    'assets/rutas/linea_824.json',
    'assets/rutas/linea_898.json',
    'assets/rutas/linea_TelefericoAmarillo.json',
    'assets/rutas/linea_TelefericoAzul.json',
    'assets/rutas/linea_TelefericoBlanco.json',
    'assets/rutas/linea_TelefericoCafe.json',
    'assets/rutas/linea_TelefericoCeleste.json',
    'assets/rutas/linea_TelefericoMorado.json',
    'assets/rutas/linea_TelefericoNaranja.json',
    'assets/rutas/linea_TelefericoPlateado.json',
    'assets/rutas/linea_TelefericoRojo.json',
    'assets/rutas/linea_TelefericoVerde.json',
    // Agrega más archivos aquí conforme levanten datos en campo
  ];

  /// Carga todas las rutas desde los assets al iniciar la app.
  /// Se llama una sola vez; las siguientes llamadas retornan el caché.
  Future<List<RutaModel>> cargarTodasLasRutas() async {
    if (_cargado) return _todasLasRutas;

    _todasLasRutas = [];
    for (final archivo in _archivosRutas) {
      try {
        final jsonStr = await rootBundle.loadString(archivo);
        final jsonData = json.decode(jsonStr) as Map<String, dynamic>;
        _todasLasRutas.add(RutaModel.fromJson(jsonData));
      } catch (e) {
        // Si falta un archivo no rompe la app, sigue con los demás
        print('⚠️ No se pudo cargar $archivo: $e');
      }
    }
    _cargado = true;
    return _todasLasRutas;
  }

  /// Elimina acentos y normaliza a minúsculas para que el filtro de
  /// stop words y la búsqueda funcionen con o sin tilde.
  static String _normalizarTexto(String texto) {
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ü', 'u');
  }

  /// Busca rutas cuyo trazado pase cerca del destino indicado.
  /// Usa distancia euclidiana simple entre paradas y el punto destino.
  Future<List<RutaModel>> buscarRutas({
    required String textoBusqueda,
    LatLng? ubicacionUsuario,
    double radioKm = 0.5,
  }) async {
    final rutas = await cargarTodasLasRutas();
    if (textoBusqueda.isEmpty) return rutas;

    // Limpieza de términos al estilo chatbot (eliminando stop words y símbolos)
    final stopWords = [
      'como',
      'llego',
      'voy',
      'ir',
      'a',
      'de',
      'el',
      'la',
      'en',
      'quiero',
      'linea',
      'minibus',
      'trufi',
      'micro',
      'pumakatari',
      'ruta',
      'parada',
      'para',
      'por',
      'favor',
      'busca',
      'dime',
      'necesito',
      'desde',
      'hasta',
      'al',
      'del',
      'un',
      'una',
      'y',
      'o',
      'lo',
      'los',
      'las'
    ];

    final tokens = _normalizarTexto(textoBusqueda)
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.trim().isNotEmpty && !stopWords.contains(t))
        .toList();

    final query = tokens.isEmpty ? _normalizarTexto(textoBusqueda).trim() : tokens.join(' ');

    if (query.isEmpty) return [];

    final busquedaLower = query; // ya está normalizada (sin acentos, minúsculas)

    return rutas.where((ruta) {
      // Busca en nombre del sindicato, origen, destino y paradas
      // También normalizamos los campos de la ruta para comparación
      if (_normalizarTexto(ruta.sindicato).contains(busquedaLower)) return true;
      if (_normalizarTexto(ruta.origen).contains(busquedaLower)) return true;
      if (_normalizarTexto(ruta.destino).contains(busquedaLower)) return true;
      if (_normalizarTexto(ruta.numeroLinea).contains(busquedaLower)) return true;

      return ruta.paradas.any(
        (parada) => _normalizarTexto(parada.nombre).contains(busquedaLower),
      );
    }).toList();
  }

  /// Retorna las rutas que pasan por un radio alrededor de una coordenada GPS
  Future<List<RutaModel>> rutasCercanas(LatLng punto,
      {double radioKm = 0.3}) async {
    final rutas = await cargarTodasLasRutas();
    const distance = Distance();

    return rutas.where((ruta) {
      return ruta.paradas.any((parada) {
        final distancia = distance.as(
          LengthUnit.Kilometer,
          parada.latLng,
          punto,
        );
        return distancia <= radioKm;
      });
    }).toList();
  }

  /// Obtiene una ruta por su ID
  Future<RutaModel?> getRutaPorId(String id) async {
    final rutas = await cargarTodasLasRutas();
    try {
      return rutas.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Fuerza recarga (útil si se agregan nuevos JSONs en runtime)
  void invalidarCache() {
    _cargado = false;
    _todasLasRutas = [];
  }

  /// Filtra rutas por tipo de vehículo
  /// Si [tiposSeleccionados] está vacío, retorna todas las rutas
  Future<List<RutaModel>> filtrarPorTipo(
      List<String> tiposSeleccionados) async {
    final rutas = await cargarTodasLasRutas();

    if (tiposSeleccionados.isEmpty) {
      return rutas;
    }

    return rutas.where((ruta) {
      // Retorna true si la ruta tiene AL MENOS UNO de los tipos seleccionados
      return ruta.tiposVehiculo.any(
        (tipo) => tiposSeleccionados.contains(tipo),
      );
    }).toList();
  }

  /// Obtiene todos los tipos de vehículo disponibles en las rutas
  Future<Set<String>> obtenerTiposDisponibles() async {
    final rutas = await cargarTodasLasRutas();
    final tipos = <String>{};
    for (final ruta in rutas) {
      tipos.addAll(ruta.tiposVehiculo);
    }
    return tipos;
  }
}
