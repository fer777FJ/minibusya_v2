// lib/controllers/chatbot_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/secrets.dart';
import '../controllers/rutas_controller.dart';
import '../models/ruta_model.dart';

class ChatbotService {
  static final ChatbotService _instance = ChatbotService._internal();
  factory ChatbotService() => _instance;
  ChatbotService._internal();

  // API key cargada desde lib/config/secrets.dart (archivo gitignoreado)
  static const String _apiKey = Secrets.geminiApiKey;

  final RutasController _rutasCtrl = RutasController();
  ChatSession? _sesion;
  GenerativeModel? _modelo;

  /// Inicializa el modelo con el contexto de todas las rutas
  Future<void> inicializar() async {
    if (_modelo != null) return;

    // Cargar todas las rutas para darle contexto a la IA
    final rutas = await _rutasCtrl.cargarTodasLasRutas();
    final contextoRutas = _construirContexto(rutas);

    _modelo = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system('''
Eres un asistente de transporte público de La Paz y El Alto, Bolivia.
Tu nombre es "MiniBus Bot". Ayudas a los usuarios a encontrar rutas de 
minibuses, trufis y micros.

DATOS DE LAS RUTAS DISPONIBLES:
$contextoRutas

INSTRUCCIONES:
- Responde SIEMPRE en español
- Sé amable y conciso
- Si el usuario pregunta cómo llegar a un lugar, busca en las rutas 
  disponibles cuál pasa más cerca
- Menciona siempre: número de línea, paradas relevantes y tarifa
- Si hay un bloqueo reportado menciona alternativas
- Si no encuentras una ruta exacta, sugiere la más cercana
- No inventes rutas que no están en los datos
- Responde en máximo 3-4 líneas para ser claro y directo
- Usa emojis ocasionalmente para ser más amigable 🚌
'''),
    );

