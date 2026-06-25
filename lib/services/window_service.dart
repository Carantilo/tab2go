// Service: WindowService
// Controla el estado y comportamiento de la ventana de la aplicación.

import 'dart:ui';
import 'package:window_manager/window_manager.dart';

import 'storage_service.dart';

class WindowService with WindowListener {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();

  bool _isInitialized = false;

  Future<void> initialize({
    required double initialWidth,
    required double initialHeight,
    required bool alwaysOnTop,
  }) async {
    if (_isInitialized) return;
    _isInitialized = true;

    await windowManager.ensureInitialized();

    WindowOptions windowOptions = WindowOptions(
      size: Size(initialWidth, initialHeight),
      minimumSize: const Size(300, 300),
      center: true,
      backgroundColor: const Color(0x00000000), // Fondo de ventana transparente
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // Ocultar bordes de ventana clásicos
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setAlwaysOnTop(alwaysOnTop);
    });

    windowManager.addListener(this);
  }

  @override
  void onWindowResized() async {
    final size = await windowManager.getSize();
    _saveWindowDimensions(size.width, size.height);
  }

  // Persistir dimensiones actuales en el archivo de configuración
  void _saveWindowDimensions(double width, double height) {
    final storage = StorageService();
    final config = storage.loadConfig();
    final updatedInterface = config.configuracionInterfaz.copyWith(
      anchoVentana: width,
      altoVentana: height,
    );
    final updatedConfig = config.copyWith(
      configuracionInterfaz: updatedInterface,
      ultimaModificacionGlobal: DateTime.now(),
    );
    storage.saveConfig(updatedConfig);
  }

  // Alternar el estado "Siempre al frente" (Always on Top)
  Future<void> toggleAlwaysOnTop(bool value) async {
    await windowManager.setAlwaysOnTop(value);
    
    final storage = StorageService();
    final config = storage.loadConfig();
    final updatedInterface = config.configuracionInterfaz.copyWith(
      siempreAlFrente: value,
    );
    final updatedConfig = config.copyWith(
      configuracionInterfaz: updatedInterface,
      ultimaModificacionGlobal: DateTime.now(),
    );
    storage.saveConfig(updatedConfig);
  }

  @override
  void onWindowClose() async {
    final storage = StorageService();
    try {
      final config = storage.loadConfig();
      if (!config.configuracionInterfaz.mantenerConexion) {
        storage.clearOAuthData();
      }
    } catch (_) {}
  }

  Future<void> setAlwaysOnTop(bool value) async {
    await windowManager.setAlwaysOnTop(value);
  }

  Future<void> minimize() async {
    await windowManager.minimize();
  }

  Future<void> close() async {
    final storage = StorageService();
    try {
      final config = storage.loadConfig();
      if (!config.configuracionInterfaz.mantenerConexion) {
        storage.clearOAuthData();
      }
    } catch (_) {}
    await windowManager.close();
  }

  Future<void> startDragging() async {
    await windowManager.startDragging();
  }
}
