// lib/controllers/chatbot_service.dart
import 'package:google_generative_ai/google_generative_ai.dart';
import '../controllers/rutas_controller.dart';
import '../models/ruta_model.dart';

class ChatbotService {
  static final ChatbotService _instance = ChatbotService._internal();
  factory ChatbotService() => _instance;
  ChatbotService._internal();

  // API key de Gemini
  static const String _apiKey = 'AQUI_MI_API_KEY';

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

  /// Envía un mensaje y obtiene respuesta de Gemini
  Future<String> enviarMensaje(String mensaje) async {
    try {
      await inicializar();

      if (_apiKey == 'AQUI_MI_API_KEY_DE_GEMINI') {
        return '❌ Error de configuración: API key no configurada. El administrador debe agregar una API key válida de Google Gemini.';
      }

      final response = await _sesion!.sendMessage(
        Content.text(mensaje),
      );

      return response.text ?? 'No pude procesar tu consulta. Intenta de nuevo.';
    } on FormatException catch (e) {
      return '❌ Error en la respuesta: ${e.message}';
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('API key') || errorMsg.contains('INVALID_ARGUMENT')) {
        return '❌ Error de API: Verifica que la API key sea válida en google_generative_ai.';
      } else if (errorMsg.contains('SocketException') || errorMsg.contains('NetworkException')) {
        return '📴 Sin conexión. Verifica tu internet e intenta de nuevo.';
      } else if (errorMsg.contains('Unauthorized') || errorMsg.contains('403')) {
        return '❌ Acceso denegado: API key inválida o sin permisos.';
      }
      return '⚠️ Error desconocido: $errorMsg';
    }
  }

  /// Reinicia la conversación
  void reiniciarChat() {
    _sesion = _modelo?.startChat();
  }
}
