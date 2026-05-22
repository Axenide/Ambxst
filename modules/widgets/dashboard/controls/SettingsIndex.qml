// this file is used to index all searchable items in the settings tab

import QtQuick
import qs.modules.theme

QtObject {
    // Array of searchable items
    // { label, keywords, section (int), subSection (string), subLabel (string), icon: (string/url), isIcon (bool) }

    // IMPORTANT: about the keywords,
    // it will try to guess what users would want to search, not the feature name only

    // Main Sections:
    // 0: Network, 1: Bluetooth, 2: Mixer, 3: Effects, 4: Theme, 5: Binds, 6: System, 7: Compositor, 8: Ambxst
    
    property var dynamicItems: []

    readonly property var staticItems: [
        // --- Network ---
        { label: "Network", keywords: "internet wifi connection ethernet ip", section: 0, subSection: "", subLabel: "", icon: Icons.wifiHigh, isIcon: true },
        
        // --- Bluetooth ---
        { label: "Bluetooth", keywords: "devices pairing connect", section: 1, subSection: "", subLabel: "", icon: Icons.bluetooth, isIcon: true },
        
        // --- Mixer ---
        { label: "Audio Mixer", keywords: "sound volume output input mic speaker", section: 2, subSection: "", subLabel: "", icon: Icons.faders, isIcon: true },
        
        // --- Effects ---
        { label: "Audio Effects", keywords: "equalizer bass treble easyeffects", section: 3, subSection: "", subLabel: "", icon: Icons.waveform, isIcon: true },
        
        // --- Theme ---
        { label: "Theme", keywords: "appearance look style customize", section: 4, subSection: "", subLabel: "Theme", icon: Icons.paintBrush, isIcon: true },
        
        // Theme > General
        { label: "Wallpapers", keywords: "background image picture desktop", section: 4, subSection: "general", subLabel: "Theme > General", icon: Icons.image, isIcon: true },
        { label: "Tint Icons", keywords: "color icons tint monochrome", section: 4, subSection: "general", subLabel: "Theme > General", icon: Icons.palette, isIcon: true },
        { label: "Enable Corners", keywords: "rounded corners radius screen", section: 4, subSection: "general", subLabel: "Theme > General", icon: Icons.cornersOut, isIcon: true },
        { label: "Animation Duration", keywords: "speed fast slow transition", section: 4, subSection: "general", subLabel: "Theme > General", icon: Icons.clock, isIcon: true },
        { label: "UI Font", keywords: "typography text family size", section: 4, subSection: "general", subLabel: "Theme > General", icon: Icons.textT, isIcon: true },
        { label: "Roundness", keywords: "radius border curve", section: 4, subSection: "general", subLabel: "Theme > General", icon: Icons.circle, isIcon: true },
        
        // Theme > Shadow
        { label: "Shadow Opacity", keywords: "darkness alpha transparency", section: 4, subSection: "shadow", subLabel: "Theme > Shadow", icon: Icons.drop, isIcon: true },
        { label: "Shadow Blur", keywords: "softness diffusion", section: 4, subSection: "shadow", subLabel: "Theme > Shadow", icon: Icons.drop, isIcon: true },
        { label: "Shadow Offset", keywords: "position x y direction", section: 4, subSection: "shadow", subLabel: "Theme > Shadow", icon: Icons.arrowsOutSimple, isIcon: true },

        // Theme > Colors
        { label: "Color Scheme", keywords: "palette variant light dark", section: 4, subSection: "colors", subLabel: "Theme > Colors", icon: Icons.palette, isIcon: true },
        { label: "Color Variant", keywords: "background popup internal bar pane", section: 4, subSection: "colors", subLabel: "Theme > Colors", icon: Icons.palette, isIcon: true },
        { label: "Background Variant", keywords: "wallpaper desktop color", section: 4, subSection: "colors", subLabel: "Theme > Colors", icon: Icons.palette, isIcon: true },
        { label: "Popup Variant", keywords: "dialog modal color", section: 4, subSection: "colors", subLabel: "Theme > Colors", icon: Icons.palette, isIcon: true },
        { label: "Internal BG Variant", keywords: "inside background color", section: 4, subSection: "colors", subLabel: "Theme > Colors", icon: Icons.palette, isIcon: true },
        { label: "Bar BG Variant", keywords: "taskbar panel color", section: 4, subSection: "colors", subLabel: "Theme > Colors", icon: Icons.palette, isIcon: true },
        { label: "Pane Variant", keywords: "sidebar panel color", section: 4, subSection: "colors", subLabel: "Theme > Colors", icon: Icons.palette, isIcon: true },
        { label: "Gradient Mode", keywords: "linear radial halftone", section: 4, subSection: "colors", subLabel: "Theme > Colors", icon: Icons.palette, isIcon: true },
        { label: "Item Color", keywords: "overbackground surface", section: 4, subSection: "colors", subLabel: "Theme > Colors", icon: Icons.palette, isIcon: true },
        { label: "Color Opacity", keywords: "alpha transparency", section: 4, subSection: "colors", subLabel: "Theme > Colors", icon: Icons.palette, isIcon: true },
        { label: "Color Border", keywords: "stroke outline", section: 4, subSection: "colors", subLabel: "Theme > Colors", icon: Icons.palette, isIcon: true },
        { label: "Gradient Stops", keywords: "color position stops", section: 4, subSection: "colors", subLabel: "Theme > Colors", icon: Icons.palette, isIcon: true },
        { label: "Gradient Angle", keywords: "direction rotation degrees", section: 4, subSection: "colors", subLabel: "Theme > Colors", icon: Icons.palette, isIcon: true },

        // --- Binds ---
        { label: "Key Bindings", keywords: "shortcuts keyboard hotkeys", section: 5, subSection: "", subLabel: "", icon: Icons.keyboard, isIcon: true },
        // Binds > Ambxst
        { label: "Launcher Keybind", keywords: "app launcher menu shortcut", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.rocket, isIcon: true },
        { label: "Dashboard Keybind", keywords: "widgets dashboard shortcut", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.squaresFour, isIcon: true },
        { label: "Clipboard Keybind", keywords: "copy paste shortcut super v", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.clipboard, isIcon: true },
        { label: "Emoji Keybind", keywords: "picker shortcut super period", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.keyboard, isIcon: true },
        { label: "Tmux Keybind", keywords: "terminal shortcut", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.keyboard, isIcon: true },
        { label: "Wallpapers Keybind", keywords: "background shortcut super comma", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.keyboard, isIcon: true },
        { label: "Assistant Keybind", keywords: "ai help shortcut", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.keyboard, isIcon: true },
        { label: "Notes Keybind", keywords: "note shortcut super n", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.keyboard, isIcon: true },
        { label: "Overview Keybind", keywords: "workspace shortcut super tab", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.keyboard, isIcon: true },
        { label: "Powermenu Keybind", keywords: "logout shutdown shortcut super escape", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.power, isIcon: true },
        { label: "Settings Keybind", keywords: "config preferences shortcut", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.gear, isIcon: true },
        { label: "Lockscreen Keybind", keywords: "lock security shortcut", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.lock, isIcon: true },
        { label: "Tools Keybind", keywords: "utilities tools shortcut", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.wrench, isIcon: true },
        { label: "Screenshot Keybind", keywords: "capture screen shortcut print", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.camera, isIcon: true },
        { label: "Screenrecord Keybind", keywords: "record video shortcut", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.videoCamera, isIcon: true },
        { label: "Lens Keybind", keywords: "magnifier zoom shortcut", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.magnifyingGlass, isIcon: true },
        { label: "Reload Keybind", keywords: "refresh restart shortcut", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.arrowCounterClockwise, isIcon: true },
        { label: "Quit Keybind", keywords: "exit close shortcut", section: 5, subSection: "", subLabel: "Binds > Ambxst", icon: Icons.signOut, isIcon: true },
        
        // --- System ---
        { label: "System", keywords: "hardware info resources cpu ram", section: 6, subSection: "", subLabel: "System", icon: Icons.circuitry, isIcon: true },
        
        // System > Prefixes
        { label: "Prefixes", keywords: "shortcuts launcher quick actions", section: 6, subSection: "prefixes", subLabel: "System > Prefixes", icon: Icons.keyboard, isIcon: true },
        { label: "Clipboard Prefix", keywords: "cc copy paste launcher", section: 6, subSection: "prefixes", subLabel: "System > Prefixes", icon: Icons.keyboard, isIcon: true },
        { label: "Emoji Prefix", keywords: "ee picker launcher", section: 6, subSection: "prefixes", subLabel: "System > Prefixes", icon: Icons.keyboard, isIcon: true },
        { label: "Tmux Prefix", keywords: "tt terminal launcher", section: 6, subSection: "prefixes", subLabel: "System > Prefixes", icon: Icons.keyboard, isIcon: true },
        { label: "Wallpapers Prefix", keywords: "ww background launcher", section: 6, subSection: "prefixes", subLabel: "System > Prefixes", icon: Icons.keyboard, isIcon: true },
        { label: "Notes Prefix", keywords: "nn note launcher", section: 6, subSection: "prefixes", subLabel: "System > Prefixes", icon: Icons.keyboard, isIcon: true },
        
        // System > Weather
        { label: "Weather Location", keywords: "city country place gps", section: 6, subSection: "weather", subLabel: "System > Weather", icon: Icons.mapPin, isIcon: true },
        { label: "Temperature Unit", keywords: "celsius fahrenheit scale", section: 6, subSection: "weather", subLabel: "System > Weather", icon: Icons.thermometer, isIcon: true },

        // System > Performance
        { label: "Blur Transition", keywords: "animation speed performance effect", section: 6, subSection: "performance", subLabel: "System > Performance", icon: Icons.lightning, isIcon: true },
        { label: "Window Preview", keywords: "thumbnail overview alt-tab", section: 6, subSection: "performance", subLabel: "System > Performance", icon: Icons.windowsLogo, isIcon: true },
        { label: "Wavy Line", keywords: "animated wave effect performance", section: 6, subSection: "performance", subLabel: "System > Performance", icon: Icons.lightning, isIcon: true },
        
        // System > Resources
        { label: "System Resources", keywords: "cpu ram memory usage monitor", section: 6, subSection: "resources", subLabel: "System > Resources", icon: Icons.circuitry, isIcon: true },
        
        // System > Idle
        { label: "Idle Settings", keywords: "screen lock timeout sleep suspend", section: 6, subSection: "idle", subLabel: "System > Idle", icon: Icons.moon, isIcon: true },
        { label: "Lock Command", keywords: "ambxst lock screen idle", section: 6, subSection: "idle", subLabel: "System > Idle", icon: Icons.moon, isIcon: true },
        { label: "Before Sleep", keywords: "loginctl lock-session idle", section: 6, subSection: "idle", subLabel: "System > Idle", icon: Icons.moon, isIcon: true },
        { label: "After Sleep", keywords: "screen on resume idle", section: 6, subSection: "idle", subLabel: "System > Idle", icon: Icons.moon, isIcon: true },
        { label: "Idle Listener", keywords: "timeout brightness screen off suspend", section: 6, subSection: "idle", subLabel: "System > Idle", icon: Icons.moon, isIcon: true },
        
        // --- Compositor ---
        { label: "Compositor", keywords: "compositor window manager wm", section: 7, subSection: "", subLabel: "Compositor", icon: Icons.compositor, isIcon: true },
        
        // Compositor > AxctlService > General
        { label: "Border Size", keywords: "width thickness stroke", section: 7, subSection: "general", subLabel: "Compositor > AxctlService", icon: Icons.frameCorners, isIcon: true },
        { label: "Window Gaps", keywords: "spacing margin padding", section: 7, subSection: "general", subLabel: "Compositor > AxctlService", icon: Icons.squaresFour, isIcon: true },
        
        // Compositor > AxctlService > Colors
        { label: "Border Colors", keywords: "active inactive focus", section: 7, subSection: "colors", subLabel: "Compositor > AxctlService", icon: Icons.palette, isIcon: true },

        // Compositor > AxctlService > Shadows
        { label: "Shadows Enabled", keywords: "toggle on off", section: 7, subSection: "shadows", subLabel: "Compositor > AxctlService", icon: Icons.drop, isIcon: true },
        { label: "Sync Shadow Color", keywords: "match border", section: 7, subSection: "shadows", subLabel: "Compositor > AxctlService", icon: Icons.palette, isIcon: true },
        { label: "Sync Shadow Opacity", keywords: "match border alpha", section: 7, subSection: "shadows", subLabel: "Compositor > AxctlService", icon: Icons.drop, isIcon: true },
        { label: "Shadow Range", keywords: "blur radius size", section: 7, subSection: "shadows", subLabel: "Compositor > AxctlService", icon: Icons.circle, isIcon: true },
        { label: "Shadow Offset", keywords: "position x y move", section: 7, subSection: "shadows", subLabel: "Compositor > AxctlService", icon: Icons.arrowsOutSimple, isIcon: true },
        { label: "Shadow Power", keywords: "strength render intensity", section: 7, subSection: "shadows", subLabel: "Compositor > AxctlService", icon: Icons.lightning, isIcon: true },
        { label: "Shadow Scale", keywords: "zoom resize", section: 7, subSection: "shadows", subLabel: "Compositor > AxctlService", icon: Icons.cornersOut, isIcon: true },

        // Compositor > AxctlService > Blur
        { label: "Blur Enabled", keywords: "toggle on off transparency", section: 7, subSection: "blur", subLabel: "Compositor > AxctlService", icon: Icons.drop, isIcon: true },
        { label: "Blur Size", keywords: "radius amount", section: 7, subSection: "blur", subLabel: "Compositor > AxctlService", icon: Icons.circle, isIcon: true },
        { label: "Blur Passes", keywords: "quality iterations", section: 7, subSection: "blur", subLabel: "Compositor > AxctlService", icon: Icons.circle, isIcon: true },
        { label: "Blur Xray", keywords: "transparency see through", section: 7, subSection: "blur", subLabel: "Compositor > AxctlService", icon: Icons.drop, isIcon: true },
        { label: "Blur New Optimizations", keywords: "performance speed", section: 7, subSection: "blur", subLabel: "Compositor > AxctlService", icon: Icons.lightning, isIcon: true },
        { label: "Blur Ignore Opacity", keywords: "transparency alpha", section: 7, subSection: "blur", subLabel: "Compositor > AxctlService", icon: Icons.drop, isIcon: true },
        { label: "Blur Ignorealpha", keywords: "explicit transparency", section: 7, subSection: "blur", subLabel: "Compositor > AxctlService", icon: Icons.drop, isIcon: true },
        { label: "Blur Ignorealpha Value", keywords: "threshold amount", section: 7, subSection: "blur", subLabel: "Compositor > AxctlService", icon: Icons.drop, isIcon: true },
        { label: "Blur Noise", keywords: "grain texture static", section: 7, subSection: "blur", subLabel: "Compositor > AxctlService", icon: Icons.drop, isIcon: true },
        { label: "Blur Contrast", keywords: "intensity difference", section: 7, subSection: "blur", subLabel: "Compositor > AxctlService", icon: Icons.drop, isIcon: true },
        { label: "Blur Brightness", keywords: "light dark level", section: 7, subSection: "blur", subLabel: "Compositor > AxctlService", icon: Icons.drop, isIcon: true },
        { label: "Blur Vibrancy", keywords: "saturation color", section: 7, subSection: "blur", subLabel: "Compositor > AxctlService", icon: Icons.drop, isIcon: true },

        // --- Ambxst / Shell ---
        { label: "Ambxst", keywords: "about info credits version shell", section: 8, subSection: "", subLabel: "", icon: Qt.resolvedUrl("../../../../assets/ambxst/ambxst-icon.svg"), isIcon: false },
        
        // Ambxst > Bar
        { label: "Bar", keywords: "panel taskbar top bottom", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.layout, isIcon: true },
        { label: "Bar Position", keywords: "top bottom left right edge", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.layout, isIcon: true },
        { label: "Launcher Icon", keywords: "logo symbol path", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.layout, isIcon: true },
        { label: "Launcher Icon Tint", keywords: "color theme", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.palette, isIcon: true },
        { label: "Launcher Icon Full Tint", keywords: "monochrome color", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.palette, isIcon: true },
        { label: "Launcher Icon Size", keywords: "width height pixels", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.layout, isIcon: true },
        { label: "Pill Style", keywords: "squished roundness radius bar", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.layout, isIcon: true },
        { label: "Firefox Player", keywords: "browser media music", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.layout, isIcon: true },
        { label: "Bar Auto-hide", keywords: "autohide hide show reveal", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.layout, isIcon: true },
        { label: "Pinned on Startup", keywords: "show visible default", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.layout, isIcon: true },
        { label: "Hover to Reveal", keywords: "mouse show hide edge", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.layout, isIcon: true },
        { label: "Hover Region Height", keywords: "pixels trigger area", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.layout, isIcon: true },
        { label: "Show Pin Button", keywords: "toggle pin unpin", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.layout, isIcon: true },
        { label: "Available on Fullscreen", keywords: "overlay game video", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.layout, isIcon: true },
        { label: "Show Running Indicators", keywords: "dots active apps", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.layout, isIcon: true },
        { label: "Show Overview Button", keywords: "workspace switcher", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.layout, isIcon: true },
        { label: "Bar Screens", keywords: "monitor display eDP", section: 8, subSection: "bar", subLabel: "Ambxst > Bar", icon: Icons.layout, isIcon: true },
        
        // Ambxst > Notch
        { label: "Notch", keywords: "island dynamic island center", section: 8, subSection: "notch", subLabel: "Ambxst > Notch", icon: Icons.layout, isIcon: true },
        
        // Ambxst > Workspaces
        { label: "Workspaces", keywords: "virtual desktop spaces", section: 8, subSection: "workspaces", subLabel: "Ambxst > Workspaces", icon: Icons.squaresFour, isIcon: true },
        { label: "Workspaces Shown", keywords: "number count visible", section: 8, subSection: "workspaces", subLabel: "Ambxst > Workspaces", icon: Icons.squaresFour, isIcon: true },
        { label: "Show App Icons", keywords: "application thumbnail workspace", section: 8, subSection: "workspaces", subLabel: "Ambxst > Workspaces", icon: Icons.squaresFour, isIcon: true },
        { label: "Always Show Numbers", keywords: "workspace label index", section: 8, subSection: "workspaces", subLabel: "Ambxst > Workspaces", icon: Icons.squaresFour, isIcon: true },
        { label: "Show Numbers", keywords: "workspace label index", section: 8, subSection: "workspaces", subLabel: "Ambxst > Workspaces", icon: Icons.squaresFour, isIcon: true },
        { label: "Dynamic Workspaces", keywords: "auto add remove flexible", section: 8, subSection: "workspaces", subLabel: "Ambxst > Workspaces", icon: Icons.squaresFour, isIcon: true },
        
        // Ambxst > Overview
        { label: "Overview", keywords: "expose mission control windows", section: 8, subSection: "overview", subLabel: "Ambxst > Overview", icon: Icons.squaresFour, isIcon: true },
        { label: "Overview Rows", keywords: "grid layout vertical", section: 8, subSection: "overview", subLabel: "Ambxst > Overview", icon: Icons.squaresFour, isIcon: true },
        { label: "Overview Columns", keywords: "grid layout horizontal", section: 8, subSection: "overview", subLabel: "Ambxst > Overview", icon: Icons.squaresFour, isIcon: true },
        { label: "Overview Scale", keywords: "zoom size preview", section: 8, subSection: "overview", subLabel: "Ambxst > Overview", icon: Icons.squaresFour, isIcon: true },
        { label: "Overview Workspace Spacing", keywords: "gap margin distance", section: 8, subSection: "overview", subLabel: "Ambxst > Overview", icon: Icons.squaresFour, isIcon: true },
        
        // Ambxst > Dock
        { label: "Dock", keywords: "taskbar launcher apps favorites", section: 8, subSection: "dock", subLabel: "Ambxst > Dock", icon: Icons.layout, isIcon: true },
        { label: "Dock Enabled", keywords: "show hide toggle", section: 8, subSection: "dock", subLabel: "Ambxst > Dock", icon: Icons.layout, isIcon: true },
        { label: "Dock Mode", keywords: "default floating integrated style", section: 8, subSection: "dock", subLabel: "Ambxst > Dock", icon: Icons.layout, isIcon: true },
        { label: "Dock Position", keywords: "left bottom right edge", section: 8, subSection: "dock", subLabel: "Ambxst > Dock", icon: Icons.layout, isIcon: true },
        { label: "Dock Height", keywords: "size thickness pixels", section: 8, subSection: "dock", subLabel: "Ambxst > Dock", icon: Icons.layout, isIcon: true },
        { label: "Dock Icon Size", keywords: "width height pixels apps", section: 8, subSection: "dock", subLabel: "Ambxst > Dock", icon: Icons.layout, isIcon: true },
        { label: "Dock Spacing", keywords: "gap between icons", section: 8, subSection: "dock", subLabel: "Ambxst > Dock", icon: Icons.layout, isIcon: true },
        { label: "Dock Margin", keywords: "edge distance offset", section: 8, subSection: "dock", subLabel: "Ambxst > Dock", icon: Icons.layout, isIcon: true },
        { label: "Dock Hover Region Height", keywords: "trigger area pixels", section: 8, subSection: "dock", subLabel: "Ambxst > Dock", icon: Icons.layout, isIcon: true },
        { label: "Dock Pinned on Startup", keywords: "show visible default", section: 8, subSection: "dock", subLabel: "Ambxst > Dock", icon: Icons.layout, isIcon: true },
        
        // Ambxst > Lockscreen
        { label: "Lockscreen", keywords: "lock screen password login", section: 8, subSection: "lockscreen", subLabel: "Ambxst > Lockscreen", icon: Icons.lock, isIcon: true },
        
        // Ambxst > Desktop
        { label: "Desktop", keywords: "icons wallpaper home", section: 8, subSection: "desktop", subLabel: "Ambxst > Desktop", icon: Icons.layout, isIcon: true },
        { label: "Desktop Enabled", keywords: "show hide icons toggle", section: 8, subSection: "desktop", subLabel: "Ambxst > Desktop", icon: Icons.layout, isIcon: true },
        { label: "Desktop Icon Size", keywords: "width height pixels", section: 8, subSection: "desktop", subLabel: "Ambxst > Desktop", icon: Icons.layout, isIcon: true },
        { label: "Desktop Vertical Spacing", keywords: "gap margin", section: 8, subSection: "desktop", subLabel: "Ambxst > Desktop", icon: Icons.layout, isIcon: true },
        { label: "Desktop Text Color", keywords: "label font", section: 8, subSection: "desktop", subLabel: "Ambxst > Desktop", icon: Icons.palette, isIcon: true },
        
        // Ambxst > System
        { label: "Shell System", keywords: "config settings ambxst", section: 8, subSection: "system", subLabel: "Ambxst > System", icon: Icons.circuitry, isIcon: true }
    ]

    property var items: staticItems.concat(dynamicItems)

    function addDynamicItems(newItems) {
        // Simple deduplication based on label + section
        let currentLabels = new Set(items.map(i => i.section + ":" + i.label));
        let uniqueNew = [];
        
        for (let i = 0; i < newItems.length; i++) {
            let item = newItems[i];
            let key = item.section + ":" + item.label;
            if (!currentLabels.has(key)) {
                uniqueNew.push(item);
                currentLabels.add(key);
            }
        }
        
        if (uniqueNew.length > 0) {
            dynamicItems = dynamicItems.concat(uniqueNew);
        }
    }
}
