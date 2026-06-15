// lib/views/search_results_view.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/rutas_controller.dart';
import '../controllers/database_helper.dart';
import '../models/ruta_model.dart';
import '../utils/app_theme.dart';
import '../widgets/letrero_widget.dart';
import 'route_detail_view.dart';
import '../utils/voice_search_helper.dart';

class SearchResultsView extends StatefulWidget {
  final String busquedaInicial;
  final LatLng? ubicacionUsuario;

  const SearchResultsView({
    super.key,
    required this.busquedaInicial,
    this.ubicacionUsuario,
  });

  @override
  State<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends State<SearchResultsView> {
  final RutasController _rutasCtrl = RutasController();
  final DatabaseHelper _db = DatabaseHelper();
  final TextEditingController _searchCtrl = TextEditingController();

  List<RutaModel> _resultados = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.busquedaInicial;
    _buscar(widget.busquedaInicial);
  }

  Future<void> _buscar(String texto) async {
    setState(() => _cargando = true);
    await _db.guardarBusqueda(texto);
    final resultados = await _rutasCtrl.buscarRutas(
      textoBusqueda: texto,
      ubicacionUsuario: widget.ubicacionUsuario,
    );
    setState(() {
      _resultados = resultados;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '¿A dónde vas?',
            hintStyle: const TextStyle(color: Colors.white60),
            border: InputBorder.none,
            filled: false,
            suffixIcon: IconButton(
              icon: const Icon(Icons.mic_outlined, color: Colors.white),
              onPressed: () {
                VoiceSearchHelper.escucharVoz(
                  context,
                  onResult: (texto) {
                    _searchCtrl.text = texto;
                    _buscar(texto);
                  },
                );
              },
            ),
          ),
          onSubmitted: _buscar,
        ),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          // Banner amarillo con cantidad de resultados
          if (!_cargando)
            Container(
              width: double.infinity,
              color: AppTheme.amarilloAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _resultados.isEmpty
                    ? 'No se encontraron rutas para "${_searchCtrl.text}"'
                    : '${_resultados.length} ruta${_resultados.length != 1 ? 's' : ''} encontrada${_resultados.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.negro,
                  fontSize: 13,
                ),
              ),
            ),

          // Lista de resultados
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _resultados.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _resultados.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _buildRutaCard(_resultados[i]),
                      ),
          ),
        ],
      ),

      // Botón "Ver en Mapa" — muestra todas las rutas encontradas
      bottomNavigationBar: _resultados.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Ver en Mapa'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildRutaCard(RutaModel ruta) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RouteDetailView(ruta: ruta),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Letrero del sindicato
              LetreroWidget(
                numeroLinea: ruta.numeroLinea,
                destino: ruta.destino,
                colorHex: ruta.colorHex,
                colorTextoHex: ruta.colorTextoHex,
                width: 100,
                height: 52,
              ),
              const SizedBox(width: 12),

              // Información de la ruta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre del sindicato
                    Text(
                      ruta.sindicato,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Ruta origen → destino
                    Row(
                      children: [
                        const Icon(Icons.circle,
                            size: 8, color: AppTheme.verdeOk),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ruta.origen,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 8, color: AppTheme.rojoAlerta),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ruta.destino,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Tarifa y paradas
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.verdeOk.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Bs. ${ruta.tarifaNormal.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.verdeOk,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${ruta.paradas.length} paradas',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.grisTexto),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Acciones
              Column(
                children: [
                  FutureBuilder<bool>(
                    future: _db.esFavorito(ruta.id),
                    builder: (_, snap) => IconButton(
                      icon: Icon(
                        snap.data == true
                            ? Icons.star
                            : Icons.star_border_outlined,
                        color: AppTheme.amarilloAccent,
                      ),
                      onPressed: () async {
                        if (snap.data == true) {
                          await _db.eliminarFavorito(ruta.id);
                        } else {
                          await _db.guardarFavorito({
                            'id': ruta.id,
                            'sindicato': ruta.sindicato,
                            'numero_linea': ruta.numeroLinea,
                            'origen': ruta.origen,
                            'destino': ruta.destino,
                            'color_hex': ruta.colorHex,
                          });
                        }
                        setState(() {}); // Rebuild para actualizar el ícono
                      },
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Sin resultados para\n"${_searchCtrl.text}"',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.grisTexto, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta buscar por nombre de\nbarrio, zona o número de línea',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
