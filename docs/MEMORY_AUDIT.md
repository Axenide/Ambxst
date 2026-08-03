# Auditoría de uso de RAM - Ambxst

**Fecha:** 2026-08-03
**Baseline medido:** PSS 339MB, PSS_Anon 211MB (con MALLOC_CONF jemalloc)

## Resumen ejecutivo

- 40 singletons `pragma Singleton` se instancian al boot por imports eager.
- 1450-line Wallpaper.qml está always-on (Loader active:true sin condición) y carga el scan completo de 699 imágenes.
- 9-10 servicios pesados (Ai, ClipboardService, DesktopService, Notifications, WeatherService, PresetsService, ...) se instancian aunque no se usen en el momento del boot.
- PanelWindows OSD está always-on (active: SuspendManager.wakeReady) por pantalla.

## Inventario por categoría

### Singletons (40 totales) - top por peso

| Singleton | Líneas | FileView | Timers/Connections | Usado desde boot | RAM estimada |
|---|---|---|---|---|---|
| Ai.qml | 1083 | 23 | 9 | NO (solo sidebar/lazy) | 10-15MB |
| ClipboardService.qml | 813 | 18 | 6 | NO (tab clipboard) | 15-25MB |
| DesktopService.qml | 647 | 9 | 4 | NO (Config.desktop.enabled) | 5-10MB |
| Notifications.qml | 625 | 5 | 6 | parcial (DBus al boot) | 10-15MB |
| GlobalStates.qml | 576 | 0 | 0 | SI (referenciado) | 5-8MB |
| WeatherService.qml | 524 | 4 | 6 | SI (bar Clock + WidgetsTab) | 5-10MB |
| PresetsService.qml | 523 | 11 | 4 | NO (solo tab presets) | 5-10MB |
| CompositorTomlWriter.qml | 511 | 0 | 6 | NO (solo binds panel) | 2-4MB |
| Screenshot.qml | 452 | 10 | 3 | NO (lazy via tool) | 3-5MB |
| BluetoothService.qml | 383 | 0 | 6 | NO (solo panel) | 2-4MB |
| AppSearch.qml | 364 | 0 | 0 | NO (solo launcher) | 3-5MB |
| PowerProfile.qml | 325 | 6 | 4 | NO (solo dashboard widget) | 2-3MB |
| Brightness.qml | 304 | 0 | 0 | NO (OSD/dock/binds) | 2-3MB |
| Colors.qml | 282 | - | - | SI (theme) | 2-3MB |
| BackendService.qml | 271 | - | - | SI (IPC) | 2-3MB |
| Icons.qml | 266 | - | - | SI (font) | 2-3MB |
| ScreenRecorder.qml | 239 | 10 | 3 | NO (tool on-demand) | 3-5MB |
| NetworkService.qml | 231 | - | - | NO (widget bar) | 2-3MB |
| GlobalShortcuts.qml | 229 | - | - | SI (keybinds) | 2-3MB |
| Audio.qml | 216 | - | - | SI (bar) | 2-3MB |
| Visibilities.qml | 210 | - | - | SI (panel) | 1-2MB |
| TaskbarApps.qml | 210 | - | - | NO (dock) | 2-3MB |
| SystemResources.qml | 191 | - | - | NO (metrics tab) | 1-2MB |
| ... (resto ~17) | <200 | - | - | varios | <1MB cada uno |

**Total estimado eager-loaded no usado en boot: ~75-110MB**

### Always-on PanelWindows / Loaders

| Componente | Always-on | Configurable | Notas |
|---|---|---|---|
| `wallpaperLoader` | SI (active:true) | NO | **No tiene config; siempre carga Wallpaper.qml (1450L)** |
| `UnifiedShellPanel` (Bar+Notch+Dock+Frame) | SI | parcial | Core, OK pero revisar Dock |
| `ReservationWindows` | SI | parcial | Necesario para exclusivas |
| `desktopLoader` (Desktop.qml) | NO | SI | `Config.desktop.enabled` |
| `ScreenCorners` | NO | SI | `Config.theme.enableCorners && Config.roundness > 0` |
| `overviewLoader` | NO | SI | OK lazy |
| `osdLoader` (OSD) | SI | NO | Always-on por pantalla, debería ser lazy |
| `notificationStack` | SI | NO | Necesario: subscriptions DBus |
| `wallpaperLoader` (otro nombre en Variants) | SI | NO | **Crítico a fix** |
| Tools: ScreenRecord, Mirror, Settings | NO | visibility | OK |

### Imports eager (forzados por shell.qml)

