// lib/views/report_view.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/mapa_controller.dart';
import '../models/ruta_model.dart';
import '../utils/app_theme.dart';
import '../controllers/reporte_service.dart';
import '../utils/voice_search_helper.dart';

class ReportView extends StatefulWidget {
  final MapaController? mapaController;

  const ReportView({super.key, this.mapaController});

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  final TextEditingController _descripcionCtrl = TextEditingController();
  late MapaController _mapaCtrl;
  bool _createdOwnMapaCtrl = false;
  String? _fotoPath;

  TipoReporte? _tipoSeleccionado;
  bool _enviando = false;

  Future<void> _seleccionarFoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _fotoPath = pickedFile.path;
        });
      }
    } catch (e) {
      debugPrint('Error seleccionando imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

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

  @override
  void initState() {
    super.initState();
    if (widget.mapaController == null) {
      _mapaCtrl = MapaController();
      _createdOwnMapaCtrl = true;
    } else {
      _mapaCtrl = widget.mapaController!;
    }

    // Intentar obtener la ubicación automáticamente al entrar si no se tiene
    if (_mapaCtrl.ubicacionUsuario == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapaCtrl.obtenerUbicacion(context: context);
      });
    }
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    if (_createdOwnMapaCtrl) {
      _mapaCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _enviarReporte() async {
    if (_tipoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el tipo de incidente')),
      );
      return;
    }

    // ── Validar que la ubicación GPS esté activa y encontrada ──
    final ubicacion = _mapaCtrl.ubicacionUsuario;
    if (ubicacion == null) {
      // Mostrar diálogo informativo
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.location_off,
              size: 48, color: AppTheme.rojoAlerta),
          title: const Text('Ubicación no disponible'),
          content: const Text(
            'Para enviar un reporte necesitamos tu ubicación GPS.\n\n'
            'Activa el GPS de tu dispositivo y presiona "Obtener ubicación" '
            'para continuar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _mapaCtrl.obtenerUbicacion(context: context);
              },
              icon: const Icon(Icons.my_location),
              label: const Text('Obtener ubicación'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final enviado = await ReporteService().enviarReporte(
        tipo: _tipoSeleccionado!,
        lat: ubicacion.latitude,
        lng: ubicacion.longitude,
        descripcion: _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
        fotoPath: _fotoPath,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enviado
                  ? '✅ Reporte enviado a la comunidad y guardado localmente'
                  : '📴 Sin internet — reporte guardado en tu dispositivo, se enviará cuando tengas conexión',
            ),
            backgroundColor:
                enviado ? AppTheme.verdeOk : AppTheme.naranjaDesvio,
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
                  onTap: () => setState(() => _tipoSeleccionado = t.tipo),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: seleccionado ? t.color : t.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            seleccionado ? t.color : t.color.withOpacity(0.3),
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
                            color: seleccionado ? Colors.white : t.color,
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
                  onPressed: () {
                    VoiceSearchHelper.escucharVoz(
                      context,
                      onResult: (texto) {
                        _descripcionCtrl.text = texto;
                      },
                    );
                  },
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

            const Text(
              'Agregar Foto del Incidente',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),

            _fotoPath == null
                ? Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _seleccionarFoto(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Tomar Foto'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.azulPrimario,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _seleccionarFoto(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galería'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.azulPrimario,
                            side: const BorderSide(color: AppTheme.azulPrimario),
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(File(_fotoPath!)),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: 8,
                          top: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.white),
                              onPressed: () => setState(() => _fotoPath = null),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

            const SizedBox(height: 16),

            // Mini mapa preview de ubicación
            AnimatedBuilder(
              animation: _mapaCtrl,
              builder: (context, _) {
                final ubicacion = _mapaCtrl.ubicacionUsuario;
                final cargando = _mapaCtrl.cargandoUbicacion;
                final error = _mapaCtrl.errorUbicacion;

                return Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.blancoFondo,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ubicacion != null
                          ? AppTheme.verdeOk.withOpacity(0.5)
                          : (error != null ? AppTheme.rojoAlerta.withOpacity(0.5) : Colors.grey[300]!),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (cargando) ...[
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.azulPrimario),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Buscando señal GPS...',
                              style: TextStyle(color: AppTheme.grisTexto, fontSize: 13),
                            ),
                          ] else if (ubicacion != null) ...[
                            const Icon(Icons.check_circle, color: AppTheme.verdeOk, size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ubicación GPS capturada',
                                    style: TextStyle(
                                      color: AppTheme.verdeOk,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Lat: ${ubicacion.latitude.toStringAsFixed(5)}, Lng: ${ubicacion.longitude.toStringAsFixed(5)}',
                                    style: const TextStyle(
                                      color: AppTheme.grisTexto,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const Icon(Icons.location_off, color: AppTheme.rojoAlerta, size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    error ?? 'Ubicación GPS no obtenida',
                                    style: const TextStyle(
                                      color: AppTheme.rojoAlerta,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Text(
                                    'Activa tu GPS para enviar el reporte',
                                    style: TextStyle(
                                      color: AppTheme.grisTexto,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.my_location, color: AppTheme.azulPrimario),
                              tooltip: 'Buscar ubicación',
                              onPressed: () => _mapaCtrl.obtenerUbicacion(context: context),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
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
