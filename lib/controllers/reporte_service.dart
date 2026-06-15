import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/ruta_model.dart';
import 'database_helper.dart';

/// Maneja el envío de reportes a Firestore.
/// Las fotos se comprimen y se guardan como base64 directamente en el documento
/// (sin Firebase Storage). SIEMPRE guarda en SQLite local primero.
class ReporteService {
  static final ReporteService _instance = ReporteService._internal();
  factory ReporteService() => _instance;
  ReporteService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _db = DatabaseHelper();

  /// Comprime la imagen y la convierte a base64 para guardar en Firestore.
  /// Objetivo: ≤ 200 KB para no superar el límite de 1 MB del documento.
  Future<String?> _imagenABase64(String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('⚠️ Archivo de imagen no existe: $localPath');
        return null;
      }

      // Comprimir imagen: máx 600×600, calidad 60
      final comprimida = await FlutterImageCompress.compressWithFile(
        localPath,
        minWidth: 600,
        minHeight: 600,
        quality: 60,
        format: CompressFormat.jpeg,
      );

      if (comprimida == null) {
        debugPrint('⚠️ No se pudo comprimir la imagen, usando original');
        final bytes = await file.readAsBytes();
        if (bytes.lengthInBytes > 800 * 1024) {
          debugPrint('❌ Imagen original demasiado grande (${bytes.lengthInBytes} bytes), omitiendo');
          return null;
        }
        return base64Encode(bytes);
      }

      debugPrint('📸 Imagen comprimida: ${comprimida.lengthInBytes} bytes');
      return base64Encode(comprimida);
    } catch (e) {
      debugPrint('❌ Error procesando imagen: $e');
      return null;
    }
  }

  /// Envía un reporte — SIEMPRE se guarda en SQLite local.
  /// Si hay internet, también se envía a Firestore con la foto en base64.
  Future<bool> enviarReporte({
    required TipoReporte tipo,
    required double lat,
    required double lng,
    String? descripcion,
    String? rutaAfectadaId,
    String? fotoPath,
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
      'foto_path': fotoPath,
    };

    // 1️⃣ SIEMPRE guardar en SQLite local (para "Mis Reportes")
    await _db.guardarReportePendiente(reporte);
    debugPrint('💾 Reporte $reporteId guardado localmente');

    // 2️⃣ Intentar enviar a Firestore si hay internet
    final conectividad = await Connectivity().checkConnectivity();
    final tieneInternet = !conectividad.contains(ConnectivityResult.none);

    if (tieneInternet) {
      try {
        // Convertir foto a base64 si existe
        String? fotoBase64;
        if (fotoPath != null) {
          fotoBase64 = await _imagenABase64(fotoPath);
          if (fotoBase64 != null) {
            debugPrint('📸 Foto convertida a base64 (${(fotoBase64.length / 1024).toStringAsFixed(1)} KB)');
          }
        }

        await _firestore.collection('reportes').add({
          'tipo': tipo.name,
          'lat': lat,
          'lng': lng,
          'descripcion': descripcion,
          'ruta_afectada_id': rutaAfectadaId,
          'timestamp': FieldValue.serverTimestamp(),
          'foto_base64': fotoBase64, // null si no hay foto
        });

        await _db.marcarEnviado(reporteId);
        debugPrint('✅ Reporte $reporteId enviado a Firestore');
        return true;
      } catch (e) {
        debugPrint('❌ Error enviando a Firestore: $e');
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
    final noEnviados = pendientes.where((r) => (r['enviado'] as int?) == 0).toList();
    if (noEnviados.isEmpty) return;

    debugPrint('🔄 Sincronizando ${noEnviados.length} reportes pendientes...');

    for (final reporte in noEnviados) {
      try {
        final reporteId = reporte['id'] as String;
        final fotoPath = reporte['foto_path'] as String?;
        String? fotoBase64;

        if (fotoPath != null) {
          fotoBase64 = await _imagenABase64(fotoPath);
        }

        await _firestore.collection('reportes').add({
          'tipo': reporte['tipo'],
          'lat': reporte['lat'],
          'lng': reporte['lng'],
          'descripcion': reporte['descripcion'],
          'ruta_afectada_id': reporte['ruta_afectada_id'],
          'timestamp': FieldValue.serverTimestamp(),
          'foto_base64': fotoBase64,
        });

        await _db.marcarEnviado(reporteId);
        debugPrint('✅ Reporte $reporteId sincronizado');
      } catch (e) {
        debugPrint('❌ Error sincronizando ${reporte['id']}: $e');
      }
    }
  }

  /// Obtiene los reportes recientes de Firestore
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