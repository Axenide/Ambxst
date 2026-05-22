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
    WlrLayershell.namespace: "nothingless:wallpaper"
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    property string wallpaperDir: wallpaperConfig.adapter.wallPath
    property string fallbackDir: decodeURIComponent(Qt.resolvedUrl("../../../../assets/nothingless-wallpapers").toString().replace("file://", ""))
    property var wallpaperPaths: []
    property var subfolderFilters: []
    property var allSubdirs: []

    // Custom palette loaded from JSON file
    property var customPalette: []
    property int customPaletteSize: 0

    // Default palette (optimizedPalette) as fallback
    readonly property var fallbackPalette: optimizedPalette
    readonly property int fallbackPaletteSize: optimizedPalette.length

    // Effective palette that will be used in the shader
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
    property alias interpolationEnabled: wallpaperAdapter.interpolationEnabled
    property alias interpolationMultiplier: wallpaperAdapter.interpolationMultiplier
    property alias targetInputFps: wallpaperAdapter.targetInputFps
    property int thumbnailsVersion: 0

    // Optimized palette color names (used as fallback)
    readonly property var optimizedPalette: [
        "background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim",
        "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest",
        "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary",
        "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow",
        "cyan", "lightCyan", "magenta", "lightMagenta"
    ]

    // -------------------------------------------------------------------
    // Bindings to sync state from primary wallpaper manager
    // -------------------------------------------------------------------
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

    // -------------------------------------------------------------------
    // Color presets
    // -------------------------------------------------------------------
    property string colorPresetsDir: Quickshell.env("HOME") + "/.config/nothingless/colors"
    property string officialColorPresetsDir: decodeURIComponent(Qt.resolvedUrl("../../../../assets/colors").toString().replace("file://", ""))
    onColorPresetsDirChanged: console.log("Color Presets Directory:", colorPresetsDir)
    property list<string> colorPresets: []
    onColorPresetsChanged: console.log("Color Presets Updated:", colorPresets)
    property string activeColorPreset: wallpaperConfig.adapter.activeColorPreset || ""

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
        if (!activeColorPreset) return;

        var mode = Config.theme.lightMode ? "light.json" : "dark.json";
        var officialFile = officialColorPresetsDir + "/" + activeColorPreset + "/" + mode;
        var userFile = colorPresetsDir + "/" + activeColorPreset + "/" + mode;
        var dest = Quickshell.env("HOME") + "/.cache/nothingless/colors.json";

        var cmd = "if [ -f '" + officialFile + "' ]; then cp '" + officialFile + "' '" + dest + "'; else cp '" + userFile + "' '" + dest + "'; fi";
        console.log("Applying color preset:", activeColorPreset);
        applyPresetProcess.command = ["bash", "-c", cmd];
        applyPresetProcess.running = true;
    }

    function setColorPreset(name) {
        wallpaperConfig.adapter.activeColorPreset = name;
    }

    // -------------------------------------------------------------------
    // Utility functions for file types
    // -------------------------------------------------------------------
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
        var basePath = wallpaperDir.endsWith("/") ? wallpaperDir : wallpaperDir + "/";
        var relativePath = filePath.replace(basePath, "");
        var pathParts = relativePath.split('/');
        var fileName = pathParts.pop();
        var thumbnailName = fileName + ".jpg";
        var relativeDir = pathParts.join('/');
        return Quickshell.env("HOME") + "/.cache/nothingless/thumbnails/" + relativeDir + "/" + thumbnailName;
    }

    function getDisplaySource(filePath) {
        var fileType = getFileType(filePath);
        if (fileType === 'video' || fileType === 'image' || fileType === 'gif') {
            return getThumbnailPath(filePath);
        }
        return filePath;
    }

    function getColorSource(filePath) {
        var fileType = getFileType(filePath);
        if (fileType === 'video') {
            return getThumbnailPath(filePath);
        }
        return filePath;
    }

    function getLockscreenFramePath(filePath) {
        if (!filePath) return "";
        var fileType = getFileType(filePath);
        if (fileType === 'image') return filePath;
        if (fileType === 'video' || fileType === 'gif') {
            var fileName = filePath.split('/').pop();
            return Quickshell.env("HOME") + "/.cache/nothingless/lockscreen/" + fileName + ".jpg";
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
        var dataPath = Quickshell.env("HOME") + "/.cache/nothingless";
        lockscreenWallpaperScript.command = ["python3", scriptPath, filePath, dataPath];
        lockscreenWallpaperScript.running = true;
    }

    function getSubfolderFromPath(filePath) {
        var basePath = wallpaperDir.endsWith("/") ? wallpaperDir : wallpaperDir + "/";
        var relativePath = filePath.replace(basePath, "");
        var parts = relativePath.split("/");
        if (parts.length > 1) return parts[0];
        return "";
    }

    // -------------------------------------------------------------------
    // Palette loading
    // -------------------------------------------------------------------
    function loadCustomPalette(filePath) {
        if (!filePath) return;
        // Vaciar paleta actual para usar fallback mientras se carga la nueva
        customPalette = [];
        customPaletteSize = 0;
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
                        fallbackToDefaultPalette();
                    }
                } else {
                    console.warn("Palette file not found (status " + xhr.status + "):", palettePath);
                    fallbackToDefaultPalette();
                }
            }
        };
        xhr.send();
    }

    function fallbackToDefaultPalette() {
        customPalette = [];
        customPaletteSize = 0;
    }

    function getPalettePath(filePath) {
        var basePath = wallpaperDir.endsWith("/") ? wallpaperDir : wallpaperDir + "/";
        var relativePath = filePath.replace(basePath, "");
        return Quickshell.env("HOME") + "/.cache/nothingless/palettes/" + relativePath + ".json";
    }

    function scanSubfolders() {
        if (!wallpaperDir) return;
        var cmd = ["find", wallpaperDir, "-mindepth", "1", "-name", ".*", "-prune", "-o", "-type", "d", "-print"];
        scanSubfoldersProcess.command = cmd;
        scanSubfoldersProcess.running = true;
    }

    onWallpaperDirChanged: {
        if (!_wallpaperDirInitialized) return;
        if (GlobalStates.wallpaperManager !== wallpaper) return;

        console.log("Wallpaper directory changed to:", wallpaperDir);
        usingFallback = false;
        wallpaperPaths = [];
        subfolderFilters = [];
        directoryWatcher.path = wallpaperDir;

        var cmd = ["find", wallpaperDir, "-name", ".*", "-prune", "-o", "-type", "f",
            "(", "-name", "*.jpg", "-o", "-name", "*.jpeg", "-o", "-name", "*.png",
            "-o", "-name", "*.webp", "-o", "-name", "*.tif", "-o", "-name", "*.tiff",
            "-o", "-name", "*.gif", "-o", "-name", "*.mp4", "-o", "-name", "*.webm",
            "-o", "-name", "*.mov", "-o", "-name", "*.avi", "-o", "-name", "*.mkv", ")", "-print"];
        scanWallpapers.command = cmd;
        scanWallpapers.running = true;
        scanSubfolders();

        if (delayedThumbnailGen.running)
            delayedThumbnailGen.restart();
        else
            delayedThumbnailGen.start();
    }

    onCurrentWallpaperChanged: {
        // Matugen is executed manually in change functions
    }

    // -------------------------------------------------------------------
    // Wallpaper control functions
    // -------------------------------------------------------------------
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
                let perScreen = Object.assign({}, wallpaperConfig.adapter.perScreenWallpapers || {});
                perScreen[targetScreen] = path;
                wallpaperConfig.adapter.perScreenWallpapers = perScreen;

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
        if (wallpaperPaths.length === 0) return;
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
        if (wallpaperPaths.length === 0) return;
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

            if (matugenProcessWithConfig.running) matugenProcessWithConfig.running = false;
            if (matugenProcessNormal.running) matugenProcessNormal.running = false;

            var commandWithConfig = ["matugen", "image", matugenSource, "--source-color-index", "0",
                "-c", decodeURIComponent(Qt.resolvedUrl("../../../../assets/matugen/config.toml").toString().replace("file://", "")),
                "-t", wallpaperConfig.adapter.matugenScheme];
            if (Config.theme.lightMode) commandWithConfig.push("-m", "light");
            matugenProcessWithConfig.command = commandWithConfig;
            matugenProcessWithConfig.running = true;

            var commandNormal = ["matugen", "image", matugenSource, "--source-color-index", "0",
                "-t", wallpaperConfig.adapter.matugenScheme];
            if (Config.theme.lightMode) commandNormal.push("-m", "light");
            matugenProcessNormal.command = commandNormal;
            matugenProcessNormal.running = true;
        }
    }

    Component.onCompleted: {
        if (GlobalStates.wallpaperManager !== null) {
            _wallpaperDirInitialized = true;
            return;
        }
        GlobalStates.wallpaperManager = wallpaper;

        checkWallpapersJson.running = true;
        scanColorPresets();
        presetsWatcher.reload();
        officialPresetsWatcher.reload();
        wallpaperConfig.reload();

        Qt.callLater(function () {
            if (currentWallpaper) {
                generateLockscreenFrame(currentWallpaper);
                loadCustomPalette(currentWallpaper);
            }
        });
    }

    // -------------------------------------------------------------------
    // Configuration file handling
    // -------------------------------------------------------------------
    FileView {
        id: wallpaperConfig
        path: Quickshell.env("HOME") + "/.cache/nothingless/wallpapers.json"
        watchChanges: true

        onLoaded: {
            if (!wallpaperConfig.adapter.wallPath) {
                console.log("Loaded config but wallPath is empty, using fallback");
                wallpaperConfig.adapter.wallPath = fallbackDir;
            }
        }

        onFileChanged: reload()
        onAdapterUpdated: {
            if (!wallpaperConfig.adapter.matugenScheme) {
                wallpaperConfig.adapter.matugenScheme = "scheme-tonal-spot";
            }
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
            property bool interpolationEnabled: false
            property real targetInputFps: 24.0 
            property int interpolationMultiplier: 2
            property var perScreenWallpapers: ({})

            onActiveColorPresetChanged: {
                if (wallpaperConfig.adapter.activeColorPreset !== wallpaper.activeColorPreset) {
                    wallpaper.activeColorPreset = wallpaperConfig.adapter.activeColorPreset || "";
                }
            }

            onCurrentWallChanged: {
                if (!wallpaper._wallpaperDirInitialized) return;
                if (currentWall && currentWall !== wallpaper.currentWallpaper) {
                    if (wallpaper.wallpaperPaths.length === 0) return;
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
                    if (!wallpaper._wallpaperDirInitialized && GlobalStates.wallpaperManager === wallpaper) {
                        wallpaper._wallpaperDirInitialized = true;
                        directoryWatcher.path = wallPath;
                        directoryWatcher.reload();

                        var cmd = ["find", wallPath, "-name", ".*", "-prune", "-o", "-type", "f",
                            "(", "-name", "*.jpg", "-o", "-name", "*.jpeg", "-o", "-name", "*.png",
                            "-o", "-name", "*.webp", "-o", "-name", "*.tif", "-o", "-name", "*.tiff",
                            "-o", "-name", "*.gif", "-o", "-name", "*.mp4", "-o", "-name", "*.webm",
                            "-o", "-name", "*.mov", "-o", "-name", "*.avi", "-o", "-name", "*.mkv", ")", "-print"];
                        scanWallpapers.command = cmd;
                        scanWallpapers.running = true;
                        wallpaper.scanSubfolders();
                        delayedThumbnailGen.start();
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------
    // External processes
    // -------------------------------------------------------------------
    Process {
        id: checkWallpapersJson
        running: false
        command: ["test", "-f", Quickshell.env("HOME") + "/.cache/nothingless/wallpapers.json"]
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
        stdout: StdioCollector { onStreamFinished: { if (text.length > 0) console.log("Matugen (with config) output:", text); } }
        stderr: StdioCollector { onStreamFinished: { if (text.length > 0) console.warn("Matugen (with config) error:", text); } }
        onExited: { console.log("Matugen with config finished"); }
    }

    Process {
        id: matugenProcessNormal
        running: false
        command: []
        stdout: StdioCollector { onStreamFinished: { if (text.length > 0) console.log("Matugen (normal) output:", text); } }
        stderr: StdioCollector { onStreamFinished: { if (text.length > 0) console.warn("Matugen (normal) error:", text); } }
        onExited: { console.log("Matugen normal finished"); }
    }

    Process {
        id: thumbnailGeneratorScript
        running: false
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("../../../../scripts/thumbgen.py").toString().replace("file://", "")),
                 Quickshell.env("HOME") + "/.cache/nothingless/wallpapers.json",
                 Quickshell.env("HOME") + "/.cache/nothingless", fallbackDir]
        stdout: StdioCollector { onStreamFinished: { if (text.length > 0) console.log("Thumbnail Generator:", text); } }
        stderr: StdioCollector { onStreamFinished: { if (text.length > 0) console.warn("Thumbnail Generator Error:", text); } }
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
        interval: 2000
        repeat: false
        onTriggered: thumbnailGeneratorScript.running = true
    }

    Process {
        id: lockscreenWallpaperScript
        running: false
        command: []
        stdout: StdioCollector { onStreamFinished: { if (text.length > 0) console.log("Lockscreen Wallpaper Generator:", text); } }
        stderr: StdioCollector { onStreamFinished: { if (text.length > 0) console.warn("Lockscreen Wallpaper Generator Error:", text); } }
        onExited: function (exitCode) {
            if (exitCode === 0) console.log("✅ Lockscreen wallpaper ready");
            else console.warn("⚠️ Lockscreen wallpaper generation failed with code:", exitCode);
        }
    }

    Process {
        id: scanSubfoldersProcess
        running: false
        command: wallpaperDir ? ["find", wallpaperDir, "-mindepth", "1", "-name", ".*", "-prune", "-o", "-type", "d", "-print"] : []
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("scanSubfolders stdout:", text);
                var rawPaths = text.trim().split("\n").filter(function (f) { return f.length > 0; });
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
                console.log("Updated subfolderFilters:", subfolderFilters);
            }
        }
        stderr: StdioCollector { onStreamFinished: { if (text.length > 0) console.warn("Error scanning subfolders:", text); } }
        onRunningChanged: {
            if (running) console.log("Starting scanSubfolders for directory:", wallpaperDir);
            else console.log("Finished scanSubfolders");
        }
    }

    // -------------------------------------------------------------------
    // Directory watchers
    // -------------------------------------------------------------------
    FileView {
        id: directoryWatcher
        path: wallpaperDir
        watchChanges: true
        printErrors: false
        onFileChanged: {
            if (wallpaperDir === "") return;
            console.log("Wallpaper directory changed, rescanning...");
            scanWallpapers.running = true;
            scanSubfoldersProcess.running = true;
            if (delayedThumbnailGen.running) delayedThumbnailGen.restart();
            else delayedThumbnailGen.start();
        }
    }

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
                if (delayedThumbnailGen.running) delayedThumbnailGen.restart();
                else delayedThumbnailGen.start();
            }
        }
    }

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
        command: wallpaperDir ? ["find", wallpaperDir, "-name", ".*", "-prune", "-o", "-type", "f",
            "(", "-name", "*.jpg", "-o", "-name", "*.jpeg", "-o", "-name", "*.png",
            "-o", "-name", "*.webp", "-o", "-name", "*.tif", "-o", "-name", "*.tiff",
            "-o", "-name", "*.gif", "-o", "-name", "*.mp4", "-o", "-name", "*.webm",
            "-o", "-name", "*.mov", "-o", "-name", "*.avi", "-o", "-name", "*.mkv", ")", "-print"] : []
        onRunningChanged: {
            if (running && wallpaperDir === "") {
                console.log("Blocking scanWallpapers because wallpaperDir is empty");
                running = false;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                var files = text.trim().split("\n").filter(function (f) { return f.length > 0; });
                if (files.length === 0) {
                    console.log("No wallpapers found in main directory, using fallback");
                    usingFallback = true;
                    scanFallback.running = true;
                } else {
                    usingFallback = false;
                    var newFiles = files.sort();
                    var listChanged = JSON.stringify(newFiles) !== JSON.stringify(wallpaperPaths);
                    if (listChanged) {
                        console.log("Wallpaper directory updated. Found", newFiles.length, "images");
                        wallpaperPaths = newFiles;
                        if (wallpaperPaths.length > 0) {
                            if (delayedThumbnailGen.running) delayedThumbnailGen.restart();
                            else delayedThumbnailGen.start();
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
        command: ["find", fallbackDir, "-name", ".*", "-prune", "-o", "-type", "f",
            "(", "-name", "*.jpg", "-o", "-name", "*.jpeg", "-o", "-name", "*.png",
            "-o", "-name", "*.webp", "-o", "-name", "*.tif", "-o", "-name", "*.tiff",
            "-o", "-name", "*.gif", "-o", "-name", "*.mp4", "-o", "-name", "*.webm",
            "-o", "-name", "*.mov", "-o", "-name", "*.avi", "-o", "-name", "*.mkv", ")", "-print"]
        stdout: StdioCollector {
            onStreamFinished: {
                var files = text.trim().split("\n").filter(function (f) { return f.length > 0; });
                console.log("Using fallback wallpapers. Found", files.length, "images");
                if (usingFallback) {
                    wallpaperPaths = files.sort();
                    if (wallpaperPaths.length > 0) {
                        if (wallpaperConfig.adapter.currentWall) {
                            var savedIndex = wallpaperPaths.indexOf(wallpaperConfig.adapter.currentWall);
                            if (savedIndex !== -1) currentIndex = savedIndex;
                            else currentIndex = 0;
                        } else {
                            currentIndex = 0;
                        }
                        if (!initialLoadCompleted) {
                            if (!wallpaperConfig.adapter.currentWall) {
                                wallpaperConfig.adapter.currentWall = wallpaperPaths[0];
                            }
                            initialLoadCompleted = true;
                        }
                    }
                }
            }
        }
    }

    Process {
        id: scanPresetsProcess
        running: false
        command: ["find", officialColorPresetsDir, colorPresetsDir, "-mindepth", "1", "-maxdepth", "1", "-type", "d"]
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("Scan Presets Output:", text);
                var rawLines = text.trim().split("\n");
                var uniqueNames = [];
                for (var i = 0; i < rawLines.length; i++) {
                    var line = rawLines[i].trim();
                    if (line.length === 0) continue;
                    var name = line.split('/').pop();
                    if (uniqueNames.indexOf(name) === -1) uniqueNames.push(name);
                }
                uniqueNames.sort();
                console.log("Found color presets:", uniqueNames);
                colorPresets = uniqueNames;
            }
        }
        stderr: StdioCollector { onStreamFinished: { /* suppress errors */ } }
    }

    Process {
        id: applyPresetProcess
        running: false
        command: []
        onExited: code => {
            if (code === 0) console.log("Color preset applied successfully");
            else console.warn("Failed to apply color preset, code:", code);
        }
    }

    // -------------------------------------------------------------------
    // Reusable shader effect for palette tinting
    // -------------------------------------------------------------------
    component PaletteShaderEffect: ShaderEffect {
        id: effect
        property var source: null
        property var paletteTexture: null
        property real paletteSize: 0
        property real texWidth: 1
        property real texHeight: 1

        vertexShader: "palette.vert.qsb"
        fragmentShader: "palette.frag.qsb"
    }

    // -------------------------------------------------------------------
    // Component for static images (jpg, png, webp, etc.)
    // -------------------------------------------------------------------
    Component {
        id: staticImageComponent
        Item {
            id: staticImageRoot
            anchors.fill: parent
            property string sourceFile
            property bool tint: wallpaper.tintEnabled

            onSourceFileChanged: console.log("staticImageComponent: sourceFile =", sourceFile)
            onTintChanged: console.log("staticImageComponent: tint =", tint)

            // ─── Canvas-based palette texture (pre-baked once; no per-frame render-to-texture) ───
            Canvas {
                id: paletteCanvas
                width: wallpaper.effectivePaletteSize
                height: 1
                visible: false

                onPaint: {
                    var ctx = getContext("2d");
                    if (!ctx) return;
                    ctx.clearRect(0, 0, width, height);
                    var pal = wallpaper.effectivePalette;
                    for (var i = 0; i < pal.length; i++) {
                        var c = pal[i];
                        if (typeof c === "string" && c.charAt(0) === '#') {
                            ctx.fillStyle = c;
                        } else {
                            ctx.fillStyle = Colors[c] || "#000000";
                        }
                        ctx.fillRect(i, 0, 1, 1);
                    }
                }

                Component.onCompleted: requestPaint()    // ⚡ Trigger initial paint

                Connections {
                    target: Colors
                    function onFileChanged() { Qt.callLater(paletteCanvas.requestPaint); }
                }
                Connections {
                    target: wallpaper
                    function onEffectivePaletteChanged() { paletteCanvas.requestPaint(); }
                }
            }

            ShaderEffectSource {
                id: paletteTextureSource
                sourceItem: paletteCanvas
                live: false                    // ⚡ static texture — no per-frame re-capture
                hideSource: true
                visible: false
                smooth: false
                recursive: false

                Connections {
                    target: paletteCanvas
                    function onPainted() { paletteTextureSource.scheduleUpdate(); }
                }
            }

            // Image with layer effect for tinting
            Image {
                id: rawImage
                anchors.fill: parent
                source: staticImageRoot.sourceFile ? "file://" + staticImageRoot.sourceFile : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
                visible: true

                // Layer effect for palette tinting
                layer.enabled: staticImageRoot.tint && wallpaper.effectivePaletteSize > 0
                layer.effect: PaletteShaderEffect {
                    property var paletteTexture: paletteTextureSource
                    property int paletteSize: wallpaper.effectivePaletteSize
                    property real sharpness: 20.0
                    property real mixStrength: 1.0
                    texWidth: rawImage.width
                    texHeight: rawImage.height

                    vertexShader: "palette.vert.qsb"
                    fragmentShader: "palette.frag.qsb"
                }

                onStatusChanged: {
                    if (status === Image.Ready) {
                        console.log("rawImage ready");
                    }
                }
            }
        }
    }
    // -------------------------------------------------------------------
    // Component for videos and GIFs with software‑controlled input FPS
    // -------------------------------------------------------------------
    Component {
        id: videoComponent
        Item {
            id: videoRoot
            anchors.fill: parent
            property string sourceFile
            property bool tint: wallpaper.tintEnabled
            property bool interpolate: wallpaper.interpolationEnabled
            property int multiplier: wallpaper.interpolationMultiplier
            property real targetInputFps: 24.0

            // Frame control properties
            property real originalFps: 30
            property real effectiveInputFps: targetInputFps
            property real captureIntervalMs: 1000 / effectiveInputFps
            property real lastCaptureTime: 0
            property real blendFactor: 0.0
            property bool isOriginalFrame: true
            property int frameCounter: 0

            // FPS estimation
            property real fpsOutput: 0
            property int frameCountSinceLastSecond: 0
            property real lastFpsUpdateTime: 0

            // Debug overlay
            property bool debugMode: false

            onTintChanged: console.log("videoComponent: tint =", tint)
            onInterpolateChanged: {
                console.log("videoComponent: interpolate =", interpolate)
                if (interpolate) {
                    captureTimer.restart()
                    frameAnimation.running = true
                    previousFrameSource.scheduleUpdate()
                    videoRoot.lastCaptureTime = Date.now()
                } else {
                    captureTimer.stop()
                    frameAnimation.running = false
                }
            }
            onMultiplierChanged: {
                // multiplier does not affect capture rate
            }
            onTargetInputFpsChanged: {
                effectiveInputFps = Math.min(originalFps, targetInputFps)
                captureIntervalMs = 1000 / effectiveInputFps
                if (interpolate) {
                    captureTimer.restart()
                    videoRoot.lastCaptureTime = Date.now()
                }
            }

            // ═══════════════════════════════════════════════════════════
            // Canvas-based palette texture (pre-baked once, no per-frame re-render)
            // ═══════════════════════════════════════════════════════════
            Canvas {
                id: paletteCanvas2
                width: wallpaper.effectivePaletteSize
                height: 1
                visible: false

                onPaint: {
                    var ctx = getContext("2d");
                    if (!ctx) return;
                    ctx.clearRect(0, 0, width, height);
                    var pal = wallpaper.effectivePalette;
                    for (var i = 0; i < pal.length; i++) {
                        var c = pal[i];
                        if (typeof c === "string" && c.charAt(0) === '#') {
                            ctx.fillStyle = c;
                        } else {
                            ctx.fillStyle = Colors[c] || "#000000";
                        }
                        ctx.fillRect(i, 0, 1, 1);
                    }
                }

                Component.onCompleted: requestPaint()    // ⚡ Trigger initial paint

                Connections {
                    target: Colors
                    function onFileChanged() { Qt.callLater(paletteCanvas2.requestPaint); }
                }
                Connections {
                    target: wallpaper
                    function onEffectivePaletteChanged() { paletteCanvas2.requestPaint(); }
                }
            }

            ShaderEffectSource {
                id: paletteTextureSource
                sourceItem: paletteCanvas2
                live: false                    // ⚡ static texture — no per-frame re-capture
                hideSource: true
                visible: false
                smooth: false
                recursive: false

                Connections {
                    target: paletteCanvas2
                    function onPainted() { paletteTextureSource.scheduleUpdate(); }
                }
            }

            // -------------------------------------------------------------------
            // Original video player (plays at normal speed)
            // -------------------------------------------------------------------
            Video {
                id: videoPlayer
                anchors.fill: parent
                source: videoRoot.sourceFile ? "file://" + videoRoot.sourceFile : ""
                loops: MediaPlayer.Infinite
                autoPlay: true
                muted: true
                fillMode: VideoOutput.PreserveAspectCrop
                visible: !videoRoot.interpolate || videoRoot.multiplier <= 1
                // Siempre a velocidad normal; el control de FPS lo hace el Timer
                playbackRate: 1.0

                onMetaDataChanged: {
                    if (metaData.frameRate && metaData.frameRate > 0) {
                        videoRoot.originalFps = metaData.frameRate
                        videoRoot.effectiveInputFps = Math.min(videoRoot.originalFps, videoRoot.targetInputFps)
                        videoRoot.captureIntervalMs = 1000 / videoRoot.effectiveInputFps
                        console.log("videoComponent: detected FPS =", videoRoot.originalFps,
                                    "effective input FPS =", videoRoot.effectiveInputFps)
                    }
                }

                onPlaybackStateChanged: {
                    if (playbackState === MediaPlayer.PlayingState && videoRoot.interpolate) {
                        captureTimer.restart()
                        frameAnimation.running = true
                        previousFrameSource.scheduleUpdate()
                        videoRoot.lastCaptureTime = Date.now()
                    } else {
                        captureTimer.stop()
                        frameAnimation.running = false
                    }
                }
            }

            // Live capture of the current frame
            ShaderEffectSource {
                id: liveSource
                // Only capture from videoPlayer when interpolation is ON.
                // When off, sourceItem = null so QSGVideoNode renders directly to screen
                // without being forced into texture-capture mode.
                sourceItem: videoRoot.interpolate ? videoPlayer : null
                live: videoRoot.interpolate
                hideSource: true
                smooth: true
                visible: false
            }

            // Buffer for the previous frame (updated at target input FPS)
            ShaderEffectSource {
                id: previousFrameSource
                sourceItem: videoRoot.interpolate ? videoPlayer : null
                live: false
                hideSource: true
                smooth: true
                visible: false
            }

            // -------------------------------------------------------------------
            // Timer that captures frames at the desired input FPS
            // -------------------------------------------------------------------
            Timer {
                id: captureTimer
                interval: videoRoot.captureIntervalMs
                repeat: true
                running: false
                onTriggered: {
                    if (!videoRoot.interpolate) return
                    previousFrameSource.scheduleUpdate()
                    videoRoot.lastCaptureTime = Date.now()
                    videoRoot.isOriginalFrame = true
                    console.log("Captured input frame at", videoRoot.lastCaptureTime)
                }
            }

            // -------------------------------------------------------------------
            // FrameAnimation for continuous blendFactor updates (VSync synced)
            // -------------------------------------------------------------------
            FrameAnimation {
                id: frameAnimation
                running: false
                onTriggered: {
                    if (!videoRoot.interpolate || videoRoot.multiplier <= 1) return
                    if (videoPlayer.playbackState !== MediaPlayer.PlayingState) return

                    var now = Date.now()
                    var elapsed = now - videoRoot.lastCaptureTime
                    var factor = elapsed / videoRoot.captureIntervalMs
                    videoRoot.blendFactor = Math.min(1.0, factor)
                    videoRoot.isOriginalFrame = (videoRoot.blendFactor < 0.01 || videoRoot.blendFactor > 0.99)

                    // Update FPS statistics
                    videoRoot.frameCountSinceLastSecond++
                    var fpsElapsed = now - videoRoot.lastFpsUpdateTime
                    if (fpsElapsed >= 1000) {
                        videoRoot.fpsOutput = videoRoot.frameCountSinceLastSecond * 1000 / fpsElapsed
                        videoRoot.frameCountSinceLastSecond = 0
                        videoRoot.lastFpsUpdateTime = now
                    }
                    videoRoot.frameCounter++
                }
            }

            // -------------------------------------------------------------------
            // Interpolation Shader Effect
            // -------------------------------------------------------------------
            ShaderEffect {
                id: interpolationEffect
                anchors.fill: parent
                visible: videoRoot.interpolate && videoRoot.multiplier > 1
                property var currentFrame: liveSource
                property var previousFrame: previousFrameSource
                property real blendFactor: videoRoot.blendFactor
                property vector2d iResolution: Qt.vector2d(width, height)
                property int blockSize: 12
                property int searchRadius: 3
                property real motionThreshold: 0.05
                property bool debugMode: videoRoot.debugMode
                property bool isOriginalFrame: videoRoot.isOriginalFrame
                property int frameCounter: videoRoot.frameCounter

                vertexShader: "interpol.vert.qsb"
                fragmentShader: "interpol.frag.qsb"

                onStatusChanged: {
                    if (status === ShaderEffect.Error) {
                        console.warn("❌ Interpolation shader error - falling back to direct video")
                        videoRoot.interpolate = false
                    } else if (status === ShaderEffect.Ready) {
                        console.log("✅ Interpolation shader ready")
                    }
                }
            }

            // -------------------------------------------------------------------
            // Tint layer applied over everything
            // -------------------------------------------------------------------
            layer.enabled: videoRoot.tint && wallpaper.effectivePaletteSize > 0
            layer.smooth: true
            layer.effect: ShaderEffect {
                property var paletteTexture: paletteTextureSource
                property int paletteSize: wallpaper.effectivePaletteSize
                property real sharpness: 20.0
                property real mixStrength: 1.0
                property real texWidth: videoRoot.width
                property real texHeight: videoRoot.height

                vertexShader: "palette.vert.qsb"
                fragmentShader: "palette.frag.qsb"
            }

            // -------------------------------------------------------------------
            // Debug overlay
            // -------------------------------------------------------------------
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.margins: 8
                color: "#80000000"
                radius: 4
                visible: videoRoot.debugMode
                width: debugColumn.implicitWidth + 16
                height: debugColumn.implicitHeight + 8

                Column {
                    id: debugColumn
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        text: "Input FPS: " + videoRoot.effectiveInputFps.toFixed(1) + " (orig: " + videoRoot.originalFps.toFixed(1) + ")"
                        color: "white"
                        font.pixelSize: 12
                    }
                    Text {
                        text: "Multiplier: x" + videoRoot.multiplier
                        color: "white"
                        font.pixelSize: 12
                    }
                    Text {
                        text: "Target Output FPS: " + (videoRoot.effectiveInputFps * videoRoot.multiplier).toFixed(1)
                        color: "#aaffaa"
                        font.pixelSize: 12
                    }
                    Text {
                        text: "Actual Output FPS: " + videoRoot.fpsOutput.toFixed(1)
                        color: "#ffaa00"
                        font.pixelSize: 12
                    }
                    Text {
                        text: "Frame: " + (videoRoot.isOriginalFrame ? "ORIGINAL" : "INTERPOLATED")
                        color: videoRoot.isOriginalFrame ? "#aaaaff" : "#aaffaa"
                        font.pixelSize: 12
                    }
                    Text {
                        text: "Blend: " + videoRoot.blendFactor.toFixed(2)
                        color: "white"
                        font.pixelSize: 12
                    }
                    Text {
                        text: "Count: " + videoRoot.frameCounter
                        color: "white"
                        font.pixelSize: 12
                    }
                }
            }

            // -------------------------------------------------------------------
            // Source synchronization
            // -------------------------------------------------------------------
            onSourceFileChanged: {
                console.log("videoComponent: sourceFile =", sourceFile)
                if (sourceFile) {
                    videoPlayer.source = "file://" + sourceFile
                } else {
                    videoPlayer.source = ""
                }
                previousFrameSource.scheduleUpdate()
                videoRoot.lastCaptureTime = Date.now()
                videoRoot.lastFpsUpdateTime = Date.now()
                videoRoot.frameCountSinceLastSecond = 0
                videoRoot.fpsOutput = 0
            }

            Component.onCompleted: {
                if (sourceFile) {
                    videoPlayer.source = "file://" + sourceFile
                }
                previousFrameSource.scheduleUpdate()
                videoRoot.lastCaptureTime = Date.now()
                videoRoot.lastFpsUpdateTime = Date.now()
            }
        }
    }
    // -------------------------------------------------------------------
    // Main wallpaper display area
    // -------------------------------------------------------------------
    Rectangle {
        id: background
        anchors.fill: parent
        color: "black"
        focus: true

        Keys.onLeftPressed: {
            if (wallpaper.wallpaperPaths.length > 0) wallpaper.previousWallpaper();
        }

        Keys.onRightPressed: {
            if (wallpaper.wallpaperPaths.length > 0) wallpaper.nextWallpaper();
        }

        // Container that handles source changes, transitions, and palette loading
        Item {
            id: wallImageContainer
            anchors.fill: parent
            property string source: wallpaper.effectiveWallpaper
            property string previousSource: ""

            onSourceChanged: {
                console.log("wallImageContainer source changed to:", source);
                if (source) wallpaper.loadCustomPalette(source);
                // Animation will be triggered after loader finishes loading
            }

            SequentialAnimation {
                id: transitionAnimation
                ParallelAnimation {
                    NumberAnimation { target: wallImageContainer; property: "scale"; to: 1.01; duration: Config.animDuration; easing.type: Easing.OutCubic }
                    NumberAnimation { target: wallImageContainer; property: "opacity"; to: 0.5; duration: Config.animDuration; easing.type: Easing.OutCubic }
                }
                ParallelAnimation {
                    NumberAnimation { target: wallImageContainer; property: "scale"; to: 1.0; duration: Config.animDuration; easing.type: Easing.OutCubic }
                    NumberAnimation { target: wallImageContainer; property: "opacity"; to: 1.0; duration: Config.animDuration; easing.type: Easing.OutCubic }
                }
            }

            Loader {
                id: wallImageLoader
                anchors.fill: parent
                asynchronous: true
                sourceComponent: {
                    if (!wallImageContainer.source) return null;
                    var fileType = wallpaper.getFileType(wallImageContainer.source);
                    console.log("Loader: fileType =", fileType, "source =", wallImageContainer.source);
                    if (fileType === 'image') return staticImageComponent;
                    else if (fileType === 'gif' || fileType === 'video') return videoComponent;
                    return staticImageComponent;
                }

                onLoaded: {
                    console.log("Loader: item loaded, assigning sourceFile =", wallImageContainer.source);
                    if (item) {
                        item.sourceFile = wallImageContainer.source;
                    }
                    // Trigger animation after new content is loaded
                    if (wallImageContainer.previousSource !== "" && 
                        wallImageContainer.source !== wallImageContainer.previousSource &&
                        Config.animDuration > 0) {
                        transitionAnimation.restart();
                    }
                    wallImageContainer.previousSource = wallImageContainer.source;
                }

                // Bind sourceFile directly to wallImageContainer.source
                Binding {
                    target: wallImageLoader.item
                    property: "sourceFile"
                    value: wallImageContainer.source
                    when: wallImageLoader.item !== null
                }
            }

            // Fallback in case Binding doesn't trigger
            Connections {
                target: wallImageContainer
                function onSourceChanged() {
                    if (wallImageLoader.item) {
                        console.log("Connections: updating sourceFile to", wallImageContainer.source);
                        wallImageLoader.item.sourceFile = wallImageContainer.source;
                    }
                }
            }
        }
    }
}