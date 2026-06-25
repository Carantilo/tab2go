// Service: StorageService
// Maneja la persistencia en el disco local y cache de adjuntos.

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/attachment_info.dart';
import '../models/interface_config.dart';
import '../models/note_tab.dart';
import '../models/sticky_tabs_config.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Rutas locales de Windows
  late final Directory _roamingDir;
  late final Directory _localCacheDir;
  late final File _configFile;

  void initialize() {
    final appData = Platform.environment['APPDATA'] ?? '';
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';

    if (appData.isEmpty || localAppData.isEmpty) {
      throw StateError('Las variables de entorno APPDATA o LOCALAPPDATA no están definidas.');
    }

    final oldRoamingDir = Directory(p.join(appData, 'StickyTabs'));
    final oldLocalCacheDir = Directory(p.join(localAppData, 'StickyTabs', 'Cache'));

    _roamingDir = Directory(p.join(appData, 'Tab2Go'));
    _localCacheDir = Directory(p.join(localAppData, 'Tab2Go', 'Cache'));
    _configFile = File(p.join(_roamingDir.path, 'notas_config.json'));

    // Si no existe la carpeta nueva pero existe la vieja, realizamos la migración de datos automáticamente
    if (!_roamingDir.existsSync() && oldRoamingDir.existsSync()) {
      _roamingDir.createSync(recursive: true);
      // Migrar archivos de configuración, credenciales y tokens
      final filesToMigrate = ['notas_config.json', 'oauth_credentials.json', 'oauth_tokens.json'];
      for (final filename in filesToMigrate) {
        final oldFile = File(p.join(oldRoamingDir.path, filename));
        if (oldFile.existsSync()) {
          try {
            oldFile.copySync(p.join(_roamingDir.path, filename));
          } catch (_) {}
        }
      }
    }

    // Asegurar que la nueva carpeta de Roaming exista (por si no hubo migración)
    if (!_roamingDir.existsSync()) {
      _roamingDir.createSync(recursive: true);
    }

    // Migrar archivos de la caché
    if (!_localCacheDir.existsSync() && oldLocalCacheDir.existsSync()) {
      _localCacheDir.createSync(recursive: true);
      try {
        oldLocalCacheDir.listSync().forEach((entity) {
          if (entity is File) {
            entity.copySync(p.join(_localCacheDir.path, p.basename(entity.path)));
          }
        });
      } catch (_) {}
    }

    // Asegurar que la nueva carpeta de caché exista
    if (!_localCacheDir.existsSync()) {
      _localCacheDir.createSync(recursive: true);
    }
  }

  Directory get localCacheDir => _localCacheDir;
  File get configFile => _configFile;

  // Cargar configuración local. Si no existe, genera una por defecto.
  StickyTabsConfig loadConfig() {
    if (!_configFile.existsSync()) {
      final defaultConfig = _createDefaultConfig();
      saveConfig(defaultConfig);
      return defaultConfig;
    }

    try {
      final content = _configFile.readAsStringSync();
      final jsonMap = json.decode(content) as Map<String, dynamic>;
      return StickyTabsConfig.fromJson(jsonMap);
    } catch (e) {
      // Si el archivo está corrupto o hay error, retornar uno por defecto para no romper el inicio
      final defaultConfig = _createDefaultConfig();
      saveConfig(defaultConfig);
      return defaultConfig;
    }
  }

  // Guardar configuración localmente
  void saveConfig(StickyTabsConfig config) {
    try {
      final jsonStr = const JsonEncoder.withIndent('  ').convert(config.toJson());
      _configFile.writeAsStringSync(jsonStr);
    } catch (e) {
      stderr.writeln('Error al guardar configuración: $e');
    }
  }

  // Genera la configuración por defecto (Post-it azul claro inicial)
  StickyTabsConfig _createDefaultConfig() {
    final noteId = const Uuid().v4();
    final defaultTab = NoteTab(
      id: noteId,
      titulo: 'Nota 1',
      colorPestana: '#B3E5FC', // Azul claro (Azul Cielo)
      ordenPosicion: 0,
      fechaCreacion: DateTime.now(),
      ultimaModificacion: DateTime.now(),
      contenidoTexto: '# ¡Bienvenido a StickyTabs!\n\nEscribe tus notas aquí...',
      archivosAdjuntos: [],
    );

    return StickyTabsConfig(
      versionFormato: '1.0.0',
      ultimoDispositivoSincronizado: Platform.localHostname,
      ultimaModificacionGlobal: DateTime.fromMillisecondsSinceEpoch(0),
      configuracionInterfaz: InterfaceConfig(
        colorTema: '#B3E5FC',
        siempreAlFrente: true,
        anchoVentana: 450,
        altoVentana: 400,
        pestanaActivaId: noteId,
        tipoTipografia: 'Inter',
        tamanoTipografia: 14.0,
        mantenerConexion: true,
      ),
      notasPestanas: [defaultTab],
    );
  }

  // Guardar credenciales OAuth locales
  File getOAuthCredentialsFile() {
    return File(p.join(_roamingDir.path, 'oauth_credentials.json'));
  }

  Map<String, String>? loadOAuthCredentials() {
    final credFile = getOAuthCredentialsFile();
    if (!credFile.existsSync()) return null;
    try {
      final data = json.decode(credFile.readAsStringSync()) as Map<String, dynamic>;
      return {
        'client_id': data['client_id'] as String? ?? '',
        'client_secret': data['client_secret'] as String? ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  void saveOAuthCredentials(String clientId, String clientSecret) {
    final credFile = getOAuthCredentialsFile();
    credFile.writeAsStringSync(json.encode({
      'client_id': clientId,
      'client_secret': clientSecret,
    }));
  }

  void clearOAuthData() {
    try {
      final credFile = getOAuthCredentialsFile();
      if (credFile.existsSync()) {
        credFile.deleteSync();
      }
      final tokenFile = File(p.join(_roamingDir.path, 'oauth_tokens.json'));
      if (tokenFile.existsSync()) {
        tokenFile.deleteSync();
      }
    } catch (_) {}
  }

  // Copiar archivo arrastrado (Drag & Drop) a la caché local
  Future<AttachmentInfo> addAttachmentFromLocalFile(File localFile) async {
    final String filename = p.basename(localFile.path);
    final String adjuntoId = const Uuid().v4();
    
    // El archivo se guarda en caché como: AppData\Local\StickyTabs\Cache\uuid_filename
    final String cachedPath = p.join(_localCacheDir.path, '${adjuntoId}_$filename');
    final File cachedFile = await localFile.copy(cachedPath);

    // Calcular MD5
    final bytes = await cachedFile.readAsBytes();
    final md5Checksum = md5.convert(bytes).toString();

    // Obtener mime type aproximado por extensión
    final mime = _getMimeTypeByExtension(p.extension(filename));

    return AttachmentInfo(
      adjuntoId: adjuntoId,
      nombreArchivo: filename,
      tipoMimo: mime,
      pesoBytes: bytes.length,
      md5Checksum: md5Checksum,
      fechaAdjuntado: DateTime.now(),
    );
  }

  // Verificar si un adjunto ya está en la caché local
  File? getCachedAttachmentFile(AttachmentInfo attachment) {
    final path = p.join(_localCacheDir.path, '${attachment.adjuntoId}_${attachment.nombreArchivo}');
    final file = File(path);
    if (file.existsSync()) {
      return file;
    }
    return null;
  }

  // Retorna el path donde debería estar el archivo en caché aunque no exista
  String getAttachmentCachePath(AttachmentInfo attachment) {
    return p.join(_localCacheDir.path, '${attachment.adjuntoId}_${attachment.nombreArchivo}');
  }

  String _getMimeTypeByExtension(String ext) {
    switch (ext.toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.xlsx':
      case '.xls':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.docx':
      case '.doc':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}
