// Wallpaper settings inside the Wallpapers tab. Based on the settings panel of
// Wallpaper Transitions (https://github.com/POSiTiiiV/ambxst-mods), Copyright (c)
// 2026 positive, MIT licensed: see LICENSE-wallpaper-transitions beside this file.
// The transition, duration and pause settings drive skwd-wall (SkwdWall).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config

FocusScope {
    id: root
    focus: true

    // No background of its own: the notch's themed background (your srBg
    // colour, opacity, gradient and rounded corners) shows through, as it does
    // behind every stock tab. This only stops clicks reaching the grid.
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {}
    }

    signal backClicked

    component MarqueeText: Item {
        id: marqueeRoot
        clip: true
        implicitHeight: textItem.implicitHeight
        implicitWidth: textItem.implicitWidth

        property alias text: textItem.text
        property alias font: textItem.font
        property alias color: textItem.color
        property alias textOpacity: textItem.opacity
        property bool hovered: false
        property bool isSelected: false
        property real speed: 38

        readonly property bool isOverflowing: marqueeRoot.width > 0 && textItem.implicitWidth > marqueeRoot.width
        readonly property real overflowDistance: (marqueeRoot.width > 0 && isOverflowing) ? Math.max(0, textItem.implicitWidth - marqueeRoot.width) : 0
        readonly property int animDuration: Math.max(1200, Math.round((overflowDistance / Math.max(1, speed)) * 1000))
        readonly property bool shouldAnimate: isOverflowing && hovered && marqueeRoot.visible

        Text {
            id: textItem
            x: 0
            width: marqueeRoot.shouldAnimate ? implicitWidth : Math.min(implicitWidth, marqueeRoot.width)
            elide: marqueeRoot.shouldAnimate ? Text.ElideNone : Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }

        SequentialAnimation {
            id: marqueeAnim
            running: marqueeRoot.shouldAnimate
            loops: Animation.Infinite

            PauseAnimation { duration: 1100 }
            NumberAnimation {
                target: textItem
                property: "x"
                to: -marqueeRoot.overflowDistance
                duration: marqueeRoot.animDuration
                easing.type: Easing.InOutQuad
            }
            PauseAnimation { duration: 1300 }
            NumberAnimation {
                target: textItem
                property: "x"
                to: 0
                duration: Math.max(700, Math.round(marqueeRoot.animDuration * 0.75))
                easing.type: Easing.InOutQuad
            }
            PauseAnimation { duration: 800 }
        }

        onShouldAnimateChanged: {
            if (!shouldAnimate) {
                marqueeAnim.stop();
                textItem.x = 0;
            }
        }
    }

    component AmbxstSwitch: Switch {
        id: swRoot
        focusPolicy: Qt.NoFocus

        indicator: Rectangle {
            implicitWidth: 40
            implicitHeight: 20
            x: swRoot.leftPadding
            y: parent.height / 2 - height / 2
            radius: height / 2
            color: swRoot.checked ? Styling.srItem("overprimary") : Colors.surfaceBright
            border.color: swRoot.checked ? Styling.srItem("overprimary") : Colors.outline

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration / 2
                }
            }

            Rectangle {
                x: swRoot.checked ? parent.width - width - 2 : 2
                y: 2
                width: parent.height - 4
                height: width
                radius: width / 2
                color: swRoot.checked ? Colors.background : Colors.overSurfaceVariant

                Behavior on x {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
        background: null
    }

    // The transition is one of skwd-wall's; an old style
    // saved by Wallpaper Transitions is shown as the skwd one it maps to.
    property string currentStyle: SkwdWall.migrateStyle(GlobalStates ? GlobalStates.wallpaperTransitionStyle : "random")
    property int currentDuration: (GlobalStates && GlobalStates.wallpaperTransitionDuration) ? GlobalStates.wallpaperTransitionDuration : 700


    // Active navigation section
    // 0: Transition Style (carousel), 2: Animation Duration, 3: Automation & Rotation,
    // 4: Material You Schemes, 5: Color Presets, 6: Back Button
    // (1 was Easing Curve: skwd-wall's transitions have no easing.)
    property int currentSection: 0
    property int focusedStyleIndex: 0
    property int focusedSpeedIndex: 1
    property int focusedAutomationIndex: 0 // 0: Periodic Toggle, 1-6: Intervals, 7: All Wallpapers, 8+: Sources
    property int focusedSchemeIndex: 0
    property int focusedPresetIndex: 0

    // skwd-wall's transitions, grouped by family (SkwdWall.transitions).
    readonly property var styleOptions: SkwdWall.transitions.map(t => ({
                id: t.key,
                title: t.title,
                desc: t.desc,
                family: t.family
            }))
    property string styleFamilyFilter: "all"
    readonly property var visibleStyleOptions: styleFamilyFilter === "all" ? styleOptions : styleOptions.filter(o => o.family === styleFamilyFilter || o.family === "random")

    readonly property var speedOptions: [
        { label: "200ms", sub: "Fast", value: 200 },
        { label: "400ms", sub: "Normal", value: 400 },
        { label: "700ms", sub: "Smooth", value: 700 },
        { label: "1.2s", sub: "Cinematic", value: 1200 }
    ]

    readonly property var intervalOptions: [
        { label: "30s", text: "30s", sec: 30 },
        { label: "1m", text: "1m", sec: 60 },
        { label: "5m", text: "5m", sec: 300 },
        { label: "15m", text: "15m", sec: 900 },
        { label: "30m", text: "30m", sec: 1800 },
        { label: "1h", text: "1h", sec: 3600 },
        { label: "2h", text: "2h", sec: 7200 }
    ]

    readonly property int currentPeriodicSeconds: GlobalStates ? GlobalStates.wallpaperPeriodicSeconds : 900
    readonly property string currentRotationMode: GlobalStates ? GlobalStates.wallpaperRotationMode : "interval"
    property bool showCustomInput: !isStandardPreset(currentPeriodicSeconds)
    property int customHours: 0
    property int customMinutes: 15
    property int customSeconds: 0

    function initCustomInput() {
        let sec = root.currentPeriodicSeconds;
        customHours = Math.floor(sec / 3600);
        customMinutes = Math.floor((sec % 3600) / 60);
        customSeconds = sec % 60;
    }

    onCurrentPeriodicSecondsChanged: initCustomInput()

    function applyCustomTimer() {
        let sec = (customHours * 3600) + (customMinutes * 60) + customSeconds;
        sec = Math.max(5, sec);
        if (GlobalStates) {
            if (!GlobalStates.wallpaperPeriodicEnabled) {
                GlobalStates.setWallpaperPeriodicEnabled(true);
            }
            GlobalStates.setWallpaperPeriodicSeconds(sec);
        }
    }

    readonly property bool isSolarSync: GlobalStates && GlobalStates.wallpaperSolarSyncEnabled
    readonly property string currentSolarPeriod: GlobalStates ? GlobalStates.getCurrentSolarPeriod() : "afternoon"

    function isStandardPreset(sec) {
        for (let i = 0; i < intervalOptions.length; i++) {
            if (intervalOptions[i].sec === sec) return true;
        }
        return false;
    }

    function formatDuration(sec) {
        if (!sec || sec < 60) {
            return (sec || 15) + "s";
        }
        let h = Math.floor(sec / 3600);
        let m = Math.floor((sec % 3600) / 60);
        let s = sec % 60;
        let parts = [];
        if (h > 0) parts.push(h + "h");
        if (m > 0) parts.push(m + "m");
        if (s > 0) parts.push(s + "s");
        return parts.join(" ");
    }

    function getSolarPhaseInfo(id) {
        switch (id) {
            case "morning": return { title: "Morning (06:00 – 11:00)", icon: Icons.sunDim, desc: "Fresh daylight & bright pastels" };
            case "afternoon": return { title: "Afternoon (11:00 – 17:00)", icon: Icons.sun, desc: "Warm, bright & vibrant daylight" };
            case "sunset": return { title: "Sunset (17:00 – 21:00)", icon: Icons.sunDim, desc: "Golden hour, warm orange & dusk" };
            case "night": return { title: "Night (21:00 – 06:00)", icon: Icons.moon, desc: "Dark, starry night & deep tones" };
            default: return { title: "Daytime", icon: Icons.sun, desc: "Balanced daylight" };
        }
    }

    function getSolarCount(period) {
        if (!GlobalStates || !GlobalStates.solarCacheMap) return 0;
        let map = GlobalStates.solarCacheMap;
        let count = 0;
        for (let k in map) {
            if (map[k] === period) count++;
        }
        return count;
    }

    readonly property var pauseOptions: [
        {
            id: "fullscreen",
            title: "Fullscreen only (Default)",
            sub: "Pause when an app is in exclusive fullscreen mode",
            desc: "Pauses video & GIF playback when a game, media player, or window is fullscreen."
        },
        {
            id: "covered",
            title: "Maximized & Fullscreen",
            sub: "Pause whenever windows cover the screen",
            desc: "Pauses live wallpaper whenever a tiled, maximized, or fullscreen window covers the screen."
        },
        {
            id: "never",
            title: "Never pause",
            sub: "Keep playing continuously",
            desc: "Always keeps video and GIF wallpapers playing, regardless of open windows."
        }
    ]

    readonly property string currentPauseMode: (GlobalStates && GlobalStates.wallpaperPauseMode) ? GlobalStates.wallpaperPauseMode : "fullscreen"
    readonly property string currentPauseScope: (GlobalStates && GlobalStates.wallpaperPauseScope) ? GlobalStates.wallpaperPauseScope : "perScreen"

    readonly property var availableSourceOptions: {
        let list = [
            { key: "image", label: "Images", icon: Icons.image, isSubfolder: false },
            { key: "gif", label: "GIFs", icon: Icons.play, isSubfolder: false },
            { key: "video", label: "Videos", icon: Icons.play, isSubfolder: false }
        ];
        if (GlobalStates && GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.subfolderFilters) {
            let subs = GlobalStates.wallpaperManager.subfolderFilters;
            for (let i = 0; i < subs.length; i++) {
                list.push({
                    key: "subfolder_" + subs[i],
                    label: subs[i],
                    icon: Icons.folder,
                    isSubfolder: true
                });
            }
        }
        return list;
    }

    function getMatchingCountText() {
        if (!GlobalStates || !GlobalStates.wallpaperManager || !GlobalStates.wallpaperManager.wallpaperPaths) {
            return "0 wallpapers";
        }
        let allPaths = GlobalStates.wallpaperManager.wallpaperPaths;
        let filters = (GlobalStates.wallpaperRandomSourceFilters && Array.isArray(GlobalStates.wallpaperRandomSourceFilters)) ? GlobalStates.wallpaperRandomSourceFilters : [];
        if (filters.length === 0) {
            return "Pool: " + allPaths.length + " (All)";
        }
        let basePath = (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.wallpaperDir) ? GlobalStates.wallpaperManager.wallpaperDir : "";
        if (basePath && !basePath.endsWith("/")) basePath += "/";

        let hasImage = filters.includes("image");
        let hasGif = filters.includes("gif");
        let hasVideo = filters.includes("video");
        let subfilters = [];
        for (let j = 0; j < filters.length; j++) {
            let f = filters[j];
            if (f.startsWith("subfolder_")) {
                subfilters.push(f.replace("subfolder_", ""));
            } else if (f !== "image" && f !== "gif" && f !== "video") {
                subfilters.push(f);
            }
        }

        let count = 0;
        for (let i = 0; i < allPaths.length; i++) {
            let p = allPaths[i];
            let ext = p.substring(p.lastIndexOf('.') + 1).toLowerCase();
            let isImg = (ext === 'jpg' || ext === 'jpeg' || ext === 'png' || ext === 'webp' || ext === 'bmp' || ext === 'tif' || ext === 'tiff');
            let isG = (ext === 'gif');
            let isV = (ext === 'mp4' || ext === 'webm' || ext === 'mov' || ext === 'avi' || ext === 'mkv');

            if ((hasImage && isImg) || (hasGif && isG) || (hasVideo && isV)) {
                count++;
                continue;
            }

            if (subfilters.length > 0 && basePath) {
                let rel = p.startsWith(basePath) ? p.substring(basePath.length) : p;
                let slashIdx = rel.indexOf('/');
                if (slashIdx !== -1) {
                    let topDir = rel.substring(0, slashIdx);
                    if (subfilters.includes(topDir)) {
                        count++;
                        continue;
                    }
                }
            }
        }
        return "Pool: " + count + " wallpapers";
    }

    property string matchingCountText: "Pool: (Calculating...)"

    function updateMatchingCount() {
        if (!root.visible) return;
        matchingCountText = getMatchingCountText();
    }

    Connections {
        target: GlobalStates
        function onWallpaperRandomSourceFiltersChanged() {
            if (root.visible) {
                root.updateMatchingCount();
            }
        }
    }

    readonly property var matugenSchemes: [
        { id: "scheme-content", label: "Content" },
        { id: "scheme-expressive", label: "Expressive" },
        { id: "scheme-fidelity", label: "Fidelity" },
        { id: "scheme-fruit-salad", label: "Fruit Salad" },
        { id: "scheme-monochrome", label: "Monochrome" },
        { id: "scheme-neutral", label: "Neutral" },
        { id: "scheme-rainbow", label: "Rainbow" },
        { id: "scheme-tonal-spot", label: "Tonal Spot" }
    ]

    property var presets: (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.colorPresets) ? GlobalStates.wallpaperManager.colorPresets : []

    NumberAnimation {
        id: scrollAnim
        target: scrollArea
        property: "contentY"
        duration: Config.animDuration > 0 ? 250 : 0
        easing.type: Easing.OutCubic
    }

    function smoothScrollTo(newY) {
        let maxScroll = Math.max(0, scrollArea.contentHeight - scrollArea.height);
        let clampedY = Math.max(0, Math.min(maxScroll, newY));
        if (Config.animDuration > 0) {
            scrollAnim.stop();
            scrollAnim.to = clampedY;
            scrollAnim.start();
        } else {
            scrollArea.contentY = clampedY;
        }
    }

    function scrollBy(deltaY) {
        scrollAnim.stop();
        let maxScroll = Math.max(0, scrollArea.contentHeight - scrollArea.height);
        scrollArea.contentY = Math.max(0, Math.min(maxScroll, scrollArea.contentY + deltaY));
    }

    function updateSetting(key, val) {
        if (!GlobalStates) return;
        if (key === "transitionStyle") {
            currentStyle = val;
            GlobalStates.setWallpaperTransitionStyle(val);
        } else if (key === "duration") {
            currentDuration = val;
            GlobalStates.setWallpaperTransitionDuration(val);
        }
    }

    Connections {
        target: GlobalStates
        function onWallpaperTransitionStyleChanged() {
            root.currentStyle = SkwdWall.migrateStyle(GlobalStates.wallpaperTransitionStyle);
        }
        function onWallpaperTransitionDurationChanged() {
            root.currentDuration = GlobalStates.wallpaperTransitionDuration;
        }
    }

    function getAvailableSections() {
        let secs = [0, 2, 3, 4];
        if (root.presets && root.presets.length > 0) {
            secs.push(5);
        }
        secs.push(6);
        return secs;
    }

    function scrollToSection(sec) {
        if (sec === 0) {
            smoothScrollTo(0);
            return;
        }
        if (sec === 6) {
            smoothScrollTo(0);
            return;
        }
        let targetItem = null;
        if (sec === 0) {
            targetItem = sectionStyle;
        } else if (sec === 2) {
            targetItem = sectionDuration;
        } else if (sec === 3) {
            targetItem = sectionAutomation;
        } else if (sec === 4) {
            targetItem = sectionSchemes;
        } else if (sec === 5) {
            targetItem = sectionPresets;
        }

        if (targetItem) {
            let itemTop = targetItem.y;
            let itemBottom = targetItem.y + targetItem.height;

            if (sec === 0) {
                itemTop = targetItem.y;
                itemBottom = targetItem.y + targetItem.height;
            } else if (sec === 2) {
                itemTop = targetItem.y;
                itemBottom = targetItem.y + 76;
            } else if (sec === 3) {
                if (focusedAutomationIndex <= 6) {
                    itemTop = targetItem.y;
                    itemBottom = targetItem.y + 110;
                } else {
                    itemTop = targetItem.y + 80;
                    itemBottom = targetItem.y + targetItem.height;
                }
            } else if (sec === 4) {
                let row = Math.floor(focusedSchemeIndex / 4);
                itemTop = row === 0 ? targetItem.y : (targetItem.y + 28 + (row * 46));
                itemBottom = itemTop + 40;
            } else if (sec === 5 && root.presets && root.presets.length > 0) {
                let row = Math.floor(focusedPresetIndex / 4);
                itemTop = row === 0 ? targetItem.y : (targetItem.y + 28 + (row * 44));
                itemBottom = itemTop + 38;
            }

            let viewH = scrollArea.height > 0 ? scrollArea.height : 500;
            let maxScroll = Math.max(0, scrollArea.contentHeight - viewH);

            if (itemTop < scrollArea.contentY + 10) {
                smoothScrollTo(Math.max(0, itemTop - 12));
            } else if (itemBottom > scrollArea.contentY + viewH - 10) {
                smoothScrollTo(Math.min(maxScroll, itemBottom - viewH + 16));
            }
        }
    }

    function syncSectionFocus(sec) {
        switch (sec) {
        case 0:
            for (let i = 0; i < root.visibleStyleOptions.length; i++) {
                if (root.visibleStyleOptions[i].id === root.currentStyle) {
                    focusedStyleIndex = i;
                    break;
                }
            }
            break;
        case 2:
            for (let i = 0; i < root.speedOptions.length; i++) {
                if (Math.abs(root.currentDuration - root.speedOptions[i].value) < 50) {
                    focusedSpeedIndex = i;
                    break;
                }
            }
            break;
        case 3:
            let maxAutomation = 7 + (root.availableSourceOptions ? root.availableSourceOptions.length : 0);
            if (focusedAutomationIndex < 0 || focusedAutomationIndex > maxAutomation) {
                focusedAutomationIndex = 0;
            }
            break;
        case 4:
            if (GlobalStates.wallpaperManager) {
                let curScheme = GlobalStates.wallpaperManager.currentMatugenScheme;
                for (let i = 0; i < root.matugenSchemes.length; i++) {
                    if (root.matugenSchemes[i].id === curScheme) {
                        focusedSchemeIndex = i;
                        break;
                    }
                }
            }
            break;
        case 5:
            if (root.presets && GlobalStates.wallpaperManager) {
                let curPreset = GlobalStates.wallpaperManager.activeColorPreset;
                for (let i = 0; i < root.presets.length; i++) {
                    if (String(root.presets[i]) === curPreset) {
                        focusedPresetIndex = i;
                        break;
                    }
                }
            }
            break;
        case 6:
            break;
        }
        scrollToSection(sec);
    }

    function nextSection() {
        let secs = getAvailableSections();
        let currentIdxInSecs = secs.indexOf(currentSection);
        if (currentIdxInSecs === -1 || currentIdxInSecs >= secs.length - 1) {
            currentSection = secs[0];
        } else {
            currentSection = secs[currentIdxInSecs + 1];
        }
        syncSectionFocus(currentSection);
    }

    function previousSection() {
        let secs = getAvailableSections();
        let currentIdxInSecs = secs.indexOf(currentSection);
        if (currentIdxInSecs <= 0) {
            currentSection = secs[secs.length - 1];
        } else {
            currentSection = secs[currentIdxInSecs - 1];
        }
        syncSectionFocus(currentSection);
    }

    function handleArrowKey(key) {
        switch (currentSection) {
        case 6: // Back to Wallpapers button (at top)
            if (key === Qt.Key_Down) {
                currentSection = 0;
                focusedStyleIndex = 0;
            }
            break;

        case 0: // Transition Style (looping carousel; the middle card is the choice)
            if (key === Qt.Key_Right) {
                styleCarousel.step(1);
            } else if (key === Qt.Key_Left) {
                styleCarousel.step(-1);
            } else if (key === Qt.Key_Down) {
                currentSection = 2; // Animation Duration
                syncSectionFocus(2);
            } else if (key === Qt.Key_Up) {
                currentSection = 6; // Back Button
            }
            break;

        case 2: // Animation Duration (4 items in 1 horizontal row: 0..3)
            if (key === Qt.Key_Right) {
                if (focusedSpeedIndex < speedOptions.length - 1) {
                    focusedSpeedIndex++;
                }
            } else if (key === Qt.Key_Left) {
                if (focusedSpeedIndex > 0) {
                    focusedSpeedIndex--;
                }
            } else if (key === Qt.Key_Down) {
                // Move down to Section 3 (Interval pills on right)
                currentSection = 3;
                focusedAutomationIndex = 1; // 1m interval pill
            } else if (key === Qt.Key_Up) {
                // Move up to the Transition Style carousel
                currentSection = 0;
            }
            break;

        case 3: // Automation & Rotation (0: Periodic Toggle, 1..6: Presets, 7: Custom Btn, 8: Solar Toggle, 9: All Walls, 10+: Sources)
            let maxSourceIdx = 9 + (root.availableSourceOptions ? root.availableSourceOptions.length : 0);
            if (key === Qt.Key_Right) {
                if (focusedAutomationIndex < 7) {
                    focusedAutomationIndex++;
                } else if (focusedAutomationIndex >= 9 && focusedAutomationIndex < maxSourceIdx) {
                    focusedAutomationIndex++;
                }
            } else if (key === Qt.Key_Left) {
                if (focusedAutomationIndex > 0 && focusedAutomationIndex <= 7) {
                    focusedAutomationIndex--;
                } else if (focusedAutomationIndex > 9) {
                    focusedAutomationIndex--;
                }
            } else if (key === Qt.Key_Down) {
                if (focusedAutomationIndex <= 7) {
                    focusedAutomationIndex = 8; // Move down to Time of Day
                } else if (focusedAutomationIndex === 8) {
                    focusedAutomationIndex = 9; // Move down to Sources (All Wallpapers)
                } else {
                    // Move from Sources down to Material You Schemes
                    currentSection = 4;
                    focusedSchemeIndex = Math.min(focusedAutomationIndex - 9, matugenSchemes.length - 1);
                }
            } else if (key === Qt.Key_Up) {
                if (focusedAutomationIndex >= 9) {
                    focusedAutomationIndex = 8; // Move up to Time of Day
                } else if (focusedAutomationIndex === 8) {
                    focusedAutomationIndex = 0; // Move up to Periodic row
                } else {
                    // Move up to Animation Duration
                    currentSection = 2;
                    focusedSpeedIndex = Math.min(Math.max(0, focusedAutomationIndex - 1), speedOptions.length - 1);
                }
            }
            break;

        case 4: // Material You Schemes (8 items, 4 cols x 2 rows: 0..3, 4..7)
            if (key === Qt.Key_Right) {
                if (focusedSchemeIndex % 4 < 3 && focusedSchemeIndex < matugenSchemes.length - 1) {
                    focusedSchemeIndex++;
                }
            } else if (key === Qt.Key_Left) {
                if (focusedSchemeIndex % 4 > 0) {
                    focusedSchemeIndex--;
                }
            } else if (key === Qt.Key_Down) {
                if (focusedSchemeIndex + 4 < matugenSchemes.length) {
                    focusedSchemeIndex += 4;
                } else {
                    // Reached bottom row of schemes
                    if (root.presets && root.presets.length > 0) {
                        currentSection = 5;
                        focusedPresetIndex = Math.min(focusedSchemeIndex - 4, root.presets.length - 1);
                    }
                }
            } else if (key === Qt.Key_Up) {
                if (focusedSchemeIndex >= 4) {
                    focusedSchemeIndex -= 4;
                } else {
                    // Move up to Section 3 (Random Sources row)
                    currentSection = 3;
                    focusedAutomationIndex = 9 + Math.min(focusedSchemeIndex, root.availableSourceOptions ? root.availableSourceOptions.length : 0);
                }
            }
            break;

        case 5: // Color Presets (4 cols x N rows)
            if (root.presets && root.presets.length > 0) {
                let len = root.presets.length;
                if (key === Qt.Key_Right) {
                    if (focusedPresetIndex < len - 1) focusedPresetIndex++;
                } else if (key === Qt.Key_Left) {
                    if (focusedPresetIndex > 0) focusedPresetIndex--;
                } else if (key === Qt.Key_Down) {
                    if (focusedPresetIndex + 4 < len) {
                        focusedPresetIndex += 4;
                    }
                } else if (key === Qt.Key_Up) {
                    if (focusedPresetIndex >= 4) {
                        focusedPresetIndex -= 4;
                    } else {
                        // Top row of presets, move up to Section 4 (Schemes bottom row)
                        currentSection = 4;
                        focusedSchemeIndex = Math.min(4 + (focusedPresetIndex % 4), matugenSchemes.length - 1);
                    }
                }
            }
            break;
        }
        scrollToSection(currentSection);
    }

    function handleActivate() {
        switch (currentSection) {
        case 0:
            if (focusedStyleIndex >= 0 && focusedStyleIndex < visibleStyleOptions.length) {
                root.updateSetting("transitionStyle", visibleStyleOptions[focusedStyleIndex].id);
            }
            break;
        case 2:
            if (focusedSpeedIndex >= 0 && focusedSpeedIndex < speedOptions.length) {
                root.updateSetting("duration", speedOptions[focusedSpeedIndex].value);
            }
            break;
        case 3:
            if (focusedAutomationIndex === 0) {
                if (GlobalStates) GlobalStates.setWallpaperPeriodicEnabled(!GlobalStates.wallpaperPeriodicEnabled);
            } else if (focusedAutomationIndex >= 1 && focusedAutomationIndex <= 6) {
                if (GlobalStates) {
                    if (!GlobalStates.wallpaperPeriodicEnabled) {
                        GlobalStates.setWallpaperPeriodicEnabled(true);
                    }
                    GlobalStates.setWallpaperPeriodicSeconds(intervalOptions[focusedAutomationIndex - 1].sec);
                }
            } else if (focusedAutomationIndex === 7) {
                root.showCustomInput = !root.showCustomInput;
                if (root.showCustomInput) root.initCustomInput();
            } else if (focusedAutomationIndex === 8) {
                if (GlobalStates) GlobalStates.setWallpaperSolarSyncEnabled(!GlobalStates.wallpaperSolarSyncEnabled);
            } else if (focusedAutomationIndex === 9) {
                // "All Wallpapers"
                if (GlobalStates) {
                    GlobalStates.setWallpaperRandomSourceFilters([]);
                }
            } else if (focusedAutomationIndex >= 10) {
                let optIdx = focusedAutomationIndex - 10;
                if (root.availableSourceOptions && optIdx < root.availableSourceOptions.length) {
                    let key = root.availableSourceOptions[optIdx].key;
                    if (GlobalStates) {
                        GlobalStates.toggleWallpaperRandomSourceFilter(key);
                    }
                }
            }
            break;
        case 4:
            if (focusedSchemeIndex >= 0 && focusedSchemeIndex < matugenSchemes.length) {
                if (GlobalStates.wallpaperManager) {
                    GlobalStates.wallpaperManager.setMatugenScheme(matugenSchemes[focusedSchemeIndex].id);
                }
            }
            break;
        case 5:
            if (root.presets && focusedPresetIndex >= 0 && focusedPresetIndex < root.presets.length) {
                if (GlobalStates.wallpaperManager) {
                    GlobalStates.wallpaperManager.setColorPreset(String(root.presets[focusedPresetIndex]));
                }
            }
            break;
        case 6:
            root.goBack();
            break;
        }
    }

    function goBack() {
        root.focus = false;
        root.backClicked();
    }

    onVisibleChanged: {
        if (visible) {
            root.forceActiveFocus();
            currentSection = 0;
            syncSectionFocus(0);
            updateMatchingCount();
            if (GlobalStates && GlobalStates.wallpaperManager && (!GlobalStates.wallpaperManager.subfolderFilters || GlobalStates.wallpaperManager.subfolderFilters.length === 0)) {
                GlobalStates.wallpaperManager.scanSubfolders();
            }
        }
    }

    onActiveFocusChanged: {
        if (activeFocus && visible) {
            syncSectionFocus(currentSection);
        }
    }

    Component.onCompleted: {
        initCustomInput();
        syncSectionFocus(0);
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Tab) {
            if (event.modifiers & Qt.ShiftModifier) {
                root.previousSection();
            } else {
                root.nextSection();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Backtab) {
            root.previousSection();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.goBack();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            root.handleArrowKey(Qt.Key_Right);
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            root.handleArrowKey(Qt.Key_Left);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            root.handleArrowKey(Qt.Key_Down);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            root.handleArrowKey(Qt.Key_Up);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.handleActivate();
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            root.scrollBy(scrollArea.height * 0.75);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            root.scrollBy(-scrollArea.height * 0.75);
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Top Navigation & Header Bar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            spacing: 12

            // Back Button
            StyledRect {
                id: backBtnRect
                Layout.preferredHeight: 44
                Layout.preferredWidth: 160
                readonly property bool isFocused: root.currentSection === 6
                variant: isFocused || backMa.containsMouse ? "primary" : "pane"
                radius: Styling.radius(4)

                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goBack()

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: Icons.caretLeft
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: backBtnRect.isFocused || backMa.containsMouse ? Styling.srItem("primary") : Colors.overSurface
                        }

                        Text {
                            text: "Back to Wallpapers"
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            font.weight: backBtnRect.isFocused || backMa.containsMouse ? Font.Bold : Font.Medium
                            color: backBtnRect.isFocused || backMa.containsMouse ? Styling.srItem("primary") : Colors.overSurface
                        }
                    }
                }
            }

            // Title
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "Advanced Wallpaper Settings"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(1)
                    font.weight: Font.Bold
                    color: Colors.overBackground
                }

                Text {
                    text: "Arrow keys navigate settings • Space/Enter to toggle sources • Tab to jump sections • Esc to return"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    color: Colors.outline
                }
            }
        }

        // Scrollable Settings Content
        Flickable {
            id: scrollArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: settingsColumn.implicitHeight + 12
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                id: vScrollBar
                policy: scrollArea.contentHeight > scrollArea.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            WheelHandler {
                id: wheelHandler
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    let delta = (event.pixelDelta && event.pixelDelta.y !== 0) ? event.pixelDelta.y : event.angleDelta.y;
                    if (delta !== 0) {
                        root.scrollBy(-delta);
                    }
                }
            }

            ColumnLayout {
                id: settingsColumn
                width: scrollArea.width - (vScrollBar.visible ? 16 : 4)
                spacing: 16

                // skwd-wall itself: install, update, or what is missing (hidden
                // when a system install is in use).
                SkwdInstallCard {
                    Layout.fillWidth: true
                }

                // Section 0: Transition Style — a carousel of skwd-wall's transitions
                ColumnLayout {
                    id: sectionStyle
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "TRANSITION STYLE"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Bold
                            color: root.currentSection === 0 ? Styling.srItem("overprimary") : Colors.overBackground
                        }

                        Item { Layout.fillWidth: true }

                        // Family filter: narrows the carousel (Random stays first).
                        Repeater {
                            model: SkwdWall.families

                            delegate: StyledRect {
                                id: familyChip
                                required property var modelData
                                readonly property bool isSelected: root.styleFamilyFilter === modelData.key
                                Layout.preferredHeight: 24
                                Layout.preferredWidth: familyLabel.implicitWidth + 18
                                variant: isSelected ? "primary" : (maFamily.containsMouse ? "focus" : "common")
                                radius: Styling.radius(2)

                                Text {
                                    id: familyLabel
                                    anchors.centerIn: parent
                                    text: familyChip.modelData.title
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-3)
                                    font.weight: familyChip.isSelected ? Font.Bold : Font.Medium
                                    color: familyChip.isSelected ? Styling.srItem("primary") : Colors.overSurface
                                }

                                MouseArea {
                                    id: maFamily
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.styleFamilyFilter = familyChip.modelData.key;
                                        root.currentSection = 0;
                                        root.syncSectionFocus(0);
                                        if (root.focusedStyleIndex >= root.visibleStyleOptions.length)
                                            root.focusedStyleIndex = 0;
                                    }
                                }
                            }
                        }
                    }

                    // A looping carousel: the chosen transition is the wide card in
                    // the middle, its neighbours are folded into narrow bars on
                    // either side. Every card is one delegate for its whole trip, so
                    // folding and unfolding is one continuous morph.
                    Item {
                        id: styleCarousel
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        clip: true

                        readonly property var items: root.visibleStyleOptions
                        readonly property int count: items.length
                        readonly property real cardWidth: Math.min(320, Math.max(200, width - 2 * sideBars * (barWidth + gap) - 2 * gap))
                        readonly property real barWidth: 30
                        readonly property real gap: 6
                        // Bars per side: up to 4, fewer when the family is small so
                        // nothing shows twice.
                        readonly property int sideBars: Math.max(0, Math.min(4, Math.floor((count - 1) / 2)))

                        // `target` is where the carousel is going (whole numbers),
                        // `pos` follows it with the animation. Both run on past the
                        // ends; the list is read modulo its length.
                        property real target: 0
                        property real pos: 0
                        property bool jump: false   // move without sliding (opening, family change)
                        Behavior on pos {
                            enabled: !styleCarousel.jump
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }

                        function wrap(i) {
                            return count > 0 ? ((Math.round(i) % count) + count) % count : 0;
                        }
                        // Signed distance of item `i` from the middle, the short way round.
                        function offsetOf(i) {
                            if (count === 0)
                                return 0;
                            let o = (i - pos) % count;
                            if (o > count / 2)
                                o -= count;
                            if (o < -count / 2)
                                o += count;
                            return o;
                        }
                        function step(n) {
                            target += n;
                        }
                        // Bring item `index` to the middle the short way round.
                        function goTo(index, animate) {
                            if (count === 0)
                                return;
                            let d = (index - wrap(target)) % count;
                            if (d > count / 2)
                                d -= count;
                            if (d < -count / 2)
                                d += count;
                            jump = !animate;
                            target = Math.round(target) + d;
                            jump = false;
                        }

                        onTargetChanged: {
                            pos = target;
                            root.focusedStyleIndex = wrap(target);
                            chooseTimer.restart();
                        }
                        // The card that settles in the middle is the chosen one.
                        Timer {
                            id: chooseTimer
                            interval: 140
                            onTriggered: {
                                const item = styleCarousel.items[styleCarousel.wrap(styleCarousel.target)];
                                if (item && item.id !== root.currentStyle)
                                    root.updateSetting("transitionStyle", item.id);
                            }
                        }
                        // Opening, a family change or a change from elsewhere: centre
                        // the chosen transition (or, if this family lacks it, the
                        // family's first).
                        function recentre(animate) {
                            let idx = -1;
                            for (let i = 0; i < count; i++)
                                if (items[i].id === root.currentStyle)
                                    idx = i;
                            if (idx < 0)
                                idx = count > 1 ? 1 : 0;
                            goTo(idx, animate);
                        }
                        onItemsChanged: Qt.callLater(() => styleCarousel.recentre(false))
                        Connections {
                            target: root
                            function onCurrentStyleChanged() {
                                const cur = styleCarousel.items[styleCarousel.wrap(styleCarousel.target)];
                                if (!cur || cur.id !== root.currentStyle)
                                    styleCarousel.recentre(true);
                            }
                        }
                        Component.onCompleted: recentre(false)

                        // Wheel: one card per notch; touchpads scroll by distance.
                        property real wheelRest: 0
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => {
                                // Wheels report notches (120 each): one card per notch. Touchpads report only pixels: a card per 20 px.
                                const ang = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y;
                                const pix = event.pixelDelta ? (event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.pixelDelta.y) : 0;
                                const d = ang !== 0 ? ang / 120 : pix / 20;
                                styleCarousel.wheelRest -= d;
                                const steps = styleCarousel.wheelRest > 0 ? Math.floor(styleCarousel.wheelRest) : Math.ceil(styleCarousel.wheelRest);
                                if (steps !== 0) {
                                    styleCarousel.wheelRest -= steps;
                                    root.currentSection = 0;
                                    styleCarousel.step(steps);
                                }
                            }
                        }

                        Repeater {
                            model: styleCarousel.items

                            delegate: StyledRect {
                                id: styleCard
                                required property var modelData
                                required property int index

                                readonly property real o: styleCarousel.offsetOf(index)
                                readonly property real ao: Math.abs(o)
                                // 1 in the middle, 0 once folded into a bar.
                                readonly property real expand: Math.max(0, 1 - ao)
                                readonly property bool isCentre: ao < 0.5
                                readonly property bool isSelected: modelData.id === root.currentStyle
                                readonly property bool isFocused: isCentre && root.currentSection === 0
                                readonly property real limit: styleCarousel.sideBars + 0.6

                                visible: ao < limit
                                width: styleCarousel.barWidth + (styleCarousel.cardWidth - styleCarousel.barWidth) * expand
                                height: styleCarousel.height - 8
                                y: 4
                                x: {
                                    const cw = styleCarousel.cardWidth, bw = styleCarousel.barWidth, g = styleCarousel.gap;
                                    const first = cw / 2 + g + bw / 2;
                                    const c = ao <= 1 ? o * first : Math.sign(o) * (first + (ao - 1) * (bw + g));
                                    return styleCarousel.width / 2 + c - width / 2;
                                }
                                z: 100 - ao
                                opacity: ao <= 1 ? 1 : Math.max(0, Math.min(1 - (ao - 1) * 0.16, (limit - ao) / 0.6))

                                variant: isCentre ? "primary" : (maCard.containsMouse ? "focus" : "pane")
                                radius: Styling.radius(4)

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: Styling.srItem("primary")
                                    border.width: 2
                                    radius: Styling.radius(4)
                                    visible: styleCard.isFocused
                                }

                                // Folded: the name, written up the bar.
                                Text {
                                    anchors.centerIn: parent
                                    width: styleCard.height - 16
                                    rotation: -90
                                    opacity: Math.max(0, 1 - styleCard.expand * 2)
                                    visible: opacity > 0
                                    text: styleCard.modelData.title
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-3)
                                    font.weight: Font.Medium
                                    color: maCard.containsMouse ? Styling.srItem("overprimary") : Colors.overSurface
                                }

                                // Unfolded: the animation and the name.
                                Item {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    opacity: Math.max(0, styleCard.expand * 2 - 1)
                                    visible: opacity > 0

                                    TransitionIcon {
                                        id: styleIcon
                                        anchors.top: parent.top
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 128
                                        height: 80
                                        transition: styleCard.modelData.id
                                        animating: styleCard.isCentre && styleCarousel.visible && root.visible
                                        // Frame and old image dimmer, the new image full strength.
                                        lineColor: Qt.alpha(Styling.srItem("primary"), 0.55)
                                        accentColor: Styling.srItem("primary")
                                    }

                                    ColumnLayout {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                            text: styleCard.modelData.title
                                            elide: Text.ElideRight
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.weight: Font.Bold
                                            color: Styling.srItem("primary")
                                        }

                                        MarqueeText {
                                            Layout.fillWidth: true
                                            text: styleCard.modelData.desc
                                            hovered: styleCard.isCentre
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-3)
                                            color: Styling.srItem("primary")
                                            textOpacity: 0.8
                                        }
                                    }
                                }

                                MouseArea {
                                    id: maCard
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: styleCard.isCentre ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentSection = 0;
                                        styleCarousel.step(Math.round(styleCard.o));
                                    }
                                }
                            }
                        }
                    }

                }

                // Section 2: Animation Duration
                ColumnLayout {
                    id: sectionDuration
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "ANIMATION DURATION"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Bold
                            color: root.currentSection === 2 ? Styling.srItem("overprimary") : Colors.overBackground
                        }

                        Item { Layout.fillWidth: true }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        spacing: 6
                        opacity: root.currentStyle === "instant" ? 0.45 : 1.0

                        Repeater {
                            model: root.speedOptions

                            delegate: StyledRect {
                                id: speedCard
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                readonly property bool isSelected: Math.abs(root.currentDuration - modelData.value) < 50
                                readonly property bool isFocused: root.currentSection === 2 && root.focusedSpeedIndex === index

                                variant: isSelected ? "primary" : ((maSpeed.containsMouse || isFocused) ? "focus" : "pane")
                                radius: Styling.radius(4)

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: speedCard.isSelected ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                    border.width: 2
                                    radius: Styling.radius(4)
                                    visible: speedCard.isFocused
                                }

                                MouseArea {
                                    id: maSpeed
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentSection = 2;
                                        root.focusedSpeedIndex = index;
                                        root.updateSetting("duration", modelData.value);
                                    }
                                    onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: modelData.label
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.weight: speedCard.isSelected ? Font.Bold : Font.Medium
                                            color: speedCard.isSelected ? Styling.srItem("primary") : Colors.overSurface
                                        }

                                        Text {
                                            text: "(" + modelData.sub + ")"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-3)
                                            color: speedCard.isSelected ? Styling.srItem("primary") : Colors.outline
                                            opacity: speedCard.isSelected ? 0.85 : 1.0
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Hint under speed options
                    Text {
                        text: root.currentStyle === "instant" ? "Instant swaps have no duration." : "How long skwd-wall takes to play the transition."
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-3)
                        color: Colors.outline
                        Layout.topMargin: 4
                    }
                }

                // Section 3: AUTOMATION & ROTATION (New feature requested by community)
                ColumnLayout {
                    id: sectionAutomation
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "AUTOMATION & ROTATION"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Bold
                            color: root.currentSection === 3 ? Styling.srItem("overprimary") : Colors.overBackground
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "CLI / Keybind: ambxst run wallpaper-random"
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.fontSize(-4)
                            color: Styling.srItem("overprimary")
                        }
                    }

                    // Card 1: Automatic Wallpaper Rotation
                    StyledRect {
                        id: periodicCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: periodicColumn.implicitHeight + 20
                        readonly property bool isPeriodic: GlobalStates && GlobalStates.wallpaperPeriodicEnabled
                        readonly property int periodicSec: root.currentPeriodicSeconds
                        variant: "pane"
                        radius: Styling.radius(4)

                        ColumnLayout {
                            id: periodicColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            // Row 1: Header + Master Toggle
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Item {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.timer
                                        font.family: Icons.font
                                        font.pixelSize: 22
                                        color: periodicCard.isPeriodic ? Styling.srItem("overprimary") : Colors.overSurface
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: "Automatic Rotation"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(0)
                                        font.weight: Font.Bold
                                        color: Colors.overBackground
                                    }

                                    Text {
                                        text: periodicCard.isPeriodic ? ("Rotates every " + root.formatDuration(periodicCard.periodicSec)) : "Automatic rotation disabled"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-3)
                                        color: periodicCard.isPeriodic ? Styling.srItem("overprimary") : Colors.outline
                                        elide: Text.ElideRight
                                    }
                                }

                                AmbxstSwitch {
                                    id: periodicSwitch
                                    checked: periodicCard.isPeriodic
                                    onToggled: {
                                        root.currentSection = 3;
                                        root.focusedAutomationIndex = 0;
                                        if (GlobalStates) GlobalStates.setWallpaperPeriodicEnabled(checked);
                                    }
                                }
                            }

                            // Divider
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Colors.outline
                                opacity: 0.15
                            }

                            // Presets Row + Dedicated Custom Timer Button
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                opacity: periodicCard.isPeriodic ? 1.0 : 0.45

                                Repeater {
                                    model: root.intervalOptions

                                    delegate: StyledRect {
                                        id: intCard
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36

                                        readonly property bool isSelected: !root.showCustomInput && periodicCard.periodicSec === modelData.sec
                                        readonly property bool isFocused: root.currentSection === 3 && root.focusedAutomationIndex === (index + 1)
                                        variant: isSelected ? "primary" : ((maInt.containsMouse || isFocused) ? "focus" : "pane")
                                        radius: Styling.radius(3)

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            border.color: intCard.isSelected ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                            border.width: 2
                                            radius: Styling.radius(3)
                                            visible: intCard.isFocused
                                        }

                                        MouseArea {
                                            id: maInt
                                            anchors.fill: parent
                                            hoverEnabled: periodicCard.isPeriodic
                                            cursorShape: periodicCard.isPeriodic ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                root.showCustomInput = false;
                                                root.currentSection = 3;
                                                root.focusedAutomationIndex = index + 1;
                                                if (!periodicCard.isPeriodic && GlobalStates) {
                                                    GlobalStates.setWallpaperPeriodicEnabled(true);
                                                }
                                                if (GlobalStates) GlobalStates.setWallpaperPeriodicSeconds(modelData.sec);
                                            }
                                            onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.text
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                font.weight: intCard.isSelected ? Font.Bold : Font.Medium
                                                color: intCard.isSelected ? Styling.srItem("primary") : Colors.overSurface
                                            }
                                        }
                                    }
                                }

                                // Distinct Dedicated Button: Custom Timer
                                StyledRect {
                                    id: customTimerButton
                                    Layout.preferredWidth: customBtnLayout.implicitWidth + 24
                                    Layout.preferredHeight: 36
                                    readonly property bool isCustomActive: !root.isStandardPreset(periodicCard.periodicSec)
                                    readonly property bool isHighlighted: root.showCustomInput || isCustomActive
                                    readonly property bool isFocused: root.currentSection === 3 && root.focusedAutomationIndex === 7
                                    variant: isHighlighted ? "primary" : ((maCustomBtn.containsMouse || isFocused) ? "focus" : "pane")
                                    radius: Styling.radius(3)

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: customTimerButton.isHighlighted ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                        border.width: 2
                                        radius: Styling.radius(3)
                                        visible: customTimerButton.isFocused
                                    }

                                    MouseArea {
                                        id: maCustomBtn
                                        anchors.fill: parent
                                        hoverEnabled: periodicCard.isPeriodic
                                        cursorShape: periodicCard.isPeriodic ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            root.currentSection = 3;
                                            root.focusedAutomationIndex = 7;
                                            root.showCustomInput = !root.showCustomInput;
                                            if (root.showCustomInput) {
                                                root.initCustomInput();
                                            }
                                        }
                                        onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                        RowLayout {
                                            id: customBtnLayout
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: Icons.timer || "⏱"
                                                font.family: Icons.font
                                                font.pixelSize: 13
                                                color: customTimerButton.isHighlighted ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                            }

                                            Text {
                                                text: customTimerButton.isCustomActive ? ("Custom (" + root.formatDuration(periodicCard.periodicSec) + ")") : "Custom Timer..."
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                font.weight: customTimerButton.isHighlighted ? Font.Bold : Font.Medium
                                                color: customTimerButton.isHighlighted ? Styling.srItem("primary") : Colors.overSurface
                                            }

                                            Text {
                                                text: root.showCustomInput ? "▲" : "▼"
                                                font.family: Config.theme.font
                                                font.pixelSize: 10
                                                color: customTimerButton.isHighlighted ? Styling.srItem("primary") : Colors.outline
                                            }
                                        }
                                    }
                                }
                            }

                            // Dedicated Custom Timer Configuration Card
                            StyledRect {
                                id: customBuilderCard
                                Layout.fillWidth: true
                                Layout.preferredHeight: customBuilderCol.implicitHeight + 20
                                visible: root.showCustomInput || !root.isStandardPreset(periodicCard.periodicSec)
                                variant: "pane"
                                radius: Styling.radius(4)

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: Styling.srItem("overprimary")
                                    border.width: 1
                                    opacity: 0.25
                                    radius: Styling.radius(4)
                                }

                                ColumnLayout {
                                    id: customBuilderCol
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    // Header
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: Icons.timer || "⏱"
                                            font.family: Icons.font
                                            font.pixelSize: 14
                                            color: Styling.srItem("overprimary")
                                        }

                                        Text {
                                            text: "CUSTOM ROTATION INTERVAL"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-2)
                                            font.weight: Font.Bold
                                            color: Styling.srItem("overprimary")
                                        }

                                        Item { Layout.fillWidth: true }

                                        StyledRect {
                                            Layout.preferredHeight: 22
                                            Layout.preferredWidth: activeDurText.implicitWidth + 14
                                            variant: "focus"
                                            radius: Styling.radius(1)

                                            Text {
                                                id: activeDurText
                                                anchors.centerIn: parent
                                                text: "Active: Every " + root.formatDuration(periodicCard.periodicSec)
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-3)
                                                font.weight: Font.Bold
                                                color: Styling.srItem("overprimary")
                                            }
                                        }
                                    }

                                    // Stepper Containers Row + Apply Button
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        // 1. Hours Stepper Card
                                        StyledRect {
                                            Layout.preferredWidth: 140
                                            Layout.preferredHeight: 64
                                            variant: "common"
                                            radius: Styling.radius(3)

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 3

                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: "HOURS"
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-4)
                                                    font.weight: Font.Bold
                                                    color: Colors.outline
                                                }

                                                RowLayout {
                                                    spacing: 6

                                                    // [-] Button
                                                    StyledRect {
                                                        Layout.preferredWidth: 32
                                                        Layout.preferredHeight: 32
                                                        variant: maHMinus.containsMouse ? "primary" : "focus"
                                                        radius: Styling.radius(2)

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: "transparent"
                                                            border.color: Styling.srItem("overprimary")
                                                            border.width: 1
                                                            opacity: maHMinus.containsMouse ? 1.0 : 0.35
                                                            radius: Styling.radius(2)
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: Icons.minus
                                                            font.family: Icons.font
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                            color: maHMinus.containsMouse ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                                        }

                                                        MouseArea {
                                                            id: maHMinus
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: { root.customHours = Math.max(0, root.customHours - 1); }
                                                        }
                                                    }

                                                    // Number Input Box
                                                    TextField {
                                                        id: inputHours
                                                        Layout.preferredWidth: 46
                                                        Layout.preferredHeight: 32
                                                        text: String(root.customHours)
                                                        horizontalAlignment: TextInput.AlignHCenter
                                                        font.family: Config.theme.monoFont
                                                        font.pixelSize: Styling.fontSize(1)
                                                        font.weight: Font.Bold
                                                        color: Colors.overBackground
                                                        validator: IntValidator { bottom: 0; top: 23 }
                                                        selectByMouse: true
                                                        Binding on text {
                                                            value: String(root.customHours)
                                                            when: !inputHours.activeFocus
                                                        }
                                                        background: StyledRect {
                                                            variant: inputHours.activeFocus ? "focus" : "pane"
                                                            radius: Styling.radius(2)
                                                            Rectangle {
                                                                anchors.fill: parent
                                                                color: "transparent"
                                                                border.color: inputHours.activeFocus ? Styling.srItem("overprimary") : Colors.outline
                                                                border.width: 1
                                                                opacity: inputHours.activeFocus ? 1.0 : 0.25
                                                                radius: Styling.radius(2)
                                                            }
                                                        }
                                                        onTextChanged: {
                                                            let val = parseInt(text);
                                                            if (!isNaN(val) && val >= 0 && val <= 23) root.customHours = val;
                                                        }
                                                    }

                                                    // [+] Button
                                                    StyledRect {
                                                        Layout.preferredWidth: 32
                                                        Layout.preferredHeight: 32
                                                        variant: maHPlus.containsMouse ? "primary" : "focus"
                                                        radius: Styling.radius(2)

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: "transparent"
                                                            border.color: Styling.srItem("overprimary")
                                                            border.width: 1
                                                            opacity: maHPlus.containsMouse ? 1.0 : 0.35
                                                            radius: Styling.radius(2)
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: Icons.plus
                                                            font.family: Icons.font
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                            color: maHPlus.containsMouse ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                                        }

                                                        MouseArea {
                                                            id: maHPlus
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: { root.customHours = Math.min(23, root.customHours + 1); }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // 2. Minutes Stepper Card
                                        StyledRect {
                                            Layout.preferredWidth: 140
                                            Layout.preferredHeight: 64
                                            variant: "common"
                                            radius: Styling.radius(3)

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 3

                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: "MINUTES"
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-4)
                                                    font.weight: Font.Bold
                                                    color: Colors.outline
                                                }

                                                RowLayout {
                                                    spacing: 6

                                                    // [-] Button
                                                    StyledRect {
                                                        Layout.preferredWidth: 32
                                                        Layout.preferredHeight: 32
                                                        variant: maMMinus.containsMouse ? "primary" : "focus"
                                                        radius: Styling.radius(2)

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: "transparent"
                                                            border.color: Styling.srItem("overprimary")
                                                            border.width: 1
                                                            opacity: maMMinus.containsMouse ? 1.0 : 0.35
                                                            radius: Styling.radius(2)
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: Icons.minus
                                                            font.family: Icons.font
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                            color: maMMinus.containsMouse ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                                        }

                                                        MouseArea {
                                                            id: maMMinus
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: { root.customMinutes = Math.max(0, root.customMinutes - 1); }
                                                        }
                                                    }

                                                    // Number Input Box
                                                    TextField {
                                                        id: inputMinutes
                                                        Layout.preferredWidth: 46
                                                        Layout.preferredHeight: 32
                                                        text: String(root.customMinutes)
                                                        horizontalAlignment: TextInput.AlignHCenter
                                                        font.family: Config.theme.monoFont
                                                        font.pixelSize: Styling.fontSize(1)
                                                        font.weight: Font.Bold
                                                        color: Colors.overBackground
                                                        validator: IntValidator { bottom: 0; top: 59 }
                                                        selectByMouse: true
                                                        Binding on text {
                                                            value: String(root.customMinutes)
                                                            when: !inputMinutes.activeFocus
                                                        }
                                                        background: StyledRect {
                                                            variant: inputMinutes.activeFocus ? "focus" : "pane"
                                                            radius: Styling.radius(2)
                                                            Rectangle {
                                                                anchors.fill: parent
                                                                color: "transparent"
                                                                border.color: inputMinutes.activeFocus ? Styling.srItem("overprimary") : Colors.outline
                                                                border.width: 1
                                                                opacity: inputMinutes.activeFocus ? 1.0 : 0.25
                                                                radius: Styling.radius(2)
                                                            }
                                                        }
                                                        onTextChanged: {
                                                            let val = parseInt(text);
                                                            if (!isNaN(val) && val >= 0 && val <= 59) root.customMinutes = val;
                                                        }
                                                    }

                                                    // [+] Button
                                                    StyledRect {
                                                        Layout.preferredWidth: 32
                                                        Layout.preferredHeight: 32
                                                        variant: maMPlus.containsMouse ? "primary" : "focus"
                                                        radius: Styling.radius(2)

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: "transparent"
                                                            border.color: Styling.srItem("overprimary")
                                                            border.width: 1
                                                            opacity: maMPlus.containsMouse ? 1.0 : 0.35
                                                            radius: Styling.radius(2)
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: Icons.plus
                                                            font.family: Icons.font
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                            color: maMPlus.containsMouse ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                                        }

                                                        MouseArea {
                                                            id: maMPlus
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: { root.customMinutes = Math.min(59, root.customMinutes + 1); }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // 3. Seconds Stepper Card
                                        StyledRect {
                                            Layout.preferredWidth: 140
                                            Layout.preferredHeight: 64
                                            variant: "common"
                                            radius: Styling.radius(3)

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 3

                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: "SECONDS"
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-4)
                                                    font.weight: Font.Bold
                                                    color: Colors.outline
                                                }

                                                RowLayout {
                                                    spacing: 6

                                                    // [-] Button
                                                    StyledRect {
                                                        Layout.preferredWidth: 32
                                                        Layout.preferredHeight: 32
                                                        variant: maSMinus.containsMouse ? "primary" : "focus"
                                                        radius: Styling.radius(2)

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: "transparent"
                                                            border.color: Styling.srItem("overprimary")
                                                            border.width: 1
                                                            opacity: maSMinus.containsMouse ? 1.0 : 0.35
                                                            radius: Styling.radius(2)
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: Icons.minus
                                                            font.family: Icons.font
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                            color: maSMinus.containsMouse ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                                        }

                                                        MouseArea {
                                                            id: maSMinus
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: { root.customSeconds = Math.max(0, root.customSeconds - 1); }
                                                        }
                                                    }

                                                    // Number Input Box
                                                    TextField {
                                                        id: inputSeconds
                                                        Layout.preferredWidth: 46
                                                        Layout.preferredHeight: 32
                                                        text: String(root.customSeconds)
                                                        horizontalAlignment: TextInput.AlignHCenter
                                                        font.family: Config.theme.monoFont
                                                        font.pixelSize: Styling.fontSize(1)
                                                        font.weight: Font.Bold
                                                        color: Colors.overBackground
                                                        validator: IntValidator { bottom: 0; top: 59 }
                                                        selectByMouse: true
                                                        Binding on text {
                                                            value: String(root.customSeconds)
                                                            when: !inputSeconds.activeFocus
                                                        }
                                                        background: StyledRect {
                                                            variant: inputSeconds.activeFocus ? "focus" : "pane"
                                                            radius: Styling.radius(2)
                                                            Rectangle {
                                                                anchors.fill: parent
                                                                color: "transparent"
                                                                border.color: inputSeconds.activeFocus ? Styling.srItem("overprimary") : Colors.outline
                                                                border.width: 1
                                                                opacity: inputSeconds.activeFocus ? 1.0 : 0.25
                                                                radius: Styling.radius(2)
                                                            }
                                                        }
                                                        onTextChanged: {
                                                            let val = parseInt(text);
                                                            if (!isNaN(val) && val >= 0 && val <= 59) root.customSeconds = val;
                                                        }
                                                    }

                                                    // [+] Button
                                                    StyledRect {
                                                        Layout.preferredWidth: 32
                                                        Layout.preferredHeight: 32
                                                        variant: maSPlus.containsMouse ? "primary" : "focus"
                                                        radius: Styling.radius(2)

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: "transparent"
                                                            border.color: Styling.srItem("overprimary")
                                                            border.width: 1
                                                            opacity: maSPlus.containsMouse ? 1.0 : 0.35
                                                            radius: Styling.radius(2)
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: Icons.plus
                                                            font.family: Icons.font
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                            color: maSPlus.containsMouse ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                                        }

                                                        MouseArea {
                                                            id: maSPlus
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: { root.customSeconds = Math.min(59, root.customSeconds + 1); }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        // Apply Custom Timer Button
                                        StyledRect {
                                            id: applyBtn
                                            Layout.preferredHeight: 48
                                            Layout.preferredWidth: applyBtnLayout.implicitWidth + 28
                                            variant: maApply.containsMouse ? "focus" : "primary"
                                            radius: Styling.radius(3)

                                            MouseArea {
                                                id: maApply
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.applyCustomTimer()

                                                RowLayout {
                                                    id: applyBtnLayout
                                                    anchors.centerIn: parent
                                                    spacing: 8

                                                    Text {
                                                        text: Icons.accept
                                                        font.family: Icons.font
                                                        font.pixelSize: 16
                                                        color: applyBtn.variant === "primary" ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                                    }

                                                    ColumnLayout {
                                                        spacing: 0
                                                        Text {
                                                            text: "Set Timer"
                                                            font.family: Config.theme.font
                                                            font.pixelSize: Styling.fontSize(0)
                                                            font.weight: Font.Bold
                                                            color: applyBtn.variant === "primary" ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                                        }
                                                        Text {
                                                            text: root.formatDuration(Math.max(5, (root.customHours * 3600) + (root.customMinutes * 60) + root.customSeconds))
                                                            font.family: Config.theme.font
                                                            font.pixelSize: Styling.fontSize(-3)
                                                            color: applyBtn.variant === "primary" ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                                            opacity: 0.85
                                                        }
                                                    }
                                                }
                                            }
                                    }
                                }
                                }
                            }
                        }
                    }

                    // Card 2: Match Time of the Day (SEPARATE TOGGLE BUTTON / FEATURE)
                    StyledRect {
                        id: solarCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: solarColumn.implicitHeight + 20
                        variant: "pane"
                        radius: Styling.radius(4)

                        ColumnLayout {
                            id: solarColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            // Row 1: Header + Independent Master Toggle
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Item {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.getSolarPhaseInfo(root.currentSolarPeriod).icon
                                        font.family: Icons.font
                                        font.pixelSize: 22
                                        color: root.isSolarSync ? Styling.srItem("overprimary") : Colors.overSurface
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    RowLayout {
                                        spacing: 8
                                        Text {
                                            text: "Match Time of Day"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            font.weight: Font.Bold
                                            color: Colors.overBackground
                                        }

                                        StyledRect {
                                            Layout.preferredHeight: 18
                                            Layout.preferredWidth: curPhaseBadgeText.implicitWidth + 10
                                            variant: root.isSolarSync ? "primary" : "focus"
                                            radius: Styling.radius(1)

                                            Text {
                                                id: curPhaseBadgeText
                                                anchors.centerIn: parent
                                                text: (root.currentSolarPeriod.toUpperCase()) + " NOW"
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-4)
                                                font.weight: Font.Bold
                                                color: root.isSolarSync ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                            }
                                        }
                                    }

                                    Text {
                                        text: root.isSolarSync ? "Active: Selecting wallpapers matching current " + root.currentSolarPeriod + " lighting" : "Disabled: Wallpaper rotation selects from all color palettes"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-3)
                                        color: root.isSolarSync ? Styling.srItem("overprimary") : Colors.outline
                                        elide: Text.ElideRight
                                    }
                                }

                                AmbxstSwitch {
                                    id: solarSwitch
                                    checked: root.isSolarSync
                                    onToggled: {
                                        if (GlobalStates) GlobalStates.setWallpaperSolarSyncEnabled(checked);
                                    }
                                }
                            }

                            // Divider
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Colors.outline
                                opacity: 0.15
                            }

                            // 4 Solar Phase Cards Strip
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4
                                rowSpacing: 6
                                columnSpacing: 6
                                opacity: root.isSolarSync ? 1.0 : 0.55

                                Repeater {
                                    model: [
                                        { id: "morning", title: "Morning", time: "06:00 – 11:00", icon: Icons.sunDim, desc: "Fresh daylight & bright pastels" },
                                        { id: "afternoon", title: "Afternoon", time: "11:00 – 17:00", icon: Icons.sun, desc: "Warm, bright & vibrant daylight" },
                                        { id: "sunset", title: "Sunset", time: "17:00 – 21:00", icon: Icons.sunDim, desc: "Golden hour, warm orange & dusk" },
                                        { id: "night", title: "Night", time: "21:00 – 06:00", icon: Icons.moon, desc: "Dark, starry night & deep tones" }
                                    ]

                                    delegate: StyledRect {
                                        id: phaseMiniCard
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 74

                                        readonly property bool isCurrent: root.currentSolarPeriod === modelData.id
                                        readonly property int matchingCount: root.getSolarCount(modelData.id)
                                        variant: isCurrent ? "focus" : "pane"
                                        radius: Styling.radius(3)

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            border.color: Styling.srItem("overprimary")
                                            border.width: phaseMiniCard.isCurrent ? 2 : 0
                                            radius: Styling.radius(3)
                                            visible: phaseMiniCard.isCurrent
                                        }

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            spacing: 2

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 4

                                                Text {
                                                    text: modelData.icon
                                                    font.family: Icons.font
                                                    font.pixelSize: 14
                                                    color: phaseMiniCard.isCurrent ? Styling.srItem("overprimary") : Colors.overBackground
                                                }

                                                Text {
                                                    text: modelData.title
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-1)
                                                    font.weight: Font.Bold
                                                    color: Colors.overBackground
                                                }

                                                Item { Layout.fillWidth: true }

                                                StyledRect {
                                                    visible: phaseMiniCard.isCurrent
                                                    Layout.preferredHeight: 16
                                                    Layout.preferredWidth: livePillText.implicitWidth + 6
                                                    variant: "primary"
                                                    radius: Styling.radius(1)
                                                    Text {
                                                        id: livePillText
                                                        anchors.centerIn: parent
                                                        text: "ACTIVE"
                                                        font.family: Config.theme.font
                                                        font.pixelSize: Styling.fontSize(-5)
                                                        font.weight: Font.Bold
                                                        color: Styling.srItem("primary")
                                                    }
                                                }
                                            }

                                            Text {
                                                text: modelData.time
                                                font.family: Config.theme.monoFont
                                                font.pixelSize: Styling.fontSize(-4)
                                                color: Colors.outline
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.desc
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-4)
                                                color: Colors.outline
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: phaseMiniCard.matchingCount > 0 ? (phaseMiniCard.matchingCount + " wallpapers match") : "Keywords fallback"
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-4)
                                                font.weight: Font.Medium
                                                color: phaseMiniCard.isCurrent ? Styling.srItem("overprimary") : Colors.overSurface
                                            }
                                        }
                                    }
                                }
                            }

                            // Footer row: info note + re-index button
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: "Palette matching applies to both automatic rotation and shortcut triggers (ambxst run wallpaper-random)."
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-3)
                                    color: Colors.outline
                                }

                                StyledRect {
                                    id: refreshIndexBtn
                                    Layout.preferredHeight: 28
                                    Layout.preferredWidth: refreshText.implicitWidth + 18
                                    variant: maRef.containsMouse ? "focus" : "pane"
                                    radius: Styling.radius(2)

                                    MouseArea {
                                        id: maRef
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (GlobalStates) GlobalStates.refreshSolarCache();
                                        }

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Text {
                                                text: "↻"
                                                font.family: Config.theme.font
                                                font.pixelSize: 12
                                                color: Styling.srItem("overprimary")
                                            }

                                            Text {
                                                id: refreshText
                                                text: "Re-index Colors"
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-3)
                                                font.weight: Font.Medium
                                                color: Colors.overBackground
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Card 2: Random Wallpaper Sources & Directories Pool
                    StyledRect {
                        id: poolCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: poolColumn.implicitHeight + 20
                        variant: "pane"
                        radius: Styling.radius(4)

                        ColumnLayout {
                            id: poolColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: Icons.folder
                                    font.family: Icons.font
                                    font.pixelSize: 18
                                    color: Styling.srItem("overprimary")
                                }

                                Text {
                                    text: "Random Rotation Sources"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    font.weight: Font.Bold
                                    color: Colors.overBackground
                                }

                                Text {
                                    text: "• Select directories & types for shuffle and periodic rotation (empty = all)"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-3)
                                    color: Colors.outline
                                }

                                Item { Layout.fillWidth: true }

                                // Wallpaper count badge
                                StyledRect {
                                    Layout.preferredHeight: 26
                                    Layout.preferredWidth: countText.implicitWidth + 20
                                    variant: "focus"
                                    radius: Styling.radius(2)

                                    Text {
                                        id: countText
                                        anchors.centerIn: parent
                                        text: root.matchingCountText
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-3)
                                        font.weight: Font.Medium
                                        color: Styling.srItem("overprimary")
                                    }
                                }
                            }

                            // Flow of source chips
                            Flow {
                                id: sourceChipsFlow
                                Layout.fillWidth: true
                                spacing: 6

                                // "All Wallpapers" chip (index: 9)
                                StyledRect {
                                    id: allChip
                                    readonly property bool isSelected: !GlobalStates || !GlobalStates.wallpaperRandomSourceFilters || GlobalStates.wallpaperRandomSourceFilters.length === 0
                                    readonly property bool isFocused: root.currentSection === 3 && root.focusedAutomationIndex === 9
                                    variant: isSelected ? "primary" : ((allMa.containsMouse || isFocused) ? "focus" : "pane")
                                    radius: Styling.radius(3)
                                    height: 32
                                    width: allRow.implicitWidth + 18

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: allChip.isSelected ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                        border.width: 2
                                        radius: Styling.radius(3)
                                        visible: allChip.isFocused
                                    }

                                    MouseArea {
                                        id: allMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.currentSection = 3;
                                            root.focusedAutomationIndex = 9;
                                            if (GlobalStates) GlobalStates.setWallpaperRandomSourceFilters([]);
                                        }
                                        onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                        RowLayout {
                                            id: allRow
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: allChip.isSelected ? Icons.accept : Icons.sparkle
                                                font.family: Icons.font
                                                font.pixelSize: 14
                                                color: allChip.isSelected ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                            }

                                            Text {
                                                text: "All Wallpapers"
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                font.weight: allChip.isSelected ? Font.Bold : Font.Medium
                                                color: allChip.isSelected ? Styling.srItem("primary") : Colors.overBackground
                                            }
                                        }
                                    }
                                }

                                // Base Types & Subfolders Repeater
                                Repeater {
                                    id: sourceRepeater
                                    model: root.availableSourceOptions

                                    delegate: StyledRect {
                                        id: chipCard
                                        required property var modelData
                                        required property int index
                                        readonly property int itemIndex: 10 + index

                                        readonly property bool isSelected: (GlobalStates && GlobalStates.wallpaperRandomSourceFilters && GlobalStates.wallpaperRandomSourceFilters.includes(modelData.key))
                                        readonly property bool isFocused: root.currentSection === 3 && root.focusedAutomationIndex === itemIndex

                                        variant: isSelected ? "primary" : ((maChip.containsMouse || isFocused) ? "focus" : "pane")
                                        radius: Styling.radius(3)
                                        height: 32
                                        width: chipRow.implicitWidth + 18

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            border.color: chipCard.isSelected ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                            border.width: 2
                                            radius: Styling.radius(3)
                                            visible: chipCard.isFocused
                                        }

                                        MouseArea {
                                            id: maChip
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.currentSection = 3;
                                                root.focusedAutomationIndex = itemIndex;
                                                if (GlobalStates) GlobalStates.toggleWallpaperRandomSourceFilter(modelData.key);
                                            }
                                            onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                            RowLayout {
                                                id: chipRow
                                                anchors.centerIn: parent
                                                spacing: 6

                                                Text {
                                                    text: chipCard.isSelected ? Icons.accept : modelData.icon
                                                    font.family: Icons.font
                                                    font.pixelSize: 14
                                                    color: chipCard.isSelected ? Styling.srItem("primary") : (modelData.isSubfolder ? Styling.srItem("overprimary") : Colors.overSurface)
                                                }

                                                Text {
                                                    text: modelData.label
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-2)
                                                    font.weight: chipCard.isSelected ? Font.Bold : Font.Medium
                                                    color: chipCard.isSelected ? Styling.srItem("primary") : Colors.overBackground
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Card 3: Live Wallpaper Playback & Power Saving
                    StyledRect {
                        id: playbackPauseCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: playbackPauseCol.implicitHeight + 20
                        variant: "pane"
                        radius: Styling.radius(4)

                        ColumnLayout {
                            id: playbackPauseCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: Icons.play
                                    font.family: Icons.font
                                    font.pixelSize: 18
                                    color: Styling.srItem("overprimary")
                                }

                                Text {
                                    text: "Live Wallpaper Playback & Power Saving"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    font.weight: Font.Bold
                                    color: Colors.overBackground
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "Pauses live wallpaper to save VRAM and GPU resources"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-3)
                                    color: Colors.outline
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: root.pauseOptions

                                    delegate: StyledRect {
                                        id: pauseCard
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 52

                                        readonly property bool isSelected: modelData.id === root.currentPauseMode

                                        variant: isSelected ? "primary" : (maPause.containsMouse ? "focus" : "pane")
                                        radius: Styling.radius(3)

                                        MouseArea {
                                            id: maPause
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (GlobalStates) GlobalStates.setWallpaperPauseMode(modelData.id);
                                            }
                                            onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 8

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1

                                                    Text {
                                                        text: modelData.title
                                                        font.family: Config.theme.font
                                                        font.pixelSize: Styling.fontSize(-1)
                                                        font.weight: pauseCard.isSelected ? Font.Bold : Font.Medium
                                                        color: pauseCard.isSelected ? Styling.srItem("primary") : Colors.overBackground
                                                    }

                                                    MarqueeText {
                                                        Layout.fillWidth: true
                                                        text: modelData.sub
                                                        font.family: Config.theme.font
                                                        font.pixelSize: Styling.fontSize(-3)
                                                        color: pauseCard.isSelected ? Styling.srItem("primary") : Colors.outline
                                                        hovered: maPause.containsMouse
                                                        isSelected: pauseCard.isSelected
                                                    }
                                                }

                                                Text {
                                                    visible: pauseCard.isSelected
                                                    text: Icons.accept
                                                    font.family: Icons.font
                                                    font.pixelSize: 14
                                                    color: Styling.srItem("primary")
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Divider
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Colors.outline
                                opacity: 0.15
                            }

                            // Monitor Scope Selector
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: "Pause Scope:"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.weight: Font.Bold
                                    color: Colors.overBackground
                                }

                                RowLayout {
                                    spacing: 6

                                    Repeater {
                                        model: [
                                            { id: "perScreen", title: "Current monitor only (Default)", icon: Icons.desktop },
                                            { id: "allScreens", title: "All monitors", icon: Icons.layoutGrid }
                                        ]

                                        delegate: StyledRect {
                                            id: scopeCard
                                            required property var modelData
                                            required property int index

                                            Layout.preferredHeight: 32
                                            Layout.preferredWidth: scopeLayout.implicitWidth + 24

                                            readonly property bool isSelected: root.currentPauseScope === scopeCard.modelData.id
                                            variant: isSelected ? "primary" : (maScope.containsMouse ? "focus" : "pane")
                                            radius: Styling.radius(3)

                                            Rectangle {
                                                anchors.fill: parent
                                                color: "transparent"
                                                border.color: scopeCard.isSelected ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                                border.width: 1
                                                opacity: scopeCard.isSelected ? 0.4 : (maScope.containsMouse ? 0.8 : 0.25)
                                                radius: Styling.radius(3)
                                            }

                                            MouseArea {
                                                id: maScope
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (GlobalStates) GlobalStates.setWallpaperPauseScope(scopeCard.modelData.id);
                                                }
                                                onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                                RowLayout {
                                                    id: scopeLayout
                                                    anchors.centerIn: parent
                                                    spacing: 8

                                                    Text {
                                                        text: scopeCard.modelData.icon
                                                        font.family: Icons.font
                                                        font.pixelSize: 14
                                                        color: scopeCard.isSelected ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                                    }

                                                    Text {
                                                        text: scopeCard.modelData.title
                                                        font.family: Config.theme.font
                                                        font.pixelSize: Styling.fontSize(-2)
                                                        font.weight: scopeCard.isSelected ? Font.Bold : Font.Medium
                                                        color: scopeCard.isSelected ? Styling.srItem("primary") : Colors.overSurface
                                                    }

                                                    Text {
                                                        visible: scopeCard.isSelected
                                                        text: Icons.accept
                                                        font.family: Icons.font
                                                        font.pixelSize: 12
                                                        color: Styling.srItem("primary")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            // skwd-wall can only pause one monitor on its own by giving each
                            // monitor its own player, which decodes a shared video twice.
                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: GlobalStates.wallpaperPauseScope === "allScreens"
                                    ? "All monitors share one video player, so a video shown on several screens is decoded once."
                                    : "Each monitor gets its own video player so it can pause on its own; a video shown on several screens is decoded once per screen."
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-3)
                                color: Colors.outline
                            }
                        }
                    }
                }

                // Section 4: Material You Color Schemes
                ColumnLayout {
                    id: sectionSchemes
                    Layout.fillWidth: true
                    spacing: 6
                    readonly property bool isPresetActive: Boolean(GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.activeColorPreset)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "MATERIAL YOU COLOR SCHEMES"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Bold
                            color: root.currentSection === 4 ? Styling.srItem("overprimary") : Colors.overBackground
                        }

                        Text {
                            visible: sectionSchemes.isPresetActive
                            text: "(Preset active — click a scheme to enable)"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                        }

                        Item { Layout.fillWidth: true }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: 6
                        columnSpacing: 6
                        opacity: sectionSchemes.isPresetActive ? 0.65 : 1.0

                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }

                        Repeater {
                            model: root.matugenSchemes

                            delegate: StyledRect {
                                id: schemeCard
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40

                                readonly property bool isSelected: !sectionSchemes.isPresetActive && (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.currentMatugenScheme === modelData.id)
                                readonly property bool isFocused: root.currentSection === 4 && root.focusedSchemeIndex === index

                                variant: isSelected ? "primary" : ((maScheme.containsMouse || isFocused) ? "focus" : "pane")
                                radius: Styling.radius(3)

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: schemeCard.isSelected ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                    border.width: 2
                                    radius: Styling.radius(3)
                                    visible: schemeCard.isFocused
                                }

                                MouseArea {
                                    id: maScheme
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentSection = 4;
                                        root.focusedSchemeIndex = index;
                                        if (GlobalStates.wallpaperManager) {
                                            GlobalStates.wallpaperManager.setMatugenScheme(modelData.id);
                                        }
                                    }
                                    onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: modelData.label
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.weight: schemeCard.isSelected ? Font.Bold : Font.Medium
                                            color: schemeCard.isSelected ? Styling.srItem("primary") : Colors.overSurface
                                        }

                                        Text {
                                            visible: schemeCard.isSelected
                                            text: Icons.accept
                                            font.family: Icons.font
                                            font.pixelSize: 14
                                            color: Styling.srItem("primary")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Section 5: Color Presets (optional)
                ColumnLayout {
                    id: sectionPresets
                    visible: root.presets && root.presets.length > 0
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "COLOR PRESETS"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Bold
                            color: root.currentSection === 5 ? Styling.srItem("overprimary") : Colors.overBackground
                        }

                        Text {
                            visible: Boolean(GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.activeColorPreset)
                            text: "(Click active preset to toggle off)"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                        }

                        Item { Layout.fillWidth: true }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: 6
                        columnSpacing: 6

                        Repeater {
                            model: root.presets

                            delegate: StyledRect {
                                id: presetCard
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38

                                readonly property bool isSelected: (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.activeColorPreset === String(modelData))
                                readonly property bool isFocused: root.currentSection === 5 && root.focusedPresetIndex === index

                                variant: isSelected ? "primary" : ((maPreset.containsMouse || isFocused) ? "focus" : "pane")
                                radius: Styling.radius(3)

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: presetCard.isSelected ? Styling.srItem("primary") : Styling.srItem("overprimary")
                                    border.width: 2
                                    radius: Styling.radius(3)
                                    visible: presetCard.isFocused
                                }

                                MouseArea {
                                    id: maPreset
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentSection = 5;
                                        root.focusedPresetIndex = index;
                                        if (GlobalStates.wallpaperManager) {
                                            GlobalStates.wallpaperManager.setColorPreset(String(modelData));
                                        }
                                    }
                                    onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: String(modelData)
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.weight: presetCard.isSelected ? Font.Bold : Font.Medium
                                            color: presetCard.isSelected ? Styling.srItem("primary") : Colors.overSurface
                                        }

                                        Text {
                                            visible: presetCard.isSelected
                                            text: Icons.accept
                                            font.family: Icons.font
                                            font.pixelSize: 14
                                            color: Styling.srItem("primary")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
