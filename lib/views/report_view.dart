// lib/views/report_view.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../controllers/database_helper.dart';
import '../models/ruta_model.dart';
import '../utils/app_theme.dart';

class ReportView extends StatefulWidget {
  const ReportView({super.key});

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  final DatabaseHelper _db = DatabaseHelper();
  final TextEditingController _descripcionCtrl = TextEditingController();

  TipoReporte? _tipoSeleccionado;
  bool _enviando = false;

  static const _tiposReporte = [
    _ReporteTipo(
      tipo: TipoReporte.bloqueo,
      label: 'Bloqueo',
      emoji: '🚧',
      color: AppTheme.rojoAlerta,
      descripcion: 'Marcha, protesta o bloqueo de calle',
    ),
    _ReporteTipo(
      tipo: TipoReporte.desvio,
      label: 'Desvío',
      emoji: '↪️',
      color: AppTheme.naranjaDesvio,
      descripcion: 'El minibús está cambiando de ruta',
    ),
    _ReporteTipo(
      tipo: TipoReporte.rutaModificada,
      label: 'Ruta Cambió',
      emoji: '🔄',
      color: AppTheme.azulSecundario,
      descripcion: 'La ruta fue modificada definitivamente',
    ),
    _ReporteTipo(
      tipo: TipoReporte.feria,
      label: 'Feria',
      emoji: '🏪',
      color: AppTheme.verdeOk,
      descripcion: 'Feria o mercado bloqueando el paso',
    ),
  ];

  Future<void> _enviarReporte() async {
    if (_tipoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el tipo de incidente')),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      await _db.guardarReportePendiente({
        'id': const Uuid().v4(),
        'tipo': _tipoSeleccionado!.name,
        // TODO: obtener lat/lng del controlador de mapa
        'lat': -16.4955,
        'lng': -68.1337,
        'descripcion': _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
        'timestamp': DateTime.now().toIso8601String(),
        'ruta_afectada_id': null,
        'enviado': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reporte guardado. Se enviará cuando haya conexión.'),
            backgroundColor: AppTheme.verdeOk,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar Incidente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_border_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de contexto
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.amarilloAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_on, color: AppTheme.negro),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tu reporte ayudará a otros usuarios de la comunidad MiniBus Ya',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.negro,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              '¿Qué está pasando?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            // BENTO GRID de tipos de reporte
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: _tiposReporte.map((t) {
                final seleccionado = _tipoSeleccionado == t.tipo;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _tipoSeleccionado = t.tipo),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: seleccionado
                          ? t.color
                          : t.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: seleccionado
                            ? t.color
                            : t.color.withOpacity(0.3),
                        width: seleccionado ? 2.5 : 1,
                      ),
                      boxShadow: seleccionado
                          ? [
                              BoxShadow(
                                color: t.color.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          t.emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: seleccionado
                                ? Colors.white
                                : t.color,
                          ),
                        ),
                        Text(
                          t.descripcion,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: seleccionado
                                ? Colors.white70
                                : AppTheme.grisTexto,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Campo de descripción con soporte para voz
            TextField(
              controller: _descripcionCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Descripción adicional (opcional)...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.mic_outlined,
                      color: AppTheme.azulPrimario),
                  onPressed: () {/* TODO: speech_to_text */},
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // Mini mapa preview de ubicación
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.blancoFondo,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, color: AppTheme.rojoAlerta),
                    SizedBox(width: 8),
                    Text(
                      'Ubicación GPS capturada',
                      style: TextStyle(
                          color: AppTheme.grisTexto, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botón de envío
            ElevatedButton.icon(
              onPressed: _enviando ? null : _enviarReporte,
              icon: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_enviando ? 'Enviando...' : 'Enviar Reporte'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.rojoAlerta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReporteTipo {
  final TipoReporte tipo;
  final String label;
  final String emoji;
  final Color color;
  final String descripcion;

  const _ReporteTipo({
    required this.tipo,
    required this.label,
    required this.emoji,
    required this.color,
    required this.descripcion,
  });
}