| Import | Línea | Efecto |
|---|---|---|
| `import qs.modules.services` | 17 | Carga los 36 singletons de services |
| `import qs.modules.widgets.dashboard.wallpapers` | 12 | Carga Wallpaper.qml (1450L) |
| `import qs.modules.theme` | (varios) | Colors + Icons + Styling |
| `import qs.modules.globals` | 24 | GlobalStates + Visibilities |
| `import qs.modules.shell` | 26 | UnifiedShellPanel + OSD |
| `import qs.modules.components` | 20 | StyledRect + BarPopup |

## Mapa de uso de singletons pesados

| Singleton | Componentes que lo referencian |
|---|---|
| Ai | AssistantSidebar, ModelSelectorPopup, AiPanel (sidebar/lazy) |
| ClipboardService | ClipboardTab, EmojiTab (lazy tabs), shell.qml |
| Notifications | ScreenRecorder, Battery, UpdateService, Icons |
| WeatherService | Clock (bar, always), WeatherWidget (WidgetsTab, always) |
| DesktopService | DesktopIcon, Desktop (lazy Config.desktop.enabled) |
| PresetsService | PresetsTab (lazy tab) |
| PowerProfile | Dashboard controls |
| AppSearch | Launcher (lazy popup) |

## Hallazgos críticos

1. **`Wallpaper.qml` always-on con `active: true` sin condición** (shell.qml:42-49).
   El componente carga scan completo de 699 paths + 2 FileView + 2 watchers + JSON cache.
   Solo se usa en: LockScreen (lazy), Overview (lazy), WallpapersTab (lazy), PywalGenerator.
   **Ninguno siempre-vivo** lo necesita. Estimado: 15-30MB.

2. **OSD always-on** (shell.qml:262-269): instancia PanelWindow por pantalla siempre.
   Solo se necesita cuando cambia volumen/brillo. Estimado: 3-8MB.

3. **Singletons lazy candidates**: Ai, ClipboardService, PresetsService, DesktopService, Screenshot, ScreenRecorder, CompositorTomlWriter, BluetoothService, AppSearch, TaskbarApps.
   Total estimado: 50-80MB si se difieren.

4. **Imports eager**: `import qs.modules.widgets.dashboard.wallpapers` fuerza compilación de 1450L aunque el Loader no se instancie (QML engine pre-compila).

## Plan priorizado

### Fase 1 - Quick wins (impacto alto, riesgo bajo)
1. **Wallpaper lazy**: convertir `wallpaperLoader.active` a `Config.desktop.wallpaperManager !== false` (default true), + transformar `import qs.modules.widgets.dashboard.wallpapers` en carga lazy dentro del Loader.
   - Ahorro esperado: 15-30MB
   - Riesgo: bajo (afecta solo al wallpaper manager)

2. **OSD lazy**: cambiar `active: SuspendManager.wakeReady` a lazy on-demand (mantener modelo reactivo).
   - Ahorro: 3-8MB
   - Riesgo: bajo

### Fase 2 - Lazy singletons (impacto medio-alto, riesgo medio)
3. Convertir singletons heavy (Ai, ClipboardService, PresetsService, DesktopService, Screenshot, ScreenRecorder, CompositorTomlWriter, AppSearch, TaskbarApps, BluetoothService) en un patrón **LazySingleton**:
   - Wrapper Component que solo instancia cuando se accede por primera vez.
   - Renombrar acceso `Ai.something` a `Ai.get().something` o usar proxy.
   - Implementación: `LazySingleton { Component { id: source } ... }`.
   - Ahorro esperado: 50-80MB
   - Riesgo: medio (requiere refactor de accesos, tests)

### Fase 3 - Compactación y profiler (impacto variable)
4. Eliminar imports eager innecesarios en componentes secundarios.
5. Compactar scripts/init deferred (mover ClipboardService init del boot a cuando se abre el tab).
6. Medir con `heaptrack` después de cada fase para confirmar.

## Estimación total potencial

| Fase | Ahorro |
|---|---|
| Fase 1 | 20-40MB |
| Fase 2 | 50-80MB |
| Fase 3 | 10-20MB |
| **Total** | **80-140MB** |

De PSS 339MB actuales → **200-260MB PSS**. Target 150MB requeriría desactivar features estructurales.

## Recomendación

Empezar por Fase 1 (quick wins): cambiar `wallpaperLoader.active` a condicional y diferir el import. Si el usuario aprueba, continuar con Fase 2 (lazy singletons).

La Fase 2 es la más invasiva (refactor de 9-10 servicios). Requiere tests cuidadosos para no romper features existentes.