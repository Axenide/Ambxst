import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.modules.globals
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
    WlrLayershell.namespace: "quickshell:wallpaper"
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    property string wallpaperDir: wallpaperConfig.adapter.wallPath || fallbackDir
    property string fallbackDir: Qt.resolvedUrl("../../../../assets/wallpapers_example").toString().replace("file://", "")
    property list<string> wallpaperPaths: []
    property var subfolderFilters: []
    property int currentIndex: 0
    property string currentWallpaper: initialLoadCompleted && wallpaperPaths.length > 0 ? wallpaperPaths[currentIndex] : ""
    property bool initialLoadCompleted: false
    property bool usingFallback: false
    property string currentMatugenScheme: wallpaperConfig.adapter.matugenScheme

    onCurrentMatugenSchemeChanged: {
        // Optional: Add any logic if needed when scheme changes
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
        var fileName = filePath.split('/').pop();
        var fileType = getFileType(filePath);
        var cacheDir = "";

        if (fileType === 'video') {
            cacheDir = "video_thumbnails";
        } else if (fileType === 'image') {
            cacheDir = "image_thumbnails";
        } else if (fileType === 'gif') {
            cacheDir = "gif_thumbnails";
        } else {
            return ""; // Unknown type
        }

        // Include original extension in thumbnail name to avoid collisions
        // Format: originalname.ext.jpg (e.g., fire-skull.png.jpg)
        var thumbnailName = fileName + ".jpg";
        return Quickshell.dataDir + "/" + cacheDir + "/" + thumbnailName;
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

    function getSubfolderFromPath(filePath) {
        var relativePath = filePath.replace(wallpaperDir + "/", "");
        var parts = relativePath.split("/");
        if (parts.length > 1) {
            return parts[0];
        }
        return "";
    }

    function scanSubfolders() {
        var command = ["find", wallpaperDir, "-type", "d", "-mindepth", "1", "-maxdepth", "1"];
        scanSubfoldersProcess.running = true;
    }

    // Update directory watcher when wallpaperDir changes
    onWallpaperDirChanged: {
        console.log("Wallpaper directory changed to:", wallpaperDir);
        usingFallback = false;
        directoryWatcher.path = wallpaperDir;
        scanWallpapers.running = true;
        scanSubfolders();
    }

    onCurrentWallpaperChanged:
    // Matugen se ejecuta manualmente en las funciones de cambio
    {}

    function setWallpaper(path) {
        console.log("setWallpaper called with:", path);
        initialLoadCompleted = true;
        var pathIndex = wallpaperPaths.indexOf(path);
        if (pathIndex !== -1) {
            currentIndex = pathIndex;
            wallpaperConfig.adapter.currentWall = path;
            runMatugenForCurrentWallpaper();
        } else {
            console.warn("Wallpaper path not found in current list:", path);
        }
    }

    function nextWallpaper() {
        if (wallpaperPaths.length === 0)
            return;
        initialLoadCompleted = true;
        currentIndex = (currentIndex + 1) % wallpaperPaths.length;
        currentWallpaper = wallpaperPaths[currentIndex];
        wallpaperConfig.adapter.currentWall = wallpaperPaths[currentIndex];
        runMatugenForCurrentWallpaper();
    }

    function previousWallpaper() {
        if (wallpaperPaths.length === 0)
            return;
        initialLoadCompleted = true;
        currentIndex = currentIndex === 0 ? wallpaperPaths.length - 1 : currentIndex - 1;
        currentWallpaper = wallpaperPaths[currentIndex];
        wallpaperConfig.adapter.currentWall = wallpaperPaths[currentIndex];
        runMatugenForCurrentWallpaper();
    }

    function setWallpaperByIndex(index) {
        if (index >= 0 && index < wallpaperPaths.length) {
            initialLoadCompleted = true;
            currentIndex = index;
            currentWallpaper = wallpaperPaths[currentIndex];
            wallpaperConfig.adapter.currentWall = wallpaperPaths[currentIndex];
            runMatugenForCurrentWallpaper();
        }
    }

    // Función para re-ejecutar Matugen con el wallpaper actual
     function setMatugenScheme(scheme) {
         wallpaperConfig.adapter.matugenScheme = scheme;
         runMatugenForCurrentWallpaper();
     }

     function runMatugenForCurrentWallpaper() {
        if (currentWallpaper && initialLoadCompleted) {
            console.log("Running Matugen for current wallpaper:", currentWallpaper);

            var fileType = getFileType(currentWallpaper);
            var matugenSource = getColorSource(currentWallpaper);

            console.log("Using source for matugen:", matugenSource, "(type:", fileType + ")");

              // Ejecutar matugen con configuración específica
              var commandWithConfig = ["matugen", "image", matugenSource, "-c", Qt.resolvedUrl("../../../../assets/matugen/config.toml").toString().replace("file://", ""), "-t", wallpaperConfig.adapter.matugenScheme];
             if (Config.theme.lightMode) {
                 commandWithConfig.push("-m", "light");
             }
             matugenProcessWithConfig.command = commandWithConfig;
             matugenProcessWithConfig.running = true;

              // Ejecutar matugen normal en paralelo
              var commandNormal = ["matugen", "image", matugenSource, "-t", wallpaperConfig.adapter.matugenScheme];
             if (Config.theme.lightMode) {
                 commandNormal.push("-m", "light");
             }
             matugenProcessNormal.command = commandNormal;
             matugenProcessNormal.running = true;
        }
    }

    Component.onCompleted: {
        GlobalStates.wallpaperManager = wallpaper;

        // Verificar si existe wallpapers.json, si no, crear con fallback
        checkWallpapersJson.running = true;

        // Ejecutar script de generación de thumbnails
        thumbnailGeneratorScript.running = true;

        // Initial scans
        scanWallpapers.running = true;
        scanSubfolders();
        // Start directory monitoring
        directoryWatcher.reload();
        // Load initial wallpaper config
        wallpaperConfig.reload();
        forceActiveFocus();
    }

    FileView {
        id: wallpaperConfig
        path: Quickshell.dataPath("wallpapers.json")
        watchChanges: true

        onFileChanged: reload()
         onAdapterUpdated: {
             // Ensure matugenScheme has a default value
             if (!wallpaperConfig.adapter.matugenScheme) {
                 wallpaperConfig.adapter.matugenScheme = "scheme-tonal-spot";
             }
             // Update the currentMatugenScheme property to trigger UI updates
             currentMatugenScheme = Qt.binding(function() { return wallpaperConfig.adapter.matugenScheme; });
             writeAdapter();
         }

         JsonAdapter {
             property string currentWall: ""
             property string wallPath: ""
             property string matugenScheme: "scheme-tonal-spot"

            onCurrentWallChanged: {
                console.log("DEBUG: currentWall changed to:", currentWall);
                console.log("DEBUG: current wallpaper is:", wallpaper.currentWallpaper);
                console.log("DEBUG: initialLoadCompleted:", wallpaper.initialLoadCompleted);
                // Siempre actualizar si es diferente al actual
                if (currentWall && currentWall !== wallpaper.currentWallpaper) {
                    console.log("Loading wallpaper from JSON:", currentWall);
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
                // Rescan wallpapers when wallPath changes
                if (wallPath) {
                    console.log("Wallpaper directory changed to:", wallPath);
                    scanWallpapers.running = true;
                    // Regenerar thumbnails para el nuevo directorio
                    thumbnailGeneratorScript.running = true;
                }
            }
        }
    }

    Keys.onLeftPressed: {
        if (wallpaperPaths.length > 0) {
            previousWallpaper();
        }
    }

    Keys.onRightPressed: {
        if (wallpaperPaths.length > 0) {
            nextWallpaper();
        }
    }

    Process {
        id: checkWallpapersJson
        running: false
        command: ["test", "-f", Quickshell.dataPath("wallpapers.json")]

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
        command: ["python3", Qt.resolvedUrl("../../../../scripts").toString().replace("file://", "") + "/thumbgen.py", Quickshell.dataDir + "/wallpapers.json", Quickshell.dataDir]

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
            } else {
                console.warn("⚠️ Thumbnail generation failed with code:", exitCode);
            }
        }
    }

    Process {
        id: scanSubfoldersProcess
        running: false
        command: ["find", wallpaperDir, "-type", "d", "-mindepth", "1", "-maxdepth", "1"]

        stdout: StdioCollector {
            onStreamFinished: {
                console.log("scanSubfolders stdout:", text);
                var folders = text.trim().split("\n").filter(function (f) {
                    return f.length > 0;
                }).map(function (folder) {
                    return folder.split('/').pop();
                }).filter(function (folderName) {
                    return !folderName.startsWith('.');
                });
                folders.sort();
                subfolderFilters = folders;
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
            console.log("Wallpaper directory changed, rescanning...");
            scanWallpapers.running = true;
            // Regenerar thumbnails si hay nuevos videos
            thumbnailGeneratorScript.running = true;
        }

        // Remove onLoadFailed to prevent premature fallback activation
    }

    Process {
        id: scanWallpapers
        running: false
        command: ["find", wallpaperDir, "-type", "f", "(", "-name", "*.jpg", "-o", "-name", "*.jpeg", "-o", "-name", "*.png", "-o", "-name", "*.webp", "-o", "-name", "*.tif", "-o", "-name", "*.tiff", "-o", "-name", "*.gif", "-o", "-name", "*.mp4", "-o", "-name", "*.webm", "-o", "-name", "*.mov", "-o", "-name", "*.avi", "-o", "-name", "*.mkv", ")"]

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
                                console.log("DEBUG: Setting initialLoadCompleted to true");
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
                    // Only fallback if we don't already have wallpapers loaded
                    if (wallpaperPaths.length === 0) {
                        console.log("Directory scan failed, using fallback");
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
        command: ["find", fallbackDir, "-type", "f", "(", "-name", "*.jpg", "-o", "-name", "*.jpeg", "-o", "-name", "*.png", "-o", "-name", "*.webp", "-o", "-name", "*.tif", "-o", "-name", "*.tiff", "-o", "-name", "*.gif", "-o", "-name", "*.mp4", "-o", "-name", "*.webm", "-o", "-name", "*.mov", "-o", "-name", "*.avi", "-o", "-name", "*.mkv", ")"]

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

    Rectangle {
        id: background
        anchors.fill: parent
        color: "black"

        WallpaperImage {
            id: wallImage
            anchors.fill: parent
            source: wallpaper.currentWallpaper
        }
    }

    component WallpaperImage: Item {
        property string source
        property string previousSource

        Process {
            id: killMpvpaperProcess
            running: false
            command: ["killall", "mpvpaper"]

            onExited: function (exitCode) {
                console.log("Killed mpvpaper processes, exit code:", exitCode);
            }
        }

        // Trigger animation when source changes
        onSourceChanged: {
            if (previousSource !== "" && source !== previousSource) {
                transitionAnimation.restart();
            }
            previousSource = source;

            // Kill mpvpaper if switching to a static image
            if (source) {
                var fileType = getFileType(source);
                if (fileType === 'image') {
                    killMpvpaperProcess.running = true;
                }
            }
        }

        SequentialAnimation {
            id: transitionAnimation

            ParallelAnimation {
                NumberAnimation {
                    target: wallImage
                    property: "scale"
                    to: 1.01
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: wallImage
                    property: "opacity"
                    to: 0.5
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
            }

            ParallelAnimation {
                NumberAnimation {
                    target: wallImage
                    property: "scale"
                    to: 1.0
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: wallImage
                    property: "opacity"
                    to: 1.0
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        Loader {
            anchors.fill: parent
            sourceComponent: {
                if (!parent.source)
                    return null;

                var fileType = getFileType(parent.source);
                if (fileType === 'image') {
                    return staticImageComponent;
                } else if (fileType === 'gif' || fileType === 'video') {
                    return mpvpaperComponent;
                }
                return staticImageComponent; // fallback
            }

            property string sourceFile: parent.source
        }

        Component {
            id: staticImageComponent
            Image {
                source: parent.sourceFile ? "file://" + parent.sourceFile : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }

        Component {
            id: mpvpaperComponent
            Item {
                property string sourceFile: parent.sourceFile
                property string scriptPath: Qt.resolvedUrl("mpvpaper.sh").toString().replace("file://", "")

                Timer {
                    id: mpvpaperRestartTimer
                    interval: 100
                    onTriggered: {
                        if (sourceFile) {
                            console.log("Restarting mpvpaper for:", sourceFile);
                            mpvpaperProcess.running = true;
                        }
                    }
                }

                onSourceFileChanged: {
                    if (sourceFile) {
                        console.log("Source file changed to:", sourceFile);
                        mpvpaperProcess.running = false;
                        mpvpaperRestartTimer.restart();
                    }
                }

                Component.onCompleted: {
                    if (sourceFile) {
                        console.log("Initial mpvpaper run for:", sourceFile);
                        mpvpaperProcess.running = true;
                    }
                }

                Component.onDestruction: {
                    // mpvpaper script handles killing previous instances
                }

                Process {
                    id: mpvpaperProcess
                    running: false
                    command: sourceFile ? ["bash", scriptPath, sourceFile] : []

                    stdout: StdioCollector {
                        onStreamFinished: {
                            if (text.length > 0) {
                                console.log("mpvpaper output:", text);
                            }
                        }
                    }

                    stderr: StdioCollector {
                        onStreamFinished: {
                            if (text.length > 0) {
                                console.warn("mpvpaper error:", text);
                            }
                        }
                    }

                    onExited: function (exitCode) {
                        console.log("mpvpaper process exited with code:", exitCode);
                    }
                }
            }
        }
    }
}
