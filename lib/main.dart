// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/app_theme.dart';
import 'views/home_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp();

  // Cargar preferencia de tema antes de iniciar la app
  final prefs = await SharedPreferences.getInstance();
  final esOscuro = prefs.getBool('tema_oscuro') ?? false;
  AppTheme.themeNotifier.value = esOscuro ? ThemeMode.dark : ThemeMode.light;

  // Solo orientación vertical (app de transporte en mano)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Modo inmersivo: oculta los botones de navegación del sistema
  // (atrás, home, recientes). Reaparecen brevemente al deslizar desde el borde.
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  // Barra de estado transparente para el mapa
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MiniBusYaApp());
}

class MiniBusYaApp extends StatelessWidget {
  const MiniBusYaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'MiniBus Ya',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.temaClaro,
          darkTheme: AppTheme.temaOscuro,
          themeMode: currentMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeIn,
    );
    _animCtrl.forward();

    // Ir al home después del splash
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeView()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.azulPrimario,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_bus,
                size: 80,
                color: AppTheme.amarilloAccent,
              ),
              SizedBox(height: 16),
              Text(
                'MiniBus Ya',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'La Paz · El Alto · Bolivia',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: 48),
              CircularProgressIndicator(
                color: AppTheme.amarilloAccent,
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
