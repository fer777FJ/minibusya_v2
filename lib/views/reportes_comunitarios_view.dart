// lib/views/reportes_comunitarios_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/reporte_service.dart';
import '../utils/app_theme.dart';

class ReportesComunitariosView extends StatefulWidget {
  const ReportesComunitariosView({super.key});

  @override
  State<ReportesComunitariosView> createState() =>
      _ReportesComunitariosViewState();
}

class _ReportesComunitariosViewState extends State<ReportesComunitariosView> {
  final ReporteService _reporteService = ReporteService();
  bool _mostrarMapa = false; // Toggle entre lista y mapa

  String _obtenerEmojiReporte(String tipo) {
    switch (tipo) {
      case 'bloqueo':
        return '🚧';
      case 'desvio':
        return '↪️';
      case 'rutaModificada':
        return '🔄';
      case 'feria':
        return '🏪';
      default:
        return '📍';
    }
  }

  Color _obtenerColorReporte(String tipo) {
    switch (tipo) {
      case 'bloqueo':
        return AppTheme.rojoAlerta;
      case 'desvio':
        return AppTheme.naranjaDesvio;
      case 'rutaModificada':
        return AppTheme.azulSecundario;
      case 'feria':
        return AppTheme.verdeOk;
      default:
        return Colors.grey;
    }
  }

  String _obtenerLabelReporte(String tipo) {
    switch (tipo) {
      case 'bloqueo':
        return 'Bloqueo';
      case 'desvio':
        return 'Desvío';
      case 'rutaModificada':
        return 'Ruta Cambió';
      case 'feria':
        return 'Feria';
      default:
        return 'Reporte';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de la Comunidad'),
        actions: [
          // Toggle Vista/Mapa
          Tooltip(
            message: _mostrarMapa ? 'Ver Lista' : 'Ver Mapa',
            child: IconButton(
              icon: Icon(_mostrarMapa ? Icons.list : Icons.map),
              onPressed: () => setState(() => _mostrarMapa = !_mostrarMapa),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _reporteService.obtenerReportesEnTiempoReal(horasAtras: 24),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppTheme.rojoAlerta),
                  const SizedBox(height: 12),
                  const Text('Error al cargar reportes'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final reportes = snapshot.data ?? [];

          if (reportes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: AppTheme.verdeOk,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Todo está bien 🎉',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No hay reportes activos en tu zona',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          // Mostrar mapa o lista según toggle
          return _mostrarMapa ? _buildMapa(reportes) : _buildLista(reportes);
        },
      ),
    );
  }

  // ─── VISTA LISTA ──────────────────────────────────────────────────────────

  Widget _buildLista(List<Map<String, dynamic>> reportes) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: reportes.length,
      itemBuilder: (context, index) {
        final reporte = reportes[index];
        final tipo = reporte['tipo'] as String;
        final descripcion = reporte['descripcion'] as String?;
        final lat = reporte['lat'] as double;
        final lng = reporte['lng'] as double;
        final fotoBase64 = reporte['foto_base64'] as String?;

        // Parsear timestamp
        dynamic timestamp = reporte['timestamp'];
        DateTime? fechaReporte;

        if (timestamp is String) {
          fechaReporte = DateTime.parse(timestamp);
        } else if (timestamp is Timestamp) {
          fechaReporte = timestamp.toDate();
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Encabezado
                Row(
                  children: [
                    Text(
                      _obtenerEmojiReporte(tipo),
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _obtenerLabelReporte(tipo),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (fechaReporte != null)
                            Text(
                              _formatearFecha(fechaReporte),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Badge de tiempo
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _obtenerColorReporte(tipo).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _obtenerTiempoTranscurrido(fechaReporte),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _obtenerColorReporte(tipo),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ─── Descripción
                if (descripcion != null && descripcion.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          descripcion,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.grisTexto,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                // ─── Foto (si existe)
                if (fotoBase64 != null && fotoBase64.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(fotoBase64),
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                // ─── Ubicación
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: _obtenerColorReporte(tipo),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$lat, $lng',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.grisTexto,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── VISTA MAPA ───────────────────────────────────────────────────────────

  Widget _buildMapa(List<Map<String, dynamic>> reportes) {
    // Convertir reportes a marcadores
    final marcadores = reportes.map((reporte) {
      final tipo = reporte['tipo'] as String;
      final lat = reporte['lat'] as double;
      final lng = reporte['lng'] as double;

      return Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _mostrarDetalleReporte(reporte),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _obtenerColorReporte(tipo),
              boxShadow: [
                BoxShadow(
                  color: _obtenerColorReporte(tipo).withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                _obtenerEmojiReporte(tipo),
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
        ),
      );
    }).toList();

    return FlutterMap(
      options: const MapOptions(
        initialCenter: LatLng(-16.4955, -68.1337), // La Paz
        initialZoom: 13.0,
        minZoom: 10.0,
        maxZoom: 18.0,
      ),
      children: [
        // Tiles OpenStreetMap
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'bo.edu.unifranz.minibus_ya',
        ),

        // Marcadores de reportes
        MarkerLayer(markers: marcadores),
      ],
    );
  }

  // ─── DIÁLOGO DE DETALLE ───────────────────────────────────────────────────

  void _mostrarDetalleReporte(Map<String, dynamic> reporte) {
    final tipo = reporte['tipo'] as String;
    final descripcion = reporte['descripcion'] as String?;
    final fotoBase64 = reporte['foto_base64'] as String?;

    dynamic timestamp = reporte['timestamp'];
    DateTime? fechaReporte;

    if (timestamp is String) {
      fechaReporte = DateTime.parse(timestamp);
    } else if (timestamp is Timestamp) {
      fechaReporte = timestamp.toDate();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    _obtenerEmojiReporte(tipo),
                    style: const TextStyle(fontSize: 40),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _obtenerLabelReporte(tipo),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        if (fechaReporte != null)
                          Text(
                            _formatearFecha(fechaReporte),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (descripcion != null && descripcion.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detalles:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(descripcion),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              if (fotoBase64 != null && fotoBase64.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Foto adjunta:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(fotoBase64),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Icon(Icons.error_outline, size: 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              Row(
                children: [
                  Icon(Icons.location_on,
                      size: 16, color: _obtenerColorReporte(tipo)),
                  const SizedBox(width: 6),
                  Text(
                    '${reporte['lat']}, ${reporte['lng']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.grisTexto,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── UTILIDADES ───────────────────────────────────────────────────────────

  String _formatearFecha(DateTime fecha) {
    return DateFormat('HH:mm').format(fecha);
  }

  String _obtenerTiempoTranscurrido(DateTime? fecha) {
    if (fecha == null) return 'Reciente';

    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inMinutes < 1) {
      return 'Ahora';
    } else if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes}m';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours}h';
    } else {
      return 'Ayer';
    }
  }
}
