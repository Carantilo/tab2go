# Plan de Implementación: StickyTabs para Windows

Este documento detalla el plan técnico para construir **StickyTabs**, una aplicación ligera de notas adhesivas con pestañas dinámicas, persistencia local en AppData, y sincronización en la nube mediante Google Drive (appDataFolder).

## Resumen del Diseño Visual y UX (Post-it Premium)
- **Marco de Ventana Personalizado:** Sin bordes de Windows, esquinas redondeadas y una sombra suave de fondo para un efecto flotante realista.
- **Cabecera de Vidrio (Glassmorphic Header):** Barra superior translúcida con controles integrados (cerrar, minimizar, pin de "Siempre al frente" y estado de sincronización).
- **Tematización Dinámica:** La aplicación completa adoptará el color de fondo de la pestaña activa (ej. Amarillo Post-it, Verde Menta, Azul Pastel), recreando la sensación de diferentes notas físicas.
- **Pestañas Notepad++:** Barra de pestañas dinámicas en la parte superior, reordenables por arrastre, renombrables con doble clic, con opción de cambiar de color y cerrarse.
- **Arrastrar y Soltar (Drag & Drop):** Zona de caída para adjuntar cualquier archivo local copiándolo a la caché y asociándolo con la nota activa.

---

## 1. Stack Tecnológico y Dependencias

Crearemos un proyecto Flutter para escritorio de Windows y añadiremos las siguientes dependencias en `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  window_manager: ^0.4.3
  desktop_drop: ^0.5.0
  google_sign_in: ^6.2.1
  google_sign_in_desktop:
    git:
      url: https://github.com/tnc1997/flutter-google-sign-in-desktop.git
  googleapis: ^13.0.0
  http: ^1.2.1
  path_provider: ^2.1.3
  url_launcher: ^6.3.0
  uuid: ^4.3.3
  crypto: ^3.0.3
  intl: ^0.19.0
```

---

## 2. Modelos de Datos (JSON Schema)

Implementaremos clases Dart para la serialización y deserialización del esquema JSON requerido:

### Modelos a crear (`lib/models/`)
1. **`StickyTabsConfig`**: Representa la raíz del esquema JSON (`version_formato`, `ultimo_dispositivo_sincronizado`, `ultima_modificacion_global`, etc.).
2. **`InterfaceConfig`**: Contiene la configuración visual (`color_tema`, `siempre_al_frente`, `ancho_ventana`, `alto_ventana`, `pestaña_activa_id`).
3. **`NoteTab`**: Representa una nota adhesiva individual con sus metadatos, contenido Markdown y adjuntos.
4. **`AttachmentInfo`**: Almacena información sobre los archivos adjuntos (`adjunto_id`, `nombre_archivo`, `tipo_mimo`, `peso_bytes`, `google_drive_file_id`, `md5_checksum`, `fecha_adjuntado`).

---

## 3. Servicios del Sistema (`lib/services/`)

