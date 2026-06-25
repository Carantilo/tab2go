// Service: DriveService
// Gestiona la sincronización con Google Drive API v3 (appDataFolder).

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'auth_service.dart';
import 'storage_service.dart';
import '../models/attachment_info.dart';
import '../models/sticky_tabs_config.dart';

enum SyncState { disconnected, synced, syncing, error }

class DriveService extends ChangeNotifier {
  static final DriveService _instance = DriveService._internal();
  factory DriveService() => _instance;
  DriveService._internal();

  SyncState _state = SyncState.disconnected;
  SyncState get state => _state;

  String? _lastError;
  String? get lastError => _lastError;

  void updateState(SyncState newState, [String? error]) {
    _state = newState;
    _lastError = error;
    notifyListeners();
  }

  // Obtiene la instancia de DriveApi si el usuario está autenticado
  Future<drive.DriveApi?> _getDriveApi() async {
    final client = await AuthService().getAuthenticatedClient();
    if (client == null) {
      updateState(SyncState.disconnected);
      return null;
    }
    return drive.DriveApi(client);
  }

  // Sincroniza el JSON central de notas
  Future<StickyTabsConfig?> syncConfig(StickyTabsConfig localConfig) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return null;

    updateState(SyncState.syncing);

    try {
      // Buscar notas_config.json en appDataFolder
      final fileList = await driveApi.files.list(
        q: "name = 'notas_config.json' and trashed = false",
        spaces: 'appDataFolder',
        $fields: 'files(id, name, modifiedTime)',
      );

      final files = fileList.files;
      if (files == null || files.isEmpty) {
        // No existe en Drive, subir el archivo local actual
        await _uploadConfig(driveApi, localConfig);
        updateState(SyncState.synced);
        return localConfig;
      }

      final remoteFile = files.first;
      final remoteFileId = remoteFile.id!;

      // Descargar config remota
      final remoteConfig = await _downloadConfig(driveApi, remoteFileId);
      if (remoteConfig == null) {
        throw Exception('No se pudo descargar la configuración remota.');
      }

      // Comparar marcas de tiempo
      var localTime = localConfig.ultimaModificacionGlobal;
      final remoteTime = remoteConfig.ultimaModificacionGlobal;

      // Si la configuración local es la inicial por defecto (sin editar),
      // forzamos su fecha a la época (1970) para priorizar siempre la descarga desde la nube.
      const defaultWelcomeText = '# ¡Bienvenido a StickyTabs!\n\nEscribe tus notas aquí...';
      final isDefaultConfig = localConfig.notasPestanas.length == 1 &&
          (localConfig.notasPestanas.first.contenidoTexto.trim() == defaultWelcomeText.trim() ||
           localConfig.notasPestanas.first.contenidoTexto.trim().isEmpty);

      if (isDefaultConfig) {
        localTime = DateTime.fromMillisecondsSinceEpoch(0);
      }

      if (remoteTime.isAfter(localTime)) {
        // Remoto es más nuevo: sobreescribir local y retornar el remoto para actualizar UI
        StorageService().saveConfig(remoteConfig);
        updateState(SyncState.synced);
        return remoteConfig;
      } else if (localTime.isAfter(remoteTime)) {
        // Local es más nuevo: actualizar el remoto
        await _updateConfig(driveApi, remoteFileId, localConfig);
        updateState(SyncState.synced);
        return localConfig;
      } else {
        // Son idénticos en tiempo, no hacer nada
        updateState(SyncState.synced);
        return localConfig;
      }
    } catch (e) {
      updateState(SyncState.error, e.toString());
      return null;
    }
  }

  // Sube por primera vez el JSON a Drive
  Future<void> _uploadConfig(drive.DriveApi driveApi, StickyTabsConfig config) async {
    final fileToUpload = drive.File()
      ..name = 'notas_config.json'
      ..parents = ['appDataFolder'];

    final jsonContent = json.encode(config.toJson());
    final utf8Bytes = utf8.encode(jsonContent);
    final media = drive.Media(
      Stream.value(utf8Bytes),
      utf8Bytes.length,
      contentType: 'application/json',
    );

    await driveApi.files.create(
      fileToUpload,
      uploadMedia: media,
    );
  }

  // Actualiza el JSON existente en Drive
  Future<void> _updateConfig(drive.DriveApi driveApi, String fileId, StickyTabsConfig config) async {
    final jsonContent = json.encode(config.toJson());
    final utf8Bytes = utf8.encode(jsonContent);
    final media = drive.Media(
      Stream.value(utf8Bytes),
      utf8Bytes.length,
      contentType: 'application/json',
    );

    await driveApi.files.update(
      drive.File(),
      fileId,
      uploadMedia: media,
    );
  }

  // Descarga el JSON de Drive
  Future<StickyTabsConfig?> _downloadConfig(drive.DriveApi driveApi, String fileId) async {
    try {
      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> bytes = [];
      await for (var chunk in response.stream) {
        bytes.addAll(chunk);
      }
      final jsonMap = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
      return StickyTabsConfig.fromJson(jsonMap);
    } catch (_) {
      return null;
    }
  }

  // Sube un archivo adjunto de forma binaria e independiente a Drive (Lazy Upload)
  Future<AttachmentInfo?> uploadAttachment(AttachmentInfo attachment) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return null;

    final localFile = StorageService().getCachedAttachmentFile(attachment);
    if (localFile == null || !localFile.existsSync()) return null;

    try {
      updateState(SyncState.syncing);

      final fileMetadata = drive.File()
        ..name = '${attachment.adjuntoId}_${attachment.nombreArchivo}'
        ..parents = ['appDataFolder'];

      final media = drive.Media(
        localFile.openRead(),
        localFile.lengthSync(),
        contentType: attachment.tipoMimo,
      );

      final uploadedFile = await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
        $fields: 'id, md5Checksum',
      );

      updateState(SyncState.synced);

      return attachment.copyWith(
        googleDriveFileId: uploadedFile.id,
        md5Checksum: uploadedFile.md5Checksum,
      );
    } catch (e) {
      updateState(SyncState.error, e.toString());
      return null;
    }
  }

  // Descarga un archivo adjunto desde Drive a la caché local cuando se requiere (Lazy Loading)
  Future<File?> downloadAttachment(AttachmentInfo attachment) async {
    if (attachment.googleDriveFileId == null) return null;

    final driveApi = await _getDriveApi();
    if (driveApi == null) return null;

    updateState(SyncState.syncing);

    try {
      final response = await driveApi.files.get(
        attachment.googleDriveFileId!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final cachePath = StorageService().getAttachmentCachePath(attachment);
      final destFile = File(cachePath);

      // Crear carpetas contenedoras si no existen
      if (!destFile.parent.existsSync()) {
        destFile.parent.createSync(recursive: true);
      }

      // Pipiar el stream directamente al archivo local para evitar sobrecarga en RAM
      final IOSink sink = destFile.openWrite();
      await response.stream.pipe(sink);
      await sink.close();

      updateState(SyncState.synced);
      return destFile;
    } catch (e) {
      updateState(SyncState.error, e.toString());
      return null;
    }
  }
}
