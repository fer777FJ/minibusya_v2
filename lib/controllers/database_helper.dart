// lib/controllers/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Gestiona la persistencia local con SQLite.
/// Almacena: rutas favoritas, historial de búsquedas y reportes pendientes.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'minibus_ya.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _crearTablas,
    );
  }

  Future<void> _crearTablas(Database db, int version) async {
    // Tabla de rutas favoritas
    await db.execute('''
      CREATE TABLE favoritos (
        id TEXT PRIMARY KEY,
        sindicato TEXT NOT NULL,
        numero_linea TEXT NOT NULL,
        origen TEXT NOT NULL,
        destino TEXT NOT NULL,
        color_hex TEXT NOT NULL,
        fecha_guardado TEXT NOT NULL
      )
    ''');

    // Tabla de historial de búsquedas
    await db.execute('''
      CREATE TABLE historial_busquedas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        texto_busqueda TEXT NOT NULL,
        fecha TEXT NOT NULL
      )
    ''');

    // Tabla de reportes comunitarios pendientes de envío
    await db.execute('''
      CREATE TABLE reportes_pendientes (
        id TEXT PRIMARY KEY,
        tipo TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        descripcion TEXT,
        timestamp TEXT NOT NULL,
        ruta_afectada_id TEXT,
        enviado INTEGER DEFAULT 0
      )
    ''');
  }

  // ─── FAVORITOS ────────────────────────────────────────────────────────────

  Future<void> guardarFavorito(Map<String, dynamic> ruta) async {
    final db = await database;
    await db.insert(
      'favoritos',
      {...ruta, 'fecha_guardado': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> eliminarFavorito(String rutaId) async {
    final db = await database;
    await db.delete('favoritos', where: 'id = ?', whereArgs: [rutaId]);
  }

  Future<List<Map<String, dynamic>>> obtenerFavoritos() async {
    final db = await database;
    return db.query('favoritos', orderBy: 'fecha_guardado DESC');
  }

  Future<bool> esFavorito(String rutaId) async {
    final db = await database;
    final result = await db.query(
      'favoritos',
      where: 'id = ?',
      whereArgs: [rutaId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // ─── HISTORIAL ────────────────────────────────────────────────────────────

  Future<void> guardarBusqueda(String textoBusqueda) async {
    if (textoBusqueda.trim().isEmpty) return;
    final db = await database;
    await db.insert('historial_busquedas', {
      'texto_busqueda': textoBusqueda.trim(),
      'fecha': DateTime.now().toIso8601String(),
    });
  }

  Future<List<String>> obtenerHistorial({int limite = 10}) async {
    final db = await database;
    final resultados = await db.query(
      'historial_busquedas',
      orderBy: 'fecha DESC',
      limit: limite,
    );
    return resultados
        .map((r) => r['texto_busqueda'] as String)
        .toSet() // Elimina duplicados
        .toList();
  }

  Future<void> limpiarHistorial() async {
    final db = await database;
    await db.delete('historial_busquedas');
  }

  // ─── REPORTES ─────────────────────────────────────────────────────────────

  Future<void> guardarReportePendiente(Map<String, dynamic> reporte) async {
    final db = await database;
    await db.insert('reportes_pendientes', reporte);
  }

  Future<List<Map<String, dynamic>>> obtenerReportesPendientes() async {
    final db = await database;
    return db.query(
      'reportes_pendientes',
      orderBy: 'timestamp DESC',
    );
  }

  /// Marca un reporte local como enviado a Firestore
  Future<void> marcarEnviado(String reporteId) async {
    final db = await database;
    await db.update(
      'reportes_pendientes',
      {'enviado': 1},
      where: 'id = ?',
      whereArgs: [reporteId],
    );
  }
}
