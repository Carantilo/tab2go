// Service: NotesState
// Administrador de estado reactivo (ChangeNotifier) de la aplicación.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../models/attachment_info.dart';
import '../models/note_tab.dart';
import '../models/sticky_tabs_config.dart';
import 'storage_service.dart';
import 'drive_service.dart';
import 'auth_service.dart';
import 'window_service.dart';

class NotesState extends ChangeNotifier {
  static final NotesState _instance = NotesState._internal();
  factory NotesState() => _instance;
  NotesState._internal();

  final StorageService _storage = StorageService();
  final DriveService _drive = DriveService();
  final AuthService _auth = AuthService();

  late StickyTabsConfig _config;
  NoteTab? _activeTab;
  Timer? _syncDebounceTimer;
  bool _isDownloadingAttachment = false;

  StickyTabsConfig get config => _config;
  NoteTab? get activeTab => _activeTab;
  List<NoteTab> get tabs => List.unmodifiable(_config.notasPestanas..sort((a, b) => a.ordenPosicion.compareTo(b.ordenPosicion)));
  bool get isDownloadingAttachment => _isDownloadingAttachment;

  void initialize() {
    _storage.initialize();
    _config = _storage.loadConfig();

    // Migrar color amarillo por defecto a azul claro para que el cambio de color sea inmediato para el usuario
    bool migrado = false;
    final migratedTabs = _config.notasPestanas.map((tab) {
      if (tab.colorPestana == '#FFF9C4') {
        migrado = true;
        return tab.copyWith(colorPestana: '#B3E5FC');
      }
      return tab;
    }).toList();

    var migratedInterface = _config.configuracionInterfaz;
    if (_config.configuracionInterfaz.colorTema == '#FFF9C4') {
      migrado = true;
      migratedInterface = migratedInterface.copyWith(colorTema: '#B3E5FC');
    }

    if (migrado) {
      _config = _config.copyWith(
        notasPestanas: migratedTabs,
        configuracionInterfaz: migratedInterface,
        ultimaModificacionGlobal: DateTime.now(),
      );
      _storage.saveConfig(_config);
    }

    _setActiveTabFromConfig();

    // Escuchar cambios de inicio de sesión para sincronizar automáticamente
    _auth.addListener(() {
      if (_auth.isSignedIn) {
        triggerCloudSync();
      }
    });
  }

  Future<void> toggleAlwaysOnTop(bool value) async {
    final updatedInterface = _config.configuracionInterfaz.copyWith(siempreAlFrente: value);
    _config = _config.copyWith(
      configuracionInterfaz: updatedInterface,
      ultimaModificacionGlobal: DateTime.now(),
    );
    _storage.saveConfig(_config);
    await WindowService().setAlwaysOnTop(value);
    notifyListeners();
  }

  Future<void> updateKeepConnection(bool value) async {
    final updatedInterface = _config.configuracionInterfaz.copyWith(mantenerConexion: value);
    _config = _config.copyWith(
      configuracionInterfaz: updatedInterface,
      ultimaModificacionGlobal: DateTime.now(),
    );
    _storage.saveConfig(_config);
    notifyListeners();
  }

  void _setActiveTabFromConfig() {
    final activeId = _config.configuracionInterfaz.pestanaActivaId;
    if (_config.notasPestanas.isEmpty) {
      _activeTab = null;
      return;
    }
    _activeTab = _config.notasPestanas.firstWhere(
      (t) => t.id == activeId,
      orElse: () => _config.notasPestanas.first,
    );
  }

  // Cambiar la pestaña activa
  void selectTab(String id) {
    if (_activeTab?.id == id) return;

    final index = _config.notasPestanas.indexWhere((t) => t.id == id);
    if (index != -1) {
      _activeTab = _config.notasPestanas[index];
      final updatedInterface = _config.configuracionInterfaz.copyWith(
        pestanaActivaId: id,
        colorTema: _activeTab!.colorPestana,
      );
      _config = _config.copyWith(
        configuracionInterfaz: updatedInterface,
        ultimaModificacionGlobal: DateTime.now(),
      );
      _storage.saveConfig(_config);
      notifyListeners();
      
      // Sincronizar estado de pestaña activa con la nube
      _debounceSync();
    }
  }

  // Crear una nueva pestaña
  void addTab(String titulo, String colorHex) {
    final newId = const Uuid().v4();
    final newPosition = _config.notasPestanas.length;

    final newTab = NoteTab(
      id: newId,
      titulo: titulo,
      colorPestana: colorHex,
      ordenPosicion: newPosition,
      fechaCreacion: DateTime.now(),
      ultimaModificacion: DateTime.now(),
      contenidoTexto: '# $titulo\n\nEmpieza a escribir aquí...',
      archivosAdjuntos: [],
    );

    final updatedTabs = List<NoteTab>.from(_config.notasPestanas)..add(newTab);
    final updatedInterface = _config.configuracionInterfaz.copyWith(
      pestanaActivaId: newId,
      colorTema: colorHex,
    );

    _config = _config.copyWith(
      notasPestanas: updatedTabs,
      configuracionInterfaz: updatedInterface,
      ultimaModificacionGlobal: DateTime.now(),
    );

    _activeTab = newTab;
    _storage.saveConfig(_config);
    notifyListeners();
    _debounceSync();
  }

