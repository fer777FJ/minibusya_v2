// lib/views/reportes_historial_view.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/database_helper.dart';
import '../models/ruta_model.dart';
import '../utils/app_theme.dart';

class ReportesHistorialView extends StatefulWidget {
  const ReportesHistorialView({super.key});

  @override
  State<ReportesHistorialView> createState() => _ReportesHistorialViewState();
}

class _ReportesHistorialViewState extends State<ReportesHistorialView> {
  final DatabaseHelper _db = DatabaseHelper();
  late Future<List<Map<String, dynamic>>> _reportes;

  @override
  void initState() {
    super.initState();
    _cargarReportes();
  }

  void _cargarReportes() {
    setState(() {
      _reportes = _db.obtenerReportesPendientes();
    });
  }

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
        title: const Text('Mis Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarReportes,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _reportes,
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
                  const Text('Error al cargar los reportes'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _cargarReportes,
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
                  Icon(
                    Icons.info_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No has hecho ningún reporte',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Los reportes que hagas aparecerán aquí',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reportes.length,
            itemBuilder: (context, index) {
              final reporte = reportes[index];
              final tipo = reporte['tipo'] as String;
              final descripcion = reporte['descripcion'] as String?;
              final lat = reporte['lat'] as double;
              final lng = reporte['lng'] as double;
              final timestamp = DateTime.parse(reporte['timestamp'] as String);
              final enviado = (reporte['enviado'] as int?) ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Encabezado: tipo y estado
                      Row(
                        children: [
                          // Emoji del tipo
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
                                Text(
                                  _formatearFecha(timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Badge de estado
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: enviado == 1
                                  ? AppTheme.verdeOk.withOpacity(0.1)
                                  : AppTheme.naranjaDesvio.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              enviado == 1 ? '✅ Enviado' : '📴 Pendiente',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: enviado == 1
                                    ? AppTheme.verdeOk
                                    : AppTheme.naranjaDesvio,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ─── Descripción (si la hay)
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
        },
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final hoy = DateTime.now();
    final ayer = DateTime(hoy.year, hoy.month, hoy.day - 1);
    final fecDia = DateTime(fecha.year, fecha.month, fecha.day);

    if (fecDia == DateTime(hoy.year, hoy.month, hoy.day)) {
      return 'Hoy a las ${DateFormat('HH:mm').format(fecha)}';
    } else if (fecDia == ayer) {
      return 'Ayer a las ${DateFormat('HH:mm').format(fecha)}';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
    }
  }
}
