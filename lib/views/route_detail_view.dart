// lib/views/route_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../controllers/mapa_controller.dart';
import '../controllers/database_helper.dart';
import '../controllers/osrm_service.dart';
import '../models/ruta_model.dart';
import '../utils/app_theme.dart';
import '../utils/distancia_helper.dart';
import '../widgets/letrero_widget.dart';

import 'package:latlong2/latlong.dart' show LatLng;

class RouteDetailView extends StatefulWidget {
  final RutaModel ruta;

  const RouteDetailView({super.key, required this.ruta});

  @override
  State<RouteDetailView> createState() => _RouteDetailViewState();
}

class _RouteDetailViewState extends State<RouteDetailView> {
  final MapaController _mapaCtrl = MapaController();
  final DatabaseHelper _db = DatabaseHelper();
  bool _esFavorito = false;

  // ─── NAVEGACIÓN INLINE ───────────────────────────────────────────────────
  bool _cargandoNav = false;
  List<LatLng> _puntosAPie = [];
  PuntoDestino? _puntoDestino;

  @override
  void initState() {
    super.initState();
    _db.esFavorito(widget.ruta.id).then((v) {
      if (mounted) setState(() => _esFavorito = v);
    });
    // Centra el mapa en la ruta al cargar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapaCtrl.centrarEnRuta(widget.ruta.coordenadas);
    });
  }

  @override
  void dispose() {
    _mapaCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarNavegacionInline() async {
    // 1. Obtener ubicación del usuario
    if (_mapaCtrl.ubicacionUsuario == null) {
      await _mapaCtrl.obtenerUbicacion(context: context);
    }
    final usuario = _mapaCtrl.ubicacionUsuario;
    if (usuario == null || !mounted) return;

    setState(() {
      _cargandoNav = true;
      _puntosAPie = [];
      _puntoDestino = null;
    });

    // 2. Calcular punto destino (polilínea o parada si es teleférico)
    final destino = calcularPuntoDestino(usuario: usuario, ruta: widget.ruta);

    // 3. Llamar a OSRM
    final puntos = await OsrmService.rutaAPie(
      origen: usuario,
      destino: destino.punto,
    );

    if (!mounted) return;

    setState(() {
      _puntoDestino = destino;
      _puntosAPie = puntos ?? [usuario, destino.punto]; // fallback línea recta
      _cargandoNav = false;
    });

    // 4. Centrar mapa para ver usuario + destino
    _mapaCtrl.mapController.move(usuario, 15.0);

    if (puntos == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Sin conexión: mostrando dirección directa'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _toggleFavorito() async {
    if (_esFavorito) {
      await _db.eliminarFavorito(widget.ruta.id);
    } else {
      await _db.guardarFavorito({
        'id': widget.ruta.id,
        'sindicato': widget.ruta.sindicato,
        'numero_linea': widget.ruta.numeroLinea,
        'origen': widget.ruta.origen,
        'destino': widget.ruta.destino,
        'color_hex': widget.ruta.colorHex,
      });
    }
    setState(() => _esFavorito = !_esFavorito);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_esFavorito
            ? 'Ruta guardada en favoritos'
            : 'Ruta eliminada de favoritos'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ruta = widget.ruta;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── APP BAR con mapa miniatura ────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppTheme.azulPrimario,
            actions: [
              IconButton(
                icon: Icon(
                  _esFavorito ? Icons.star : Icons.star_border_outlined,
                  color: AppTheme.amarilloAccent,
                ),
                onPressed: _toggleFavorito,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildMapaMiniatura(ruta),
            ),
            // Banner amarillo que identifica la ruta actual
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(32),
              child: Container(
                color: AppTheme.amarilloAccent,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                child: Text(
                  'RUTA ACTUAL  •  ${ruta.sindicato.toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppTheme.negro,
                  ),
                ),
              ),
            ),
          ),

          // ─── CONTENIDO ────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Letrero + info básica
                _buildHeaderInfo(ruta),
                const SizedBox(height: 16),

                // Tarifas
                _buildTarifasCard(ruta),
                const SizedBox(height: 16),

                // Horarios
                _buildHorariosCard(ruta),
                const SizedBox(height: 16),

                // Paradas (stepper)
                _buildParadasStepper(ruta),
                const SizedBox(height: 80), // Espacio para el botón
              ]),
            ),
          ),
        ],
      ),

      // ─── BOTÓN "CÓMO LLEGAR" ─────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Panel de navegación cuando está activo
            if (_puntoDestino != null) _buildNavPanel(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ElevatedButton.icon(
                onPressed: _cargandoNav ? null : _iniciarNavegacionInline,
                icon: _cargandoNav
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.directions_walk),
                label: Text(
                  _cargandoNav
                      ? 'Calculando ruta…'
                      : (_puntoDestino != null
                          ? 'Recalcular ruta'
                          : 'Cómo llegar a esta línea'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavPanel() {
    final d = _puntoDestino!;
    final usuario = _mapaCtrl.ubicacionUsuario;
    final dist = usuario != null
        ? distanciaMetros(usuario, d.punto)
        : d.distanciaM;
    return Container(
      color: Colors.blue.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            d.esParadaOficial ? Icons.tram : Icons.directions_walk,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatearDistancia(dist),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                Text(
                  d.nombre,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white60),
            onPressed: () => setState(() {
              _puntoDestino = null;
              _puntosAPie = [];
            }),
          ),
        ],
      ),
    );
  }

  // Mini mapa con la polilínea de la ruta
  Widget _buildMapaMiniatura(RutaModel ruta) {
    return AnimatedBuilder(
      animation: _mapaCtrl,
      builder: (_, __) => FlutterMap(
        mapController: _mapaCtrl.mapController,
        options: MapOptions(
          initialCenter: ruta.coordenadas.isNotEmpty
              ? ruta.coordenadas[ruta.coordenadas.length ~/ 2]
              : const LatLng_placeholder(),
          initialZoom: 13.5,
          interactionOptions: InteractionOptions(
            // Interactivo solo cuando hay navegación activa
            flags: _puntosAPie.isNotEmpty
                ? InteractiveFlag.all
                : InteractiveFlag.none,
          ),
        ),
        children: [
          _mapaCtrl.getTileLayer(offline: false),
          // Polilínea de la ruta
          PolylineLayer(
            polylines: [
              Polyline(
                points: ruta.coordenadas,
                color: AppTheme.amarilloAccent,
                strokeWidth: 4,
                borderColor: AppTheme.azulPrimario,
                borderStrokeWidth: 1,
              ),
            ],
          ),
          // Polilínea de caminata (OSRM)
          if (_puntosAPie.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _puntosAPie,
                  color: Colors.white.withValues(alpha: 0.8),
                  strokeWidth: 5.0,
                ),
                Polyline(
                  points: _puntosAPie,
                  color: Colors.blue,
                  strokeWidth: 3.0,
                ),
              ],
            ),
          // Marcador destino
          if (_puntoDestino != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _puntoDestino!.punto,
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                        Icons.directions_walk, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          // Marcador usuario
          if (_mapaCtrl.ubicacionUsuario != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _mapaCtrl.ubicacionUsuario!,
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(RutaModel ruta) {
    return Row(
      children: [
        LetreroWidget(
          numeroLinea: ruta.numeroLinea,
          destino: ruta.destino,
          colorHex: ruta.colorHex,
          colorTextoHex: ruta.colorTextoHex,
          width: 110,
          height: 58,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ruta.sindicato,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: AppTheme.verdeOk),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(ruta.origen,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 8, color: AppTheme.rojoAlerta),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(ruta.destino,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: ruta.tiposVehiculo
                    .map(
                      (t) => Chip(
                        label: Text(t,
                            style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        backgroundColor:
                            AppTheme.azulPrimario.withOpacity(0.1),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTarifasCard(RutaModel ruta) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tarifas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Divider(),
            _tarifaRow('Normal', ruta.tarifaNormal, AppTheme.azulPrimario),
            _tarifaRow(
                'Estudiante', ruta.tarifaEstudiantil, AppTheme.verdeOk),
            _tarifaRow('Nocturna', ruta.tarifaNocturna, AppTheme.naranjaDesvio),
          ],
        ),
      ),
    );
  }

  Widget _tarifaRow(String label, double monto, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Bs. ${monto.toStringAsFixed(1)}',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorariosCard(RutaModel ruta) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.access_time, color: AppTheme.azulPrimario),
        title: const Text('Horario de servicio'),
        subtitle: Text('${ruta.horarioInicio} — ${ruta.horarioFin}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.verdeOk.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'En servicio',
            style: TextStyle(
                color: AppTheme.verdeOk,
                fontWeight: FontWeight.bold,
                fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildParadasStepper(RutaModel ruta) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ruta.paradas.length} Paradas',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Divider(),
            ...ruta.paradas.asMap().entries.map((entry) {
              final i = entry.key;
              final parada = entry.value;
              final esUltima = i == ruta.paradas.length - 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Línea de tiempo vertical
                    SizedBox(
                      width: 24,
                      child: Column(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: parada.esTerminal
                                  ? hexToColor(ruta.colorHex)
                                  : Colors.grey[400],
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                          ),
                          if (!esUltima)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: Colors.grey[300],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          parada.nombre,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: parada.esTerminal
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: parada.esTerminal
                                ? AppTheme.negro
                                : AppTheme.grisTexto,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// Placeholder temporal — Flutter requiere LatLng válido
// ignore: camel_case_types
class LatLng_placeholder extends LatLng {
  const LatLng_placeholder() : super(-16.4955, -68.1337);
}