### A. Servicio de Almacenamiento Local (`storage_service.dart`)
- **Configuración de Rutas:**
  - Configuración y Notas: `AppData\Roaming\StickyTabs\notas_config.json`
  - Descargas temporales/Caché: `AppData\Local\StickyTabs\Cache\`
- **Operaciones:**
  - Cargar/Guardar el JSON de configuración de forma atómica.
  - Copiar archivos arrastrados a la caché local con un nombre único basado en su `adjunto_id`.
  - Comprobar la existencia del archivo en la caché para evitar volver a descargarlo.

### B. Servicio de Autenticación de Google (`auth_service.dart`)
- **Token Data Store:** Implementa `GoogleSignInDesktopStore<GoogleSignInDesktopTokenData>` para persistir las credenciales localmente de forma segura en `AppData\Roaming\StickyTabs\oauth_tokens.json`.
- **Credenciales Flexibles:** Lee la ID del Cliente (`client_id`) y el Secreto (`client_secret`) desde un archivo local de configuración `oauth_credentials.json` en AppData, o permite que el usuario los configure dinámicamente desde un panel de ajustes en la interfaz de la aplicación.
- **Inicio de Sesión:** Maneja el flujo OAuth en el navegador del sistema a través de un puerto local de redirección.

### C. Servicio de Google Drive (`drive_service.dart`)
- **Aislamiento en la Nube:** Utiliza estrictamente el scope `drive.appdata` para leer/escribir en la carpeta oculta `appDataFolder`.
- **Sincronización Transparente:**
  - Al iniciar, descarga el `notas_config.json` remoto y lo fusiona con el local basándose en `ultima_modificacion_global`.
  - Sube el JSON local actualizado cuando hay modificaciones de texto o pestañas.
- **Lazy Loading de Adjuntos:**
  - Los archivos pesados se suben a Drive de manera individual en segundo plano.
  - La aplicación solo descarga un archivo de Drive a la caché local cuando el usuario hace doble clic sobre él.
  - Compara el hash MD5 local con el de Drive para evitar subidas o descargas redundantes.

### D. Servicio de Ventana (`window_service.dart`)
- Controla el estado sin bordes, tamaño de ventana (`ancho_ventana` x `alto_ventana`), posición y "Siempre al frente".
- Guarda los cambios de tamaño y posición de la ventana en el JSON de configuración local.

---

## 4. Diseño de Interfaz de Usuario (`lib/ui/`)

### Estructura de Componentes
1. **`FramelessWindowWrapper`**: Envoltorio transparente que dibuja la sombra exterior, bordes redondeados y proporciona la estructura base de la app.
2. **`CustomTitleBar`**: Barra superior translúcida que permite arrastrar la ventana y contiene:
   - Botón de Pin para "Siempre al frente".
   - Indicador de sincronización (Gris = Desconectado, Verde = Sincronizado, Azul animado = Sincronizando, Rojo = Error).
   - Botones de minimizar y cerrar ventana.
3. **`TabsContainer`**: Fila superior de pestañas dinámicas con:
   - Doble clic para renombrar.
   - Drag & Drop para reordenar posiciones.
   - Botón "+" para crear pestañas con colores seleccionables.
   - Botón "x" para eliminar pestañas con confirmación.
4. **`NoteEditor`**: Área de texto principal (TextField multilínea con fuente monoespaciada o sans elegante).
5. **`AttachmentsList`**: Panel inferior que muestra los archivos adjuntos a la nota actual. Admite doble clic para abrirlos a través de `url_launcher`.
6. **`SettingsPanel`**: Panel flotante o modal para configurar las credenciales OAuth (Client ID y Client Secret) de Google Cloud.

---

## 5. Plan de Verificación

### Pruebas Automatizadas
- **Pruebas Unitarias de Serialización:** Validar que los modelos se convierten correctamente de/hacia JSON respetando los nombres de atributos exactos del esquema.
- **Pruebas de Servicio de Persistencia:** Verificar la escritura en AppData y creación automática de carpetas.

### Pruebas Manuales
1. **Verificación de Ventana:** Comprobar que no hay bordes clásicos de Windows, que el pin de "Siempre al frente" mantiene la aplicación visible sobre otros programas, y que la ventana se puede arrastrar desde la cabecera.
2. **Verificación de Pestañas:** Crear múltiples pestañas, cambiarles el nombre, reordenarlas por arrastre, cambiar sus colores y comprobar que la interfaz adapta su color al de la pestaña activa.
3. **Verificación de Drag & Drop:** Arrastrar archivos del Explorador de Windows a la ventana y confirmar que aparecen como archivos adjuntos.
4. **Verificación de Sincronización:** Configurar las credenciales, iniciar sesión de Google y validar que el archivo `notas_config.json` y los adjuntos se suben/descargan de la carpeta `appDataFolder` de Drive de forma transparente.
