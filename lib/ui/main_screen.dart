// UI: MainScreen
// Pantalla principal de la aplicación StickyTabs.

import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note_tab.dart';
import '../services/auth_service.dart';
import '../services/drive_service.dart';
import '../services/notes_state.dart';
import '../services/window_service.dart';
import 'settings_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final NotesState _notesState = NotesState();
  final AuthService _auth = AuthService();
  final DriveService _drive = DriveService();
  final WindowService _window = WindowService();

  final TextEditingController _textController = TextEditingController();
  final FocusNode _editorFocusNode = FocusNode();
  
  String? _editingTabId;
  final TextEditingController _renameController = TextEditingController();
  final FocusNode _renameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _notesState.addListener(_onStateChanged);
    _auth.addListener(_onAuthChanged);
    _drive.addListener(_onDriveChanged);

    // Inicializar controlador de texto
    if (_notesState.activeTab != null) {
      _textController.text = _notesState.activeTab!.contenidoTexto;
    }
  }

  @override
  void dispose() {
    _notesState.removeListener(_onStateChanged);
    _auth.removeListener(_onAuthChanged);
    _drive.removeListener(_onDriveChanged);
    _textController.dispose();
    _editorFocusNode.dispose();
    _renameController.dispose();
    _renameFocusNode.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    setState(() {
      // Si el tab activo cambió o el contenido difiere del controlador (ej. por sync)
      if (_notesState.activeTab != null && 
          _textController.text != _notesState.activeTab!.contenidoTexto) {
        final selection = _textController.selection;
        _textController.text = _notesState.activeTab!.contenidoTexto;
        // Conservar la posición del cursor si era válido
        if (selection.baseOffset <= _textController.text.length) {
          _textController.selection = selection;
        }
      }
    });
  }

  void _onAuthChanged() => setState(() {});
  void _onDriveChanged() => setState(() {});

  // Parsear color hexadecimal a objeto Color
  Color _parseColor(String hex) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFFFFF9C4); // Amarillo por defecto
    }
  }

  // Convertir Color a hexadecimal string
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2, 8).toUpperCase()}';
  }

  // Colores Post-it por defecto
  final List<String> _defaultPostItColors = [
    '#FFF9C4', // Amarillo clásico
    '#FFECB3', // Durazno
    '#C8E6C9', // Verde Menta
    '#B3E5FC', // Azul Cielo
    '#E1BEE7', // Lavanda
    '#F8BBD0', // Rosa Pastel
  ];

  void _showColorPicker(NoteTab tab) {
    showDialog(
      context: context,
      builder: (context) {
        Color selectedColor = _parseColor(tab.colorPestana);
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(
            'Color de Pestaña',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Colores predefinidos
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _defaultPostItColors.map((hex) {
                    final color = _parseColor(hex);
                    return GestureDetector(
                      onTap: () {
                        _notesState.updateTabColor(tab.id, hex);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: tab.colorPestana == hex
                                ? Colors.white
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.grey),
                const SizedBox(height: 10),
                // Color Picker completo
                ColorPicker(
                  pickerColor: selectedColor,
                  onColorChanged: (color) {
                    selectedColor = color;
                  },
                  pickerAreaHeightPercent: 0.7,
                  enableAlpha: false,
                  displayThumbColor: true,
                  paletteType: PaletteType.hsvWithHue,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _notesState.updateTabColor(tab.id, _colorToHex(selectedColor));
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: Text(
                'Seleccionar',
                style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _startRename(NoteTab tab) {
    setState(() {
      _editingTabId = tab.id;
      _renameController.text = tab.titulo;
      _renameFocusNode.requestFocus();
    });
  }

  void _finishRename(String id) {
    if (_renameController.text.trim().isNotEmpty) {
      _notesState.renameTab(id, _renameController.text.trim());
    }
    setState(() {
      _editingTabId = null;
    });
  }

  void _showTabContextMenu(BuildContext context, NoteTab tab, Offset tapPosition) {
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        tapPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: const Color(0xFF2C2C2C),
      items: [
        PopupMenuItem(
          onTap: () => Future.delayed(Duration.zero, () => _startRename(tab)),
          child: Row(
            children: [
              const Icon(Icons.edit, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Renombrar', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () => Future.delayed(Duration.zero, () => _showColorPicker(tab)),
          child: Row(
            children: [
              const Icon(Icons.color_lens, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Cambiar Color', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            if (_notesState.tabs.length > 1) {
              Future.delayed(
                Duration.zero,
                () => _confirmDeleteTab(tab),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No puedes cerrar la última pestaña activa.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
          child: Row(
            children: [
              const Icon(Icons.delete, color: Colors.redAccent, size: 18),
              const SizedBox(width: 8),
              Text('Cerrar pestaña', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDeleteTab(NoteTab tab) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text('¿Cerrar pestaña?', style: GoogleFonts.outfit(color: Colors.white)),
          content: Text(
            '¿Seguro que deseas eliminar "${tab.titulo}"? Esta acción se guardará localmente y se sincronizará.',
            style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                _notesState.removeTab(tab.id);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text('Eliminar', style: GoogleFonts.outfit(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSyncIcon() {
    IconData icon;
    Color color;

    switch (_drive.state) {
      case SyncState.synced:
        icon = Icons.cloud_done;
        color = Colors.greenAccent;
        break;
      case SyncState.syncing:
        icon = Icons.sync;
        color = Colors.blueAccent;
        break;
      case SyncState.error:
        icon = Icons.cloud_off;
        color = Colors.redAccent;
        break;
      case SyncState.disconnected:
        icon = Icons.cloud_queue;
        color = Colors.grey;
        break;
    }

    return Icon(icon, color: color, size: 16);
  }

  String _getSyncText() {
    switch (_drive.state) {
      case SyncState.synced:
        return 'Sincronizado';
      case SyncState.syncing:
        return 'Sincronizando...';
      case SyncState.error:
        return 'Error de sincronización';
      case SyncState.disconnected:
        return 'Sin sincronizar';
    }
  }

  Future<void> _toggleGoogleSession() async {
    if (_auth.isSignedIn) {
      await _auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión de Google cerrada.')),
        );
      }
    } else {
      if (!_auth.isConfigured) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => const SettingsDialog(),
          );
        }
      } else {
        try {
          await _auth.signIn();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al iniciar sesión: $e')),
            );
          }
        }
      }
    }
  }

  void _showFontSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentFont = _notesState.config.configuracionInterfaz.tipoTipografia;
            final currentSize = _notesState.config.configuracionInterfaz.tamanoTipografia;
            
            final List<String> availableFonts = ['Inter', 'Roboto', 'Outfit', 'Fira Code', 'Lora'];

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text(
                'Fuente de las Notas',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector de Familia Tipográfica y Tamaño de Letra en un mismo Box
                  Text(
                    'Fuente y Tamaño:',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Row(
                      children: [
                        // Selector de Tipografía (3/4 de ancho)
                        Expanded(
                          flex: 3,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: currentFont,
                              dropdownColor: const Color(0xFF2C2C2C),
                              isExpanded: true,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                              items: availableFonts.map((font) {
                                TextStyle style;
                                switch (font) {
                                  case 'Roboto': style = GoogleFonts.roboto(); break;
                                  case 'Outfit': style = GoogleFonts.outfit(); break;
                                  case 'Fira Code': style = GoogleFonts.firaCode(); break;
                                  case 'Lora': style = GoogleFonts.lora(); break;
                                  default: style = GoogleFonts.inter(); break;
                                }
                                return DropdownMenuItem<String>(
                                  value: font,
                                  child: Text(font, style: style.copyWith(color: Colors.white)),
                                );
                              }).toList(),
                              onChanged: (value) async {
                                if (value != null) {
                                  setDialogState(() {});
                                  await _notesState.updateTypography(value);
                                }
                              },
                            ),
                          ),
                        ),
                        // Línea divisora
                        Container(
                          height: 24,
                          width: 1,
                          color: Colors.grey[800],
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        // Selector de Tamaño (1/4 de ancho)
                        SizedBox(
                          width: 55,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<double>(
                              value: currentSize.roundToDouble().clamp(10.0, 28.0),
                              dropdownColor: const Color(0xFF2C2C2C),
                              isExpanded: true,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                              items: List.generate(19, (index) => 10.0 + index).map((size) {
                                return DropdownMenuItem<double>(
                                  value: size,
                                  child: Text('${size.toInt()}', style: GoogleFonts.inter(color: Colors.white)),
                                );
                              }).toList(),
                              onChanged: (value) async {
                                if (value != null) {
                                  setDialogState(() {});
                                  await _notesState.updateFontSize(value);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Aceptar',
                    style: GoogleFonts.outfit(color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  TextStyle _getNotesTextStyle() {
    final fontName = _notesState.config.configuracionInterfaz.tipoTipografia;
    final double fontSize = _notesState.config.configuracionInterfaz.tamanoTipografia;
    const double height = 1.5;
    const Color color = blackDE;

    switch (fontName) {
      case 'Roboto':
        return GoogleFonts.roboto(fontSize: fontSize, height: height, color: color);
      case 'Outfit':
        return GoogleFonts.outfit(fontSize: fontSize, height: height, color: color);
      case 'Fira Code':
        return GoogleFonts.firaCode(fontSize: fontSize, height: height, color: color);
      case 'Lora':
        return GoogleFonts.lora(fontSize: fontSize, height: height, color: color);
      case 'Inter':
      default:
        return GoogleFonts.inter(fontSize: fontSize, height: height, color: color);
    }
  }



  @override
  Widget build(BuildContext context) {
    final activeTab = _notesState.activeTab;
    if (activeTab == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final Color postItColor = _parseColor(activeTab.colorPestana);

    // Construir la ventana frameless
    return Scaffold(
      backgroundColor: Colors.transparent, // Permite la transparencia exterior
      body: DropTarget(
        onDragDone: (detail) async {
          for (final file in detail.files) {
            await _notesState.attachFileToActiveTab(File(file.path));
          }
        },
        child: Container(
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: postItColor,
          ),
          child: Column(
            children: [
              // 1. Cabecera Translúcida (Custom Title Bar + Drag Area)
              GestureDetector(
                onPanStart: (_) => _window.startDragging(),
                child: Container(
                  height: 32, // Altura reducida adicionalmente un 20% (de 40 a 32)
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12), // Translúcido sobre el color del post-it
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
                      // Menú desplegable con los iconos de configuración y sync
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.menu, size: 14, color: Colors.black87),
                        tooltip: 'Menú principal',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 220),
                        color: const Color(0xFF2C2C2C),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            enabled: false,
                            child: Row(
                              children: [
                                _buildSyncIcon(),
                                const SizedBox(width: 8),
                                Text(
                                  _getSyncText(),
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'sync',
                            child: Row(
                              children: [
                                const Icon(Icons.sync, size: 14, color: Colors.white),
                                const SizedBox(width: 8),
                                Text('Sincronizar ahora', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'google_session',
                            child: Row(
                              children: [
                                Icon(
                                  _auth.isSignedIn ? Icons.logout : Icons.login,
                                  size: 14,
                                  color: _auth.isSignedIn ? Colors.redAccent : Colors.greenAccent,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _auth.isSignedIn ? 'Cerrar sesión de Google' : 'Iniciar sesión de Google',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'settings',
                            child: Row(
                              children: [
                                const Icon(Icons.settings, size: 14, color: Colors.white),
                                const SizedBox(width: 8),
                                Text('Ajustes de Google Cloud', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'color_picker',
                            child: Row(
                              children: [
                                const Icon(Icons.color_lens, size: 14, color: Colors.white),
                                const SizedBox(width: 8),
                                Text('Color de esta hoja...', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'font_settings',
                            child: Row(
                              children: [
                                const Icon(Icons.font_download, size: 14, color: Colors.white),
                                const SizedBox(width: 8),
                                Text('Fuente de las notas...', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) async {
                          if (value == 'sync') {
                            _notesState.triggerCloudSync();
                          } else if (value == 'google_session') {
                            _toggleGoogleSession();
                          } else if (value == 'settings') {
                            showDialog(
                              context: context,
                              builder: (_) => const SettingsDialog(),
                            );
                          } else if (value == 'color_picker') {
                            _showColorPicker(activeTab);
                          } else if (value == 'font_settings') {
                            _showFontSettingsDialog();
                          }
                        },
                      ),
                      const Spacer(),
                      // Título corto
                      Text(
                        'Tab2Go',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5, // Tipografía reducida acorde al tamaño
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      // Pin de Siempre al Frente (ahora a la derecha)
                      Tooltip(
                        message: _notesState.config.configuracionInterfaz.siempreAlFrente
                            ? 'Quitar "Siempre al frente"'
                            : 'Fijar "Siempre al frente"',
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
                          icon: Icon(
                            _notesState.config.configuracionInterfaz.siempreAlFrente
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            size: 14,
                            color: _notesState.config.configuracionInterfaz.siempreAlFrente
                                ? Colors.amber[600]
                                : Colors.black87,
                          ),
                          onPressed: () async {
                            final currentVal =
                                _notesState.config.configuracionInterfaz.siempreAlFrente;
                            await _notesState.toggleAlwaysOnTop(!currentVal);
                          },
                        ),
                      ),
                      // Minimizar
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
                        icon: const Icon(Icons.remove, size: 14, color: Colors.black87),
                        onPressed: () => _window.minimize(),
                      ),
                      // Cerrar
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
                        icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                        onPressed: () => _window.close(),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
              
              // 2. Fila de Pestañas dinámicas (Notepad++ Style)
              Container(
                height: 28,
                color: Colors.black.withOpacity(0.05),
                child: Row(
                  children: [
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        buildDefaultDragHandles: false,
                        itemCount: _notesState.tabs.length,
                        onReorder: (oldIndex, newIndex) {
                          _notesState.reorderTabs(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final tab = _notesState.notesStateTabsList[index];
                          final isSelected = tab.id == activeTab.id;
                          final tabColor = _parseColor(tab.colorPestana);

                          return ReorderableDragStartListener(
                            key: ValueKey(tab.id),
                            index: index,
                            child: GestureDetector(
                              onTap: () => _notesState.selectTab(tab.id),
                              onDoubleTap: () => _startRename(tab),
                              onSecondaryTapDown: (details) {
                                _showTabContextMenu(context, tab, details.globalPosition);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                margin: const EdgeInsets.only(top: 3, left: 2, right: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? postItColor : tabColor.withOpacity(0.65),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                  border: isSelected
                                      ? Border(
                                          top: BorderSide(color: Colors.black.withOpacity(0.15), width: 1.5),
                                          left: BorderSide(color: Colors.black.withOpacity(0.15), width: 1.5),
                                          right: BorderSide(color: Colors.black.withOpacity(0.15), width: 1.5),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_editingTabId == tab.id)
                                      SizedBox(
                                        width: 50,
                                        height: 16,
                                        child: TextField(
                                          controller: _renameController,
                                          focusNode: _renameFocusNode,
                                          style: GoogleFonts.inter(
                                            fontSize: 10.0,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: Colors.black87,
                                          ),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onSubmitted: (_) => _finishRename(tab.id),
                                          onEditingComplete: () => _finishRename(tab.id),
                                        ),
                                      )
                                    else
                                      Text(
                                        tab.titulo,
                                        style: GoogleFonts.inter(
                                          fontSize: 10.0,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    const SizedBox(width: 5),
                                    // Botón rápido de cerrar pestaña
                                    GestureDetector(
                                      onTap: () {
                                        if (_notesState.tabs.length > 1) {
                                          _notesState.removeTab(tab.id);
                                        }
                                      },
                                      child: const Icon(Icons.close, size: 10, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Botón para añadir pestaña
                    IconButton(
                      icon: const Icon(Icons.add, size: 16, color: Colors.black87),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
                      onPressed: () {
                        final nextIndex = _notesState.tabs.length + 1;
                        _notesState.addTab('Nota $nextIndex', '#B3E5FC');
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),

              // 3. Editor de Notas (Markdown text field)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    controller: _textController,
                    focusNode: _editorFocusNode,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: _getNotesTextStyle(),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Comienza a escribir tu Post-it...',
                      hintStyle: TextStyle(color: Colors.black38),
                    ),
                    onChanged: (val) {
                      _notesState.updateActiveTabContent(val);
                    },
                  ),
                ),
              ),

              // 4. Panel de Archivos Adjuntos
              if (activeTab.archivosAdjuntos.isNotEmpty)
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    border: Border(top: BorderSide(color: Colors.black.withOpacity(0.08))),
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: activeTab.archivosAdjuntos.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                    itemBuilder: (context, index) {
                      final attachment = activeTab.archivosAdjuntos[index];
                      return Tooltip(
                        message: '${attachment.nombreArchivo} (${(attachment.pesoBytes / 1024).toStringAsFixed(1)} KB) - Doble click para abrir',
                        child: GestureDetector(
                          onDoubleTap: () async {
                            try {
                              await _notesState.openAttachment(attachment);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al abrir adjunto: $e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8.0),
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _getAttachmentIcon(attachment.nombreArchivo),
                                const SizedBox(width: 6),
                                Text(
                                  attachment.nombreArchivo,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
              // Cargando Descarga en progreso
              if (_notesState.isDownloadingAttachment)
                LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber[800]!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getAttachmentIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    IconData icon;
    Color color;

    switch (ext) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red[800]!;
        break;
      case 'xlsx':
      case 'xls':
        icon = Icons.grid_on;
        color = Colors.green[800]!;
        break;
      case 'docx':
      case 'doc':
        icon = Icons.description;
        color = Colors.blue[800]!;
        break;
      case 'png':
      case 'jpg':
      case 'jpeg':
        icon = Icons.image;
        color = Colors.purple[800]!;
        break;
      default:
        icon = Icons.attach_file;
        color = Colors.black87;
    }

    return Icon(icon, size: 14, color: color);
  }
}

// Extensión rápida para acceder a la lista cruda de pestañas sin ordenar si es necesario
extension on NotesState {
  List<NoteTab> get notesStateTabsList => tabs;
}

// Color negro con opacidad de énfasis típica de material (87%)
const Color blackDE = Color(0xDE000000);
