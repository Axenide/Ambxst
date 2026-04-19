import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.modules.globals
import qs.modules.theme
import qs.config

PanelWindow {
    id: wallpaper

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "ambxst:wallpaper"
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    property string wallpaperDir: wallpaperConfig.adapter.wallPath
    property string fallbackDir: decodeURIComponent(Qt.resolvedUrl("../../../../assets/wallpapers_example").toString().replace("file://", ""))
    property var wallpaperPaths: []
    property var subfolderFilters: []
    property var allSubdirs: []

    // Paleta personalizada cargada desde archivo JSON
    property var customPalette: []
    property int customPaletteSize: 0

    // Paleta por defecto (optimizedPalette) como fallback
    readonly property var fallbackPalette: optimizedPalette
    readonly property int fallbackPaletteSize: optimizedPalette.length

    // Paleta efectiva que se usará en el shader
    readonly property var effectivePalette: customPaletteSize > 0 ? customPalette : fallbackPalette
    readonly property int effectivePaletteSize: customPaletteSize > 0 ? customPaletteSize : fallbackPaletteSize



    property int currentIndex: 0
    property string currentWallpaper: initialLoadCompleted && wallpaperPaths.length > 0 ? wallpaperPaths[currentIndex] : ""
    property bool initialLoadCompleted: false
    property bool usingFallback: false
    property bool _wallpaperDirInitialized: false
    property string currentMatugenScheme: wallpaperConfig.adapter.matugenScheme
    property var perScreenWallpapers: wallpaperConfig.adapter.perScreenWallpapers || {}
    property string effectiveWallpaper: perScreenWallpapers[currentScreenName] || currentWallpaper
    property string currentScreenName: wallpaper.screen ? wallpaper.screen.name : ""
    property alias tintEnabled: wallpaperAdapter.tintEnabled
    property int thumbnailsVersion: 0

    readonly property var optimizedPalette: ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]

    // Sync state from the primary wallpaper manager to secondary instances
    Binding {
        target: wallpaper
        property: "wallpaperPaths"
        value: GlobalStates.wallpaperManager.wallpaperPaths
        when: GlobalStates.wallpaperManager !== null && GlobalStates.wallpaperManager !== wallpaper
    }

    Binding {
        target: wallpaper
        property: "currentIndex"
        value: GlobalStates.wallpaperManager.currentIndex
        when: GlobalStates.wallpaperManager !== null && GlobalStates.wallpaperManager !== wallpaper
    }

    Binding {
        target: wallpaper
        property: "subfolderFilters"
        value: GlobalStates.wallpaperManager.subfolderFilters
        when: GlobalStates.wallpaperManager !== null && GlobalStates.wallpaperManager !== wallpaper
    }

    Binding {
        target: wallpaper
        property: "initialLoadCompleted"
        value: GlobalStates.wallpaperManager.initialLoadCompleted
        when: GlobalStates.wallpaperManager !== null && GlobalStates.wallpaperManager !== wallpaper
    }

    property string colorPresetsDir: Quickshell.env("HOME") + "/.config/ambxst/colors"
    property string officialColorPresetsDir: decodeURIComponent(Qt.resolvedUrl("../../../../assets/colors").toString().replace("file://", ""))
    onColorPresetsDirChanged: console.log("Color Presets Directory:", colorPresetsDir)
    property list<string> colorPresets: []
    onColorPresetsChanged: console.log("Color Presets Updated:", colorPresets)
    property string activeColorPreset: wallpaperConfig.adapter.activeColorPreset || ""

    // React to light/dark mode changes
    property bool isLightMode: Config.theme.lightMode
    onIsLightModeChanged: {
        if (activeColorPreset) {
            applyColorPreset();
        } else {
            runMatugenForCurrentWallpaper();
        }
    }

    onActiveColorPresetChanged: {
        if (activeColorPreset) {
            applyColorPreset();
        } else {
            runMatugenForCurrentWallpaper();
        }
    }

    function scanColorPresets() {
        scanPresetsProcess.running = true;
    }

    function applyColorPreset() {
        if (!activeColorPreset)
            return;

        var mode = Config.theme.lightMode ? "light.json" : "dark.json";

        var officialFile = officialColorPresetsDir + "/" + activeColorPreset + "/" + mode;
        var userFile = colorPresetsDir + "/" + activeColorPreset + "/" + mode;
        var dest = Quickshell.env("HOME") + "/.cache/ambxst/colors.json";

        // Try official first, then user. Use bash conditional.
        var cmd = "if [ -f '" + officialFile + "' ]; then cp '" + officialFile + "' '" + dest + "'; else cp '" + userFile + "' '" + dest + "'; fi";

        console.log("Applying color preset:", activeColorPreset);
        applyPresetProcess.command = ["bash", "-c", cmd];
        applyPresetProcess.running = true;
    }

    function setColorPreset(name) {
        wallpaperConfig.adapter.activeColorPreset = name;
    // activeColorPreset property will update automatically via binding to adapter
    }

    // Funciones utilitarias para tipos de archivo
    function getFileType(path) {
        var extension = path.toLowerCase().split('.').pop();
        if (['jpg', 'jpeg', 'png', 'webp', 'tif', 'tiff', 'bmp'].includes(extension)) {
            return 'image';
        } else if (['gif'].includes(extension)) {
            return 'gif';
        } else if (['mp4', 'webm', 'mov', 'avi', 'mkv'].includes(extension)) {
            return 'video';
        }
        return 'unknown';
    }

    function getThumbnailPath(filePath) {
        // Compute relative path from wallpaperDir
        var basePath = wallpaperDir.endsWith("/") ? wallpaperDir : wallpaperDir + "/";
        var relativePath = filePath.replace(basePath, "");

        // Replace the filename with .jpg extension
        var pathParts = relativePath.split('/');
        var fileName = pathParts.pop();
        var thumbnailName = fileName + ".jpg";
        var relativeDir = pathParts.join('/');

        // Build the proxy path
        var thumbnailPath = Quickshell.env("HOME") + "/.cache/ambxst" + "/thumbnails/" + relativeDir + "/" + thumbnailName;
        return thumbnailPath;
    }

    function getDisplaySource(filePath) {
        var fileType = getFileType(filePath);

        // Para el display (WallpapersTab), siempre usar thumbnails si están disponibles
        if (fileType === 'video' || fileType === 'image' || fileType === 'gif') {
            var thumbnailPath = getThumbnailPath(filePath);
            // Verificar si el thumbnail existe (esto es solo para debugging, QML manejará el fallback)
            return thumbnailPath;
        }

        // Fallback al archivo original si no es un tipo soportado
        return filePath;
    }

    function getColorSource(filePath) {
        var fileType = getFileType(filePath);

        // Para generación de colores: solo videos usan thumbnails
        if (fileType === 'video') {
            return getThumbnailPath(filePath);
        }

        // Imágenes y GIFs usan el archivo original para colores
        return filePath;
    }

    function getLockscreenFramePath(filePath) {
        if (!filePath) {
            return "";
        }

        var fileType = getFileType(filePath);

        // Para imágenes estáticas, usar el archivo original
        if (fileType === 'image') {
            return filePath;
        }

        // Para videos y GIFs, usar el frame cacheado
        if (fileType === 'video' || fileType === 'gif') {
            var fileName = filePath.split('/').pop();
            var cachePath = Quickshell.env("HOME") + "/.cache/ambxst" + "/lockscreen/" + fileName + ".jpg";
            return cachePath;
        }

        return filePath;
    }

    function generateLockscreenFrame(filePath) {
        if (!filePath) {
            console.warn("generateLockscreenFrame: empty filePath");
            return;
        }

        console.log("Generating lockscreen frame for:", filePath);

        var scriptPath = decodeURIComponent(Qt.resolvedUrl("../../../../scripts/lockwall.py").toString().replace("file://", ""));
        var dataPath = Quickshell.env("HOME") + "/.cache/ambxst";

        lockscreenWallpaperScript.command = ["python3", scriptPath, filePath, dataPath];

        lockscreenWallpaperScript.running = true;
    }

    function getSubfolderFromPath(filePath) {
        var basePath = wallpaperDir.endsWith("/") ? wallpaperDir : wallpaperDir + "/";
        var relativePath = filePath.replace(basePath, "");
        var parts = relativePath.split("/");
        if (parts.length > 1) {
            return parts[0];
        }
        return "";
    }
    
    function loadCustomPalette(filePath) {
        if (!filePath) return;
        var palettePath = getPalettePath(filePath);
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "file://" + palettePath, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText);
                        customPalette = data.colors;
                        customPaletteSize = data.size;
                        console.log("Palette loaded:", customPaletteSize, "colors - First:", customPalette[0]);
                    } catch (e) {
                        console.warn("Failed to parse palette:", palettePath, e);
                        customPalette = [];
                        customPaletteSize = 0;
                    }
                } else {
                    console.warn("Palette file not found (status " + xhr.status + "):", palettePath);
                    customPalette = [];
                    customPaletteSize = 0;
                }
            }
        };
        xhr.send();
    }

    function getPalettePath(filePath) {
        var basePath = wallpaperDir.endsWith("/") ? wallpaperDir : wallpaperDir + "/";
        var relativePath = filePath.replace(basePath, "");
        return Quickshell.env("HOME") + "/.cache/ambxst/palettes/" + relativePath + ".json";
    }

    function scanSubfolders() {
        if (!wallpaperDir)
            return;
        // Explicitly update command with current wallpaperDir
        var cmd = ["find", wallpaperDir, "-mindepth", "1", "-name", ".*", "-prune", "-o", "-type", "d", "-print"];
        scanSubfoldersProcess.command = cmd;
        scanSubfoldersProcess.running = true;
    }

    // Update directory watcher when wallpaperDir changes
    onWallpaperDirChanged: {
        // Skip initial spurious changes before config is loaded
        if (!_wallpaperDirInitialized)
            return;

        // Only the primary wallpaper manager should handle directory changes
        if (GlobalStates.wallpaperManager !== wallpaper)
            return;

        console.log("Wallpaper directory changed to:", wallpaperDir);
        usingFallback = false;

        // Clear current lists to reflect change immediately
        wallpaperPaths = [];
        subfolderFilters = [];

        directoryWatcher.path = wallpaperDir;

        // Force update scan command
        var cmd = ["find", wallpaperDir, "-name", ".*", "-prune", "-o", "-type", "f", "(", "-name", "*.jpg", "-o", "-name", "*.jpeg", "-o", "-name", "*.png", "-o", "-name", "*.webp", "-o", "-name", "*.tif", "-o", "-name", "*.tiff", "-o", "-name", "*.gif", "-o", "-name", "*.mp4", "-o", "-name", "*.webm", "-o", "-name", "*.mov", "-o", "-name", "*.avi", "-o", "-name", "*.mkv", ")", "-print"];
        scanWallpapers.command = cmd;
        scanWallpapers.running = true;

        scanSubfolders();

        // Regenerate thumbnails for the new directory (delayed)
        if (delayedThumbnailGen.running)
            delayedThumbnailGen.restart();
        else
            delayedThumbnailGen.start();
    }

    onCurrentWallpaperChanged:
    // Matugen se ejecuta manualmente en las funciones de cambio
    {}

    function setWallpaper(path, targetScreen = null) {
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager !== wallpaper) {
            GlobalStates.wallpaperManager.setWallpaper(path, targetScreen);
            return;
        }

        console.log("setWallpaper called with:", path, "for screen:", targetScreen);
        initialLoadCompleted = true;
        var pathIndex = wallpaperPaths.indexOf(path);
        if (pathIndex !== -1) {
            if (targetScreen) {
                // If targeting a specific screen, save to perScreenWallpapers instead of currentWall
                let perScreen = Object.assign({}, wallpaperConfig.adapter.perScreenWallpapers || {});
                perScreen[targetScreen] = path;
                wallpaperConfig.adapter.perScreenWallpapers = perScreen;
                
                // If this targetScreen is the primary screen, it must update currentWall
                // because currentWall is exactly the primary monitor fallback.
                let isPrimary = false;
                if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.screen) {
                    isPrimary = (targetScreen === GlobalStates.wallpaperManager.screen.name);
                }

                if (isPrimary || !wallpaperConfig.adapter.currentWall) {
                    currentIndex = pathIndex;
                    wallpaperConfig.adapter.currentWall = path;
                    currentWallpaper = path;
                    loadCustomPalette(path);
                    generateLockscreenFrame(path);
                    runMatugenForCurrentWallpaper();
                }
            } else {
                // Global fallback target
                currentIndex = pathIndex;
                wallpaperConfig.adapter.currentWall = path;
                currentWallpaper = path;
                loadCustomPalette(path);
                generateLockscreenFrame(path);
                runMatugenForCurrentWallpaper();
            }
            generateLockscreenFrame(path);
        } else {
            console.warn("Wallpaper path not found in current list:", path);
        }
    }

    function clearPerScreenWallpaper(targetScreen) {
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager !== wallpaper) {
            GlobalStates.wallpaperManager.clearPerScreenWallpaper(targetScreen);
            return;
        }
        
        console.log("Clearing per-screen wallpaper for:", targetScreen);
        let perScreen = Object.assign({}, wallpaperConfig.adapter.perScreenWallpapers || {});
        if (perScreen[targetScreen]) {
            delete perScreen[targetScreen];
            wallpaperConfig.adapter.perScreenWallpapers = perScreen;
        }
    }

    function nextWallpaper() {
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager !== wallpaper) {
            GlobalStates.wallpaperManager.nextWallpaper();
            return;
        }

        if (wallpaperPaths.length === 0)
            return;
        initialLoadCompleted = true;
        currentIndex = (currentIndex + 1) % wallpaperPaths.length;
        currentWallpaper = wallpaperPaths[currentIndex];
        wallpaperConfig.adapter.currentWall = wallpaperPaths[currentIndex];
        runMatugenForCurrentWallpaper();
        generateLockscreenFrame(wallpaperPaths[currentIndex]);
    }

    function previousWallpaper() {
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager !== wallpaper) {
            GlobalStates.wallpaperManager.previousWallpaper();
            return;
        }

        if (wallpaperPaths.length === 0)
            return;
        initialLoadCompleted = true;
        currentIndex = currentIndex === 0 ? wallpaperPaths.length - 1 : currentIndex - 1;
        currentWallpaper = wallpaperPaths[currentIndex];
        wallpaperConfig.adapter.currentWall = wallpaperPaths[currentIndex];
        runMatugenForCurrentWallpaper();
        generateLockscreenFrame(wallpaperPaths[currentIndex]);
    }

    function setWallpaperByIndex(index) {
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager !== wallpaper) {
            GlobalStates.wallpaperManager.setWallpaperByIndex(index);
            return;
        }

        if (index >= 0 && index < wallpaperPaths.length) {
            initialLoadCompleted = true;
            currentIndex = index;
            currentWallpaper = wallpaperPaths[currentIndex];
            wallpaperConfig.adapter.currentWall = wallpaperPaths[currentIndex];
            runMatugenForCurrentWallpaper();
            generateLockscreenFrame(wallpaperPaths[currentIndex]);
        }
    }

    // Función para re-ejecutar Matugen con el wallpaper actual
    function setMatugenScheme(scheme) {
        wallpaperConfig.adapter.matugenScheme = scheme;

        if (wallpaperConfig.adapter.activeColorPreset) {
            console.log("Switching to Matugen scheme, clearing preset");
            wallpaperConfig.adapter.activeColorPreset = "";
        } else {
            runMatugenForCurrentWallpaper();
        }
    }

    function runMatugenForCurrentWallpaper() {
        if (activeColorPreset) {
            console.log("Skipping Matugen because color preset is active:", activeColorPreset);
            return;
        }

        if (currentWallpaper && initialLoadCompleted) {
            console.log("Running Matugen for current wallpaper:", currentWallpaper);

            var fileType = getFileType(currentWallpaper);
            var matugenSource = getColorSource(currentWallpaper);

            console.log("Using source for matugen:", matugenSource, "(type:", fileType + ")");

            // Stop existing processes if running to prioritize new request
            if (matugenProcessWithConfig.running) {
                matugenProcessWithConfig.running = false;
            }
            if (matugenProcessNormal.running) {
                matugenProcessNormal.running = false;
            }

            // Ejecutar matugen con configuración específica
            var commandWithConfig = ["matugen", "image", matugenSource, "--source-color-index", "0", "-c", decodeURIComponent(Qt.resolvedUrl("../../../../assets/matugen/config.toml").toString().replace("file://", "")), "-t", wallpaperConfig.adapter.matugenScheme];
            if (Config.theme.lightMode) {
                commandWithConfig.push("-m", "light");
            }
            matugenProcessWithConfig.command = commandWithConfig;
            matugenProcessWithConfig.running = true;

            // Ejecutar matugen normal en paralelo
            var commandNormal = ["matugen", "image", matugenSource, "--source-color-index", "0", "-t", wallpaperConfig.adapter.matugenScheme];
            if (Config.theme.lightMode) {
                commandNormal.push("-m", "light");
            }
            matugenProcessNormal.command = commandNormal;
            matugenProcessNormal.running = true;
        }
    }

    Component.onCompleted: {
        // Only the first Wallpaper instance should manage scanning
        // Other instances (for other screens) share the same data via GlobalStates
        if (GlobalStates.wallpaperManager !== null) {
            // Another instance already registered, skip initialization
            _wallpaperDirInitialized = true;
            return;
        }

        GlobalStates.wallpaperManager = wallpaper;

        // Verificar si existe wallpapers.json, si no, crear con fallback
        checkWallpapersJson.running = true;

        // Initial scans - do these once after config is loaded
        scanColorPresets();
        // Start directory monitoring
        presetsWatcher.reload();
        officialPresetsWatcher.reload();
        // Load initial wallpaper config - this will trigger onWallPathChanged which does the actual scan
        wallpaperConfig.reload();

        // Generate lockscreen frame for initial wallpaper after a short delay
        Qt.callLater(function () {
            if (currentWallpaper) {
                generateLockscreenFrame(currentWallpaper);
                loadCustomPalette(currentWallpaper);
            }
        });
    }

    FileView {
        id: wallpaperConfig
        path: Quickshell.env("HOME") + "/.cache/ambxst/wallpapers.json"
        watchChanges: true

        onLoaded: {
            if (!wallpaperConfig.adapter.wallPath) {
                console.log("Loaded config but wallPath is empty, using fallback");
                wallpaperConfig.adapter.wallPath = fallbackDir;
            }
        }

        onFileChanged: reload()
        onAdapterUpdated: {
            // Ensure matugenScheme has a default value
            if (!wallpaperConfig.adapter.matugenScheme) {
                wallpaperConfig.adapter.matugenScheme = "scheme-tonal-spot";
            }
            // Update the currentMatugenScheme property to trigger UI updates
            currentMatugenScheme = Qt.binding(function () {
                return wallpaperConfig.adapter.matugenScheme;
            });
            writeAdapter();
        }

        JsonAdapter {
            id: wallpaperAdapter
            property string currentWall: ""
            property string wallPath: ""
            property string matugenScheme: "scheme-tonal-spot"
            property string activeColorPreset: ""
            property bool tintEnabled: false
            property var perScreenWallpapers: ({})

            onActiveColorPresetChanged: {
                if (wallpaperConfig.adapter.activeColorPreset !== wallpaper.activeColorPreset) {
                    wallpaper.activeColorPreset = wallpaperConfig.adapter.activeColorPreset || "";
                }
            }

            onCurrentWallChanged: {
                // Skip during initial load - scanWallpapers handles this
                if (!wallpaper._wallpaperDirInitialized)
                    return;

                // Siempre actualizar si es diferente al actual
                if (currentWall && currentWall !== wallpaper.currentWallpaper) {
                    // If paths are not loaded yet, wait for scanWallpapers to finish
                    if (wallpaper.wallpaperPaths.length === 0) {
                        return;
                    }

                    var pathIndex = wallpaper.wallpaperPaths.indexOf(currentWall);
                    if (pathIndex !== -1) {
                        wallpaper.currentIndex = pathIndex;
                        if (!wallpaper.initialLoadCompleted) {
                            wallpaper.initialLoadCompleted = true;
                        }
                        wallpaper.runMatugenForCurrentWallpaper();
                    } else {
                        console.warn("Saved wallpaper not found in current list:", currentWall);
                    }
                }
            }

            onWallPathChanged: {
                if (wallPath) {
                    console.log("Config wallPath updated:", wallPath);

                    // Initialize scanning on first valid wallPath load
                    if (!wallpaper._wallpaperDirInitialized && GlobalStates.wallpaperManager === wallpaper) {
                        wallpaper._wallpaperDirInitialized = true;

                        // Set up directory watcher
                        directoryWatcher.path = wallPath;
                        directoryWatcher.reload();

                        // Perform initial wallpaper scan
                        var cmd = ["find", wallPath, "-name", ".*", "-prune", "-o", "-type", "f", "(", "-name", "*.jpg", "-o", "-name", "*.jpeg", "-o", "-name", "*.png", "-o", "-name", "*.webp", "-o", "-name", "*.tif", "-o", "-name", "*.tiff", "-o", "-name", "*.gif", "-o", "-name", "*.mp4", "-o", "-name", "*.webm", "-o", "-name", "*.mov", "-o", "-name", "*.avi", "-o", "-name", "*.mkv", ")", "-print"];
                        scanWallpapers.command = cmd;
                        scanWallpapers.running = true;
                        wallpaper.scanSubfolders();

                        // Start thumbnail generation
                        delayedThumbnailGen.start();
                    }
                }
            }
        }
    }

    Process {
        id: checkWallpapersJson
        running: false
        command: ["test", "-f", Quickshell.env("HOME") + "/.cache/ambxst/wallpapers.json"]

        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.log("wallpapers.json does not exist, creating with fallbackDir");
                wallpaperConfig.adapter.wallPath = fallbackDir;
            } else {
                console.log("wallpapers.json exists");
            }
        }
    }

    Process {
        id: matugenProcessWithConfig
        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("Matugen (with config) output:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Matugen (with config) error:", text);
                }
            }
        }

        onExited: {
            console.log("Matugen with config finished");
        }
    }

    Process {
        id: matugenProcessNormal
        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("Matugen (normal) output:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Matugen (normal) error:", text);
                }
            }
        }

        onExited: {
            console.log("Matugen normal finished");
        }
    }

    // Proceso para generar thumbnails de videos
    Process {
        id: thumbnailGeneratorScript
        running: false
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("../../../../scripts/thumbgen.py").toString().replace("file://", "")), Quickshell.env("HOME") + "/.cache/ambxst" + "/wallpapers.json", Quickshell.env("HOME") + "/.cache/ambxst", fallbackDir]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("Thumbnail Generator:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Thumbnail Generator Error:", text);
                }
            }
        }

        onExited: function (exitCode) {
            if (exitCode === 0) {
                console.log("✅ Video thumbnails generated successfully");
                thumbnailsVersion++;
            } else {
                console.warn("⚠️ Thumbnail generation failed with code:", exitCode);
            }
        }
    }

    Timer {
        id: delayedThumbnailGen
        interval: 2000 // Delay 2 seconds after change to not block
        repeat: false
        onTriggered: thumbnailGeneratorScript.running = true
    }

    // Proceso para generar frame de lockscreen con el script de Python
    Process {
        id: lockscreenWallpaperScript
        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("Lockscreen Wallpaper Generator:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Lockscreen Wallpaper Generator Error:", text);
                }
            }
        }

        onExited: function (exitCode) {
            if (exitCode === 0) {
                console.log("✅ Lockscreen wallpaper ready");
            } else {
                console.warn("⚠️ Lockscreen wallpaper generation failed with code:", exitCode);
            }
        }
    }

    Process {
        id: scanSubfoldersProcess
        running: false
        command: wallpaperDir ? ["find", wallpaperDir, "-mindepth", "1", "-name", ".*", "-prune", "-o", "-type", "d", "-print"] : []

        stdout: StdioCollector {
            onStreamFinished: {
                console.log("scanSubfolders stdout:", text);
                var rawPaths = text.trim().split("\n").filter(function (f) {
                    return f.length > 0;
                });

                allSubdirs = rawPaths;

                var basePath = wallpaperDir.endsWith("/") ? wallpaperDir : wallpaperDir + "/";

                var topLevelFolders = rawPaths.filter(function (path) {
                    var relative = path.replace(basePath, "");
                    return relative.indexOf("/") === -1;
                }).map(function (path) {
                    return path.split("/").pop();
                }).filter(function (name) {
                    return name.length > 0 && !name.startsWith(".");
                });

                topLevelFolders.sort();
                subfolderFilters = topLevelFolders;
                subfolderFiltersChanged();  // Emitir señal manualmente
                console.log("Updated subfolderFilters:", subfolderFilters);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Error scanning subfolders:", text);
                }
            }
        }

        onRunningChanged: {
            if (running) {
                console.log("Starting scanSubfolders for directory:", wallpaperDir);
            } else {
                console.log("Finished scanSubfolders");
            }
        }
    }

    // Directory watcher using FileView to monitor the wallpaper directory
    FileView {
        id: directoryWatcher
        path: wallpaperDir
        watchChanges: true
        printErrors: false

        onFileChanged: {
            if (wallpaperDir === "")
                return;
            console.log("Wallpaper directory changed, rescanning...");
            scanWallpapers.running = true;
            scanSubfoldersProcess.running = true;
            // Regenerar thumbnails si hay nuevos videos (delayed)
            if (delayedThumbnailGen.running)
                delayedThumbnailGen.restart();
            else
                delayedThumbnailGen.start();
        }

        // Remove onLoadFailed to prevent premature fallback activation
    }

    // Recursive directory watchers for subfolders
    Instantiator {
        model: allSubdirs

        delegate: FileView {
            path: modelData
            watchChanges: true
            printErrors: false
            onFileChanged: {
                console.log("Subdirectory content changed (" + path + "), rescanning...");
                scanWallpapers.running = true;
                scanSubfoldersProcess.running = true;

                // Regenerar thumbnails (delayed)
                if (delayedThumbnailGen.running)
                    delayedThumbnailGen.restart();
                else
                    delayedThumbnailGen.start();
            }
        }
    }

    // Directory watcher for user color presets
    FileView {
        id: presetsWatcher
        path: colorPresetsDir
        watchChanges: true
        printErrors: false

        onFileChanged: {
            console.log("User color presets directory changed, rescanning...");
            scanPresetsProcess.running = true;
        }
    }

    // Directory watcher for official color presets
    FileView {
        id: officialPresetsWatcher
        path: officialColorPresetsDir
        watchChanges: true
        printErrors: false

        onFileChanged: {
            console.log("Official color presets directory changed, rescanning...");
            scanPresetsProcess.running = true;
        }
    }

    Process {
        id: scanWallpapers
        running: false
        command: wallpaperDir ? ["find", wallpaperDir, "-name", ".*", "-prune", "-o", "-type", "f", "(", "-name", "*.jpg", "-o", "-name", "*.jpeg", "-o", "-name", "*.png", "-o", "-name", "*.webp", "-o", "-name", "*.tif", "-o", "-name", "*.tiff", "-o", "-name", "*.gif", "-o", "-name", "*.mp4", "-o", "-name", "*.webm", "-o", "-name", "*.mov", "-o", "-name", "*.avi", "-o", "-name", "*.mkv", ")", "-print"] : []

        onRunningChanged: {
            if (running && wallpaperDir === "") {
                console.log("Blocking scanWallpapers because wallpaperDir is empty");
                running = false;
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var files = text.trim().split("\n").filter(function (f) {
                    return f.length > 0;
                });
                if (files.length === 0) {
                    console.log("No wallpapers found in main directory, using fallback");
                    usingFallback = true;
                    scanFallback.running = true;
                } else {
                    usingFallback = false;
                    // Only update if the list has actually changed
                    var newFiles = files.sort();
                    var listChanged = JSON.stringify(newFiles) !== JSON.stringify(wallpaperPaths);
                    if (listChanged) {
                        console.log("Wallpaper directory updated. Found", newFiles.length, "images");
                        wallpaperPaths = newFiles;

                        // Always try to load the saved wallpaper when list changes
                        if (wallpaperPaths.length > 0) {
                            // Trigger thumbnail generation if list changed
                            if (delayedThumbnailGen.running)
                                delayedThumbnailGen.restart();
                            else
                                delayedThumbnailGen.start();

                            if (wallpaperConfig.adapter.currentWall) {
                                var savedIndex = wallpaperPaths.indexOf(wallpaperConfig.adapter.currentWall);
                                if (savedIndex !== -1) {
                                    currentIndex = savedIndex;
                                    console.log("Loaded saved wallpaper at index:", savedIndex);
                                } else {
                                    currentIndex = 0;
                                    console.log("Saved wallpaper not found, using first");
                                }
                            } else {
                                currentIndex = 0;
                            }

                            if (!initialLoadCompleted) {
                                if (!wallpaperConfig.adapter.currentWall) {
                                    wallpaperConfig.adapter.currentWall = wallpaperPaths[0];
                                }
                                initialLoadCompleted = true;
                                // runMatugenForCurrentWallpaper() will be called by onCurrentWallChanged
                            }
                        }
                    }
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Error scanning wallpaper directory:", text);
                    // Only fallback if we don't already have wallpapers loaded AND we have a valid directory that failed
                    if (wallpaperPaths.length === 0 && wallpaperDir !== "") {
                        console.log("Directory scan failed for " + wallpaperDir + ", using fallback");
                        usingFallback = true;
                        scanFallback.running = true;
                    }
                }
            }
        }
    }

    Process {
        id: scanFallback
        running: false
        command: ["find", fallbackDir, "-name", ".*", "-prune", "-o", "-type", "f", "(", "-name", "*.jpg", "-o", "-name", "*.jpeg", "-o", "-name", "*.png", "-o", "-name", "*.webp", "-o", "-name", "*.tif", "-o", "-name", "*.tiff", "-o", "-name", "*.gif", "-o", "-name", "*.mp4", "-o", "-name", "*.webm", "-o", "-name", "*.mov", "-o", "-name", "*.avi", "-o", "-name", "*.mkv", ")", "-print"]

        stdout: StdioCollector {
            onStreamFinished: {
                var files = text.trim().split("\n").filter(function (f) {
                    return f.length > 0;
                });
                console.log("Using fallback wallpapers. Found", files.length, "images");

                // Only use fallback if we don't already have main wallpapers loaded
                if (usingFallback) {
                    wallpaperPaths = files.sort();

                    // Initialize fallback wallpaper selection
                    if (wallpaperPaths.length > 0) {
                        if (wallpaperConfig.adapter.currentWall) {
                            var savedIndex = wallpaperPaths.indexOf(wallpaperConfig.adapter.currentWall);
                            if (savedIndex !== -1) {
                                currentIndex = savedIndex;
                            } else {
                                currentIndex = 0;
                            }
                        } else {
                            currentIndex = 0;
                        }

                        if (!initialLoadCompleted) {
                            if (!wallpaperConfig.adapter.currentWall) {
                                wallpaperConfig.adapter.currentWall = wallpaperPaths[0];
                            }
                            initialLoadCompleted = true;
                            // runMatugenForCurrentWallpaper() will be called by onCurrentWallChanged
                        }
                    }
                }
            }
        }
    }

    Process {
        id: scanPresetsProcess
        running: false
        // Scan both directories. find will complain to stderr if one is missing but still output what it finds.
        command: ["find", officialColorPresetsDir, colorPresetsDir, "-mindepth", "1", "-maxdepth", "1", "-type", "d"]

        stdout: StdioCollector {
            onStreamFinished: {
                console.log("Scan Presets Output:", text);
                var rawLines = text.trim().split("\n");
                var uniqueNames = [];
                for (var i = 0; i < rawLines.length; i++) {
                    var line = rawLines[i].trim();
                    if (line.length === 0)
                        continue;
                    var name = line.split('/').pop();
                    // Deduplicate
                    if (uniqueNames.indexOf(name) === -1) {
                        uniqueNames.push(name);
                    }
                }
                uniqueNames.sort();
                console.log("Found color presets:", uniqueNames);
                colorPresets = uniqueNames;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                // Suppress common "No such file or directory" if one dir is missing
                // console.warn("Scan Presets Error:", text);
            }
        }
    }

    Process {
        id: applyPresetProcess
        running: false
        command: []

        onExited: code => {
            if (code === 0)
                console.log("Color preset applied successfully");
            else
                console.warn("Failed to apply color preset, code:", code);
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: "black"
        focus: true

        Keys.onLeftPressed: {
            if (wallpaper.wallpaperPaths.length > 0) {
                wallpaper.previousWallpaper();
            }
        }

        Keys.onRightPressed: {
            if (wallpaper.wallpaperPaths.length > 0) {
                wallpaper.nextWallpaper();
            }
        }

        WallpaperImage {
            id: wallImage
            anchors.fill: parent
            source: wallpaper.effectiveWallpaper
        }
    }

    component WallpaperImage: Item {
        id: wallImage
        property string source
        property string previousSource

        onSourceChanged: {
            if (previousSource !== "" && source !== previousSource) {
                if (Config.animDuration > 0) {
                    transitionAnimation.restart();
                }
            }
            previousSource = source;
            // Cargar paleta cuando la fuente cambie
            if (source) {
                wallpaper.loadCustomPalette(source);
            }
        }

        SequentialAnimation {
            id: transitionAnimation
            ParallelAnimation {
                NumberAnimation { target: wallImage; property: "scale"; to: 1.01; duration: Config.animDuration; easing.type: Easing.OutCubic }
                NumberAnimation { target: wallImage; property: "opacity"; to: 0.5; duration: Config.animDuration; easing.type: Easing.OutCubic }
            }
            ParallelAnimation {
                NumberAnimation { target: wallImage; property: "scale"; to: 1.0; duration: Config.animDuration; easing.type: Easing.OutCubic }
                NumberAnimation { target: wallImage; property: "opacity"; to: 1.0; duration: Config.animDuration; easing.type: Easing.OutCubic }
            }
        }

        Loader {
            anchors.fill: parent
            sourceComponent: {
                if (!wallImage.source) return null;
                var fileType = wallpaper.getFileType(wallImage.source);
                if (fileType === 'image') {
                    return staticImageComponent;
                } else if (fileType === 'gif' || fileType === 'video') {
                    return videoComponent;
                }
                return staticImageComponent;
            }
            property string sourceFile: wallImage.source
        }

        Component {
            id: staticImageComponent
            Item {
                id: staticImageRoot
                anchors.fill: parent
                property string sourceFile: parent.sourceFile
                property bool tint: wallpaper.tintEnabled

                Item {
                    id: paletteSourceItem
                    visible: true
                    width: wallpaper.effectivePaletteSize
                    height: 1
                    opacity: 0

                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: wallpaper.effectivePalette
                            Rectangle {
                                width: 1
                                height: 1
                                color: {
                                    if (typeof modelData === "string") {
                                        if (modelData.charAt(0) === '#') {
                                            return modelData;
                                        } else {
                                            return Colors[modelData] || "black";
                                        }
                                    }
                                    return modelData;
                                }
                            }
                        }
                    }

                    Component.onCompleted: {
                        if (width > 0) paletteTextureSource.scheduleUpdate();
                    }
                    onWidthChanged: {
                        if (width > 0) paletteTextureSource.scheduleUpdate();
                    }
                }

                ShaderEffectSource {
                    id: paletteTextureSource
                    sourceItem: paletteSourceItem
                    hideSource: true
                    visible: false
                    smooth: false
                    recursive: false
                }

                Item {
                    id: mediaContainer
                    anchors.fill: parent
                    clip: true

                    Image {
                        id: rawImage
                        anchors.fill: parent
                        source: staticImageRoot.sourceFile ? "file://" + staticImageRoot.sourceFile : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        opacity: staticImageRoot.tint ? 0.0 : 1.0
                        visible: true
                    }

                    ShaderEffectSource {
                        id: mediaTextureSource
                        sourceItem: rawImage
                        hideSource: staticImageRoot.tint
                        live: true
                        smooth: true
                        recursive: false
                    }

                    ShaderEffect {
                        anchors.fill: parent
                        visible: staticImageRoot.tint && wallpaper.effectivePaletteSize > 0
                        property var source: mediaTextureSource
                        property var paletteTexture: paletteTextureSource
                        property real paletteSize: wallpaper.effectivePaletteSize
                        property real texWidth: Math.max(rawImage.width, 1)
                        property real texHeight: Math.max(rawImage.height, 1)

                        vertexShader: "palette.vert.qsb"
                        fragmentShader: "palette.frag.qsb"
                    }
                }
            }
        }

        Component {
            id: videoComponent
            Item {
                id: videoRoot
                anchors.fill: parent
                property string sourceFile: parent.sourceFile
                property bool tint: wallpaper.tintEnabled

                Item {
                    id: paletteSourceItem
                    visible: true
                    width: wallpaper.effectivePaletteSize
                    height: 1
                    opacity: 0

                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: wallpaper.effectivePalette
                            Rectangle {
                                width: 1
                                height: 1
                                color: {
                                    if (typeof modelData === "string") {
                                        if (modelData.charAt(0) === '#') {
                                            return modelData;
                                        } else {
                                            return Colors[modelData] || "black";
                                        }
                                    }
                                    return modelData;
                                }
                            }
                        }
                    }

                    Component.onCompleted: {
                        if (width > 0) paletteTextureSource.scheduleUpdate();
                    }
                    onWidthChanged: {
                        if (width > 0) paletteTextureSource.scheduleUpdate();
                    }
                }

                ShaderEffectSource {
                    id: paletteTextureSource
                    sourceItem: paletteSourceItem
                    hideSource: true
                    visible: false
                    smooth: false
                    recursive: false
                }

                Item {
                    id: mediaContainer
                    anchors.fill: parent
                    clip: true

                    Video {
                        id: videoPlayer
                        anchors.fill: parent
                        source: videoRoot.sourceFile ? "file://" + videoRoot.sourceFile : ""
                        loops: MediaPlayer.Infinite
                        autoPlay: true
                        muted: true
                        fillMode: VideoOutput.PreserveAspectCrop
                        opacity: videoRoot.tint ? 0.0 : 1.0
                        visible: true
                    }

                    ShaderEffectSource {
                        id: mediaTextureSource
                        sourceItem: videoPlayer
                        hideSource: videoRoot.tint
                        live: true
                        smooth: true
                        recursive: false
                    }

                    ShaderEffect {
                        anchors.fill: parent
                        visible: videoRoot.tint && wallpaper.effectivePaletteSize > 0
                        property var source: mediaTextureSource
                        property var paletteTexture: paletteTextureSource
                        property real paletteSize: wallpaper.effectivePaletteSize
                        property real texWidth: Math.max(videoPlayer.width, 1)
                        property real texHeight: Math.max(videoPlayer.height, 1)

                        vertexShader: "palette.vert.qsb"
                        fragmentShader: "palette.frag.qsb"
                    }
                }
            }
        }
    }
}