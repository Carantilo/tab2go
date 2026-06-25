// Model: InterfaceConfig
// Representa la configuración visual de la interfaz.

class InterfaceConfig {
  final String colorTema;
  final bool siempreAlFrente;
  final double anchoVentana;
  final double altoVentana;
  final String? pestanaActivaId;
  final String tipoTipografia;
  final double tamanoTipografia;
  final bool mantenerConexion;

  InterfaceConfig({
    required this.colorTema,
    required this.siempreAlFrente,
    required this.anchoVentana,
    required this.altoVentana,
    this.pestanaActivaId,
    required this.tipoTipografia,
    required this.tamanoTipografia,
    required this.mantenerConexion,
  });

  factory InterfaceConfig.fromJson(Map<String, dynamic> json) {
    return InterfaceConfig(
      colorTema: json['color_tema'] as String? ?? '#B3E5FC',
      siempreAlFrente: json['siempre_al_frente'] as bool? ?? true,
      anchoVentana: (json['ancho_ventana'] as num? ?? 450.0).toDouble(),
      altoVentana: (json['alto_ventana'] as num? ?? 400.0).toDouble(),
      pestanaActivaId: json['pestaña_activa_id'] as String?,
      tipoTipografia: json['tipo_tipografia'] as String? ?? 'Inter',
      tamanoTipografia: (json['tamano_tipografia'] as num? ?? 14.0).toDouble(),
      mantenerConexion: json['mantener_conexion'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color_tema': colorTema,
      'siempre_al_frente': siempreAlFrente,
      'ancho_ventana': anchoVentana.toInt(),
      'alto_ventana': altoVentana.toInt(),
      'pestaña_activa_id': pestanaActivaId,
      'tipo_tipografia': tipoTipografia,
      'tamano_tipografia': tamanoTipografia,
      'mantener_conexion': mantenerConexion,
    };
  }

  InterfaceConfig copyWith({
    String? colorTema,
    bool? siempreAlFrente,
    double? anchoVentana,
    double? altoVentana,
    String? pestanaActivaId,
    String? tipoTipografia,
    double? tamanoTipografia,
    bool? mantenerConexion,
  }) {
    return InterfaceConfig(
      colorTema: colorTema ?? this.colorTema,
      siempreAlFrente: siempreAlFrente ?? this.siempreAlFrente,
      anchoVentana: anchoVentana ?? this.anchoVentana,
      altoVentana: altoVentana ?? this.altoVentana,
      pestanaActivaId: pestanaActivaId ?? this.pestanaActivaId,
      tipoTipografia: tipoTipografia ?? this.tipoTipografia,
      tamanoTipografia: tamanoTipografia ?? this.tamanoTipografia,
      mantenerConexion: mantenerConexion ?? this.mantenerConexion,
    );
  }
}
