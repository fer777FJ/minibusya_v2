# MiniBus Ya 🚌
### Aplicación de Transporte Público — La Paz & El Alto, Bolivia
**Universidad Privada Franz Tamayo | Sistemas Operativos Móviles y Embebidos**

---

## Stack Tecnológico (SIN costos, SIN APIs de pago)

| Componente | Solución | Costo |
|---|---|---|
| Mapa visual | `flutter_map` + OSM tiles | **Gratis** |
| Tiles offline | MOBAC (Mobile Atlas Creator) | **Gratis** |
| Rutas/polilíneas | Archivos `.json` locales en assets | **Gratis** |
| GPS del usuario | `geolocator` | **Gratis** |
| Base de datos local | `sqflite` (SQLite) | **Gratis** |

---

## Estructura del Proyecto

```
minibus_ya/
├── lib/
│   ├── main.dart                    # Punto de entrada + SplashScreen
│   ├── models/
│   │   └── ruta_model.dart          # RutaModel, ParadaModel, ReporteModel
│   ├── controllers/
│   │   ├── rutas_controller.dart    # Carga JSONs, lógica de búsqueda
│   │   ├── mapa_controller.dart     # flutter_map + geolocalización
│   │   └── database_helper.dart    # SQLite: favoritos, historial
│   ├── views/
│   │   ├── home_view.dart           # Pantalla principal con mapa
│   │   ├── search_results_view.dart # Lista de rutas encontradas
│   │   ├── route_detail_view.dart   # Detalle + stepper de paradas
│   │   └── report_view.dart         # Reporte comunitario (bento grid)
│   ├── widgets/
│   │   └── letrero_widget.dart      # Replica visual del letrero del minibús
│   └── utils/
│       └── app_theme.dart           # Paleta de colores + tema Material 3
├── assets/
│   ├── mapa/                        # ← Tiles PNG generados con MOBAC
│   │   └── {z}/{x}/{y}.png
│   ├── rutas/                       # ← Un JSON por cada línea de bus
│   │   ├── linea_273_villa_san_antonio.json
│   │   ├── linea_102_miraflores.json
│   │   └── linea_trufi_CH.json
│   └── letreros/                    # Fotos de letreros físicos (opcional)
└── pubspec.yaml
```

---

## Paso 1: Generar tiles offline con MOBAC

**MOBAC** convierte un mapa de OpenStreetMap en miles de imágenes PNG
que tu app usa sin internet.

### Descarga e instalación
1. Ve a: https://mobac.sourceforge.io/
2. Descarga el `.zip` y extrae (requiere Java 11+)
3. Ejecuta `start-MOBAC.bat` (Windows) o `./start-MOBAC.sh` (Linux/Mac)

### Configuración para La Paz / El Alto
```
1. En "Map Source" selecciona: OpenStreetMap 4UMaps (o cualquier OSM)
2. Dibuja el rectángulo sobre La Paz y El Alto con el mouse
3. En "Zoom Levels" marca solo: 12, 13, 14, 15, 16
   (más zoom = más espacio en disco, con el 16 ya es suficiente)
4. En "Atlas Format" selecciona: "Big Planet Tiles" o "OSM And"
5. Haz clic en "Create Atlas"
6. Copia la carpeta generada a: assets/mapa/
   La estructura debe quedar: assets/mapa/{z}/{x}/{y}.png
```

> ⚠️ Los tiles del área completa La Paz + El Alto en zoom 12-16
> pesan aproximadamente **80-150 MB**. Es normal.

---

## Paso 2: Levantar datos de rutas en campo

Cada línea de transporte necesita su archivo JSON en `assets/rutas/`.

### Estructura del JSON
```json
{
  "id": "linea_XXX",
  "sindicato": "Nombre del Sindicato",
  "numero_linea": "XXX",
  "origen": "Punto de inicio",
  "destino": "Punto final",
  "color_hex": "#0D47A1",
  "color_texto_hex": "#FFFFFF",
  "tarifa_normal": 2.0,
  "tarifa_estudiantil": 1.5,
  "tarifa_nocturna": 2.5,
  "horario_inicio": "05:30",
  "horario_fin": "22:00",
  "tipos_vehiculo": ["Minibús"],
  "paradas": [
    {
      "id": "XXX_p01",
      "nombre": "Nombre de la parada",
      "lat": -16.4955,
      "lng": -68.1337,
      "es_terminal": true,
      "orden_en_ruta": 1
    }
  ],
  "coordenadas": [
    { "lat": -16.4955, "lng": -68.1337 },
    { "lat": -16.4960, "lng": -68.1340 }
  ]
}
```

### Cómo obtener las coordenadas GPS de una ruta
**Opción A (recomendada) — Google Maps:**
1. Abre Google Maps en el PC
2. Traza el recorrido del minibús haciendo clic en cada esquina
3. Clic derecho en cada punto → "¿Qué hay aquí?" → copia lat/lng

**Opción B — GPX Tracker en el celular:**
1. Instala "GPS Logger" o "OsmAnd"
2. Súbete al minibús con la app grabando
3. Exporta el trayecto como GPX y convierte a JSON

**Opción C — OpenStreetMap:**
1. Ve a https://www.openstreetmap.org
2. Busca la ruta y usa las herramientas de edición para extraer coordenadas

---

## Paso 3: Agregar nueva ruta a la app

1. Crea el archivo JSON en `assets/rutas/linea_XXX_nombre.json`
2. Agrega la ruta en `lib/controllers/rutas_controller.dart`:
   ```dart
   static const List<String> _archivosRutas = [
     'assets/rutas/linea_273_villa_san_antonio.json',
     'assets/rutas/linea_102_miraflores.json',
     'assets/rutas/linea_XXX_nombre.json',  // ← agrega aquí
   ];
   ```
3. Decláralo en `pubspec.yaml` (ya está configurado con `assets/rutas/`)
4. `flutter pub get` y listo

---

## Instalación y ejecución

```bash
# 1. Instalar dependencias
flutter pub get

# 2. Verificar dispositivo conectado
flutter devices

# 3. Correr en modo desarrollo (online, para probar sin tiles offline)
flutter run

# 4. Build APK para instalar en el teléfono
flutter build apk --release
# El APK queda en: build/app/outputs/flutter-apk/app-release.apk
```

---

## Modo Offline vs Online

En `HomeView._mostrarOffline` (línea ~45):
```dart
bool _mostrarOffline = true;  // true = tiles MOBAC, false = OSM internet
```

- **`true`**: usa los tiles de `assets/mapa/` (carga instantánea, sin internet)
- **`false`**: usa OpenStreetMap online (para desarrollo sin tiles)

También puedes cambiarlo desde el Drawer de la app en tiempo real.

---

## Distribución de tareas sugerida

| Área | Tarea |
|---|---|
| **Estudiante 1 (Frontend)** | Refinar UI de `home_view`, `search_results_view`, animaciones |
| **Estudiante 2 (Datos)** | Levantar coordenadas GPS en campo, crear todos los JSONs de rutas |
| **Estudiante 3 (Arquitectura)** | Integrar geolocalización real, lógica de búsqueda por proximidad |
| **Estudiante 4 (QA)** | Pruebas en dispositivos reales, generar tiles con MOBAC, documentación |

---

## Dependencias principales (`pubspec.yaml`)

```yaml
flutter_map: ^6.1.0      # Mapa (reemplaza Google Maps)
latlong2: ^0.9.0          # Coordenadas GPS
geolocator: ^11.0.0       # GPS del dispositivo
sqflite: ^2.3.2           # Base de datos local
permission_handler: ^11.3.0
```
