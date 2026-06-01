import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/ruta_model.dart';
import 'database_helper.dart';

/// Maneja el envío de reportes a Firestore.
/// Si no hay internet, guarda en SQLite y reintenta después.
class ReporteService {
  static final ReporteService _instance = ReporteService._internal();
  factory ReporteService() => _instance;
  ReporteService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _db = DatabaseHelper();

  /// Envía un reporte — online va a Firestore, offline queda en SQLite
  Future<bool> enviarReporte({
    required TipoReporte tipo,
    required double lat,
    required double lng,
    String? descripcion,
    String? rutaAfectadaId,
  }) async {
    final reporte = {
      'tipo': tipo.name,
      'lat': lat,
      'lng': lng,
      'descripcion': descripcion,
      'ruta_afectada_id': rutaAfectadaId,
      'timestamp': DateTime.now().toIso8601String(),
      'enviado': 0,
    };

    // Verificar conexión
    final conectividad = await Connectivity().checkConnectivity();
    final tieneInternet = conectividad != ConnectivityResult.none;

    if (tieneInternet) {
      try {
        // Enviar directamente a Firestore
        await _firestore.collection('reportes').add({
          ...reporte,
          'timestamp': FieldValue.serverTimestamp(),
          'enviado': 1,
        });
        print('✅ Reporte enviado a Firestore');
        return true;
      } catch (e) {
        print('❌ Error enviando a Firestore: $e');
        // Si falla, guardar local como respaldo
        await _guardarLocal(reporte);
        return false;
      }
    } else {
      // Sin internet — guardar local y sincronizar después
      await _guardarLocal(reporte);
      print('📴 Sin internet — reporte guardado localmente');
      return false;
    }
  }

  Future<void> _guardarLocal(Map<String, dynamic> reporte) async {
    await _db.guardarReportePendiente({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      ...reporte,
    });
  }

  /// Sincroniza los reportes pendientes cuando hay internet
  Future<void> sincronizarPendientes() async {
    final conectividad = await Connectivity().checkConnectivity();
    if (conectividad == ConnectivityResult.none) return;

    final pendientes = await _db.obtenerReportesPendientes();
    if (pendientes.isEmpty) return;

    print('🔄 Sincronizando ${pendientes.length} reportes pendientes...');

    for (final reporte in pendientes) {
      try {
        await _firestore.collection('reportes').add({
          'tipo': reporte['tipo'],
          'lat': reporte['lat'],
          'lng': reporte['lng'],
          'descripcion': reporte['descripcion'],
          'ruta_afectada_id': reporte['ruta_afectada_id'],
          'timestamp': FieldValue.serverTimestamp(),
          'enviado': 1,
        });
        // Marcar como enviado en SQLite
        // TODO: agregar método marcarEnviado en DatabaseHelper
        print('✅ Reporte ${reporte['id']} sincronizado');
      } catch (e) {
        print('❌ Error sincronizando ${reporte['id']}: $e');
      }
    }
  }

  /// Obtiene los reportes recientes de Firestore para mostrar en el mapa
  Future<List<Map<String, dynamic>>> obtenerReportesRecientes({
    int limite = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('reportes')
          .orderBy('timestamp', descending: true)
          .limit(limite)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('❌ Error obteniendo reportes: $e');
      return [];
    }
  }

  /// Stream en tiempo real de reportes comunitarios (últimas 24 horas)
  /// Útil para mostrar reportes activos en la aplicación
  Stream<List<Map<String, dynamic>>> obtenerReportesEnTiempoReal({
    int horasAtras = 24,
  }) {
    final hace24Horas = DateTime.now().subtract(Duration(hours: horasAtras));

    return _firestore
        .collection('reportes')
        .where('timestamp', isGreaterThan: hace24Horas)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => {
            'id': doc.id,
            ...doc.data(),
          }).toList();
        });
  }
}