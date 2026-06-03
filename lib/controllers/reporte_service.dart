import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/ruta_model.dart';
import 'database_helper.dart';

/// Maneja el envío de reportes a Firestore.
/// SIEMPRE guarda en SQLite local + envía a Firestore si hay internet.
class ReporteService {
  static final ReporteService _instance = ReporteService._internal();
  factory ReporteService() => _instance;
  ReporteService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _db = DatabaseHelper();

  /// Envía un reporte — SIEMPRE se guarda en SQLite local.
  /// Si hay internet, también se envía a Firestore y se marca como enviado.
  Future<bool> enviarReporte({
    required TipoReporte tipo,
    required double lat,
    required double lng,
    String? descripcion,
    String? rutaAfectadaId,
  }) async {
    final reporteId = DateTime.now().millisecondsSinceEpoch.toString();

    final reporte = {
      'id': reporteId,
      'tipo': tipo.name,
      'lat': lat,
      'lng': lng,
      'descripcion': descripcion,
      'ruta_afectada_id': rutaAfectadaId,
      'timestamp': DateTime.now().toIso8601String(),
      'enviado': 0,
    };

    // 1️⃣ SIEMPRE guardar en SQLite local (para "Mis Reportes")
    await _db.guardarReportePendiente(reporte);
    debugPrint('💾 Reporte $reporteId guardado localmente');

    // 2️⃣ Intentar enviar a Firestore si hay internet
    final conectividad = await Connectivity().checkConnectivity();
    final tieneInternet = !conectividad.contains(ConnectivityResult.none);

    if (tieneInternet) {
      try {
        await _firestore.collection('reportes').add({
          'tipo': tipo.name,
          'lat': lat,
          'lng': lng,
          'descripcion': descripcion,
          'ruta_afectada_id': rutaAfectadaId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        // Marcar como enviado en SQLite
        await _db.marcarEnviado(reporteId);
        debugPrint('✅ Reporte $reporteId enviado a Firestore');
        return true;
      } catch (e) {
        debugPrint('❌ Error enviando a Firestore: $e');
        // Se queda como pendiente en SQLite
        return false;
      }
    } else {
      debugPrint('📴 Sin internet — reporte guardado solo localmente');
      return false;
    }
  }

  /// Sincroniza los reportes pendientes cuando hay internet
  Future<void> sincronizarPendientes() async {
    final conectividad = await Connectivity().checkConnectivity();
    if (conectividad.contains(ConnectivityResult.none)) return;

    final pendientes = await _db.obtenerReportesPendientes();
    // Filtrar solo los no enviados
    final noEnviados = pendientes.where((r) => (r['enviado'] as int?) == 0).toList();
    if (noEnviados.isEmpty) return;

    debugPrint('🔄 Sincronizando ${noEnviados.length} reportes pendientes...');

    for (final reporte in noEnviados) {
      try {
        await _firestore.collection('reportes').add({
          'tipo': reporte['tipo'],
          'lat': reporte['lat'],
          'lng': reporte['lng'],
          'descripcion': reporte['descripcion'],
          'ruta_afectada_id': reporte['ruta_afectada_id'],
          'timestamp': FieldValue.serverTimestamp(),
        });
        // Marcar como enviado en SQLite
        await _db.marcarEnviado(reporte['id'] as String);
        debugPrint('✅ Reporte ${reporte['id']} sincronizado');
      } catch (e) {
        debugPrint('❌ Error sincronizando ${reporte['id']}: $e');
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

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      debugPrint('❌ Error obteniendo reportes: $e');
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
          return snapshot.docs.map((doc) {
            return {'id': doc.id, ...doc.data()};
          }).toList();
        });
  }
}