// lib/utils/voice_search_helper.dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'app_theme.dart';

class VoiceSearchHelper {
  static Future<void> escucharVoz(
    BuildContext context, {
    required Function(String) onResult,
  }) async {
    final speech = stt.SpeechToText();
    
    try {
      bool disponible = await speech.initialize(
        onStatus: (val) => debugPrint('STT Status: $val'),
        onError: (val) => debugPrint('STT Error: $val'),
      );
      
      if (!disponible) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El dictado por voz no está disponible en este dispositivo')),
          );
        }
        return;
      }

      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        isDismissible: true,
        enableDrag: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) {
          String textoEscuchado = "...";
          bool escuchando = true;
          
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              if (escuchando && !speech.isListening) {
                speech.listen(
                  onResult: (result) {
                    setSheetState(() {
                      textoEscuchado = result.recognizedWords;
                    });
                    if (result.finalResult) {
                      Future.delayed(const Duration(milliseconds: 600), () {
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                        onResult(result.recognizedWords);
                      });
                    }
                  },
                  localeId: 'es_BO', // Español de Bolivia
                );
              }
              
              return Container(
                height: 220,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.mic, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Escuchando tu voz...',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      textoEscuchado,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14, 
                        color: AppTheme.grisTexto,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ).then((_) {
        speech.stop();
      });
    } catch (e) {
      debugPrint('Error en STT: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar micrófono: $e')),
        );
      }
    }
  }
}
