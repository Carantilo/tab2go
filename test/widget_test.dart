import 'package:flutter_test/flutter_test.dart';
import 'package:tab2go/models/note_tab.dart';

void main() {
  group('NoteTab Model Tests', () {
    test('Serialization and Deserialization', () {
      final now = DateTime.now();
      final tab = NoteTab(
        id: 'test-id',
        titulo: 'Test Note',
        colorPestana: '#B3E5FC',
        ordenPosicion: 0,
        fechaCreacion: now,
        ultimaModificacion: now,
        contenidoTexto: 'Hello World',
        archivosAdjuntos: [],
      );

      final json = tab.toJson();
      expect(json['id'], 'test-id');
      expect(json['titulo'], 'Test Note');
      expect(json['color_pestaña'], '#B3E5FC');
      expect(json['contenido_texto'], 'Hello World');

      final deserialized = NoteTab.fromJson(json);
      expect(deserialized.id, tab.id);
      expect(deserialized.titulo, tab.titulo);
      expect(deserialized.colorPestana, tab.colorPestana);
      expect(deserialized.contenidoTexto, tab.contenidoTexto);
    });

    test('copyWith copies attributes correctly', () {
      final now = DateTime.now();
      final tab = NoteTab(
        id: 'test-id',
        titulo: 'Test Note',
        colorPestana: '#B3E5FC',
        ordenPosicion: 0,
        fechaCreacion: now,
        ultimaModificacion: now,
        contenidoTexto: 'Hello World',
        archivosAdjuntos: [],
      );

      final updated = tab.copyWith(titulo: 'Updated Title', colorPestana: '#FFECB3');
      expect(updated.id, 'test-id');
      expect(updated.titulo, 'Updated Title');
      expect(updated.colorPestana, '#FFECB3');
      expect(updated.contenidoTexto, 'Hello World');
    });
  });
}
