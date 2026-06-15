// lib/views/home_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/mapa_controller.dart';
import '../controllers/rutas_controller.dart';
import '../controllers/osrm_service.dart';
import '../models/ruta_model.dart';
import '../utils/app_theme.dart';
import '../utils/distancia_helper.dart';
import '../widgets/letrero_widget.dart';
import 'search_results_view.dart';
import 'report_view.dart';
import 'reportes_historial_view.dart';
import 'reportes_comunitarios_view.dart';
import 'favoritos_view.dart';
import 'historial_view.dart';
import 'configuracion_view.dart';
import 'chatbot_view.dart';
import '../utils/voice_search_helper.dart';

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

  // ─── NAVEGACIÓN ────────────────────────────────────────────────────────
  bool _modoNavegacion = false;
  bool _cargandoRutaAPie = false;
  List<LatLng> _puntosRutaAPie = [];
  PuntoDestino? _puntoDestino;

  // Última posición usada para calcular la ruta a pie (para detectar cambios)
  LatLng? _ultimaPosicionRuta;

  // ─── FILTROS DE TIPO DE VEHÍCULO ──────────────────────────────────────
  Set<String> _tiposDisponibles = {}; // Tipos que existen en las rutas
  Set<String> _tiposSeleccionados = {'Minibus'}; // Por defecto, Minibus activo

  @override
  void initState() {
    super.initState();
    _cargarRutasYFiltros();
    _mapaCtrl.obtenerUbicacion();
    // Escuchar cambios de ubicación para recalcular la ruta a pie en tiempo real
    _mapaCtrl.addListener(_onUbicacionCambiada);
  }

  @override
  void dispose() {
    _mapaCtrl.removeListener(_onUbicacionCambiada);
    _mapaCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Se llama cada vez que el MapaController notifica un cambio (incl. GPS).
  /// Si estamos en modo navegación y el usuario se movió más de 10 m,
  /// recalcula la ruta a pie automáticamente.
  void _onUbicacionCambiada() {
    if (!_modoNavegacion) return;
    if (_cargandoRutaAPie) return;
    final nuevaPos = _mapaCtrl.ubicacionUsuario;
    if (nuevaPos == null || _puntoDestino == null) return;

    // Solo recalcular si el usuario se movió más de 10 metros
    if (_ultimaPosicionRuta != null) {
      final delta = distanciaMetros(_ultimaPosicionRuta!, nuevaPos);
      if (delta < 10) return;
    }

    _recalcularRutaAPie(nuevaPos);
  }

  /// Recalcula la ruta a pie desde la posición actual hasta el destino.
  Future<void> _recalcularRutaAPie(LatLng origen) async {
    if (_puntoDestino == null) return;
    _ultimaPosicionRuta = origen;
    setState(() => _cargandoRutaAPie = true);

    final puntos = await OsrmService.rutaAPie(
      origen: origen,
      destino: _puntoDestino!.punto,
    );

    if (!mounted) return;
    setState(() {
      if (puntos != null && puntos.isNotEmpty) {
        _puntosRutaAPie = puntos;
      } else {
        // Fallback: línea recta si OSRM falla
        _puntosRutaAPie = [origen, _puntoDestino!.punto];
      }
      _cargandoRutaAPie = false;
    });
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

  // ─── NAVEGACIÓN: calcular destino y pedir ruta OSRM ───────────────────

  Future<void> _iniciarNavegacion() async {
    final usuario = _mapaCtrl.ubicacionUsuario;
    final ruta = _rutaSeleccionada;

    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activa tu ubicación primero 📍')),
      );
      return;
    }
    if (ruta == null) return;

    if (_mostrarOffline) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.signal_wifi_statusbar_connected_no_internet_4, color: Colors.orange),
              SizedBox(width: 8),
              Text('Precisión de calles'),
            ],
          ),
          content: const Text(
            'Para mayor precisión en calles, conéctese a una red.\n\n'
            'Tu ubicación GPS funciona de todas formas, pero la ruta '
            'seguirá calles reales solo con conexión a internet (OSRM).\n\n'
            '¿Deseas activar el modo online para trazar la ruta por calles?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar sin red'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.wifi),
              label: const Text('Activar Online'),
              onPressed: () {
                setState(() => _mostrarOffline = false);
                Navigator.pop(ctx, true);
              },
            ),
          ],
        ),
      );
      if (continuar != true) return;
    }

    final destino = calcularPuntoDestino(usuario: usuario, ruta: ruta);

    setState(() {
      _cargandoRutaAPie = true;
      _puntoDestino = destino;
      _puntosRutaAPie = [];
    });

    final puntos = await OsrmService.rutaAPie(
      origen: usuario,
      destino: destino.punto,
    );

    if (!mounted) return;

    if (puntos == null || puntos.isEmpty) {
      setState(() {
        _puntosRutaAPie = [usuario, destino.punto];
        _cargandoRutaAPie = false;
        _modoNavegacion = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ No se pudo calcular ruta exacta, mostrando dirección directa'),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      setState(() {
        _puntosRutaAPie = puntos;
        _cargandoRutaAPie = false;
        _modoNavegacion = true;
      });
    }

    _mapaCtrl.mapController.move(usuario, 15.5);
  }

  void _cancelarNavegacion() {
    setState(() {
      _modoNavegacion = false;
      _puntosRutaAPie = [];
      _puntoDestino = null;
      _cargandoRutaAPie = false;
      _ultimaPosicionRuta = null;
    });
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

          // ─── BOTTOM SHEET DE FILTROS ──────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomSheet(),
          ),

          // ─── PANEL DE RUTA SELECCIONADA ───────────────────────────────────────────────
          if (_rutaSeleccionada != null && !_modoNavegacion)
            Positioned(
              bottom: 120,
              left: 12,
              right: 12,
              child: _buildRutaSeleccionadaCard(),
            ),

          // ─── PANEL DE NAVEGACIÓN ACTIVA ───────────────────────────────────────────────
          if (_modoNavegacion && _puntoDestino != null)
            Positioned(
              bottom: 110,
              left: 12,
              right: 12,
              child: AnimatedBuilder(
                animation: _mapaCtrl,
                builder: (_, __) => _buildPanelNavegacion(),
              ),
            ),

          // ─── FAB CHATBOT (IZQUIERDA) ──────────────────────────────────────
          Positioned(
            bottom: 100,
            left: 12,
            child: FloatingActionButton(
              heroTag: 'chatbot',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatbotView(offlineMode: _mostrarOffline),
                ),
              ),
              backgroundColor: Theme.of(context).primaryColor,
              tooltip: 'Asistente de rutas',
              child: const Icon(Icons.chat_outlined, color: Colors.white),
            ),
          ),
        ],
      ),

      // FAB para ubicación y reporte (DERECHA)
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Botón ubicación
          _buildBotonUbicacion(),
          const SizedBox(height: 12),
          // Botón reporte
          FloatingActionButton(
            heroTag: 'reporte',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ReportView(mapaController: _mapaCtrl)),
            ),
            tooltip: 'Reportar incidente',
            child: const Icon(Icons.warning_amber_rounded),
          ),
        ],
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
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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

        // 5️⃣  Polilínea de caminata (OSRM, azul con borde blanco)
        if (_puntosRutaAPie.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _puntosRutaAPie,
                color: Colors.white.withValues(alpha: 0.8),
                strokeWidth: 6.0,
              ),
              Polyline(
                points: _puntosRutaAPie,
                color: Colors.blue,
                strokeWidth: 3.5,
              ),
            ],
          ),

        // 6️⃣  Marcador del punto destino de navegación
        if (_puntoDestino != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _puntoDestino!.punto,
                width: 44,
                height: 44,
                child: _buildMarcadorDestino(),
              ),
            ],
          ),

        // 7️⃣  Marcador de la ubicación del usuario
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

  Widget _buildMarcadorDestino() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.5),
            blurRadius: 12,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(Icons.directions_walk, color: Colors.white, size: 22),
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
            width: parada.esTerminal ? 64 : 16,
            height: parada.esTerminal ? 30 : 16,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
      child: TextField(
        controller: _searchCtrl,
        onSubmitted: _onSearchSubmit,
        style: TextStyle(color: isDark ? Colors.white : AppTheme.negro),
        decoration: InputDecoration(
          hintText: '¿A dónde vas?',
          hintStyle: const TextStyle(color: AppTheme.grisTexto),
          prefixIcon: Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.menu, color: isDark ? Colors.white70 : Colors.black87),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.mic_outlined, color: isDark ? Colors.white70 : Colors.black87),
                onPressed: () {
                  VoiceSearchHelper.escucharVoz(
                    context,
                    onResult: (texto) {
                      _searchCtrl.text = texto;
                      _onSearchSubmit(texto);
                    },
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.search, color: isDark ? Colors.white70 : Colors.black87),
                onPressed: () => _onSearchSubmit(_searchCtrl.text),
              ),
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
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

        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return FloatingActionButton.small(
          heroTag: 'ubicacion',
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: conUbicacion
              ? AppTheme.verdeOk
              : (isDarkMode ? Colors.white : Theme.of(context).primaryColor),
          onPressed: cargando
              ? null
              : () => _mapaCtrl.obtenerUbicacion(context: context),
          // Efecto visual: sombra más pronunciada cuando tiene ubicación
          elevation: conUbicacion ? 8 : 2,
          child: cargando
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).primaryColor : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white54 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildFiltroChipInteractivo('Minibus', '🚐'),
                _buildFiltroChipInteractivo('Trufi', '🚗'),
                _buildFiltroChipInteractivo('Micro', '🚌'),
                _buildFiltroChipInteractivo('Teleferico', '🚡'),
                _buildFiltroChipInteractivo('PumaKatari', '🚍'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChipInteractivo(String label, String emoji) {
    final seleccionado = _tiposSeleccionados.contains(label);
    final disponible = _tiposDisponibles.contains(label);

    if (!disponible) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color chipBgColor;
    Color chipBorderColor;
    Color textColor;
    List<BoxShadow>? shadow;

    if (isDark) {
      chipBgColor = seleccionado 
          ? Colors.white 
          : Colors.white.withOpacity(0.2);
      chipBorderColor = seleccionado ? Colors.white : Colors.transparent;
      textColor = seleccionado ? Colors.white : Colors.white70;
      shadow = seleccionado
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                spreadRadius: 1,
              )
            ]
          : null;
    } else {
      chipBgColor = seleccionado 
          ? Theme.of(context).primaryColor.withOpacity(0.15) 
          : AppTheme.blancoFondo;
      chipBorderColor = seleccionado ? Theme.of(context).primaryColor : Colors.transparent;
      textColor = seleccionado ? Theme.of(context).primaryColor : AppTheme.grisTexto;
      shadow = seleccionado
          ? [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 1,
              )
            ]
          : null;
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: chipBgColor,
              border: Border.all(
                color: chipBorderColor,
                width: 2,
              ),
              boxShadow: shadow,
            ),
            child: Text(
              emoji,
              style: const TextStyle(
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ─── CARD DE RUTA SELECCIONADA ────────────────────────────────────────────

  Widget _buildRutaSeleccionadaCard() {
    final ruta = _rutaSeleccionada!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                      Text(ruta.sindicato,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${ruta.origen} → ${ruta.destino}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.grisTexto),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Bs. ${ruta.tarifaNormal.toStringAsFixed(1)} normal  •  '
                        'Bs. ${ruta.tarifaEstudiantil.toStringAsFixed(1)} estudiante',
                        style: TextStyle(
                            fontSize: 11, color: Theme.of(context).primaryColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() => _rutaSeleccionada = null);
                    _cancelarNavegacion();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _cargandoRutaAPie ? null : _iniciarNavegacion,
                icon: _cargandoRutaAPie
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.directions_walk),
                label: Text(
                  _cargandoRutaAPie
                      ? 'Calculando ruta…'
                      : '🧭 Cómo llegar a la línea',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PANEL DE NAVEGACIÓN ACTIVA ──────────────────────────────────────────

  Widget _buildPanelNavegacion() {
    final destino = _puntoDestino!;
    final ruta = _rutaSeleccionada!;
    final usuario = _mapaCtrl.ubicacionUsuario;
    final distActual = usuario != null
        ? distanciaMetros(usuario, destino.punto)
        : destino.distanciaM;

    return Card(
      color: Colors.blue.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              children: [
                const Icon(Icons.navigation, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'NAVEGANDO A PIE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _cancelarNavegacion,
                  child: const Icon(Icons.close, color: Colors.white70, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Distancia grande
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatearDistancia(distActual),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'caminando',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Destino
            Row(
              children: [
                Icon(
                  destino.esParadaOficial ? Icons.tram : Icons.directions_bus,
                  color: Colors.blue.shade200,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    destino.nombre,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.route, color: Colors.white38, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Línea ${ruta.numeroLinea} — ${ruta.destino}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Nota informativa
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 13, color: Colors.white60),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      destino.esParadaOficial
                          ? 'Dirígete a la estación de teleférico'
                          : 'Dirígete al punto del recorrido del transporte',
                      style: const TextStyle(color: Colors.white60, fontSize: 10),
                    ),
                  ),
                ],
              ),
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
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Theme.of(context).colorScheme.surface 
                  : Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  'MiniBus Ya',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  'La Paz · El Alto · Bolivia',
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white70 
                          : Colors.white70, 
                      fontSize: 13),
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
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReportesHistorialView()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('Reportes de la Comunidad'),
            subtitle: const Text('Reportes activos en tiempo real',
                style: TextStyle(fontSize: 11)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReportesComunitariosView()));
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
          ListTile(
            leading: Icon(
              Icons.chat_outlined,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : AppTheme.azulPrimario,
            ),
            title: const Text('Asistente MiniBus Bot'),
            subtitle: const Text('Pregunta cómo llegar a tu destino'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatbotView(offlineMode: _mostrarOffline),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
