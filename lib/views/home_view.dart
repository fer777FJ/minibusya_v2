// lib/views/home_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/mapa_controller.dart';
import '../controllers/rutas_controller.dart';
import '../models/ruta_model.dart';
import '../utils/app_theme.dart';
import '../widgets/letrero_widget.dart';
import 'search_results_view.dart';
import 'report_view.dart';
import 'reportes_historial_view.dart';
import 'reportes_comunitarios_view.dart';
import 'favoritos_view.dart';
import 'historial_view.dart';
import 'configuracion_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final MapaController _mapaCtrl = MapaController();
  final RutasController _rutasCtrl = RutasController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<RutaModel> _rutasVisibles = [];
  RutaModel? _rutaSeleccionada;
  bool _mostrarOffline =
      false; // ← false = OSM online, true = tiles offline (MOBAC)

  // ─── FILTROS DE TIPO DE VEHÍCULO ──────────────────────────────────────
  Set<String> _tiposDisponibles = {}; // Tipos que existen en las rutas
  Set<String> _tiposSeleccionados = {'Minibus'}; // Por defecto, Minibus activo

  @override
  void initState() {
    super.initState();
    _cargarRutasYFiltros();
    _mapaCtrl.obtenerUbicacion();
  }

  Future<void> _cargarRutasYFiltros() async {
    // Cargar tipos disponibles
    final tipos = await _rutasCtrl.obtenerTiposDisponibles();
    setState(() => _tiposDisponibles = tipos);

    // Cargar rutas filtradas
    await _aplicarFiltros();
  }

  Future<void> _aplicarFiltros() async {
    final rutas = await _rutasCtrl.filtrarPorTipo(_tiposSeleccionados.toList());
    if (mounted) setState(() => _rutasVisibles = rutas);
  }

  void _onSearchSubmit(String texto) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsView(
          busquedaInicial: texto,
          ubicacionUsuario: _mapaCtrl.ubicacionUsuario,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // ─── MAPA PRINCIPAL ───────────────────────────────────────────────
          // Envuelto en AnimatedBuilder para que se reconstruya cuando cambia la ubicación
          AnimatedBuilder(
            animation: _mapaCtrl,
            builder: (_, __) => _buildMapa(),
          ),

          // ─── BARRA DE BÚSQUEDA FLOTANTE (parte superior) ─────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: _buildSearchBar(),
          ),

          // ─── BOTÓN DE UBICACIÓN ───────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 140,
            child: _buildBotonUbicacion(),
          ),

          // ─── BOTTOM SHEET DE FILTROS ──────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomSheet(),
          ),

          // ─── PANEL DE RUTA SELECCIONADA ───────────────────────────────────
          if (_rutaSeleccionada != null)
            Positioned(
              bottom: 120,
              left: 12,
              right: 12,
              child: _buildRutaSeleccionadaCard(),
            ),
        ],
      ),

      // FAB amarillo para reportar
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReportView(mapaController: _mapaCtrl)),
        ),
        tooltip: 'Reportar incidente',
        child: const Icon(Icons.warning_amber_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ─── MAPA con flutter_map ─────────────────────────────────────────────────

  Widget _buildMapa() {
    return FlutterMap(
      mapController: _mapaCtrl.mapController,
      options: MapOptions(
        initialCenter: const LatLng(-16.4955, -68.1337),
        initialZoom: 14.0,
        minZoom: 12.0,
        maxZoom: 18.0,
        onTap: (_, __) => setState(() => _rutaSeleccionada = null),
      ),
      children: [
        // 1️⃣  Tiles del mapa (offline o OSM online)
        _mapaCtrl.getTileLayer(
            offline:
                _mostrarOffline), // true = MOBAC offline, false = OSM online

        // 2️⃣  Polilíneas de TODAS las rutas (tenue)
        PolylineLayer(
          polylines: _rutasVisibles.map((ruta) {
            return Polyline(
              points: ruta.coordenadas,
              color: AppTheme.azulSecundario.withOpacity(0.3),
              strokeWidth: 2.5,
            );
          }).toList(),
        ),

        // 3️⃣  Polilínea destacada de la ruta seleccionada
        if (_rutaSeleccionada != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _rutaSeleccionada!.coordenadas,
                color: AppTheme.amarilloAccent,
                strokeWidth: 5.0,
                borderColor: AppTheme.negro.withOpacity(0.5),
                borderStrokeWidth: 1.0,
              ),
            ],
          ),

        // 4️⃣  Marcadores de paradas
        MarkerLayer(
          markers: _buildMarcadoresParadas(),
        ),

        // 5️⃣  Marcador de la ubicación del usuario
        if (_mapaCtrl.ubicacionUsuario != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _mapaCtrl.ubicacionUsuario!,
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  List<Marker> _buildMarcadoresParadas() {
    final rutasMostrar =
        _rutaSeleccionada != null ? [_rutaSeleccionada!] : _rutasVisibles;

    final markers = <Marker>[];
    for (final ruta in rutasMostrar) {
      for (final parada in ruta.paradas) {
        markers.add(
          Marker(
            point: parada.latLng,
            width: parada.esTerminal ? 36 : 16,
            height: parada.esTerminal ? 36 : 16,
            child: GestureDetector(
              onTap: () => _mostrarInfoParada(parada, ruta),
              child: parada.esTerminal
                  ? LetreroMiniWidget(
                      numeroLinea: ruta.numeroLinea,
                      colorHex: ruta.colorHex,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hexToColor(ruta.colorHex),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
            ),
          ),
        );
      }
    }
    return markers;
  }

  void _mostrarInfoParada(ParadaModel parada, RutaModel ruta) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LetreroWidget(
                  numeroLinea: ruta.numeroLinea,
                  destino: ruta.destino,
                  colorHex: ruta.colorHex,
                  colorTextoHex: ruta.colorTextoHex,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parada.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        ruta.sindicato,
                        style: const TextStyle(
                          color: AppTheme.grisTexto,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _rutaSeleccionada = ruta);
                _mapaCtrl.centrarEnRuta(ruta.coordenadas);
              },
              icon: const Icon(Icons.route),
              label: const Text('Ver ruta completa'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SEARCH BAR ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: TextField(
        controller: _searchCtrl,
        onSubmitted: _onSearchSubmit,
        decoration: InputDecoration(
          hintText: '¿A dónde vas?',
          hintStyle: const TextStyle(color: AppTheme.grisTexto),
          prefixIcon: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.mic_outlined),
                onPressed: () {/* TODO: integrar speech_to_text */},
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _onSearchSubmit(_searchCtrl.text),
              ),
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  // ─── BOTÓN DE UBICACIÓN ───────────────────────────────────────────────────

  Widget _buildBotonUbicacion() {
    return AnimatedBuilder(
      animation: _mapaCtrl,
      builder: (_, __) {
        final cargando = _mapaCtrl.cargandoUbicacion;
        final conUbicacion = _mapaCtrl.ubicacionUsuario != null;
        
        return FloatingActionButton.small(
          heroTag: 'ubicacion',
          backgroundColor: Colors.white,
          foregroundColor: conUbicacion ? AppTheme.verdeOk : AppTheme.azulPrimario,
          onPressed: cargando ? null : _mapaCtrl.obtenerUbicacion,
          // Efecto visual: sombra más pronunciada cuando tiene ubicación
          elevation: conUbicacion ? 8 : 2,
          child: cargando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.azulPrimario),
                  ),
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulse background cuando tiene ubicación
                    if (conUbicacion)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.verdeOk.withOpacity(0.2),
                          ),
                        ),
                      ),
                    Icon(
                      conUbicacion ? Icons.location_on : Icons.my_location,
                      size: conUbicacion ? 20 : 22,
                    ),
                  ],
                ),
        );
      },
    );
  }

  // ─── BOTTOM SHEET ─────────────────────────────────────────────────────────

  Widget _buildBottomSheet() {
    return Container(
      height: 100,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildFiltroChipInteractivo('Minibus', Icons.directions_bus),
                _buildFiltroChipInteractivo('Trufi', Icons.local_taxi),
                _buildFiltroChipInteractivo('Micro', Icons.directions_bus_filled),
                _buildFiltroChipInteractivo('PumaKatari', Icons.directions_bus_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChipInteractivo(String label, IconData icon) {
    final seleccionado = _tiposSeleccionados.contains(label);
    // Solo mostrar si el tipo está disponible en las rutas
    final disponible = _tiposDisponibles.contains(label);

    if (!disponible) {
      return const SizedBox.shrink(); // No mostrar si no hay rutas
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (seleccionado) {
            _tiposSeleccionados.remove(label);
          } else {
            _tiposSeleccionados.add(label);
          }
        });
        _aplicarFiltros();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: seleccionado ? AppTheme.azulPrimario : AppTheme.blancoFondo,
              boxShadow: seleccionado
                  ? [
                      BoxShadow(
                        color: AppTheme.azulPrimario.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: seleccionado ? Colors.white : AppTheme.grisTexto,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: seleccionado ? AppTheme.azulPrimario : AppTheme.grisTexto,
              fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (_tiposSeleccionados.isEmpty)
            Text(
              '(sin filtro)',
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String label, IconData icon, bool activo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor:
              activo ? AppTheme.azulPrimario : AppTheme.blancoFondo,
          child: Icon(
            icon,
            color: activo ? Colors.white : AppTheme.grisTexto,
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: activo ? AppTheme.azulPrimario : AppTheme.grisTexto,
            fontWeight: activo ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ─── CARD DE RUTA SELECCIONADA ────────────────────────────────────────────

  Widget _buildRutaSeleccionadaCard() {
    final ruta = _rutaSeleccionada!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            LetreroWidget(
              numeroLinea: ruta.numeroLinea,
              destino: ruta.destino,
              colorHex: ruta.colorHex,
              colorTextoHex: ruta.colorTextoHex,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ruta.sindicato,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${ruta.origen} → ${ruta.destino}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.grisTexto),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Bs. ${ruta.tarifaNormal.toStringAsFixed(1)} normal  •  '
                    'Bs. ${ruta.tarifaEstudiantil.toStringAsFixed(1)} estudiante',
                    style:
                        const TextStyle(fontSize: 11, color: AppTheme.azulPrimario),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _rutaSeleccionada = null),
            ),
          ],
        ),
      ),
    );
  }

  // ─── DRAWER ───────────────────────────────────────────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: AppTheme.azulPrimario),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.directions_bus, color: Colors.white, size: 40),
                SizedBox(height: 8),
                Text(
                  'MiniBus Ya',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  'La Paz · El Alto · Bolivia',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Inicio'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Rutas Favoritas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const FavoritosView()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historial'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HistorialView()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.warning_outlined),
            title: const Text('Mis Reportes'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReportesHistorialView()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('Reportes de la Comunidad'),
            subtitle: const Text('Reportes activos en tiempo real', style: TextStyle(fontSize: 11)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReportesComunitariosView()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Configuración'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ConfiguracionView()));
            },
          ),
          ListTile(
            leading: Icon(
              _mostrarOffline ? Icons.wifi_off : Icons.wifi,
              color: _mostrarOffline ? AppTheme.rojoAlerta : AppTheme.verdeOk,
            ),
            title: Text(_mostrarOffline ? 'Modo Offline' : 'Modo Online'),
            subtitle: Text(
              _mostrarOffline ? 'Tiles locales (MOBAC)' : 'OpenStreetMap',
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () => setState(() => _mostrarOffline = !_mostrarOffline),
          ),
        ],
      ),
    );
  }
}
