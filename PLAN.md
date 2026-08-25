# Plan: Migración de herramientas visuales al backend Go

Puerto del motor de captura de DankMaterialShell (MIT) al backend `ambxst`,
eliminando dependencias externas (`grim`, ImageMagick) y el glue bash/pgrep/pkill
de QML.

## Decisiones

- **Screenshots híbridos**: overlay QML actual se conserva; backend hace la
  captura (wlr-screencopy), crop, encode PNG y guardado.
- **Recorder**: servicio IPC dueño del proceso `gpu-screen-recorder` (SIGINT,
  estado por eventos). DMS no tiene grabación: diseño propio.
- **Colorpicker**: lupa layer-shell completa de DMS.
- **OCR/QR**: subcomandos Go (`slurp` región + motor + tesseract/zbarimg).
- **Thumbs**: imágenes 100% Go nativo; vídeos siguen con ffmpeg.
- **Se mantienen**: slurp, tesseract, zbarimg, gpu-screen-recorder, wl-copy,
  ffmpeg, notify-send. **Se eliminan**: grim, imagemagick.

## Fases

1. [x] Motor de captura Wayland en `backend/internal/screenshot/`
   - `types.go`, `shm.go`, `png.go` (casi copia directa de DMS)
   - `capture.go`: connect/registry/outputs/capture/crop (sin modos interactivos)
   - `backend/internal/proto/{wlr_screencopy,wlr_layer_shell,wp_viewporter,keyboard_shortcuts_inhibit,wp_color_management}`
   - Dep: `github.com/AvengeMedia/dankgo` (MIT). Atribución MIT en headers.
2. [x] Servicios IPC
   - `pkg/svc/screenshot`: `frame {output,cursor}`, `capture {mode,output,x,y,w,h,clipboard}`, `list`
   - `pkg/svc/recorder`: `start/stop/status` + evento `recorder.state`
   - `pkg/paths`: parseo `~/.config/user-dirs.dirs`
3. [x] Frontend QML
   - `Screenshot.qml` sobre `BackendService.call`; API/señales intactas para overlays
   - `ScreenRecorder.qml` cliente fino estilo GameModeClient
   - `ToolsMenu.qml`: OCR/QR → subcomandos; `google_lens.sh` acepta path
   - Borrar `scripts/{ocr,qr_scan,wf-record}.sh`, props muertas
4. [x] Colorpicker lupa DMS (`backend/internal/colorpicker`) + rewrite CLI
5. [x] `ambxst ocr [langs]` / `ambxst qr`
6. [x] Thumbs nativos imágenes (`backend/internal/media`)
7. [x] Packaging: quitar grim/imagemagick de nix + install.sh

## Contratos IPC

```
screenshot.frame   {output:string, cursor:bool}            -> {path,w,h}
screenshot.capture {mode:"region"|"output"|"screen"|"fullscreen",
                    output?, x?,y?,w?,h?, clipboard?}      -> {path,w,h}
screenshot.list    {}                                      -> {outputs:[{name,x,y,w,h,scale}]}
recorder.start     {mode:"screen"|"region"|"window"|"portal",
                    output?, region? "WxH+X+Y", audioOut, audioIn}
recorder.stop      {}
recorder.status    {}                                      -> {recording,elapsedMs,path}
evento recorder.state {recording, elapsedMs, path, error}
```

## Riesgos a validar manualmente (requiere sesión viva)

- Monitor rotado: mapeo región física ↔ buffer puede diferir de grim
- Escala fraccional multi-monitor
- Latencia de captura en daemon (~100-300ms/frame)
- Lupa colorpicker: input/keyboard-inhibit en Hyprland

## Créditos

Código portado de https://github.com/AvengeMedia/DankMaterialShell (core/internal/screenshot,
core/internal/colorpicker, core/internal/proto) — Copyright (c) 2025 Avenge Media LLC, MIT.
