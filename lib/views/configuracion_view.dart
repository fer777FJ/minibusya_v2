import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';

class ConfiguracionView extends StatefulWidget {
  const ConfiguracionView({super.key});

  @override
  State<ConfiguracionView> createState() => _ConfiguracionViewState();
}

class _ConfiguracionViewState extends State<ConfiguracionView> {
  bool _modoOffline = true;
  bool _mostrarTarifaEstudiante = false;
  bool _mostrarMinibus = true;
  bool _mostrarTrufi = true;
  bool _mostrarMicro = true;
  bool _mostrarPumaKatari = true;
  bool _mostrarTeleferico = true;
  bool _temaOscuro = false;

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _modoOffline = prefs.getBool('modo_offline') ?? true;
      _mostrarTarifaEstudiante =
          prefs.getBool('tarifa_estudiante') ?? false;
      _mostrarMinibus = prefs.getBool('mostrar_minibus') ?? true;
      _mostrarTrufi = prefs.getBool('mostrar_trufi') ?? true;
      _mostrarMicro = prefs.getBool('mostrar_micro') ?? true;
      _mostrarPumaKatari = prefs.getBool('mostrar_pumakatari') ?? true;
      _mostrarTeleferico = prefs.getBool('mostrar_teleferico') ?? true;
      _temaOscuro = prefs.getBool('tema_oscuro') ?? false;
    });
  }

  Future<void> _guardar(String clave, bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(clave, valor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        children: [

          // ── TEMA Y MAPA ─────────────────────────────────────────
          _seccion('Apariencia y Mapa'),
          SwitchListTile(
            secondary: const Icon(Icons.wifi_off),
            title: const Text('Modo Offline'),
            subtitle: const Text('Usa tiles descargados, sin internet'),
            value: _modoOffline,
            activeThumbColor: Theme.of(context).primaryColor,
            activeTrackColor: Theme.of(context).primaryColor.withOpacity(0.4),
            inactiveThumbColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : null,
            inactiveTrackColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white24
                : null,
            onChanged: (v) {
              setState(() => _modoOffline = v);
              _guardar('modo_offline', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Tema Oscuro'),
            subtitle: const Text('Naranja y negro (apagado = azul y blanco)'),
            value: _temaOscuro,
            activeThumbColor: Theme.of(context).primaryColor,
            activeTrackColor: Theme.of(context).primaryColor.withOpacity(0.4),
            inactiveThumbColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : null,
            inactiveTrackColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white24
                : null,
            onChanged: (v) {
              setState(() => _temaOscuro = v);
              _guardar('tema_oscuro', v);
              AppTheme.themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          const Divider(),

          // ── TARIFAS ───────────────────────────────────────────
          _seccion('Tarifas'),
          SwitchListTile(
            secondary: const Icon(Icons.school_outlined),
            title: const Text('Soy estudiante'),
            subtitle: const Text(
                'Muestra la tarifa estudiantil como principal'),
            value: _mostrarTarifaEstudiante,
            activeThumbColor: Theme.of(context).primaryColor,
            activeTrackColor: Theme.of(context).primaryColor.withOpacity(0.4),
            inactiveThumbColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : null,
            inactiveTrackColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white24
                : null,
            onChanged: (v) {
              setState(() => _mostrarTarifaEstudiante = v);
              _guardar('tarifa_estudiante', v);
            },
          ),
          const Divider(),

          // ── TIPOS DE VEHÍCULO ─────────────────────────────────
          _seccion('Mostrar en el mapa'),
          CheckboxListTile(
            secondary: const Text('🚐', style: TextStyle(fontSize: 24)),
            title: const Text('Minibus'),
            value: _mostrarMinibus,
            activeColor: Theme.of(context).primaryColor,
            checkColor: Colors.white,
            side: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey,
              width: 2,
            ),
            onChanged: (v) {
              setState(() => _mostrarMinibus = v!);
              _guardar('mostrar_minibus', v!);
            },
          ),
          CheckboxListTile(
            secondary: const Text('🚗', style: TextStyle(fontSize: 24)),
            title: const Text('Trufi'),
            value: _mostrarTrufi,
            activeColor: Theme.of(context).primaryColor,
            checkColor: Colors.white,
            side: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey,
              width: 2,
            ),
            onChanged: (v) {
              setState(() => _mostrarTrufi = v!);
              _guardar('mostrar_trufi', v!);
            },
          ),
          CheckboxListTile(
            secondary: const Text('🚌', style: TextStyle(fontSize: 24)),
            title: const Text('Micro'),
            value: _mostrarMicro,
            activeColor: Theme.of(context).primaryColor,
            checkColor: Colors.white,
            side: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey,
              width: 2,
            ),
            onChanged: (v) {
              setState(() => _mostrarMicro = v!);
              _guardar('mostrar_micro', v!);
            },
          ),
          CheckboxListTile(
            secondary: const Text('🚡', style: TextStyle(fontSize: 24)),
            title: const Text('Teleferico'),
            value: _mostrarTeleferico,
            activeColor: Theme.of(context).primaryColor,
            checkColor: Colors.white,
            side: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey,
              width: 2,
            ),
            onChanged: (v) {
              setState(() => _mostrarTeleferico = v!);
              _guardar('mostrar_teleferico', v!);
            },
          ),
          CheckboxListTile(
            secondary: const Text('🚍', style: TextStyle(fontSize: 24)),
            title: const Text('PumaKatari'),
            value: _mostrarPumaKatari,
            activeColor: Theme.of(context).primaryColor,
            checkColor: Colors.white,
            side: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey,
              width: 2,
            ),
            onChanged: (v) {
              setState(() => _mostrarPumaKatari = v!);
              _guardar('mostrar_pumakatari', v!);
            },
          ),
          const Divider(),

          // ── DATOS ─────────────────────────────────────────────
          _seccion('Datos'),
          ListTile(
            leading: const Icon(Icons.delete_outline,
                color: AppTheme.rojoAlerta),
            title: const Text('Limpiar historial de búsquedas'),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Historial eliminado')),
              );
            },
          ),
          const Divider(),

          // ── ACERCA DE ─────────────────────────────────────────
          _seccion('Acerca de'),
          ListTile(
            leading: Icon(
              Icons.directions_bus,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Theme.of(context).primaryColor,
            ),
            title: const Text('MiniBus Ya'),
            subtitle: const Text('Versión 1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.school_outlined),
            title: Text('Universidad Privada Franz Tamayo'),
            subtitle: Text('Sistemas Operativos Móviles y Embebidos'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _seccion(String titulo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        titulo.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          // En dark mode: blanco para que resalte sobre el fondo negro
          color: isDark ? Colors.white : Theme.of(context).primaryColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}