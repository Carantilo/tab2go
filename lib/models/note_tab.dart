// Model: NoteTab
// Representa una pestaña de nota individual.

import 'attachment_info.dart';

class NoteTab {
  final String id;
  final String titulo;
  final String colorPestana; // Hex String (ej. #FFF9C4)
  final int ordenPosicion;
  final DateTime fechaCreacion;
  final DateTime ultimaModificacion;
  final String contenidoTexto;
  final List<AttachmentInfo> archivosAdjuntos;

  NoteTab({
    required this.id,
    required this.titulo,
    required this.colorPestana,
    required this.ordenPosicion,
    required this.fechaCreacion,
    required this.ultimaModificacion,
    required this.contenidoTexto,
    required this.archivosAdjuntos,
  });

  factory NoteTab.fromJson(Map<String, dynamic> json) {
    var adjuntosList = json['archivos_adjuntos'] as List? ?? [];
    List<AttachmentInfo> adjuntos = adjuntosList
        .map((a) => AttachmentInfo.fromJson(a as Map<String, dynamic>))
        .toList();

    return NoteTab(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      colorPestana: json['color_pestaña'] as String,
      ordenPosicion: json['orden_posicion'] as int,
      fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
      ultimaModificacion: DateTime.parse(json['ultima_modificacion'] as String),
      contenidoTexto: json['contenido_texto'] as String,
      archivosAdjuntos: adjuntos,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'color_pestaña': colorPestana,
      'orden_posicion': ordenPosicion,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'ultima_modificacion': ultimaModificacion.toIso8601String(),
      'contenido_texto': contenidoTexto,
      'archivos_adjuntos': archivosAdjuntos.map((a) => a.toJson()).toList(),
    };
  }

  NoteTab copyWith({
    String? id,
    String? titulo,
    String? colorPestana,
    int? ordenPosicion,
    DateTime? fechaCreacion,
    DateTime? ultimaModificacion,
    String? contenidoTexto,
    List<AttachmentInfo>? archivosAdjuntos,
  }) {
    return NoteTab(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      colorPestana: colorPestana ?? this.colorPestana,
      ordenPosicion: ordenPosicion ?? this.ordenPosicion,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      ultimaModificacion: ultimaModificacion ?? this.ultimaModificacion,
      contenidoTexto: contenidoTexto ?? this.contenidoTexto,
      archivosAdjuntos: archivosAdjuntos ?? this.archivosAdjuntos,
    );
  }
}
