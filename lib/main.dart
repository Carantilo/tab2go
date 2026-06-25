// Main Entry Point
// Inicializa la aplicación y los servicios requeridos de Windows y Google Cloud.

import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'services/notes_state.dart';
import 'services/window_service.dart';
import 'ui/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializar servicios de estado y persistencia local
  final notesState = NotesState();
  notesState.initialize();

  // 2. Inicializar sistema de autenticación OAuth
  final authService = AuthService();
  await authService.initialize();

  // 3. Obtener configuración de interfaz previa para restaurar la ventana
  final interfaceConfig = notesState.config.configuracionInterfaz;

  // 4. Inicializar y mostrar ventana sin bordes nativos (Custom Frame)
  final windowService = WindowService();
  await windowService.initialize(
    initialWidth: interfaceConfig.anchoVentana,
    initialHeight: interfaceConfig.altoVentana,
    alwaysOnTop: interfaceConfig.siempreAlFrente,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tab2Go',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.light,
        ),
      ),
      home: const MainScreen(),
    );
  }
}
