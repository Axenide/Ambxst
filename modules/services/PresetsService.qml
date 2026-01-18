pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Available presets
    property var presets: []

    // Current preset being loaded/saved
    property string currentPreset: ""
    property string activePreset: ""

    // Config directory paths
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/Ambxst"
    readonly property string presetsDir: configDir + "/presets"
    readonly property string assetsPresetsDir: Qt.resolvedUrl("../../assets/presets").toString().replace("file://", "")
    readonly property string activePresetFile: presetsDir + "/active_preset"

    // Signal when presets change
    signal presetsUpdated()

    // Scan presets directory
    function scanPresets() {
        scanProcess.running = true
        readActivePresetProcess.running = true
    }

    // Check if a preset name is taken by an official preset
    function isOfficialName(name) {
        return presets.some(p => p.name === name && p.isOfficial)
    }

    // Load a preset by name
    function loadPreset(presetName: string) {
        if (presetName === "") {
            console.warn("Cannot load empty preset name")
            return
        }

        console.log("Loading preset:", presetName)
        currentPreset = presetName

        // Find the preset object to get its config files
        // Prioritize user presets if names collide? Or just find the first match?
        // Since names can be duplicated now, we need to know WHICH one to load.
        // But the loadPreset signature only takes a name. 
        // For now, let's assume the UI passes the unique ID or we handle the ambiguity.
        // Given the constraints, let's try to find a match.
        // If we have duplicate names, 'activePreset' just stores the string name.
        // This is a limitation of the current active_preset storage (just a string).
        // Use the first match found.
        const preset = presets.find(p => p.name === presetName)
        if (!preset) {
            console.warn("Preset not found in list:", presetName)
            return
        }

        // Build command to copy config files
        // Use the preset's actual path (which could be in assets)
        const presetPath = preset.path
        let copyCmd = ""
        
        for (const configFile of preset.configFiles) {
             const jsonFile = configFile.replace('.js', '.json')
             if (jsonFile === 'system.json') continue; // Skip system.json

             const srcPath = presetPath + "/" + jsonFile
             const dstPath = configDir + "/config/" + jsonFile
             copyCmd += `cp "${srcPath}" "${dstPath}" && `
        }
        
        // Update active preset file
        copyCmd += `echo "${presetName}" > "${activePresetFile}"`

        if (copyCmd.length > 0) {
            loadProcess.command = ["sh", "-c", copyCmd]
            loadProcess.running = true
        } else {
            console.warn("No config files found in preset:", presetName)
        }
    }

    // Save current config as preset
    function savePreset(presetName: string, configFiles: var) {
        if (presetName === "") {
            console.warn("Cannot save preset with empty name")
            return
        }

        if (isOfficialName(presetName)) {
            console.warn("Cannot create preset with official name:", presetName)
            Quickshell.execDetached(["notify-send", "Error", `Cannot use reserved official name "${presetName}".`])
            return
        }

        if (configFiles.length === 0) {
            console.warn("No config files selected for preset")
            return
        }

        console.log("Saving preset:", presetName, "with files:", configFiles)

        // Create preset directory and copy config files
        const presetPath = presetsDir + "/" + presetName
        const createCmd = `mkdir -p "${presetPath}"`

        let copyCmd = ""
        for (const configFile of configFiles) {
            const jsonFile = configFile.replace('.js', '.json')
            if (jsonFile === 'system.json') continue; // Skip system.json

            // The source is configDir (~/.config/Ambxst), NOT configDir/config
            // But wait, the configDir property is defined as ~/.config/Ambxst below?
            // Let's check the property definition.
            // property string configDir: ... + "/Ambxst"
            // But Config.qml says configDir is ... + "/Ambxst/config"
            // We need to match Config.qml's path.
            
            // In Config.qml: property string configDir: ... + "/Ambxst/config"
            // Here: readonly property string configDir: ... + "/Ambxst"
            // This is a mismatch!
            
            // We should use the same path as Config.qml for reading/writing config files.
            // Let's assume the files are in .../Ambxst/config based on Config.qml and ls output.
            
            const srcPath = configDir + "/config/" + jsonFile 
            const dstPath = presetPath + "/" + jsonFile
            copyCmd += `cp "${srcPath}" "${dstPath}" && `
        }
        
        // Create info.json with default author
        const infoContent = JSON.stringify({ author: "User", authorUrl: "" }, null, 4)
        // Use printf to write info.json safely
        copyCmd += `printf '${infoContent}' > "${presetPath}/info.json" && `

        copyCmd = copyCmd.slice(0, -4) // Remove last " && "

        const fullCmd = `${createCmd} && ${copyCmd}`
        saveProcess.command = ["sh", "-c", fullCmd]
        saveProcess.running = true

        root.pendingPresetName = presetName
    }

    // Internal properties for saving
    property string pendingPresetName: ""

    // Scan presets process
    Process {
        id: scanProcess
        // Find all JSON files in subdirectories of presetsDir (depth 2) and assetsPresetsDir
        // Exclude system.json and info.json from the file list
        // Then, read info.json files content using grep
        command: ["sh", "-c", "find '" + presetsDir + "' '" + assetsPresetsDir + "' -mindepth 2 -maxdepth 2 -name '*.json' -not -name 'info.json' -not -name 'system.json'; echo '---METADATA---'; find '" + presetsDir + "' '" + assetsPresetsDir + "' -mindepth 2 -maxdepth 2 -name 'info.json' -exec grep -H . {} +"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split('\n');
                const presetsMap = {}
                const metadataMap = {} // key: presetPath, value: json string builder

                let processingMetadata = false;

                for (const line of lines) {
                    if (line === '---METADATA---') {
                        processingMetadata = true;
                        continue;
                    }

                    if (!processingMetadata) {
                        if (line.length === 0) continue;
                        
                        // Config file path
                        const parts = line.split('/')
                        const configName = parts.pop() // remove config.json, parts is now the folder path
                        
                        // The path to the preset directory
                        const presetPath = parts.join('/')
                        const presetName = parts[parts.length - 1]
                        
                        // Determine if official based on path prefix
                        const isOfficial = line.startsWith(root.assetsPresetsDir)

                        // Use presetPath as key to ensure uniqueness per preset folder
                        const key = presetPath

                        if (!presetsMap[key]) {
                            presetsMap[key] = {
                                name: presetName,
                                path: presetPath,
                                isOfficial: isOfficial,
                                configFiles: [],
                                author: "Unknown",
                                authorUrl: ""
                            }
                        }
                        
                        // Convert .json to .js for UI display
                        presetsMap[key].configFiles.push(configName.replace('.json', '.js'))
                    } else {
                        // Metadata line: path/to/info.json: content
                        const idx = line.indexOf(':');
                        if (idx !== -1) {
                            const filePath = line.substring(0, idx);
                            const content = line.substring(idx + 1);
                            
                            // Extract preset path from file path (remove /info.json)
                            const parts = filePath.split('/');
                            parts.pop(); // remove info.json
                            const presetPath = parts.join('/');
                            
                            if (!metadataMap[presetPath]) {
                                metadataMap[presetPath] = "";
                            }
                            metadataMap[presetPath] += content + "\n";
                        }
                    }
                }

                // Process metadata
                for (const key in metadataMap) {
                     if (presetsMap[key]) {
                         try {
                             const info = JSON.parse(metadataMap[key]);
                             if (info.author) presetsMap[key].author = info.author;
                             if (info.authorUrl) presetsMap[key].authorUrl = info.authorUrl;
                         } catch (e) {
                             console.warn("Failed to parse metadata for preset:", key, e);
                         }
                     }
                }

                // Convert map to array
                const newPresets = Object.values(presetsMap)
                // Sort: Official first (alphabetical), then Custom (alphabetical)
                newPresets.sort((a, b) => {
                    if (a.isOfficial && !b.isOfficial) return -1;
                    if (!a.isOfficial && b.isOfficial) return 1;
                    return a.name.localeCompare(b.name);
                })

                root.presets = newPresets
                root.presetsUpdated()
            }
        }
        
        onExited: function(exitCode) {
             if (exitCode !== 0) {
                // If find fails, it might be empty or error.
                // We keep existing presets or clear if needed.
                // Usually find returns 0 even if empty.
             }
        }
    }

    // Rename a preset
    function renamePreset(oldName: string, newName: string) {
        if (oldName === "" || newName === "" || oldName === newName) {
            console.warn("Invalid rename parameters")
            return
        }

        const preset = presets.find(p => p.name === oldName)
        if (preset && preset.isOfficial) {
             console.warn("Cannot rename official preset")
             return
        }

        if (isOfficialName(newName)) {
            console.warn("Cannot rename to official name")
            Quickshell.execDetached(["notify-send", "Error", `Cannot rename to reserved official name "${newName}".`])
            return
        }

        console.log("Renaming preset:", oldName, "to:", newName)
        root.pendingRename = { oldName: oldName, newName: newName }

        const oldPath = presetsDir + "/" + oldName
        const newPath = presetsDir + "/" + newName
        renameProcess.command = ["mv", oldPath, newPath]
        renameProcess.running = true
    }

    // Update a preset with current config files
    function updatePreset(presetName: string, configFiles: var) {
        if (presetName === "" || configFiles.length === 0) {
            console.warn("Invalid update parameters")
            return
        }

        // Find the preset to check if it's official
        const preset = presets.find(p => p.name === presetName)
        if (preset && preset.isOfficial) {
            console.log("Updating official preset - creating custom copy")
            const newName = presetName + " (Custom)"
            savePreset(newName, configFiles)
            return
        }

        console.log("Updating preset:", presetName, "with files:", configFiles)
        root.pendingUpdateName = presetName

        const presetPath = presetsDir + "/" + presetName

        let copyCmd = ""
        for (const configFile of configFiles) {
            const jsonFile = configFile.replace('.js', '.json')
            if (jsonFile === 'system.json') continue; // Skip system.json
            const srcPath = configDir + "/config/" + jsonFile
            const dstPath = presetPath + "/" + jsonFile
            copyCmd += `cp "${srcPath}" "${dstPath}" && `
        }
        copyCmd = copyCmd.slice(0, -4) // Remove last " && "

        updateProcess.command = ["sh", "-c", copyCmd]
        updateProcess.running = true
    }

    // Delete a preset
    function deletePreset(presetName: string) {
        if (presetName === "") {
            console.warn("Cannot delete preset with empty name")
            return
        }

        const preset = presets.find(p => p.name === presetName)
        if (preset && preset.isOfficial) {
             console.warn("Cannot delete official preset")
             return
        }

        console.log("Deleting preset:", presetName)
        root.pendingDeleteName = presetName

        const presetPath = presetsDir + "/" + presetName
        deleteProcess.command = ["rm", "-rf", presetPath]
        deleteProcess.running = true
    }

    // Internal properties
    property var pendingRename: null
    property string pendingUpdateName: ""
    property string pendingDeleteName: ""

    // Save process
    Process {
        id: saveProcess
        running: false

        onExited: function(exitCode) {
            if (exitCode === 0) {
                console.log("Preset saved successfully:", root.pendingPresetName)
                Quickshell.execDetached(["notify-send", "Preset Saved", `Preset "${root.pendingPresetName}" saved successfully.`])
                // Trigger scan
                root.scanProcess.running = true
            } else {
                console.warn("Failed to save preset:", root.pendingPresetName)
                Quickshell.execDetached(["notify-send", "Error", `Failed to save preset "${root.pendingPresetName}".`])
            }
            root.pendingPresetName = ""
        }
    }

    // Rename process
    Process {
        id: renameProcess
        running: false

        onExited: function(exitCode) {
            if (exitCode === 0 && root.pendingRename) {
                console.log("Preset renamed successfully:", root.pendingRename.oldName, "->", root.pendingRename.newName)
                Quickshell.execDetached(["notify-send", "Preset Renamed", `Preset renamed to "${root.pendingRename.newName}".`])
                // Update active preset if it was the renamed one
                if (root.activePreset === root.pendingRename.oldName) {
                    root.activePreset = root.pendingRename.newName
                    // Update active preset file
                    updateActivePresetFileProcess.command = ["sh", "-c", `echo "${root.pendingRename.newName}" > "${activePresetFile}"`]
                    updateActivePresetFileProcess.running = true
                }
                root.scanProcess.running = true
            } else {
                console.warn("Failed to rename preset")
                Quickshell.execDetached(["notify-send", "Error", "Failed to rename preset."])
            }
            root.pendingRename = null
        }
    }

    // Update process
    Process {
        id: updateProcess
        running: false

        onExited: function(exitCode) {
            if (exitCode === 0) {
                console.log("Preset updated successfully:", root.pendingUpdateName)
                Quickshell.execDetached(["notify-send", "Preset Updated", `Preset "${root.pendingUpdateName}" updated successfully.`])
                root.scanProcess.running = true
            } else {
                console.warn("Failed to update preset:", root.pendingUpdateName)
                Quickshell.execDetached(["notify-send", "Error", `Failed to update preset "${root.pendingUpdateName}".`])
            }
            root.pendingUpdateName = ""
        }
    }

    // Delete process
    Process {
        id: deleteProcess
        running: false

        onExited: function(exitCode) {
            if (exitCode === 0) {
                console.log("Preset deleted successfully:", root.pendingDeleteName)
                Quickshell.execDetached(["notify-send", "Preset Deleted", `Preset "${root.pendingDeleteName}" deleted.`])
                // Clear active preset if it was the deleted one
                if (root.activePreset === root.pendingDeleteName) {
                    root.activePreset = ""
                }
                root.scanProcess.running = true
            } else {
                console.warn("Failed to delete preset:", root.pendingDeleteName)
                Quickshell.execDetached(["notify-send", "Error", `Failed to delete preset "${root.pendingDeleteName}".`])
            }
            root.pendingDeleteName = ""
        }
    }

    // Update active preset file process
    Process {
        id: updateActivePresetFileProcess
        running: false
    }

    // Load process
    Process {
        id: loadProcess
        running: false

        onExited: function(exitCode) {
            if (exitCode === 0) {
                console.log("Preset loaded successfully:", root.currentPreset)
                Quickshell.execDetached(["notify-send", "Preset Loaded", `Preset "${root.currentPreset}" loaded successfully.`])
                root.activePreset = root.currentPreset
            } else {
                console.warn("Failed to load preset:", root.currentPreset)
                Quickshell.execDetached(["notify-send", "Error", `Failed to load preset "${root.currentPreset}".`])
            }
            root.currentPreset = ""
        }
    }

    // Read active preset process
    Process {
        id: readActivePresetProcess
        command: ["cat", activePresetFile]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                root.activePreset = text.trim()
            }
        }
    }

    // Directory watcher for the main presets directory (detects new/deleted presets)
    FileView {
        path: presetsDir
        watchChanges: true
        printErrors: false

        onFileChanged: {
            console.log("Presets directory changed, rescanning...")
            scanProcess.running = true
        }
    }

    // Watch individual preset directories for content changes (added/removed files inside a preset)
    Instantiator {
        model: root.presets
        delegate: FileView {
            required property var modelData
            path: modelData.path
            watchChanges: true
            printErrors: false
            onFileChanged: {
                console.log("Preset modified (content change):", modelData.name)
                // Use a debouncer or simple timer to avoid spamming scans if multiple files change
                root.scanProcess.running = true
            }
        }
    }
    
    // Init process (create directory)
    Process {
        id: initProcess
        command: ["mkdir", "-p", presetsDir]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.scanPresets()
            }
        }
    }

    // Initialize
    Component.onCompleted: {
        console.log("PresetsService created, presetsDir:", presetsDir)
        initProcess.running = true
    }
}
