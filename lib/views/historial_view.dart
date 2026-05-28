import 'package:flutter/material.dart';
import '../controllers/database_helper.dart';
import '../utils/app_theme.dart';
import 'search_results_view.dart';

class HistorialView extends StatefulWidget {
  const HistorialView({super.key});

  @override
  State<HistorialView> createState() => _HistorialViewState();
}

class _HistorialViewState extends State<HistorialView> {
  final DatabaseHelper _db = DatabaseHelper();
  List<String> _historial = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final h = await _db.obtenerHistorial(limite: 20);
    setState(() => _historial = h);
  }

  Future<void> _limpiar() async {
    await _db.limpiarHistorial();
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Búsquedas'),
        actions: [
          if (_historial.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Limpiar historial',
              onPressed: () async {
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('¿Limpiar historial?'),
                    content: const Text(
                        'Se eliminarán todas las búsquedas guardadas.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Limpiar',
                            style: TextStyle(color: AppTheme.rojoAlerta)),
                      ),
                    ],
                  ),
                );
                if (confirmar == true) _limpiar();
              },
            ),
        ],
      ),
      body: _historial.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Sin búsquedas recientes',
                    style: TextStyle(
                        fontSize: 16, color: AppTheme.grisTexto),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _historial.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final texto = _historial[i];
                return ListTile(
                  leading: const Icon(Icons.history,
                      color: AppTheme.grisTexto),
                  title: Text(texto),
                  trailing: const Icon(Icons.north_west,
                      size: 16, color: AppTheme.grisTexto),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SearchResultsView(
                        busquedaInicial: texto,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}