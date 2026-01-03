pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string desktopDir: ""
    property bool initialLoadComplete: false
    property string positionsFile: Quickshell.dataPath("desktop-positions.json")
    property int maxRowsHint: 15
    property int maxColumnsHint: 10
    property bool gridReady: false
    property bool positionsLoaded: false

    onMaxRowsHintChanged: checkGridReady()
    onMaxColumnsHintChanged: checkGridReady()
    onPositionsLoadedChanged: checkGridReady()

    function checkGridReady() {
        if (maxRowsHint > 0 && maxColumnsHint > 0 && positionsLoaded && !gridReady) {
            gridReady = true;
            console.log("Grid ready - rows:", maxRowsHint, "cols:", maxColumnsHint);
            if (tempItems.length > 0 || tempDesktopFiles.length > 0) {
                console.log("Finalizing items with", tempItems.length + tempDesktopFiles.length, "items");
                finalizeItems();
            }
        }
    }

    property ListModel items: ListModel {
        id: itemsModel
    }

    property var iconPositions: ({})

    function savePositions() {
        var json = JSON.stringify(iconPositions, null, 2);
        savePositionsProcess.command = ["sh", "-c", "echo '" + json.replace(/'/g, "'\\''") + "' > " + positionsFile];
        savePositionsProcess.running = true;
    }

    function loadPositions() {
        loadPositionsProcess.running = true;
    }

    function updateIconPosition(path, gridX, gridY) {
        iconPositions[path] = {
            x: gridX,
            y: gridY
        };
        savePositions();
    }

    function getIconPosition(path) {
        return iconPositions[path] || null;
    }

    function calculateAutoPosition(index) {
        var usedPositions = {};

        for (var key in iconPositions) {
            var pos = iconPositions[key];
            usedPositions[pos.x + "," + pos.y] = true;
        }

        var gridX = 0;
        var gridY = 0;
        var checked = 0;

        while (checked <= index) {
            var posKey = gridX + "," + gridY;
            if (!usedPositions[posKey]) {
                if (checked === index) {
                    return {
                        x: gridX,
                        y: gridY
                    };
                }
                checked++;
            }
            gridY++;
            if (gridY >= maxRowsHint) {
                gridY = 0;
                gridX++;
            }
        }

        return {
            x: gridX,
            y: gridY
        };
    }

    function getDesktopDir() {
        getDesktopDirProcess.running = true;
    }

    function generateThumbnails() {
        if (desktopDir) {
            thumbnailProcess.running = true;
        }
    }

    function scanDesktop() {
        if (desktopDir) {
            if (parsingInProgress) {
                needsRescan = true;
            } else {
                scanProcess.running = true;
            }
        }
    }

    function parseDesktopFile(filePath) {
        parseDesktopProcess.command = ["cat", filePath];
        parseDesktopProcess.running = true;
    }

    function executeDesktopFile(filePath) {
        var escapedPath = filePath.replace(/'/g, "'\\''");
        var processComponent = Qt.createQmlObject('
            import Quickshell
            import Quickshell.Io
            Process {
                running: true
                command: ["bash", "-c", "cd ~ && setsid gio launch \'' + escapedPath + '\' < /dev/null > /dev/null 2>&1 &"]

                stdout: StdioCollector {
                    onStreamFinished: {
                        if (text.length > 0) {
                            console.log("Desktop file execution:", text);
                        }
                    }
                }

                stderr: StdioCollector {
                    onStreamFinished: {
                        if (text.length > 0) {
                            console.warn("Desktop file execution error:", text);
                        }
                    }
                }

                onRunningChanged: {
                    if (!running) {
                        destroy();
                    }
                }
            }
        ', root);
    }

    function openFile(filePath) {
        var escapedPath = filePath.replace(/'/g, "'\\''");
        var processComponent = Qt.createQmlObject('
            import Quickshell
            import Quickshell.Io
            Process {
                running: true
                command: ["bash", "-c", "setsid xdg-open \'' + escapedPath + '\' < /dev/null > /dev/null 2>&1 &"]

                stdout: StdioCollector {
                    onStreamFinished: {
                        if (text.length > 0) {
                            console.log("File opened:", text);
                        }
                    }
                }

                stderr: StdioCollector {
                    onStreamFinished: {
                        if (text.length > 0) {
                            console.warn("Error opening file:", text);
                        }
                    }
                }

                onRunningChanged: {
                    if (!running) {
                        destroy();
                    }
                }
            }
        ', root);
    }

    function trashFile(filePath) {
        var escapedPath = filePath.replace(/'/g, "'\\''");
        var processComponent = Qt.createQmlObject('
            import Quickshell
            import Quickshell.Io
            Process {
                running: true
                command: ["bash", "-c", "gio trash \'' + escapedPath + '\'"]

                stdout: StdioCollector {
                    onStreamFinished: {
                        if (text.length > 0) {
                            console.log("File moved to trash:", text);
                        }
                    }
                }

                stderr: StdioCollector {
                    onStreamFinished: {
                        if (text.length > 0) {
                            console.warn("Error moving file to trash:", text);
                        }
                    }
                }

                onRunningChanged: {
                    if (!running) {
                        destroy();
                    }
                }
            }
        ', root);
    }

    function saveAllPositions() {
        iconPositions = {};

        for (var i = 0; i < items.count; i++) {
            var item = items.get(i);
            if (!item.isPlaceholder && item.path) {
                var col = Math.floor(i / maxRowsHint);
                var row = i % maxRowsHint;
                iconPositions[item.path] = {
                    x: col,
                    y: row
                };
            }
        }

        savePositions();
    }

    function moveItem(fromIndex, toIndex) {
        if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0 || fromIndex >= items.count) {
            return;
        }

        if (toIndex >= items.count) {
            toIndex = items.count - 1;
        }

        var targetIsPlaceholder = items.get(toIndex).isPlaceholder === true;

        if (targetIsPlaceholder) {
            var item = items.get(fromIndex);
            items.setProperty(toIndex, "name", item.name);
            items.setProperty(toIndex, "path", item.path);
            items.setProperty(toIndex, "type", item.type);
            items.setProperty(toIndex, "icon", item.icon);
            items.setProperty(toIndex, "isDesktopFile", item.isDesktopFile);
            items.setProperty(toIndex, "isPlaceholder", false);

            items.setProperty(fromIndex, "name", "");
            items.setProperty(fromIndex, "path", "");
            items.setProperty(fromIndex, "type", "placeholder");
            items.setProperty(fromIndex, "icon", "");
            items.setProperty(fromIndex, "isDesktopFile", false);
            items.setProperty(fromIndex, "isPlaceholder", true);

            var col = Math.floor(toIndex / maxRowsHint);
            var row = toIndex % maxRowsHint;
            items.setProperty(toIndex, "gridX", col);
            items.setProperty(toIndex, "gridY", row);
        } else {
            items.move(fromIndex, toIndex, 1);

            var sourceCol = Math.floor(toIndex / maxRowsHint);
            var sourceRow = toIndex % maxRowsHint;
            items.setProperty(toIndex, "gridX", sourceCol);
            items.setProperty(toIndex, "gridY", sourceRow);

            var targetCol = Math.floor(fromIndex / maxRowsHint);
            var targetRow = fromIndex % maxRowsHint;
            items.setProperty(fromIndex, "gridX", targetCol);
            items.setProperty(fromIndex, "gridY", targetRow);
        }

        saveAllPositions();
    }

    function getFileType(fileName) {
        var ext = fileName.toLowerCase().split('.').pop();

        if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp'].includes(ext)) {
            return 'image';
        } else if (['mp4', 'webm', 'mov', 'avi', 'mkv', 'mp3', 'wav', 'ogg', 'flac'].includes(ext)) {
            return 'media';
        } else if (['pdf'].includes(ext)) {
            return 'pdf';
        } else if (['txt', 'md', 'log'].includes(ext)) {
            return 'text';
        } else if (['zip', 'tar', 'gz', 'rar', '7z'].includes(ext)) {
            return 'archive';
        } else if (['doc', 'docx', 'odt'].includes(ext)) {
            return 'document';
        }
        return 'file';
    }

    function getIconForType(type) {
        switch (type) {
        case 'folder':
            return 'folder';
        case 'image':
            return 'image-x-generic';
        case 'media':
            return 'video-x-generic';
        case 'pdf':
            return 'application-pdf';
        case 'text':
            return 'text-x-generic';
        case 'archive':
            return 'package-x-generic';
        case 'document':
            return 'x-office-document';
        default:
            return 'text-x-generic';
        }
    }

    Component.onCompleted: {
        getDesktopDir();
    }

    Process {
        id: savePositionsProcess
        running: false
        command: []

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Error saving positions:", text);
                }
            }
        }
    }

    Process {
        id: loadPositionsProcess
        running: false
        command: ["cat", positionsFile]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    try {
                        var parsed = JSON.parse(text);

                        for (var key in root.iconPositions) {
                            delete root.iconPositions[key];
                        }

                        for (var k in parsed) {
                            root.iconPositions[k] = {
                                x: parsed[k].x,
                                y: parsed[k].y
                            };
                        }

                        console.log("Loaded", Object.keys(root.iconPositions).length, "icon positions");
                    } catch (e) {
                        console.warn("Error parsing positions file:", e);
                    }
                }
                root.positionsLoaded = true;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                root.positionsLoaded = true;
            }
        }
    }

    Process {
        id: getDesktopDirProcess
        running: false
        command: ["sh", "-c", "echo ${XDG_DESKTOP_DIR:-$HOME/Desktop}"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.desktopDir = text.trim();
                console.log("Desktop directory:", root.desktopDir);
                console.log("Positions file:", root.positionsFile);
                loadPositions();
                scanDesktop();
                directoryWatcher.path = root.desktopDir;
                directoryWatcher.reload();
            }
        }
    }

    FileView {
        id: directoryWatcher
        path: ""
        watchChanges: true
        printErrors: false

        onFileChanged: {
            console.log("Desktop directory changed, rescanning...");
            scanDesktop();
            thumbnailTimer.restart();
        }
    }

    Process {
        id: scanProcess
        running: false
        command: ["sh", "-c", "ls -1ap " + root.desktopDir + " | grep -v '^\\.$' | grep -v '^\\.\\.$'"]

        stdout: StdioCollector {
            onStreamFinished: {
                var entries = text.trim().split("\n").filter(f => f.length > 0);
                var newItems = [];
                var pendingDesktopFiles = [];

                for (var i = 0; i < entries.length; i++) {
                    var entry = entries[i];
                    var isDir = entry.endsWith('/');
                    var name = isDir ? entry.slice(0, -1) : entry;
                    var fullPath = root.desktopDir + "/" + name;

                    if (name.startsWith('.')) {
                        continue;
                    }

                    if (isDir) {
                        newItems.push({
                            name: name,
                            path: fullPath,
                            type: 'folder',
                            icon: 'folder',
                            isDesktopFile: false,
                            sortOrder: 0
                        });
                    } else if (name.endsWith('.desktop')) {
                        pendingDesktopFiles.push({
                            name: name,
                            path: fullPath,
                            type: 'application',
                            icon: 'application-x-executable',
                            isDesktopFile: true,
                            sortOrder: 1
                        });
                    } else {
                        var fileType = root.getFileType(name);
                        newItems.push({
                            name: name,
                            path: fullPath,
                            type: fileType,
                            icon: root.getIconForType(fileType),
                            isDesktopFile: false,
                            sortOrder: 2
                        });
                    }
                }

                if (!parsingInProgress) {
                    tempDesktopFiles = pendingDesktopFiles;
                    tempItems = newItems;

                    if (pendingDesktopFiles.length > 0) {
                        parsingInProgress = true;
                        currentDesktopFileIndex = 0;
                        parseNextDesktopFile();
                    } else {
                        if (gridReady && positionsLoaded) {
                            finalizeItems();
                        }
                    }
                } else {
                    needsRescan = true;
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Error scanning desktop:", text);
                }
            }
        }
    }

    property var tempDesktopFiles: []
    property var tempItems: []
    property int currentDesktopFileIndex: -1
    property bool parsingInProgress: false
    property bool needsRescan: false

    function parseNextDesktopFile() {
        if (currentDesktopFileIndex < tempDesktopFiles.length) {
            var item = tempDesktopFiles[currentDesktopFileIndex];
            parseDesktopFileProcess.command = ["cat", item.path];
            parseDesktopFileProcess.running = true;
        } else {
            parsingInProgress = false;
            if (gridReady && positionsLoaded) {
                finalizeItems();
            }
            if (needsRescan) {
                needsRescan = false;
                scanDesktop();
            }
        }
    }

    function finalizeItems() {
        var allItems = tempItems.concat(tempDesktopFiles);

        allItems.sort((a, b) => {
            if (a.sortOrder !== b.sortOrder) {
                return a.sortOrder - b.sortOrder;
            }
            return a.name.localeCompare(b.name);
        });

        items.clear();

        var gridSize = maxRowsHint * maxColumnsHint;

        for (var i = 0; i < gridSize; i++) {
            items.append({
                name: "",
                path: "",
                type: "placeholder",
                icon: "",
                isDesktopFile: false,
                isPlaceholder: true,
                gridX: Math.floor(i / maxRowsHint),
                gridY: i % maxRowsHint
            });
        }

        var usedIndices = {};

        for (var i = 0; i < allItems.length; i++) {
            var item = allItems[i];
            var savedPos = getIconPosition(item.path);
            var gridIndex = -1;

            if (savedPos && savedPos.x < maxColumnsHint && savedPos.y < maxRowsHint) {
                gridIndex = savedPos.x * maxRowsHint + savedPos.y;

                if (usedIndices[gridIndex]) {
                    gridIndex = -1;
                }
            }

            if (gridIndex === -1) {
                for (var j = 0; j < gridSize; j++) {
                    if (!usedIndices[j]) {
                        gridIndex = j;
                        break;
                    }
                }
            }

            if (gridIndex !== -1 && gridIndex < items.count) {
                usedIndices[gridIndex] = true;
                var col = Math.floor(gridIndex / maxRowsHint);
                var row = gridIndex % maxRowsHint;

                items.setProperty(gridIndex, "name", item.name);
                items.setProperty(gridIndex, "path", item.path);
                items.setProperty(gridIndex, "type", item.type);
                items.setProperty(gridIndex, "icon", item.icon);
                items.setProperty(gridIndex, "isDesktopFile", item.isDesktopFile);
                items.setProperty(gridIndex, "isPlaceholder", false);
                items.setProperty(gridIndex, "gridX", col);
                items.setProperty(gridIndex, "gridY", row);
            }
        }

        root.initialLoadComplete = true;
    }

    Process {
        id: parseDesktopFileProcess
        running: false
        command: []

        onRunningChanged: {
            if (!running && currentDesktopFileIndex >= 0 && currentDesktopFileIndex < tempDesktopFiles.length) {
                currentDesktopFileIndex++;
                if (currentDesktopFileIndex < tempDesktopFiles.length) {
                    Qt.callLater(parseNextDesktopFile);
                } else {
                    parsingInProgress = false;
                    currentDesktopFileIndex = -1;
                    if (gridReady && positionsLoaded) {
                        finalizeItems();
                    }
                    if (needsRescan) {
                        needsRescan = false;
                        scanDesktop();
                    }
                }
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (currentDesktopFileIndex >= tempDesktopFiles.length) {
                    return;
                }

                var item = tempDesktopFiles[currentDesktopFileIndex];
                var lines = text.split("\n");
                var name = "";
                var icon = "application-x-executable";

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.startsWith("Name=")) {
                        name = line.substring(5);
                    } else if (line.startsWith("Icon=")) {
                        icon = line.substring(5);
                    }
                }

                if (name) {
                    item.name = name;
                }
                item.icon = icon;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Error parsing .desktop file:", text);
                }
                if (currentDesktopFileIndex >= tempDesktopFiles.length) {
                    parsingInProgress = false;
                    if (needsRescan) {
                        needsRescan = false;
                        scanDesktop();
                    }
                    return;
                }
                currentDesktopFileIndex++;
                parseNextDesktopFile();
            }
        }
    }

    Process {
        id: thumbnailProcess
        running: false
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("../../scripts/desktop_thumbgen.py").toString().replace("file://", "")), desktopDir, Quickshell.dataDir + "/desktop_thumbnails"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("Thumbnail generation:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("Thumbnail generation output:", text);
                }
            }
        }
    }

    Timer {
        id: thumbnailTimer
        interval: 1000
        running: false
        onTriggered: generateThumbnails()
    }

    onDesktopDirChanged: {
        if (desktopDir) {
            thumbnailTimer.running = true;
        }
    }
}
