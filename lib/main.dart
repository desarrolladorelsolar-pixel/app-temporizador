// =============================================================================
// PUNTO DE ENTRADA — main.dart
// =============================================================================
// Inicializa la app Flutter, configura el tema, localización y Provider,
// y lanza la SplashScreen como pantalla inicial.
//
// RESPONSABILIDADES:
//   - Inicializar el binding de Flutter antes de cualquier operación async.
//   - Cargar los datos de localización en español (para DateFormat y DatePicker).
//   - Configurar la barra de estado del sistema (color rojo corporativo).
//   - Crear el AppState y envolverlo en ChangeNotifierProvider global.
//   - Definir el tema visual de toda la app (color primario rojo #C62828).
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'screens/splash_screen.dart';

/// Punto de entrada de la app.
/// Es `async` porque necesita esperar la inicialización de localización.
void main() async {
  // Garantiza que el binding de Flutter esté listo antes de cualquier
  // operación (necesario para SystemChrome y operaciones async en main).
  WidgetsFlutterBinding.ensureInitialized();

  // Carga los datos de formato de fechas en español.
  // Necesario para que DateFormat('dd/MM/yyyy', 'es_ES') funcione
  // y para el selector de rango de fechas del historial.
  await initializeDateFormatting('es_ES');

  // Configura la UI de borde a borde (el contenido llega hasta los bordes
  // de la pantalla, debajo de la barra de estado y de navegación).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Define los colores de la barra de estado del sistema.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFC62828),             // rojo corporativo
      statusBarIconBrightness: Brightness.light,     // íconos blancos
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    // ChangeNotifierProvider crea el AppState una sola vez y lo pone
    // disponible para toda la app. El `..init()` carga los datos de SQLite
    // inmediatamente después de crear el estado.
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const TemporizadorApp(),
    ),
  );
}

/// Widget raíz de la aplicación.
/// Define el tema global, la localización y la pantalla inicial.
class TemporizadorApp extends StatelessWidget {
  const TemporizadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Temporizador Cocina',
      debugShowCheckedModeBanner: false, // oculta el banner de debug en pantalla

      // ── Localización ────────────────────────────────────────────────────
      // Necesario para que showDateRangePicker muestre el calendario en español.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],

      // ── Tema visual ─────────────────────────────────────────────────────
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC62828),
          primary: const Color(0xFFC62828), // rojo El Solar
        ),
        scaffoldBackgroundColor: Colors.white,

        // InkSplash es más liviano que el default de Material 3 en GPUs débiles.
        // En web se usa InkRipple (más suave).
        splashFactory: kIsWeb
            ? InkRipple.splashFactory
            : InkSplash.splashFactory,

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFC62828),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Color(0xFFC62828),
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),

        // Estilo global para todos los ElevatedButton de la app.
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC62828),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        useMaterial3: true,
      ),

      // SafeArea global: garantiza que el contenido no quede debajo
      // de la barra de estado en ningún dispositivo.
      builder: (context, child) => SafeArea(
        top: true,
        bottom: false, // el bottom no se reserva para permitir gestos del sistema
        child: child!,
      ),

      // La app siempre arranca con la splash screen.
      home: const SplashScreen(),
    );
  }
}
