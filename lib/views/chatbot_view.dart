// lib/views/chatbot_view.dart
import 'package:flutter/material.dart';
import '../controllers/chatbot_service.dart';
import '../utils/app_theme.dart';

class ChatbotView extends StatefulWidget {
  const ChatbotView({super.key});

  @override
  State<ChatbotView> createState() => _ChatbotViewState();
}

class _ChatbotViewState extends State<ChatbotView> {
  final ChatbotService _chatbot = ChatbotService();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<_Mensaje> _mensajes = [];
  bool _cargando = false;
  bool _inicializado = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    // Mensaje de bienvenida
    setState(() {
      _mensajes.add(_Mensaje(
        texto: '¡Hola! 👋 Soy MiniBus Bot. '
            'Pregúntame cómo llegar a cualquier lugar de '
            'La Paz o El Alto y te ayudo a encontrar tu ruta. 🚌',
        esBot: true,
      ));
    });

    await _chatbot.inicializar();
    setState(() => _inicializado = true);
  }

  Future<void> _enviar() async {
    final texto = _inputCtrl.text.trim();
    if (texto.isEmpty || _cargando) return;

    // Agregar mensaje del usuario
    setState(() {
      _mensajes.add(_Mensaje(texto: texto, esBot: false));
      _cargando = true;
    });
    _inputCtrl.clear();
    _scrollAlFinal();

    // Obtener respuesta de Gemini
    final respuesta = await _chatbot.enviarMensaje(texto);

    setState(() {
      _mensajes.add(_Mensaje(texto: respuesta, esBot: true));
      _cargando = false;
    });
    _scrollAlFinal();
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.amarilloAccent,
              child: Icon(Icons.directions_bus,
                  size: 18, color: AppTheme.negro),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MiniBus Bot',
                    style: TextStyle(fontSize: 15)),
                Text('Asistente de rutas',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Nueva conversación',
            onPressed: () {
              _chatbot.reiniciarChat();
              setState(() {
                _mensajes.clear();
                _mensajes.add(_Mensaje(
                  texto: '¡Chat reiniciado! ¿En qué te ayudo? 🚌',
                  esBot: true,
                ));
              });
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // ─── SUGERENCIAS RÁPIDAS ────────────────────────────
          _buildSugerencias(),

          // ─── LISTA DE MENSAJES ───────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: _mensajes.length + (_cargando ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _mensajes.length) {
                  return _buildIndicadorEscribiendo();
                }
                return _buildBurbuja(_mensajes[i]);
              },
            ),
          ),

          // ─── INPUT ───────────────────────────────────────────
          _buildInput(),
        ],
      ),
    );
  }

  // Sugerencias de preguntas frecuentes
  Widget _buildSugerencias() {
    final sugerencias = [
      '¿Cómo llego al centro?',
      '¿Qué línea va a El Alto?',
      '¿Cuánto cuesta el pasaje?',
      '¿Horarios de servicio?',
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: sugerencias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text(sugerencias[i],
              style: const TextStyle(fontSize: 12)),
          backgroundColor: AppTheme.azulPrimario.withOpacity(0.1),
          side: BorderSide(
              color: AppTheme.azulPrimario.withOpacity(0.3)),
          onPressed: () {
            _inputCtrl.text = sugerencias[i];
            _enviar();
          },
        ),
      ),
    );
  }

  // Burbuja de mensaje
  Widget _buildBurbuja(_Mensaje mensaje) {
    final esBot = mensaje.esBot;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            esBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (esBot) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.azulPrimario,
              child: Icon(Icons.directions_bus,
                  size: 14, color: Colors.white),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: esBot
                    ? Colors.white
                    : AppTheme.azulPrimario,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(esBot ? 4 : 16),
                  bottomRight: Radius.circular(esBot ? 16 : 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                mensaje.texto,
                style: TextStyle(
                  color: esBot ? AppTheme.negro : Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (!esBot) ...[
            const SizedBox(width: 6),
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.amarilloAccent,
              child: Icon(Icons.person,
                  size: 14, color: AppTheme.negro),
            ),
          ],
        ],
      ),
    );
  }

  // Indicador "escribiendo..."
  Widget _buildIndicadorEscribiendo() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.azulPrimario,
            child: Icon(Icons.directions_bus,
                size: 14, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _puntito(0),
                const SizedBox(width: 4),
                _puntito(200),
                const SizedBox(width: 4),
                _puntito(400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _puntito(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.azulPrimario
              .withOpacity(0.3 + (v * 0.7)),
        ),
      ),
    );
  }

  // Campo de texto + botón enviar
  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              enabled: _inicializado,
              onSubmitted: (_) => _enviar(),
              decoration: InputDecoration(
                hintText: _inicializado
                    ? '¿A dónde quieres ir?'
                    : 'Cargando rutas...',
                filled: true,
                fillColor: AppTheme.blancoFondo,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: _cargando ? null : _enviar,
            backgroundColor: AppTheme.azulPrimario,
            child: _cargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Mensaje {
  final String texto;
  final bool esBot;
  _Mensaje({required this.texto, required this.esBot});
}