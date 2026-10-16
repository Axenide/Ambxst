pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services
import qs.config

Singleton {
    id: root

    property var wallpaperManager: null
    property string avatarCacheBuster: ""

    // Broadcast to every BarContent instance: flip the pinned state.
    signal barPinToggled()

    function pickUserAvatar() {
        filePickerProcess.running = true;
    }

    Process {
        id: filePickerProcess
        running: false
        command: ["zenity", "--file-selection", "--title=Select User Icon", "--file-filter=Images | *.png *.jpg *.jpeg *.svg *.webp"]

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path) {
                    console.log("Selected icon:", path);
                    copyIconProcess.command = ["cp", path, Quickshell.env("HOME") + "/.face.icon"];
                    copyIconProcess.running = true;
                }
            }
        }
    }

    Process {
        id: copyIconProcess
        running: false
        command: []

        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("Icon updated successfully");
                avatarCacheBuster = Date.now();
            } else {
                console.warn("Failed to update icon");
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // COMPOSITOR LAYOUT STATE (persisted via StateService)
    // Layouts are fetched per compositor from `axctl layout list`;
    // on niri that's just ["scrolling"], on hyprland the live set.
    // ═══════════════════════════════════════════════════════════════
    property string compositorLayout: ""
    property bool compositorLayoutReady: false
    readonly property var fallbackLayouts: ["dwindle", "master", "scrolling", "monocle"]
    property var availableLayouts: fallbackLayouts

    Timer {
        id: layoutFetchRetry
        interval: 1000
        repeat: true
        property int attempts: 0

        onTriggered: {
            attempts++;
            if (attempts > 30) {
                running = false;
                return;
            }
            root.fetchLayoutList();
        }
    }

    function applyLayoutList(payload) {
        if (!payload) return;
        const names = (payload.items || []).map(item => item.name).filter(name => !!name);
        if (names.length > 0) {
            root.availableLayouts = names;
        }
        const active = payload.active || ((payload.items || []).find(item => item.current) || {}).name || "";
        if (active) {
            root.compositorLayout = active;
        } else {
            root.compositorLayout = StateService.get("compositorLayout", names[0] || "dwindle");
        }
        // The payload carries the compositor name too; sync it so the
        // overview/overview-button detection doesn't wait for the
        // separate get-compositor probe.
        if (payload.compositor) {
            AxctlService.compositorName = payload.compositor;
        }
        root.compositorLayoutReady = true;
        layoutFetchRetry.running = false;
    }

    function fetchLayoutList() {
        BackendService.call("compositor.dispatch", {args: ["layout", "list"]}, (result, error) => {
            if (error || !result || result.error || result.exit_code !== 0) {
                if (layoutFetchRetry.attempts >= 30) {
                    console.warn("GlobalStates: axctl layout list failed:", error || (result && result.error));
                    if (!root.compositorLayout) {
                        root.compositorLayout = StateService.get("compositorLayout", "dwindle");
                    }
                    root.compositorLayoutReady = true;
                }
                return;
            }
            try {
                root.applyLayoutList(JSON.parse(result.stdout || ""));
            } catch (e) {
                console.warn("GlobalStates: failed to parse layout list:", e);
                if (!root.compositorLayout) {
                    root.compositorLayout = StateService.get("compositorLayout", "dwindle");
                }
                root.compositorLayoutReady = true;
                layoutFetchRetry.running = false;
            }
        });
    }

    function setCompositorLayout(layout) {
        if (!availableLayouts.includes(layout)) {
            return;
        }
        compositorLayout = layout;
        StateService.set("compositorLayout", layout);
        BackendService.call("compositor.dispatch", {args: ["layout", "set", layout]}, (result, error) => {
            if (error || !result || result.error || result.exit_code !== 0) {
                console.warn("GlobalStates: axctl layout set failed (", layout, "):", error || (result && result.error));
            }
        });
    }

    function cycleCompositorLayout() {
        if (availableLayouts.length === 0) {
            return;
        }
        const currentIndex = availableLayouts.indexOf(compositorLayout);
        const nextIndex = (currentIndex + 1) % availableLayouts.length;
        setCompositorLayout(availableLayouts[nextIndex]);
    }


    // Ensure LockscreenService singleton is loaded
    Component.onCompleted: {
        // Reference the singleton to ensure it loads
        LockscreenService.toString();
        // Fetch the active layout from the compositor
        fetchLayoutList();
        layoutFetchRetry.running = true;
    }

    // Persistent launcher state across monitors
    property string launcherSearchText: ""
    property int launcherSelectedIndex: -1
    property int launcherCurrentTab: 0

    function clearLauncherState() {
        launcherSearchText = "";
        launcherSelectedIndex = -1;
    }

    // Persistent dashboard state across monitors  
    property int dashboardCurrentTab: 0
    
    // Widgets tab internal state (for prefix-based tabs)
    // 0=launcher, 1=clipboard, 2=emoji, 3=tmux, 4=wallpapers
    property int widgetsTabCurrentIndex: 0

    // Persistent wallpaper navigation state
    property int wallpaperSelectedIndex: -1

    // Bumped to re-align video wallpapers across screens (seek to 0)
    property int videoSyncTick: 0

    // Per-screen Wallpaper instances (screen name -> instance)
    property var screenWallpapers: ({})

    function wallpaperForScreen(name) {
        return (screenWallpapers && screenWallpapers[name]) || wallpaperManager || null;
    }

    function clearWallpaperState() {
        wallpaperSelectedIndex = -1;
    }

    // Wallpaper Transitions & Automation State (persisted via StateService)
    // The transition is one of skwd-wall's (SkwdWall.transitions),
    // "random" picks a different one each time; duration is in milliseconds.
    property string wallpaperTransitionStyle: StateService.get("wallpaperTransitionStyle", "random")
    property int wallpaperTransitionDuration: StateService.get("wallpaperTransitionDuration", 700)
    property string wallpaperPauseMode: StateService.get("wallpaperPauseMode", "fullscreen")
    property string wallpaperPauseScope: StateService.get("wallpaperPauseScope", "perScreen")
    property bool wallpapersTabShowSettings: false
    property bool wallpaperPeriodicEnabled: StateService.get("wallpaperPeriodicEnabled", false)
    property int wallpaperPeriodicSeconds: StateService.get("wallpaperPeriodicSeconds", StateService.get("wallpaperPeriodicInterval", 15) * 60)
    property int wallpaperPeriodicInterval: Math.max(1, Math.round(wallpaperPeriodicSeconds / 60))
    property bool wallpaperSolarSyncEnabled: StateService.get("wallpaperSolarSyncEnabled", false)
    property string lastTriggeredSolarPeriod: ""
    property var wallpaperRandomSourceFilters: StateService.get("wallpaperRandomSourceFilters", [])
    property var solarCacheMap: ({})

    FileView {
        id: solarCacheFileView
        path: Quickshell.env("HOME") + "/.cache/ambxst/wallpaper_solar_cache.json"
        onLoaded: {
            try {
                let txt = solarCacheFileView.text();
                if (txt && txt.length > 2) {
                    root.solarCacheMap = JSON.parse(txt);
                }
            } catch (e) {
                console.warn("GlobalStates: Failed to parse wallpaper_solar_cache.json:", e);
            }
        }
    }

    Process {
        id: solarIndexProcess
        // The time-of-day indexer for Match Time of Day.
        command: ["python3", Quickshell.shellDir + "/scripts/skwd_solar_index.py"]
        running: false
        onExited: (code) => {
            if (code === 0) {
                solarCacheFileView.reload();
            }
        }
    }

    function refreshSolarCache() {
        if (!solarIndexProcess.running) {
            solarIndexProcess.running = true;
        }
    }

    function getCurrentSolarPeriod() {
        let hour = new Date().getHours();
        if (hour >= 6 && hour < 11) return "morning";
        if (hour >= 11 && hour < 17) return "afternoon";
        if (hour >= 17 && hour < 21) return "sunset";
        return "night";
    }

    function setWallpaperPauseMode(mode) {
        wallpaperPauseMode = mode;
        if (StateService && StateService.initialized) StateService.set("wallpaperPauseMode", mode);
    }

    function setWallpaperPauseScope(scope) {
        wallpaperPauseScope = scope;
        if (StateService && StateService.initialized) StateService.set("wallpaperPauseScope", scope);
    }

    function setWallpaperTransitionStyle(style) {
        wallpaperTransitionStyle = style;
        if (StateService && StateService.initialized) StateService.set("wallpaperTransitionStyle", style);
    }

    function setWallpaperTransitionDuration(duration) {
        wallpaperTransitionDuration = duration;
        if (StateService && StateService.initialized) StateService.set("wallpaperTransitionDuration", duration);
    }

    function setWallpaperPeriodicEnabled(enabled) {
        wallpaperPeriodicEnabled = enabled;
        if (StateService && StateService.initialized) StateService.set("wallpaperPeriodicEnabled", enabled);
    }

    function setWallpaperSolarSyncEnabled(enabled) {
        wallpaperSolarSyncEnabled = enabled;
        if (StateService && StateService.initialized) StateService.set("wallpaperSolarSyncEnabled", enabled);
        if (enabled) {
            if (!solarCacheMap || Object.keys(solarCacheMap).length === 0) {
                refreshSolarCache();
            }
        }
    }

    function setWallpaperPeriodicSeconds(sec) {
        let val = Math.max(5, Math.round(sec));
        wallpaperPeriodicSeconds = val;
        wallpaperPeriodicInterval = Math.max(1, Math.round(val / 60));
        if (StateService && StateService.initialized) {
            StateService.set("wallpaperPeriodicSeconds", val);
            StateService.set("wallpaperPeriodicInterval", wallpaperPeriodicInterval);
        }
    }

    function setWallpaperPeriodicInterval(interval) {
        setWallpaperPeriodicSeconds(Math.max(1, interval) * 60);
    }

    function setWallpaperRandomSourceFilters(filters) {
        wallpaperRandomSourceFilters = filters;
        if (StateService && StateService.initialized) StateService.set("wallpaperRandomSourceFilters", filters);
    }

    function toggleWallpaperRandomSourceFilter(filterKey) {
        let cur = (root.wallpaperRandomSourceFilters && Array.isArray(root.wallpaperRandomSourceFilters)) ? root.wallpaperRandomSourceFilters.slice() : [];
        let idx = cur.indexOf(filterKey);
        if (idx >= 0) {
            cur.splice(idx, 1);
        } else {
            cur.push(filterKey);
        }
        root.setWallpaperRandomSourceFilters(cur);
    }

    property var wallpaperShuffleDeck: []
    property string wallpaperShufflePoolKey: ""

    function triggerRandomWallpaper() {
        if (!wallpaperManager || !wallpaperManager.wallpaperPaths || wallpaperManager.wallpaperPaths.length === 0) return;
        let allPaths = wallpaperManager.wallpaperPaths;
        if (allPaths.length === 0) return;

        let paths = allPaths;
        let activeFilters = (root.wallpaperRandomSourceFilters && Array.isArray(root.wallpaperRandomSourceFilters)) ? root.wallpaperRandomSourceFilters : [];
        if (activeFilters.length > 0) {
            let basePath = wallpaperManager.wallpaperDir || "";
            if (basePath && !basePath.endsWith("/")) basePath += "/";

            let hasImage = activeFilters.includes("image");
            let hasGif = activeFilters.includes("gif");
            let hasVideo = activeFilters.includes("video");
            let subfilters = [];
            for (let j = 0; j < activeFilters.length; j++) {
                let f = activeFilters[j];
                if (f.startsWith("subfolder_")) {
                    subfilters.push(f.replace("subfolder_", ""));
                } else if (f !== "image" && f !== "gif" && f !== "video") {
                    subfilters.push(f);
                }
            }

            let filtered = allPaths.filter(function(path) {
                let ext = path.substring(path.lastIndexOf('.') + 1).toLowerCase();
                let isImg = (ext === 'jpg' || ext === 'jpeg' || ext === 'png' || ext === 'webp' || ext === 'bmp' || ext === 'tif' || ext === 'tiff');
                let isG = (ext === 'gif');
                let isV = (ext === 'mp4' || ext === 'webm' || ext === 'mov' || ext === 'avi' || ext === 'mkv');

                if ((hasImage && isImg) || (hasGif && isG) || (hasVideo && isV)) {
                    return true;
                }

                if (subfilters.length > 0 && basePath) {
                    let rel = path.startsWith(basePath) ? path.substring(basePath.length) : path;
                    let slashIdx = rel.indexOf('/');
                    if (slashIdx !== -1) {
                        let topDir = rel.substring(0, slashIdx);
                        if (subfilters.includes(topDir)) {
                            return true;
                        }
                    }
                }
                return false;
            });
            if (filtered.length > 0) {
                paths = filtered;
            }
        }

        if (root.wallpaperSolarSyncEnabled) {
            let period = root.getCurrentSolarPeriod();
            let basePath = wallpaperManager.wallpaperDir || "";
            if (basePath && !basePath.endsWith("/")) basePath += "/";

            let solarFiltered = paths.filter(function(path) {
                let rel = path.startsWith(basePath) ? path.substring(basePath.length) : path;
                if (root.solarCacheMap && root.solarCacheMap[rel]) {
                    return root.solarCacheMap[rel] === period;
                }
                // Fallback to keyword matching if not cached
                let lower = path.toLowerCase();
                let keywords = [];
                if (period === "morning") {
                    keywords = ["morning", "dawn", "sunrise", "early", "daybreak", "light"];
                } else if (period === "afternoon") {
                    keywords = ["afternoon", "midday", "noon", "day", "bright", "sun", "warm"];
                } else if (period === "sunset") {
                    keywords = ["sunset", "dusk", "evening", "golden", "twilight", "sundown", "orange"];
                } else {
                    keywords = ["night", "dark", "midnight", "stars", "moon", "starry", "neon", "space"];
                }
                for (let k = 0; k < keywords.length; k++) {
                    if (lower.indexOf(keywords[k]) !== -1) return true;
                }
                return false;
            });

            if (solarFiltered.length > 0) {
                paths = solarFiltered;
            }
        }

        let screenName = (typeof AxctlService !== "undefined" && AxctlService.focusedMonitor && AxctlService.focusedMonitor.name)
            ? AxctlService.focusedMonitor.name
            : ((wallpaperManager.screen && wallpaperManager.screen.name) ? wallpaperManager.screen.name : (wallpaperManager.currentScreenName || ""));
        let perScreen = wallpaperManager.perScreenWallpapers || {};
        let isPerScreen = (screenName !== "" && perScreen[screenName] !== undefined);
        let curPath = isPerScreen ? perScreen[screenName] : ((wallpaperManager.effectiveWallpaper !== undefined && wallpaperManager.effectiveWallpaper !== "") ? wallpaperManager.effectiveWallpaper : (wallpaperManager.currentWallpaper || ""));

        // Shuffle Deck management: 100% fair random permutation without repetition
        let periodKey = root.wallpaperSolarSyncEnabled ? (":" + root.getCurrentSolarPeriod()) : "";
        let poolKey = activeFilters.slice().sort().join("|") + ":" + paths.length + periodKey;
        if (root.wallpaperShufflePoolKey !== poolKey || !Array.isArray(root.wallpaperShuffleDeck)) {
            root.wallpaperShuffleDeck = [];
            root.wallpaperShufflePoolKey = poolKey;
        }

        if (root.wallpaperShuffleDeck.length === 0) {
            let deck = paths.slice();
            // Fisher-Yates shuffle
            for (let i = deck.length - 1; i > 0; i--) {
                let j = Math.floor(Math.random() * (i + 1));
                let temp = deck[i];
                deck[i] = deck[j];
                deck[j] = temp;
            }
            // Avoid repeating curPath on reshuffle boundary
            if (deck.length > 1 && deck[0] === curPath) {
                let swapIdx = 1 + Math.floor(Math.random() * (deck.length - 1));
                let temp = deck[0];
                deck[0] = deck[swapIdx];
                deck[swapIdx] = temp;
            }
            root.wallpaperShuffleDeck = deck;
        }

        let nextWallpaper = root.wallpaperShuffleDeck.shift();
        if (nextWallpaper === curPath && root.wallpaperShuffleDeck.length > 0) {
            let alt = root.wallpaperShuffleDeck.shift();
            root.wallpaperShuffleDeck.push(nextWallpaper);
            nextWallpaper = alt;
        }

        if (isPerScreen) {
            wallpaperManager.setWallpaper(nextWallpaper, screenName);
        } else {
            wallpaperManager.setWallpaper(nextWallpaper);
        }
        wallpaperSelectedIndex = allPaths.indexOf(nextWallpaper);
    }

    Timer {
        id: wallpaperPeriodicTimer
        interval: Math.max(5, root.wallpaperPeriodicSeconds) * 1000
        repeat: true
        running: root.wallpaperPeriodicEnabled
        onTriggered: {
            root.triggerRandomWallpaper();
        }
    }

    Timer {
        id: solarPhaseCheckTimer
        interval: 30000
        repeat: true
        running: root.wallpaperPeriodicEnabled && root.wallpaperSolarSyncEnabled
        onTriggered: {
            let curPeriod = root.getCurrentSolarPeriod();
            if (root.lastTriggeredSolarPeriod === "") {
                root.lastTriggeredSolarPeriod = curPeriod;
            } else if (curPeriod !== root.lastTriggeredSolarPeriod) {
                root.lastTriggeredSolarPeriod = curPeriod;
                root.triggerRandomWallpaper();
            }
        }
    }

    Connections {
        target: StateService
        function onInitializedChanged() {
            if (StateService.initialized) {
                root.wallpaperTransitionStyle = StateService.get("wallpaperTransitionStyle", "random");
                root.wallpaperTransitionDuration = StateService.get("wallpaperTransitionDuration", 700);
                root.wallpaperPeriodicEnabled = StateService.get("wallpaperPeriodicEnabled", false);
                root.wallpaperPeriodicSeconds = StateService.get("wallpaperPeriodicSeconds", StateService.get("wallpaperPeriodicInterval", 15) * 60);
                root.wallpaperPeriodicInterval = Math.max(1, Math.round(root.wallpaperPeriodicSeconds / 60));
                root.wallpaperSolarSyncEnabled = StateService.get("wallpaperSolarSyncEnabled", false);
                root.wallpaperRandomSourceFilters = StateService.get("wallpaperRandomSourceFilters", []);
                root.wallpaperPauseMode = StateService.get("wallpaperPauseMode", "fullscreen");
                root.wallpaperPauseScope = StateService.get("wallpaperPauseScope", "perScreen");
            }
        }
        function onStateLoaded() {
            root.wallpaperTransitionStyle = StateService.get("wallpaperTransitionStyle", "random");
            root.wallpaperTransitionDuration = StateService.get("wallpaperTransitionDuration", 700);
            root.wallpaperPeriodicEnabled = StateService.get("wallpaperPeriodicEnabled", false);
            root.wallpaperPeriodicSeconds = StateService.get("wallpaperPeriodicSeconds", StateService.get("wallpaperPeriodicInterval", 15) * 60);
            root.wallpaperPeriodicInterval = Math.max(1, Math.round(root.wallpaperPeriodicSeconds / 60));
            root.wallpaperSolarSyncEnabled = StateService.get("wallpaperSolarSyncEnabled", false);
            root.wallpaperRandomSourceFilters = StateService.get("wallpaperRandomSourceFilters", []);
            root.wallpaperPauseMode = StateService.get("wallpaperPauseMode", "fullscreen");
            root.wallpaperPauseScope = StateService.get("wallpaperPauseScope", "perScreen");
        }
    }

    function getNotchOpen(screenName) {
        let visibilities = Visibilities.getForScreen(screenName);
        return visibilities.launcher || visibilities.dashboard || visibilities.overview || visibilities.presets;
    }

    function getActiveLauncher() {
        let active = Visibilities.getForActive();
        return active ? active.launcher : false;
    }

    function getActiveDashboard() {
        let active = Visibilities.getForActive();
        return active ? active.dashboard : false;
    }

    function getActiveOverview() {
        let active = Visibilities.getForActive();
        return active ? active.overview : false;
    }

    function getActivePresets() {
        let active = Visibilities.getForActive();
        return active ? active.presets : false;
    }

    function getActiveNotchOpen() {
        let active = Visibilities.getForActive();
        return active ? (active.launcher || active.dashboard || active.overview) : false;
    }

    // Legacy properties for backward compatibility - use active screen
    readonly property bool notchOpen: getActiveNotchOpen()
    readonly property bool overviewOpen: getActiveOverview()
    readonly property bool presetsOpen: getActivePresets()
    readonly property bool launcherOpen: getActiveLauncher()
    readonly property bool dashboardOpen: getActiveDashboard()

    // Lockscreen state
    property bool lockscreenVisible: false

    // OSD state
    property bool osdVisible: false
    property string osdIndicator: "volume" // volume, mic, brightness

    // Screenshot Tool state
    property bool screenshotToolVisible: false
    // property string screenshotToolMode: "normal" // DEPRECATED
    property string screenshotCaptureMode: "region" // region, window, screen
    
    // Global selection state for synchronization
    property int screenshotSelectionX: 0
    property int screenshotSelectionY: 0
    property int screenshotSelectionW: 0
    property int screenshotSelectionH: 0

    // Screen Record Tool state
    property bool screenRecordToolVisible: false

    // Mirror Tool state
    property bool mirrorWindowVisible: false

    // Settings Window state
    property bool settingsWindowVisible: false
    property int settingsTargetWorkspaceId: 0
    property string settingsTargetScreenName: ""

    // Theme editor state - persists across tab switches
    property bool themeHasChanges: false
    property var themeSnapshot: null

    // Constants for theme snapshot operations (avoid duplication)
    // Get SR variant names dynamically from Config.theme
    function _getSrVariantNames() {
        var names = [];
        var keys = Object.keys(Config.theme);
        for (var i = 0; i < keys.length; i++) {
            if (keys[i].startsWith("sr")) {
                names.push(keys[i]);
            }
        }
        return names;
    }

    readonly property var _simpleThemeProps: [
        "roundness", "oledMode", "lightMode", "font", "fontSize", "monoFont", "monoFontSize",
        "tintIcons", "enableCorners", "animDuration",
        "shadowOpacity", "shadowColor", "shadowXOffset", "shadowYOffset", "shadowBlur"
    ]
    readonly property var _srVariantProps: [
        "gradientType", "gradientAngle", "gradientCenterX", "gradientCenterY",
        "halftoneDotMin", "halftoneDotMax", "halftoneStart", "halftoneEnd",
        "halftoneDotColor", "halftoneBackgroundColor", "itemColor", "opacity"
    ]

    // Deep copy a single SR variant
    function _copySrVariant(src) {
        var copy = {};
        for (var i = 0; i < _srVariantProps.length; i++) {
            if (src[_srVariantProps[i]] !== undefined) {
                copy[_srVariantProps[i]] = src[_srVariantProps[i]];
            }
        }
        // Deep copy arrays with safety checks
        try {
            copy.gradient = (src.gradient !== undefined) ? JSON.parse(JSON.stringify(src.gradient)) : [];
        } catch (e) {
            console.warn("GlobalStates: Error cloning gradient: " + e);
            copy.gradient = [];
        }
        
        try {
            copy.border = (src.border !== undefined) ? JSON.parse(JSON.stringify(src.border)) : [];
        } catch (e) {
            console.warn("GlobalStates: Error cloning border: " + e);
            copy.border = [];
        }
        
        return copy;
    }

    // Restore a single SR variant from source to destination
    function _restoreSrVariant(src, dest) {
        for (var i = 0; i < _srVariantProps.length; i++) {
            if (src[_srVariantProps[i]] !== undefined) {
                dest[_srVariantProps[i]] = src[_srVariantProps[i]];
            }
        }
        // Deep copy arrays with safety checks
        if (src.gradient !== undefined) {
            try {
                dest.gradient = JSON.parse(JSON.stringify(src.gradient));
            } catch (e) { console.warn("GlobalStates: Error restoring gradient: " + e); }
        }
        
        if (src.border !== undefined) {
            try {
                dest.border = JSON.parse(JSON.stringify(src.border));
            } catch (e) { console.warn("GlobalStates: Error restoring border: " + e); }
        }
    }

    // Create a deep copy of the current theme config
    function createThemeSnapshot() {
        var snapshot = {};
        var theme = Config.theme;
        var srVariantNames = _getSrVariantNames();

        // Copy simple properties
        for (var i = 0; i < _simpleThemeProps.length; i++) {
            var prop = _simpleThemeProps[i];
            snapshot[prop] = theme[prop];
        }

        // Copy SR variants
        for (var j = 0; j < srVariantNames.length; j++) {
            var name = srVariantNames[j];
            snapshot[name] = _copySrVariant(theme[name]);
        }

        return snapshot;
    }

    // Restore theme from snapshot
    function restoreThemeSnapshot(snapshot) {
        if (!snapshot) return;

        var theme = Config.theme;
        var srVariantNames = _getSrVariantNames();

        // Restore simple properties
        for (var i = 0; i < _simpleThemeProps.length; i++) {
            var prop = _simpleThemeProps[i];
            theme[prop] = snapshot[prop];
        }

        // Restore SR variants
        for (var j = 0; j < srVariantNames.length; j++) {
            var name = srVariantNames[j];
            if (snapshot[name]) {
                _restoreSrVariant(snapshot[name], theme[name]);
            }
        }
    }

    function markThemeChanged() {
        // Take a snapshot before the first change
        if (!themeHasChanges) {
            themeSnapshot = createThemeSnapshot();
            Config.pauseAutoSave = true;
        }
        themeHasChanges = true;
    }

    function applyThemeChanges() {
        if (themeHasChanges) {
            Config.loader.writeAdapter();
            themeHasChanges = false;
            themeSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    function discardThemeChanges() {
        if (themeHasChanges && themeSnapshot) {
            restoreThemeSnapshot(themeSnapshot);
            themeHasChanges = false;
            themeSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SHELL SETTINGS STATE
    // ═══════════════════════════════════════════════════════════════
    property bool shellHasChanges: false
    property var shellSnapshot: null

    // Shell config sections and their properties
    readonly property var _shellSections: {
        "bar": ["position", "launcherIcon", "launcherIconTint", "launcherIconFullTint", "launcherIconSize", "enableFirefoxPlayer", "screenList", "frameEnabled", "frameThickness", "pinnedOnStartup", "hoverToReveal", "hoverRegionHeight", "showPinButton", "availableOnFullscreen", "pillStyle", "use12hFormat", "containBar", "keepBarShadow", "keepBarBorder"],
        "notch": ["theme", "position", "hoverRegionHeight", "keepHidden"],
        "workspaces": ["shown", "showAppIcons", "alwaysShowNumbers", "showNumbers", "dynamic"],
        "overview": ["rows", "columns", "scale", "workspaceSpacing"],
        "dock": ["enabled", "theme", "position", "height", "iconSize", "spacing", "margin", "hoverRegionHeight", "pinnedOnStartup", "hoverToReveal", "availableOnFullscreen", "showRunningIndicators", "showPinButton", "showOverviewButton", "screenList", "keepHidden"],
        "lockscreen": ["position"],
        "desktop": ["enabled", "iconSize", "spacingVertical", "textColor"],
        "system": ["idle", "ocr"]
    }

    // Create a deep copy of the current shell config
    function createShellSnapshot() {
        var snapshot = {};
        var sections = Object.keys(_shellSections);
        for (var i = 0; i < sections.length; i++) {
            var section = sections[i];
            var props = _shellSections[section];
            snapshot[section] = {};
            for (var j = 0; j < props.length; j++) {
                var prop = props[j];
                var val = Config[section][prop];
                // Deep copy arrays or objects
                if (typeof val === 'object' && val !== null) {
                    snapshot[section][prop] = JSON.parse(JSON.stringify(val));
                } else {
                    snapshot[section][prop] = val;
                }
            }
        }
        return snapshot;
    }

    // Restore shell config from snapshot
    function restoreShellSnapshot(snapshot) {
        if (!snapshot) return;
        var sections = Object.keys(_shellSections);
        for (var i = 0; i < sections.length; i++) {
            var section = sections[i];
            var props = _shellSections[section];
            for (var j = 0; j < props.length; j++) {
                var prop = props[j];
                var val = snapshot[section][prop];
                
                // Special handling for system.idle (JsonObject)
                if (section === "system" && prop === "idle" && val) {
                    if (val.general) {
                        var generalProps = ["lock_cmd", "before_sleep_cmd", "after_sleep_cmd"];
                        for (var k = 0; k < generalProps.length; k++) {
                            var gp = generalProps[k];
                            if (val.general[gp] !== undefined) {
                                Config.system.idle.general[gp] = val.general[gp];
                            }
                        }
                    }
                    if (val.listeners) {
                        Config.system.idle.listeners = JSON.parse(JSON.stringify(val.listeners));
                    }
                }
                // Special handling for system.ocr (JsonObject)
                else if (section === "system" && prop === "ocr" && val) {
                    var keys = Object.keys(val);
                    for (var k = 0; k < keys.length; k++) {
                        var key = keys[k];
                        Config.system.ocr[key] = val[key];
                    }
                }
                // Deep copy arrays or objects
                else if (typeof val === 'object' && val !== null) {
                    Config[section][prop] = JSON.parse(JSON.stringify(val));
                } else {
                    Config[section][prop] = val;
                }
            }
        }
    }

    function markShellChanged() {
        // Take a snapshot before the first change
        if (!shellHasChanges) {
            shellSnapshot = createShellSnapshot();
            Config.pauseAutoSave = true;
        }
        shellHasChanges = true;
    }

    function applyShellChanges() {
        if (shellHasChanges) {
            Config.saveBar();
            Config.saveNotch();
            Config.saveWorkspaces();
            Config.saveOverview();
            Config.saveDock();
            Config.saveLockscreen();
            Config.saveDesktop();
            Config.saveSystem();
            
            shellHasChanges = false;
            shellSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    function discardShellChanges() {
        if (shellHasChanges && shellSnapshot) {
            restoreShellSnapshot(shellSnapshot);
            shellHasChanges = false;
            shellSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // COMPOSITOR SETTINGS STATE
    // ═══════════════════════════════════════════════════════════════
    property bool compositorHasChanges: false
    property var compositorSnapshot: null

    // Compositor config properties (AxctlService)
    readonly property var _compositorProps: [
        "syncBorderWidth", "borderSize",
        "syncRoundness", "rounding",
        "gapsIn", "gapsOut",
        "borderAngle", "inactiveBorderAngle",
        "syncBorderColor", "activeBorderColor", "inactiveBorderColor",
        "shadowEnabled", "syncShadowColor", "syncShadowOpacity",
        "shadowRange", "shadowRenderPower", "shadowScale",
        "shadowOpacity", "shadowSharp", "shadowIgnoreWindow",
        "blurEnabled", "blurSize", "blurPasses", "blurXray",
        "blurNewOptimizations", "blurIgnoreOpacity",
        "blurNoise", "blurContrast", "blurBrightness", "blurVibrancy",
        "blurVibrancyDarkness", "blurSpecial", "blurPopups", "blurPopupsIgnorealpha",
        "blurInputMethods", "blurInputMethodsIgnorealpha",
        "blurExplicitIgnoreAlpha", "blurIgnoreAlphaValue",
        "shadowOffset", "shadowColorInactive"
    ]

    // Create a deep copy of the current compositor config
    function createCompositorSnapshot() {
        var snapshot = {};
        for (var i = 0; i < _compositorProps.length; i++) {
            var prop = _compositorProps[i];
            var val = Config.compositor[prop];
            // Deep copy arrays
            if (Array.isArray(val)) {
                snapshot[prop] = JSON.parse(JSON.stringify(val));
            } else {
                snapshot[prop] = val;
            }
        }
        return snapshot;
    }

    // Restore compositor config from snapshot
    function restoreCompositorSnapshot(snapshot) {
        if (!snapshot) return;
        for (var i = 0; i < _compositorProps.length; i++) {
            var prop = _compositorProps[i];
            if (snapshot[prop] !== undefined) {
                var val = snapshot[prop];
                // Deep copy arrays
                if (Array.isArray(val)) {
                    Config.compositor[prop] = JSON.parse(JSON.stringify(val));
                } else {
                    Config.compositor[prop] = val;
                }
            }
        }
    }

    function markCompositorChanged() {
        // Take a snapshot before the first change
        if (!compositorHasChanges) {
            compositorSnapshot = createCompositorSnapshot();
            Config.pauseAutoSave = true;
        }
        compositorHasChanges = true;
    }

    function applyCompositorChanges() {
        if (compositorHasChanges) {
            Config.saveCompositor();
            compositorHasChanges = false;
            compositorSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    function discardCompositorChanges() {
        if (compositorHasChanges && compositorSnapshot) {
            restoreCompositorSnapshot(compositorSnapshot);
            compositorHasChanges = false;
            compositorSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // ASSISTANT SIDEBAR STATE
    // ═══════════════════════════════════════════════════════════════
    property bool assistantVisible: false
    property bool assistantPinned: Config.ai.sidebarPinnedOnStartup ?? false
    property int assistantWidth: Config.ai.sidebarWidth ?? 400
    property string assistantPosition: Config.ai.sidebarPosition ?? "right"
    property string assistantScreenName: ""

    signal assistantFocusRequested(bool wasAlreadyOpen)

    function toggleAssistant() {
        if (assistantVisible) {
            assistantFocusRequested(true);
        } else {
            assistantVisible = true;
            if (AxctlService.focusedMonitor && AxctlService.focusedMonitor.name) {
                assistantScreenName = AxctlService.focusedMonitor.name;
            } else if (Quickshell.screens.length > 0) {
                assistantScreenName = Quickshell.screens[0].name;
            }
            assistantFocusRequested(false);
        }
    }

    function hideAssistant() {
        assistantVisible = false;
    }

    property int settingsCurrentTab: 0
}
