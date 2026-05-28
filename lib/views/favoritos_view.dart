import 'package:flutter/material.dart';
import '../controllers/database_helper.dart';
import '../controllers/rutas_controller.dart';
import '../models/ruta_model.dart';
import '../utils/app_theme.dart';
import '../widgets/letrero_widget.dart';
import 'route_detail_view.dart';

class FavoritosView extends StatefulWidget {
  const FavoritosView({super.key});

  @override
  State<FavoritosView> createState() => _FavoritosViewState();
}

class _FavoritosViewState extends State<FavoritosView> {
  final DatabaseHelper _db = DatabaseHelper();
  final RutasController _rutasCtrl = RutasController();
  List<RutaModel> _favoritos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarFavoritos();
  }

  Future<void> _cargarFavoritos() async {
    final registros = await _db.obtenerFavoritos();
    final rutas = <RutaModel>[];

    for (final reg in registros) {
      final ruta = await _rutasCtrl.getRutaPorId(reg['id'] as String);
      if (ruta != null) rutas.add(ruta);
    }

    setState(() {
      _favoritos = rutas;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rutas Favoritas')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _favoritos.isEmpty
              ? _buildEstadoVacio()
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _favoritos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _buildCard(_favoritos[i]),
                ),
    );
  }

  Widget _buildCard(RutaModel ruta) {
    return Card(
      child: ListTile(
        leading: LetreroWidget(
          numeroLinea: ruta.numeroLinea,
          destino: ruta.destino,
          colorHex: ruta.colorHex,
          colorTextoHex: ruta.colorTextoHex,
          width: 80,
          height: 44,
        ),
        title: Text(ruta.sindicato,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${ruta.origen} → ${ruta.destino}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.star, color: AppTheme.amarilloAccent),
              onPressed: () async {
                await _db.eliminarFavorito(ruta.id);
                _cargarFavoritos();
              },
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RouteDetailView(ruta: ruta)),
        ),
      ),
    );
  }

  Widget _buildEstadoVacio() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_border_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Aún no tienes rutas favoritas',
            style: TextStyle(fontSize: 16, color: AppTheme.grisTexto),
          ),
          SizedBox(height: 8),
          Text(
            'Toca el ⭐ en cualquier ruta para guardarla aquí',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}