    _sesion = _modelo!.startChat();
  }

  /// Construye el contexto de rutas para la IA
  String _construirContexto(List<RutaModel> rutas) {
    final buffer = StringBuffer();
    for (final ruta in rutas) {
      buffer.writeln('LÍNEA ${ruta.numeroLinea}:');
      buffer.writeln('  Sindicato: ${ruta.sindicato}');
      buffer.writeln('  Recorrido: ${ruta.origen} → ${ruta.destino}');
      buffer.writeln('  Tarifa: Bs.${ruta.tarifaNormal} normal, '
          'Bs.${ruta.tarifaEstudiantil} estudiante');
      buffer.writeln('  Horario: ${ruta.horarioInicio} - ${ruta.horarioFin}');
      buffer.writeln('  Tipo: ${ruta.tiposVehiculo.join(', ')}');
      buffer.writeln(
          '  Paradas: ${ruta.paradas.map((p) => p.nombre).join(' → ')}');
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Envía un mensaje y obtiene respuesta de Gemini (online) o de la Red Neuronal (offline)
  Future<String> enviarMensaje(String mensaje,
      {bool forceOffline = false}) async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final tieneInternet =
          !connectivityResult.contains(ConnectivityResult.none);

      if (forceOffline || !tieneInternet) {
        return await _responderOffline(mensaje);
      }

      await inicializar();

      final response = await _sesion!.sendMessage(
        Content.text(mensaje),
      );

      return response.text ?? 'No pude procesar tu consulta. Intenta de nuevo.';
    } on FormatException catch (e) {
      return '❌ Error en la respuesta: ${e.message}';
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('API key') ||
          errorMsg.contains('INVALID_ARGUMENT')) {
        return '❌ Error de API: Verifica que la API key sea válida en google_generative_ai.';
      } else if (errorMsg.contains('SocketException') ||
          errorMsg.contains('NetworkException')) {
        // Fallback automático al modo offline en caso de error de conexión en runtime
        debugPrint(
            '🔌 Fallo de conexión en Gemini: usando fallback offline...');
        return await _responderOffline(mensaje);
      } else if (errorMsg.contains('Unauthorized') ||
          errorMsg.contains('403')) {
        return '❌ Acceso denegado: API key inválida o sin permisos.';
      }
      return '⚠️ Error desconocido: $errorMsg';
    }
  }

  /// Reinicia la conversación
  void reiniciarChat() {
    _sesion = _modelo?.startChat();
  }

  /// Elimina acentos y normaliza a minúsculas para que el filtro de
  /// stop words funcione con o sin tilde (ej: "Cómo" → "como").
  static String _normalizarTexto(String texto) {
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ü', 'u');
  }

  /// Procesa y responde la consulta de manera 100% offline
  Future<String> _responderOffline(String mensaje) async {
    final intent = RedNeuronalClasificador.clasificar(mensaje);

    switch (intent) {
      case 'SALUDO':
        return '¡Hola! 👋 Soy MiniBus Bot (Modo Offline 📴). ¿A dónde deseas ir hoy por La Paz o El Alto? Escribe tu destino y te ayudaré a buscar.';

      case 'CONSULTAR_TARIFA':
        return '💵 *Tarifas Oficiales Offline:*\n'
            '• Minibuses: Bs. 2.00 (tramo corto) / Bs. 2.60 (tramo largo).\n'
            '• Micros: Bs. 1.50.\n'
            '• Trufis: Bs. 3.00 - Bs. 3.50.\n'
            '• Pumakatari: Bs. 2.30 (tarjeta) / Bs. 2.50 (efectivo).\n'
            '• Escolar/Mayor: Bs. 1.00 (minibuses).';

      case 'CONSULTAR_HORARIO':
        return '⏰ *Horarios Offline:*\n'
            'La mayoría de las líneas operan de 06:00 a 22:00.\n'
            'El servicio nocturno (tarifa +Bs. 0.50) rige a partir de las 20:30.';

      case 'AYUDA':
        return '🤖 *Asistente de Rutas Offline:*\n'
            'Escribe tu destino (ej: "ir a Sopocachi" o "línea a El Alto") y buscaré en la base de datos offline del dispositivo.';

      case 'BUSCAR_RUTA':
      default:
        final stopWords = [
          'como',
          'llego',
          'voy',
          'ir',
          'a',
          'de',
          'el',
          'la',
          'en',
          'quiero',
          'linea',
          'minibus',
          'trufi',
          'micro',
          'pumakatari',
          'ruta',
          'parada',
          'para',
          'por',
          'favor',
          'busca',
          'dime',
          'necesito',
          'desde',
          'hasta',
          'al',
          'del',
          'un',
          'una',
          'y',
          'o',
          'lo',
          'los',
          'las'
        ];

        final tokens = _normalizarTexto(mensaje)
            .replaceAll(RegExp(r'[^\w\s]'), '')
            .split(RegExp(r'\s+'))
            .where((t) => t.trim().isNotEmpty && !stopWords.contains(t))
            .toList();

        final query = tokens.isEmpty ? mensaje.trim() : tokens.join(' ');

        if (query.isEmpty) {
          return '🤖 Escribe el lugar al que quieres ir (ej: "Miraflores") para buscarte una ruta.';
        }

        final rutasEncontradas =
            await _rutasCtrl.buscarRutas(textoBusqueda: query);

        if (rutasEncontradas.isEmpty) {
          return '📴 *Búsqueda Offline:*\n'
              'No encontré rutas directas que pasen por o terminen en "$query".\n'
              'Sugerencia: Intenta buscar con una zona general o punto conocido (ej: "Ceja", "Miraflores", "Plaza Murillo").';
        }

        final buffer = StringBuffer();
        buffer.writeln(
            '📴 *Rutas Offline encontradas para "$query" (${rutasEncontradas.length}):*');

        final limiteRutas = rutasEncontradas.take(3).toList();
        for (final ruta in limiteRutas) {
          buffer
              .writeln('\n🚌 *Línea ${ruta.numeroLinea}* (${ruta.sindicato})');
          buffer.writeln('  • *Recorrido:* ${ruta.origen} ➔ ${ruta.destino}');
          buffer.writeln(
              '  • *Tarifa:* Bs. ${ruta.tarifaNormal.toStringAsFixed(1)}');
          buffer.writeln('  • *Vehículos:* ${ruta.tiposVehiculo.join(', ')}');
        }

        if (rutasEncontradas.length > 3) {
          buffer.writeln('\n...y ${rutasEncontradas.length - 3} rutas más.');
        }

        return buffer.toString();
    }
  }
}

/// Clasificador de red neuronal feed-forward para intenciones en Dart puro.
class RedNeuronalClasificador {
  static const List<String> vocab = [
    'como',
    'llego',
    'voy',
    'ir',
    'linea',
    'minibus',
    'trufi',
    'micro',
    'alto',
    'miraflores',
    'san',
    'antonio',
    'plaza',
    'murillo',
    'sopocachi',
    'centro',
    'tarifa',
    'precio',
    'pasaje',
    'cuesta',
    'horario',
    'hora',
    'inicia',
    'termina',
    'servicio',
    'hola',
    'buenos',
    'dias',
    'tardes',
    'ayuda',
    'haces',
    'funcionas',
    'gracias',
    'chau',
    'adios',
    'estudiante',
    'normal',
    'nocturna',
    'ver',
    'ruta',
    'parada',
    'sindicato',
    'pumakatari'
  ];

