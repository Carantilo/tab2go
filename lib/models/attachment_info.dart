// Model: AttachmentInfo
// Representa un archivo adjunto asociado a una nota.

class AttachmentInfo {
  final String adjuntoId;
  final String nombreArchivo;
  final String tipoMimo;
  final int pesoBytes;
  final String? googleDriveFileId;
  final String? md5Checksum;
  final DateTime fechaAdjuntado;

  AttachmentInfo({
    required this.adjuntoId,
    required this.nombreArchivo,
    required this.tipoMimo,
    required this.pesoBytes,
    this.googleDriveFileId,
    this.md5Checksum,
    required this.fechaAdjuntado,
  });

  factory AttachmentInfo.fromJson(Map<String, dynamic> json) {
    return AttachmentInfo(
      adjuntoId: json['adjunto_id'] as String,
      nombreArchivo: json['nombre_archivo'] as String,
      tipoMimo: json['tipo_mimo'] as String,
      pesoBytes: json['peso_bytes'] as int,
      googleDriveFileId: json['google_drive_file_id'] as String?,
      md5Checksum: json['md5_checksum'] as String?,
      fechaAdjuntado: DateTime.parse(json['fecha_adjuntado'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'adjunto_id': adjuntoId,
      'nombre_archivo': nombreArchivo,
      'tipo_mimo': tipoMimo,
      'peso_bytes': pesoBytes,
      'google_drive_file_id': googleDriveFileId,
      'md5_checksum': md5Checksum,
      'fecha_adjuntado': fechaAdjuntado.toIso8601String(),
    };
  }

  AttachmentInfo copyWith({
    String? adjuntoId,
    String? nombreArchivo,
    String? tipoMimo,
    int? pesoBytes,
    String? googleDriveFileId,
    String? md5Checksum,
    DateTime? fechaAdjuntado,
  }) {
    return AttachmentInfo(
      adjuntoId: adjuntoId ?? this.adjuntoId,
      nombreArchivo: nombreArchivo ?? this.nombreArchivo,
      tipoMimo: tipoMimo ?? this.tipoMimo,
      pesoBytes: pesoBytes ?? this.pesoBytes,
      googleDriveFileId: googleDriveFileId ?? this.googleDriveFileId,
      md5Checksum: md5Checksum ?? this.md5Checksum,
      fechaAdjuntado: fechaAdjuntado ?? this.fechaAdjuntado,
    );
  }
}
