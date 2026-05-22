// lib/views/route_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../controllers/mapa_controller.dart';
import '../controllers/database_helper.dart';
import '../models/ruta_model.dart';
import '../utils/app_theme.dart';
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

      // ─── BOTÓN "SEGUIR RUTA" ─────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Modo navegación — próximamente'),
                ),
              );
            },
            icon: const Icon(Icons.navigation),
            label: const Text('Seguir Ruta'),
          ),
        ),
      ),
    );
  }

  // Mini mapa con la polilínea de la ruta
  Widget _buildMapaMiniatura(RutaModel ruta) {
    return FlutterMap(
      mapController: _mapaCtrl.mapController,
      options: MapOptions(
        initialCenter: ruta.coordenadas.isNotEmpty
            ? ruta.coordenadas[ruta.coordenadas.length ~/ 2]
            : const LatLng_placeholder(),
        initialZoom: 13.5,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none, // Mapa no interactivo (miniatura)
        ),
      ),
      children: [
        _mapaCtrl.getTileLayer(offline: false), // Online para la miniatura
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
      ],
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
