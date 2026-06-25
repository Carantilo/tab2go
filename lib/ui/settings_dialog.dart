// UI: SettingsDialog
// Diálogo de configuración para las credenciales de Google OAuth.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/notes_state.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _clientIdController;
  late final TextEditingController _clientSecretController;
  bool _isSaving = false;
  bool _mantenerConexion = true;

  @override
  void initState() {
    super.initState();
    final creds = StorageService().loadOAuthCredentials();
    _clientIdController = TextEditingController(text: creds?['client_id'] ?? '');
    _clientSecretController = TextEditingController(text: creds?['client_secret'] ?? '');
    _mantenerConexion = NotesState().config.configuracionInterfaz.mantenerConexion;
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await NotesState().updateKeepConnection(_mantenerConexion);
      await AuthService().updateCredentials(
        _clientIdController.text.trim(),
        _clientSecretController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credenciales guardadas con éxito.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar credenciales: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E), // Fondo oscuro premium
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajustes de Google Drive',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Introduce tus credenciales de Google OAuth de escritorio para sincronizar tus notas.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _clientIdController,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Client ID',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[800]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.amber),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorStyle: const TextStyle(color: Colors.redAccent),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clientSecretController,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Client Secret',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[800]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.amber),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorStyle: const TextStyle(color: Colors.redAccent),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: Text(
                  'Mantener datos de conexión al salir',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                ),
                subtitle: Text(
                  'Si se desmarca, se borrarán tus credenciales y sesión al cerrar la app.',
                  style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 10),
                ),
                value: _mantenerConexion,
                activeColor: Colors.amber,
                checkColor: Colors.black,
                side: BorderSide(color: Colors.grey[600]!, width: 1.5),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (bool? value) {
                  setState(() {
                    _mantenerConexion = value ?? true;
                  });
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[400],
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            'Guardar',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
