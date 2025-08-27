import QtQuick
import QtMultimedia
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

    property string wallpaperDir: wallpaperConfig.adapter.wallPath || Quickshell.env("HOME") + "/Wallpapers"
    property string fallbackDir: Quickshell.env("PWD") + "/assets/wallpapers_example"
    property list<string> wallpaperPaths: []
    property int currentIndex: 0
    property string currentWallpaper: wallpaperPaths.length > 0 ? wallpaperPaths[currentIndex] : ""
    property bool initialLoadCompleted: false
    property bool usingFallback: false

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

    function getThumbnailPath(videoPath) {
        var fileName = videoPath.split('/').pop();
        var baseName = fileName.substring(0, fileName.lastIndexOf('.'));
        return Quickshell.env("HOME") + "/.cache/quickshell/video_thumbnails/" + baseName + ".jpg";
    }

    // Update directory watcher when wallpaperDir changes
    onWallpaperDirChanged: {
        console.log("Wallpaper directory changed to:", wallpaperDir);
        usingFallback = false;
        directoryWatcher.path = wallpaperDir;
        scanWallpapers.running = true;
    }

    onCurrentWallpaperChanged: {
        if (currentWallpaper && initialLoadCompleted) {
            console.log("Wallpaper changed to:", currentWallpaper);

            var fileType = getFileType(currentWallpaper);
            var matugenSource = currentWallpaper;
            
            // Si es un video, usar su thumbnail para matugen
            if (fileType === 'video') {
                matugenSource = getThumbnailPath(currentWallpaper);
                console.log("Using video thumbnail for matugen:", matugenSource);
            }

            // Ejecutar matugen con configuración específica
            matugenProcessWithConfig.command = ["matugen", "image", matugenSource, "-c", Qt.resolvedUrl("../../../assets/matugen/config.toml").toString().replace("file://", "")];
            matugenProcessWithConfig.running = true;
        }
    }

    function setWallpaper(path) {
        console.log("setWallpaper called with:", path);
        initialLoadCompleted = true;
        var pathIndex = wallpaperPaths.indexOf(path);
        if (pathIndex !== -1) {
            currentIndex = pathIndex;
            wallpaperConfig.adapter.currentWall = path;
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
    }

    function previousWallpaper() {
        if (wallpaperPaths.length === 0)
            return;
        initialLoadCompleted = true;
        currentIndex = currentIndex === 0 ? wallpaperPaths.length - 1 : currentIndex - 1;
        currentWallpaper = wallpaperPaths[currentIndex];
        wallpaperConfig.adapter.currentWall = wallpaperPaths[currentIndex];
    }

    function setWallpaperByIndex(index) {
        if (index >= 0 && index < wallpaperPaths.length) {
            initialLoadCompleted = true;
            currentIndex = index;
            currentWallpaper = wallpaperPaths[currentIndex];
            wallpaperConfig.adapter.currentWall = wallpaperPaths[currentIndex];
        }
    }

    Component.onCompleted: {
        GlobalStates.wallpaperManager = wallpaper;
        
        // Ejecutar script de generación de thumbnails
        thumbnailGeneratorScript.running = true;
        
        // Initial scan
        scanWallpapers.running = true;
        // Start directory monitoring
        directoryWatcher.reload();
        forceActiveFocus();
    }

    FileView {
        id: wallpaperConfig
        path: Quickshell.env("PWD") + "/modules/widgets/wallpapers/wallpaper_config.json"
        watchChanges: true

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            property string currentWall: ""
            property string wallPath: ""

            onCurrentWallChanged: {
                console.log("DEBUG: currentWall changed to:", currentWall);
                console.log("DEBUG: current wallpaper is:", wallpaper.currentWallpaper);
                console.log("DEBUG: initialLoadCompleted:", wallpaper.initialLoadCompleted);
                // Solo actualizar si el cambio viene del archivo JSON y es diferente al actual
                if (currentWall && currentWall !== wallpaper.currentWallpaper && wallpaper.initialLoadCompleted) {
                    console.log("Loading wallpaper from JSON:", currentWall);
                    var pathIndex = wallpaper.wallpaperPaths.indexOf(currentWall);
                    if (pathIndex !== -1) {
                        wallpaper.currentIndex = pathIndex;
                    } else {
                        console.warn("Saved wallpaper not found in current list:", currentWall);
                    }
                } else if (currentWall && !wallpaper.initialLoadCompleted) {
                    console.log("DEBUG: Deferring wallpaper load until scan completes");
                }
            }

            onWallPathChanged: {
                // Rescan wallpapers when wallPath changes
                if (wallPath) {
                    console.log("Wallpaper directory changed to:", wallPath);
                    scanWallpapers.running = true;
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
            // Cuando termina el primer proceso, ejecutar el segundo sin configuración
            console.log("Matugen with config finished, running normal matugen...");
            var fileType = getFileType(currentWallpaper);
            var matugenSource = currentWallpaper;
            
            // Si es un video, usar su thumbnail para matugen
            if (fileType === 'video') {
                matugenSource = getThumbnailPath(currentWallpaper);
                console.log("Using video thumbnail for normal matugen:", matugenSource);
            }
            
            matugenProcessNormal.command = ["matugen", "image", matugenSource];
            matugenProcessNormal.running = true;
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
            console.log("Both matugen processes completed");
        }
    }

    // Proceso para generar thumbnails de videos
    Process {
        id: thumbnailGeneratorScript
        running: false
        command: ["python3", Qt.resolvedUrl("../../../scripts/generate_thumbnails.py").toString().replace("file://", ""), Qt.resolvedUrl("wallpaper_config.json").toString().replace("file://", "")]

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

        onExited: function(exitCode) {
            if (exitCode === 0) {
                console.log("✅ Video thumbnails generated successfully");
            } else {
                console.warn("⚠️ Thumbnail generation failed with code:", exitCode);
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
                    if (JSON.stringify(newFiles) !== JSON.stringify(wallpaperPaths)) {
                        console.log("Wallpaper directory updated. Found", newFiles.length, "images");
                        wallpaperPaths = newFiles;

                        // Initialize wallpaper selection
                        if (wallpaperPaths.length > 0 && !initialLoadCompleted) {
                            console.log("DEBUG: Initializing wallpaper selection");
                            if (wallpaperConfig.adapter.currentWall) {
                                console.log("DEBUG: Found saved wallpaper:", wallpaperConfig.adapter.currentWall);
                                var savedIndex = wallpaperPaths.indexOf(wallpaperConfig.adapter.currentWall);
                                if (savedIndex !== -1) {
                                    console.log("DEBUG: Loading saved wallpaper at index:", savedIndex);
                                    currentIndex = savedIndex;
                                } else {
                                    console.log("DEBUG: Saved wallpaper not found, using first wallpaper");
                                    currentIndex = 0;
                                    wallpaperConfig.adapter.currentWall = wallpaperPaths[0];
                                }
                            } else {
                                console.log("DEBUG: No saved wallpaper, using first one");
                                currentIndex = 0;
                                wallpaperConfig.adapter.currentWall = wallpaperPaths[0];
                            }
                            console.log("DEBUG: Setting initialLoadCompleted to true");
                            initialLoadCompleted = true;
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
                    if (wallpaperPaths.length > 0 && !initialLoadCompleted) {
                        currentIndex = 0;
                        wallpaperConfig.adapter.currentWall = wallpaperPaths[0];
                        initialLoadCompleted = true;
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

        // Trigger animation when source changes
        onSourceChanged: {
            if (previousSource !== "" && source !== previousSource) {
                transitionAnimation.restart();
            }
            previousSource = source;
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
                } else if (fileType === 'gif') {
                    return animatedImageComponent;
                } else if (fileType === 'video') {
                    return videoComponent;
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
            id: animatedImageComponent
            AnimatedImage {
                source: parent.sourceFile ? "file://" + parent.sourceFile : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                playing: true
            }
        }

        Component {
            id: videoComponent
            VideoOutput {
                fillMode: VideoOutput.PreserveAspectCrop
                property string videoSource: parent.sourceFile || ""
                
                MediaPlayer {
                    id: mediaPlayer
                    source: ""
                    loops: MediaPlayer.Infinite
                    audioOutput: AudioOutput {
                        muted: true
                    }
                    autoPlay: false
                    
                    onMediaStatusChanged: {
                        console.log("MediaPlayer status changed:", mediaStatus, "for:", source);
                        if (mediaStatus === MediaPlayer.LoadedMedia) {
                            console.log("Video loaded, starting playback");
                            play();
                        } else if (mediaStatus === MediaPlayer.InvalidMedia) {
                            console.warn("Invalid media:", source);
                        }
                    }
                    
                    onErrorOccurred: function(error, errorString) {
                        console.warn("MediaPlayer error:", error, errorString);
                    }
                }
                
                onVideoSourceChanged: {
                    if (videoSource) {
                        var newSource = "file://" + videoSource;
                        console.log("Video source changed, loading:", newSource);
                        mediaPlayer.stop();
                        mediaPlayer.source = newSource;
                    }
                }
                
                Component.onCompleted: {
                    console.log("VideoOutput created for:", videoSource);
                    mediaPlayer.videoOutput = this;
                    
                    if (videoSource) {
                        var initialSource = "file://" + videoSource;
                        console.log("Initial video load:", initialSource);
                        mediaPlayer.source = initialSource;
                    }
                }
                
                Component.onDestruction: {
                    console.log("VideoOutput destroyed, stopping playback");
                    if (mediaPlayer) {
                        mediaPlayer.stop();
                        mediaPlayer.source = "";
                    }
                }
            }
        }
    }
}