  // Eliminar pestaña
  void removeTab(String id) {
    if (_config.notasPestanas.length <= 1) {
      // No permitir borrar la última pestaña
      return;
    }

    final updatedTabs = List<NoteTab>.from(_config.notasPestanas)..removeWhere((t) => t.id == id);
    
    // Corregir posiciones de orden
    for (int i = 0; i < updatedTabs.length; i++) {
      updatedTabs[i] = updatedTabs[i].copyWith(ordenPosicion: i);
    }

    String? nextActiveId = _config.configuracionInterfaz.pestanaActivaId;
    if (nextActiveId == id) {
      nextActiveId = updatedTabs.first.id;
    }

    final nextActiveTab = updatedTabs.firstWhere((t) => t.id == nextActiveId);

    final updatedInterface = _config.configuracionInterfaz.copyWith(
      pestanaActivaId: nextActiveId,
      colorTema: nextActiveTab.colorPestana,
    );

    _config = _config.copyWith(
      notasPestanas: updatedTabs,
      configuracionInterfaz: updatedInterface,
      ultimaModificacionGlobal: DateTime.now(),
    );

    _activeTab = nextActiveTab;
    _storage.saveConfig(_config);
    notifyListeners();
    _debounceSync();
  }

  // Renombrar pestaña
  void renameTab(String id, String nuevoTitulo) {
    final index = _config.notasPestanas.indexWhere((t) => t.id == id);
    if (index != -1) {
      final updatedTab = _config.notasPestanas[index].copyWith(
        titulo: nuevoTitulo,
        ultimaModificacion: DateTime.now(),
      );

      final updatedTabs = List<NoteTab>.from(_config.notasPestanas)..[index] = updatedTab;
      _config = _config.copyWith(
        notasPestanas: updatedTabs,
        ultimaModificacionGlobal: DateTime.now(),
      );

      if (_activeTab?.id == id) {
        _activeTab = updatedTab;
      }

      _storage.saveConfig(_config);
      notifyListeners();
      _debounceSync();
    }
  }

  // Cambiar color de pestaña
  void updateTabColor(String id, String colorHex) {
    final index = _config.notasPestanas.indexWhere((t) => t.id == id);
    if (index != -1) {
      final updatedTab = _config.notasPestanas[index].copyWith(
        colorPestana: colorHex,
        ultimaModificacion: DateTime.now(),
      );

      final updatedTabs = List<NoteTab>.from(_config.notasPestanas)..[index] = updatedTab;
      
      var updatedInterface = _config.configuracionInterfaz;
      if (_activeTab?.id == id) {
        _activeTab = updatedTab;
        updatedInterface = updatedInterface.copyWith(colorTema: colorHex);
      }

      _config = _config.copyWith(
        notasPestanas: updatedTabs,
        configuracionInterfaz: updatedInterface,
        ultimaModificacionGlobal: DateTime.now(),
      );

      _storage.saveConfig(_config);
      notifyListeners();
      _debounceSync();
    }
  }

  // Cambiar tipografía de las notas
  Future<void> updateTypography(String typography) async {
    final updatedInterface = _config.configuracionInterfaz.copyWith(tipoTipografia: typography);
    _config = _config.copyWith(
      configuracionInterfaz: updatedInterface,
      ultimaModificacionGlobal: DateTime.now(),
    );
    _storage.saveConfig(_config);
    notifyListeners();
    _debounceSync();
  }

  // Cambiar tamaño de fuente de las notas
  Future<void> updateFontSize(double size) async {
    final updatedInterface = _config.configuracionInterfaz.copyWith(tamanoTipografia: size);
    _config = _config.copyWith(
      configuracionInterfaz: updatedInterface,
      ultimaModificacionGlobal: DateTime.now(),
    );
    _storage.saveConfig(_config);
    notifyListeners();
    _debounceSync();
  }

  // Reordenar pestañas
  void reorderTabs(int oldIndex, int newIndex) {
    var list = tabs.toList();
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    // Actualizar los índices de orden
    final updatedTabs = <NoteTab>[];
    for (int i = 0; i < list.length; i++) {
      final originalIndex = _config.notasPestanas.indexWhere((t) => t.id == list[i].id);
      final updatedTab = _config.notasPestanas[originalIndex].copyWith(ordenPosicion: i);
      updatedTabs.add(updatedTab);
    }

    _config = _config.copyWith(
      notasPestanas: updatedTabs,
      ultimaModificacionGlobal: DateTime.now(),
    );

    _setActiveTabFromConfig();
    _storage.saveConfig(_config);
    notifyListeners();
    _debounceSync();
  }