  static const List<String> intents = [
    'SALUDO',
    'BUSCAR_RUTA',
    'CONSULTAR_TARIFA',
    'CONSULTAR_HORARIO',
    'AYUDA'
  ];

  // Matriz de pesos de la capa oculta (16 neuronas, vocab.length entradas)
  static final List<List<double>> _w1 = List.generate(16, (i) {
    final row = List<double>.filled(vocab.length, 0.0);
    if (i >= 0 && i <= 2) {
      // SALUDO
      for (final w in ['hola', 'buenos', 'dias', 'tardes']) {
        final idx = vocab.indexOf(w);
        if (idx != -1) row[idx] = 2.0;
      }
    } else if (i >= 3 && i <= 7) {
      // BUSCAR_RUTA
      for (final w in [
        'como',
        'llego',
        'voy',
        'ir',
        'linea',
        'minibus',
        'trufi',
        'micro',
        'alto',
        'miraflores',
        'san',
        'antonio',
        'plaza',
        'murillo',
        'sopocachi',
        'centro',
        'pumakatari',
        'ruta',
        'parada'
      ]) {
        final idx = vocab.indexOf(w);
        if (idx != -1) row[idx] = 2.0;
      }
    } else if (i >= 8 && i <= 10) {
      // CONSULTAR_TARIFA
      for (final w in [
        'tarifa',
        'precio',
        'pasaje',
        'cuesta',
        'estudiante',
        'normal',
        'nocturna'
      ]) {
        final idx = vocab.indexOf(w);
        if (idx != -1) row[idx] = 2.0;
      }
    } else if (i >= 11 && i <= 13) {
      // CONSULTAR_HORARIO
      for (final w in ['horario', 'hora', 'inicia', 'termina', 'servicio']) {
        final idx = vocab.indexOf(w);
        if (idx != -1) row[idx] = 2.0;
      }
    } else {
      // AYUDA
      for (final w in ['ayuda', 'haces', 'funcionas', 'gracias']) {
        final idx = vocab.indexOf(w);
        if (idx != -1) row[idx] = 2.0;
      }
    }
    return row;
  });

  static final List<double> _b1 = List<double>.filled(16, 0.1);

  // Matriz de pesos de la capa de salida (5 intenciones, 16 neuronas)
  static final List<List<double>> _w2 = [
    [
      2.0,
      2.0,
      2.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0
    ], // SALUDO
    [
      -1.0,
      -1.0,
      -1.0,
      2.0,
      2.0,
      2.0,
      2.0,
      2.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0
    ], // BUSCAR_RUTA
    [
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      2.0,
      2.0,
      2.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0
    ], // CONSULTAR_TARIFA
    [
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      2.0,
      2.0,
      2.0,
      -1.0,
      -1.0
    ], // CONSULTAR_HORARIO
    [
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      -1.0,
      2.0,
      2.0
    ] // AYUDA
  ];

  static final List<double> _b2 = [0.0, 0.0, 0.0, 0.0, 0.0];

  /// Clasifica la consulta y retorna la intención correspondiente.
  static String clasificar(String query) {
    final cleanQuery = query.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final tokens = cleanQuery.split(RegExp(r'\s+'));
    final x = List<double>.filled(vocab.length, 0.0);
    for (final token in tokens) {
      final idx = vocab.indexOf(token);
      if (idx != -1) {
        x[idx] = 1.0;
      }
    }

    // Capa oculta: hidden = relu(W1 * x + b1)
    final hidden = List<double>.filled(16, 0.0);
    for (var i = 0; i < 16; i++) {
      var sum = 0.0;
      for (var j = 0; j < vocab.length; j++) {
        sum += _w1[i][j] * x[j];
      }
      hidden[i] = sum + _b1[i];
      if (hidden[i] < 0.0) hidden[i] = 0.0; // ReLU
    }

    // Capa de salida: out = W2 * hidden + b2
    final out = List<double>.filled(intents.length, 0.0);
    var maxVal = -double.infinity;
    var maxIdx = 0;

    for (var k = 0; k < intents.length; k++) {
      var sum = 0.0;
      for (var i = 0; i < 16; i++) {
        sum += _w2[k][i] * hidden[i];
      }
      out[k] = sum + _b2[k];
      if (out[k] > maxVal) {
        maxVal = out[k];
        maxIdx = k;
      }
    }

    final totalKeywords = x.reduce((a, b) => a + b);
    if (totalKeywords == 0) {
      if (query.trim().length > 3) {
        return 'BUSCAR_RUTA';
      }
      return 'AYUDA';
    }

    return intents[maxIdx];
  }
}
