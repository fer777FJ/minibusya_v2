// lib/controllers/mapa_controller.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

/// Controlador del mapa offline con flutter_map.
/// Gestiona tiles locales (MOBAC) y la geolocalización del usuario.
class MapaController with ChangeNotifier {
  // Centro inicial: Plaza Murillo, La Paz
  static const LatLng _centroLaPaz = LatLng(-16.4955, -68.1337);
  static const double _zoomInicial = 14.0;

  LatLng _centroActual = _centroLaPaz;
  double _zoomActual = _zoomInicial;
  LatLng? _ubicacionUsuario;
  bool _cargandoUbicacion = false;
  String? _errorUbicacion;
  StreamSubscription<Position>? _positionSubscription;

  final MapController mapController = MapController();

  LatLng get centroActual => _centroActual;
  double get zoomActual => _zoomActual;
  LatLng? get ubicacionUsuario => _ubicacionUsuario;
  bool get cargandoUbicacion => _cargandoUbicacion;
  String? get errorUbicacion => _errorUbicacion;

  /// Configuración del TileProvider para tiles OFFLINE.
  ///
  /// INSTRUCCIONES PARA GENERAR LOS TILES CON MOBAC:
  /// 1. Descarga MOBAC desde: https://mobac.sourceforge.io/
  /// 2. Abre MOBAC > selecciona "OpenStreetMap" como fuente
  /// 3. Dibuja el área de La Paz y El Alto
  /// 4. Zoom levels: selecciona del 12 al 16 (zoom urbano suficiente)
  /// 5. Atlas format: "Big Planet Tiles" o "OSMand"
  /// 6. Guarda los tiles como PNG en: assets/mapa/{z}/{x}/{y}.png
  ///
  /// ALTERNATIVA RÁPIDA SIN MOBAC (online, para desarrollo):
  /// Usa NetworkTileProvider con OSM mientras preparas los tiles offline.
  TileLayer getTileLayer({bool offline = false}) {
    if (offline) {
      // 🔌 MODO OFFLINE — usa tiles descargados con MOBAC
      // La ruta sigue el formato estándar de tiles: zoom/x/y.png
      return TileLayer(
        urlTemplate: 'assets/mapa/{z}/{x}/{y}.png',
        tileProvider: _getAssetTileProvider(),
        minZoom: 12.0,
        maxZoom: 16.0,
        errorTileCallback: (tile, error, stackTrace) {
          debugPrint('❌ Tile faltante: ${tile.coordinates} - Error: $error');
        },
      );
    } else {
      // 🌐 MODO ONLINE — OpenStreetMap (gratuito, sin API key)
      // Usa este modo durante el desarrollo mientras generas los tiles offline
      return TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'bo.edu.unifranz.minibus_ya',
        maxZoom: 19.0,
      );
    }
  }

  /// Retorna el tile provider para assets
  /// En flutter_map 6.1+, usa AssetTileProvider si está disponible
  TileProvider _getAssetTileProvider() {
    // Para flutter_map 6.1.0+, usamos el proveedor de assets
    // que viene incluido en la librería
    try {
      // Intenta usar AssetTileProvider (disponible en versiones recientes)
      return AssetTileProvider();
    } catch (e) {
      // Si no está disponible, usa NetworkTileProvider como fallback
      debugPrint('⚠️ AssetTileProvider no disponible, usando fallback: $e');
      return NetworkTileProvider();
    }
  }

  /// Solicita permisos y obtiene la ubicación actual del usuario
  Future<void> obtenerUbicacion({BuildContext? context}) async {
    _cargandoUbicacion = true;
    _errorUbicacion = null;
    notifyListeners();

    // Evitar llamadas de Geolocator en pruebas unitarias/de widgets
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _ubicacionUsuario = _centroLaPaz;
      _cargandoUbicacion = false;
      notifyListeners();
      return;
    }

    try {
      // Verificar si el servicio GPS está habilitado
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context != null && context.mounted) {
          final abrirAjustes = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('GPS Desactivado'),
              content: const Text(
                'El GPS de tu dispositivo está desactivado. Para poder centrar el mapa y usar tu ubicación, debes activarlo.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Ir a Ajustes'),
                ),
              ],
            ),
          );
          if (abrirAjustes == true) {
            await Geolocator.openLocationSettings();
          }
        }
        _errorUbicacion = 'Activa el GPS de tu dispositivo';
        _cargandoUbicacion = false;
        notifyListeners();
        return;
      }

      // Verificar / solicitar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _errorUbicacion = 'Permiso de ubicación denegado';
          _cargandoUbicacion = false;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (context != null && context.mounted) {
          final abrirConfig = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Permiso Denegado Permanentemente'),
              content: const Text(
                'Los permisos de ubicación están denegados permanentemente en tu dispositivo.\n\n'
                'Debes activarlos desde la configuración de la aplicación para poder ver tu ubicación.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Abrir Ajustes'),
                ),
              ],
            ),
          );
          if (abrirConfig == true) {
            await Geolocator.openAppSettings();
          }
        }
        _errorUbicacion = 'Activa el permiso de ubicación en Ajustes';
        _cargandoUbicacion = false;
        notifyListeners();
        return;
      }

      // Obtener posición
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _ubicacionUsuario = LatLng(position.latitude, position.longitude);
      _centrarEnUbicacion(_ubicacionUsuario!);

      // Iniciar el seguimiento continuo en tiempo real
      _iniciarSeguimientoUbicacion();
    } catch (e) {
      _errorUbicacion = 'No se pudo obtener la ubicación';
    } finally {
      _cargandoUbicacion = false;
      notifyListeners();
    }
  }

  /// Inicializa la escucha de actualizaciones de ubicación en tiempo real
  void _iniciarSeguimientoUbicacion() {
    _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, // Se actualiza cada 2 metros de movimiento
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _ubicacionUsuario = LatLng(position.latitude, position.longitude);
        _errorUbicacion = null;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('❌ Error en el flujo de ubicación: $e');
      },
    );
  }

  void _centrarEnUbicacion(LatLng ubicacion) {
    mapController.move(ubicacion, 15.0);
    _centroActual = ubicacion;
    _zoomActual = 15.0;
  }

  /// Centra el mapa en una ruta específica calculando su bounding box
  void centrarEnRuta(List<LatLng> coordenadas) {
    if (coordenadas.isEmpty) return;

    double minLat = coordenadas.first.latitude;
    double maxLat = coordenadas.first.latitude;
    double minLng = coordenadas.first.longitude;
    double maxLng = coordenadas.first.longitude;

    for (final coord in coordenadas) {
      if (coord.latitude < minLat) minLat = coord.latitude;
      if (coord.latitude > maxLat) maxLat = coord.latitude;
      if (coord.longitude < minLng) minLng = coord.longitude;
      if (coord.longitude > maxLng) maxLng = coord.longitude;
    }

    final centro = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    mapController.move(centro, 13.5);
    _centroActual = centro;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    mapController.dispose();
    super.dispose();
  }
}