  // Actualizar contenido de texto (con debounce para sincronización en la nube)
  void updateActiveTabContent(String content) {
    if (_activeTab == null) return;

    final index = _config.notasPestanas.indexWhere((t) => t.id == _activeTab!.id);
    if (index != -1) {
      final updatedTab = _config.notasPestanas[index].copyWith(
        contenidoTexto: content,
        ultimaModificacion: DateTime.now(),
      );

      final updatedTabs = List<NoteTab>.from(_config.notasPestanas)..[index] = updatedTab;
      _config = _config.copyWith(
        notasPestanas: updatedTabs,
        ultimaModificacionGlobal: DateTime.now(),
      );

      _activeTab = updatedTab;
      _storage.saveConfig(_config);
      notifyListeners();

      // Debounce para subir a la nube (evita saturar la conexión mientras el usuario teclea)
      _debounceSync();
    }
  }

  // Agregar archivo adjunto
  Future<void> attachFileToActiveTab(File file) async {
    if (_activeTab == null) return;

    // Copiar a caché local
    final newAttachment = await _storage.addAttachmentFromLocalFile(file);

    // Actualizar estado local
    final index = _config.notasPestanas.indexWhere((t) => t.id == _activeTab!.id);
    if (index != -1) {
      final updatedAdjuntos = List<AttachmentInfo>.from(_activeTab!.archivosAdjuntos)..add(newAttachment);
      final updatedTab = _config.notasPestanas[index].copyWith(
        archivosAdjuntos: updatedAdjuntos,
        ultimaModificacion: DateTime.now(),
      );

      final updatedTabs = List<NoteTab>.from(_config.notasPestanas)..[index] = updatedTab;
      _config = _config.copyWith(
        notasPestanas: updatedTabs,
        ultimaModificacionGlobal: DateTime.now(),
      );

      _activeTab = updatedTab;
      _storage.saveConfig(_config);
      notifyListeners();

      // Si está conectado a Drive, subir el archivo de forma binaria primero
      if (_auth.isSignedIn) {
        _uploadAttachmentInBg(newAttachment, _activeTab!.id);
      } else {
        _debounceSync();
      }
    }
  }

  // Subir adjunto en segundo plano
  Future<void> _uploadAttachmentInBg(AttachmentInfo attachment, String tabId) async {
    final result = await _drive.uploadAttachment(attachment);
    if (result != null) {
      // Reemplazar el adjunto local con el que ya tiene google_drive_file_id y md5
      final tabIndex = _config.notasPestanas.indexWhere((t) => t.id == tabId);
      if (tabIndex != -1) {
        final tab = _config.notasPestanas[tabIndex];
        final adjuntosIndex = tab.archivosAdjuntos.indexWhere((a) => a.adjuntoId == attachment.adjuntoId);
        if (adjuntosIndex != -1) {
          final updatedAdjuntos = List<AttachmentInfo>.from(tab.archivosAdjuntos)..[adjuntosIndex] = result;
          final updatedTab = tab.copyWith(
            archivosAdjuntos: updatedAdjuntos,
            ultimaModificacion: DateTime.now(),
          );

          final updatedTabs = List<NoteTab>.from(_config.notasPestanas)..[tabIndex] = updatedTab;
          _config = _config.copyWith(
            notasPestanas: updatedTabs,
            ultimaModificacionGlobal: DateTime.now(),
          );

          if (_activeTab?.id == tabId) {
            _activeTab = updatedTab;
          }

          _storage.saveConfig(_config);
          notifyListeners();
          
          // Ahora sincronizar el JSON central que tiene las IDs de Drive de los adjuntos
          triggerCloudSync();
        }
      }
    }
  }

  // Abrir adjunto: Lazy loading de Drive y ejecución nativa
  Future<void> openAttachment(AttachmentInfo attachment) async {
    // 1. Verificar si está en la caché local
    var localFile = _storage.getCachedAttachmentFile(attachment);
    
    if (localFile == null || !localFile.existsSync()) {
      // 2. Si no está en caché y estamos conectados, descargarlo de Drive
      if (attachment.googleDriveFileId != null && _auth.isSignedIn) {
        _isDownloadingAttachment = true;
        notifyListeners();
        
        localFile = await _drive.downloadAttachment(attachment);
        
        _isDownloadingAttachment = false;
        notifyListeners();
      }
    }

    // 3. Lanzar el archivo con el programa por defecto de Windows
    if (localFile != null && localFile.existsSync()) {
      final uri = Uri.file(localFile.path);
      if (await launchUrl(uri)) {
        // Exito
      } else {
        throw Exception('No se pudo abrir el archivo con el lanzador nativo.');
      }
    } else {
      throw Exception('El archivo no está en caché y no se pudo descargar.');
    }
  }

  // Sincronizar de forma inmediata con Drive
  Future<void> triggerCloudSync() async {
    if (!_auth.isSignedIn) return;

    final syncedConfig = await _drive.syncConfig(_config);
    if (syncedConfig != null) {
      _config = syncedConfig;
      _setActiveTabFromConfig();
      notifyListeners();
    }
  }

  // Debounce para agrupar guardados antes de sincronizar
  void _debounceSync() {
    _syncDebounceTimer?.cancel();
    if (_auth.isSignedIn) {
      _syncDebounceTimer = Timer(const Duration(seconds: 2), () {
        triggerCloudSync();
      });
    }
  }

  @override
  void dispose() {
    _syncDebounceTimer?.cancel();
    super.dispose();
  }
}
