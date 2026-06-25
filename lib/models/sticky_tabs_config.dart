// Model: StickyTabsConfig
// Clase principal que serializa el JSON central de StickyTabs.

import 'interface_config.dart';
import 'note_tab.dart';

class StickyTabsConfig {
  final String versionFormato;
  final String ultimoDispositivoSincronizado;
  final DateTime ultimaModificacionGlobal;
  final InterfaceConfig configuracionInterfaz;
  final List<NoteTab> notasPestanas;

  StickyTabsConfig({
    required this.versionFormato,
    required this.ultimoDispositivoSincronizado,
    required this.ultimaModificacionGlobal,
    required this.configuracionInterfaz,
    required this.notasPestanas,
  });

  factory StickyTabsConfig.fromJson(Map<String, dynamic> json) {
    var notasList = json['notas_pestañas'] as List? ?? [];
    List<NoteTab> notas = notasList
        .map((n) => NoteTab.fromJson(n as Map<String, dynamic>))
        .toList();

    return StickyTabsConfig(
      versionFormato: json['version_formato'] as String? ?? '1.0.0',
      ultimoDispositivoSincronizado:
          json['ultimo_dispositivo_sincronizado'] as String? ?? 'Desconocido',
      ultimaModificacionGlobal: DateTime.parse(
          json['ultima_modificacion_global'] as String? ??
              DateTime.now().toIso8601String()),
      configuracionInterfaz: InterfaceConfig.fromJson(
          json['configuracion_interfaz'] as Map<String, dynamic>? ?? {}),
      notasPestanas: notas,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version_formato': versionFormato,
      'ultimo_dispositivo_sincronizado': ultimoDispositivoSincronizado,
      'ultima_modificacion_global': ultimaModificacionGlobal.toIso8601String(),
      'configuracion_interfaz': configuracionInterfaz.toJson(),
      'notas_pestañas': notasPestanas.map((n) => n.toJson()).toList(),
    };
  }

  StickyTabsConfig copyWith({
    String? versionFormato,
    String? ultimoDispositivoSincronizado,
    DateTime? ultimaModificacionGlobal,
    InterfaceConfig? configuracionInterfaz,
    List<NoteTab>? notasPestanas,
  }) {
    return StickyTabsConfig(
      versionFormato: versionFormato ?? this.versionFormato,
      ultimoDispositivoSincronizado:
          ultimoDispositivoSincronizado ?? this.ultimoDispositivoSincronizado,
      ultimaModificacionGlobal:
          ultimaModificacionGlobal ?? this.ultimaModificacionGlobal,
      configuracionInterfaz:
          configuracionInterfaz ?? this.configuracionInterfaz,
      notasPestanas: notasPestanas ?? this.notasPestanas,
    );
  }
}
