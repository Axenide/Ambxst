pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.modules.theme

// skwd-wall (https://github.com/liixini/skwd-wall) draws every
// wallpaper; Ambxst keeps the picker, the library, per-screen choices, rotation
// and matugen colours.
//
// This service watches what each screen should show and keeps the skwd daemon
// in step (`skwd-helm apply FILE -o OUTPUT`). Ambxst's own VideoWallpaper asks
// `offloads(path)` before starting its QtMultimedia player and stays idle while
// skwd plays the file. The wallpaper settings (transition, duration, when to
// pause) are written into skwd's own config, ~/.config/skwd-wall-v2/config.json,
// which the daemon re-reads on its own.
//
// If skwd is missing or keeps failing, `active` turns false and Ambxst draws
// and plays everything itself again.
//
// Options: ~/.config/ambxst/skwd-wall.json
//   enabled   false hands every wallpaper back to Ambxst and stops skwd
Singleton {
    id: root

    readonly property bool enabled: options.adapter.enabled
    readonly property bool available: source !== "none"

    // ── which skwd: the system's (AUR / distro package), the copy Ambxst
    // installed into ~/.local/share/ambxst/skwd-wall, or none ──────────────
    property string source: "unknown"   // unknown | system | local | none
    readonly property string localRoot: Quickshell.env("HOME") + "/.local/share/ambxst/skwd-wall"
    readonly property string helm: source === "local" ? localRoot + "/current/bin/skwd-helm" : "skwd-helm"
    readonly property string unit: source === "local" ? "ambxst-skwd-walld.service" : "skwd-walld.service"
    readonly property string installer: Quickshell.shellDir + "/scripts/skwd_install.sh"
    property bool failed: false         // the daemon could not be reached
    // Ambxst's Tint maps the wallpaper onto the theme palette. skwd does the
    // same for images with its Palette effect (a recoloured copy is made and
    // shown); it cannot recolour videos, so a tinted video stays in Ambxst.
    readonly property bool tint: manager ? manager.tintEnabled === true : false
    readonly property bool tintBlocks: tint && Object.keys(desired).some(n => isMoving(desired[n]))
    readonly property bool active: enabled && available && !failed && !tintBlocks

    readonly property var manager: GlobalStates.wallpaperManager
    readonly property var videoExtensions: ["mp4", "webm", "mov", "avi", "mkv", "gif"]

    // ── skwd's transitions (wall-proto/src/transitions.rs, skwd-deck) ──
    // `instant` is ours: skwd's `transition.enabled = false`.
    readonly property var families: [
        { key: "all", title: "All" },
        { key: "fade", title: "Fade", desc: "Dissolves and blends, no geometry" },
        { key: "wipe", title: "Wipe", desc: "A shape or edge sweeps across the screen" },
        { key: "warp", title: "Warp", desc: "The image bends, stretches or ripples" },
        { key: "break", title: "Break up", desc: "The image shatters, pixelates or smears" },
        { key: "sand", title: "Sand", desc: "Every pixel becomes a grain and flies into a shape" }
    ]
    readonly property var transitions: [
        { key: "random", family: "random", title: "Random", desc: "A different transition every time" },
        { key: "crossfade", family: "fade", title: "Crossfade", desc: "Smooth dissolve from old to new" },
        { key: "fadecolor", family: "fade", title: "Fade Through Black", desc: "Fades to black, then the new image fades up" },
        { key: "colour-distance", family: "fade", title: "Colour Match", desc: "Areas whose colours already match swap first" },
        { key: "perlin", family: "fade", title: "Noise Dissolve", desc: "Cloudy noise patches fill in with the new image" },
        { key: "pixelfade-wave", family: "fade", title: "Pixel Wave", desc: "Pixelated band sweeps top-left to bottom-right" },
        { key: "soft-warp-fade", family: "fade", title: "Soft Warp Fade", desc: "Gentle shimmering crossfade" },
        { key: "circle-crop", family: "wipe", title: "Circle Crop", desc: "Old shrinks into a centre circle, new circle grows back" },
        { key: "iris", family: "wipe", title: "Iris Open", desc: "Circle opens from centre with colour-fringed edge" },
        { key: "crosshatch", family: "wipe", title: "Crosshatch", desc: "Random thin rows and columns of new flick in" },
        { key: "directional", family: "wipe", title: "Push Up", desc: "Old slides up and off, new pushes in from below" },
        { key: "directional-scaled", family: "wipe", title: "Card Slide", desc: "Shrinks to a card, slides up, new card rises in" },
        { key: "directional-wipe", family: "wipe", title: "Diagonal Wipe", desc: "Soft diagonal wipe from bottom-left to top-right" },
        { key: "polka-dots-curtain", family: "wipe", title: "Polka Dots", desc: "Growing dots fill in from the top-left corner" },
        { key: "puzzle-right", family: "wipe", title: "Tile Flip", desc: "4x4 tiles flip sideways at random to the new" },
        { key: "randomsquares", family: "wipe", title: "Random Squares", desc: "Grid squares switch to the new at random" },
        { key: "crosswarp", family: "warp", title: "Cross Warp", desc: "Zooming warp sweeps across from right to left" },
        { key: "heat-melt", family: "warp", title: "Heat Melt", desc: "Dark areas melt in from bottom-right corner" },
        { key: "morph", family: "warp", title: "Colour Morph", desc: "Pixels drift along their colours while blending" },
        { key: "zoom-blur-pull", family: "warp", title: "Zoom Blur Pull", desc: "Radial zoom blur whose focus drifts left to right" },
        { key: "chromatic-bloom", family: "break", title: "Chromatic Bloom", desc: "RGB fringes push out from centre, glow, quick swap" },
        { key: "glitch", family: "break", title: "Jitter Split", desc: "Whole frame jitters with RGB split while fading" },
        { key: "glitch-displace", family: "break", title: "Grey Glitch Snap", desc: "Old smears to a grey ghost, snaps to warped new" },
        { key: "parametric-glitch", family: "break", title: "Wave Fold", desc: "Old folds into wavy colour-keyed bands, fades out" },
        { key: "ink-splash", family: "break", title: "Ink Splash", desc: "Ragged ink blot spreads from centre with dark rim" },
        { key: "inkwell-drop", family: "break", title: "Inkwell Drop", desc: "Rippling ring spreads from a drop left of centre" },
        { key: "mosaic-tumble", family: "break", title: "Mosaic Pan", desc: "Zooms out to a tile wall, pans, zooms into new" },
        { key: "pixelate", family: "break", title: "Pixelate", desc: "Pixelates to a coarse grid, swaps, then sharpens" },
        { key: "plasma-flow", family: "break", title: "Plasma Flow", desc: "Liquid wobble warp while crossfading" },
        { key: "smoke", family: "break", title: "Smoke Reveal", desc: "Smoky wisps eat inward from the edges to centre" },
        { key: "voronoi-shatter", family: "break", title: "Voronoi Shatter", desc: "Cell shards slide the old away, revealing new" },
        { key: "sand-bloom", family: "sand", title: "Sand Bloom", desc: "Old blows away edge-first, new sand lands centre-out" },
        { key: "sand-donut", family: "sand", title: "Sand Donut", desc: "Sand spins round a centre ring, recolours, returns" },
        { key: "sand-galaxy", family: "sand", title: "Sand Galaxy", desc: "Sand swirls into a flat spinning spiral disk" },
        { key: "sand-globe", family: "sand", title: "Sand Globe", desc: "Sand wraps into a spinning globe, then lands" },
        { key: "sand-helix", family: "sand", title: "Sand Helix", desc: "Double helix of sand pours down the centre" },
        { key: "sand-maelstrom", family: "sand", title: "Sand Maelstrom", desc: "Sand churns through a ring vortex both ways" },
        { key: "sand-mobius", family: "sand", title: "Sand Mobius", desc: "Sand twists into a rotating Mobius band" },
        { key: "sand-murmuration", family: "sand", title: "Sand Flock", desc: "Sand flocks out to the right, new flock from left" },
        { key: "sand-tornado", family: "sand", title: "Sand Tornado", desc: "Sand spins up a swaying funnel, then settles" },
        { key: "instant", family: "instant", title: "Instant", desc: "No transition, a straight swap" }
    ]

    function transitionInfo(key) {
        for (let i = 0; i < transitions.length; i++)
            if (transitions[i].key === key)
                return transitions[i];
        return transitions[0];
    }

    // Styles saved by the Wallpaper Transitions mod, mapped to skwd's.
    function migrateStyle(style) {
        const map = {
            circleOut: "iris",
            circleIn: "circle-crop",
            slideLeft: "directional",
            slideRight: "directional",
            slideUp: "directional",
            slideDown: "directional",
            zoomFade: "zoom-blur-pull",
            pulse: "soft-warp-fade",
            none: "instant"
        };
        if (map[style])
            return map[style];
        for (let i = 0; i < transitions.length; i++)
            if (transitions[i].key === style)
                return style;
        return "random";
    }

    // ── what each screen shows ─────────────────────────────────────────
    readonly property var desired: {
        const m = root.manager;
        const out = {};
        if (!m)
            return out;
        const per = m.perScreenWallpapers || {};
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            const name = screens[i].name;
            const file = per[name] || m.currentWallpaper || "";
            if (file)
                out[name] = file;
        }
        return out;
    }

    // The palette Ambxst's tint shader uses (VideoWallpaper.optimizedPalette).
    readonly property var tintRoles: ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]
    readonly property var tintPalette: tintRoles.map(r => {
        const c = Colors[r];
        if (c === undefined || c === null)
            return null;
        const hex = v => ("0" + Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)).slice(-2);
        return "#" + hex(c.r) + hex(c.g) + hex(c.b);
    }).filter(h => h !== null)
    readonly property string tintKey: tintPalette.join(",")
    readonly property string tintDir: Quickshell.env("HOME") + "/.cache/ambxst/skwd-tint"
    readonly property string effectsBin: source === "local" ? localRoot + "/current/bin/skwd-wall-effects" : "skwd-wall-effects"
    property var tintSources: ({})      // tinted copy -> the wallpaper it was made from

    function tintedPath(file) {
        const ext = String(file).toLowerCase().split('.').pop();
        return tintDir + "/" + Qt.md5(file + "|" + tintKey) + (ext === "jpg" || ext === "jpeg" ? ".jpg" : ".png");
    }

    // What skwd should show on each screen: the wallpaper, or its tinted copy.
    readonly property var shown: {
        const out = {};
        const map = {};
        for (const n in desired) {
            const f = desired[n];
            if (tint && !isMoving(f)) {
                const t = tintedPath(f);
                map[t] = f;
                out[n] = t;
            } else {
                out[n] = f;
            }
        }
        root.tintSources = map;
        return out;
    }
    onShownChanged: syncDebounce.restart()

    // skwd-helm apply, making the tinted copy first when it does not exist yet.
    function applyCommand(file, output) {
        const src = tintSources[file];
        if (!src)
            return output ? [root.helm, "apply", file, "-o", output] : [root.helm, "apply", file];
        const params = JSON.stringify({ palette: tintPalette });
        return ["sh", "-c",
            'mkdir -p "$1" && find "$1" -type f -mmin +30 -delete 2>/dev/null; '
            + '[ -s "$2" ] || "$3" render --input "$4" --effect theme --params "$5" --output "$2" >/dev/null || exit 70; '
            + 'if [ -n "$7" ]; then exec "$6" apply "$2" -o "$7"; else exec "$6" apply "$2"; fi',
            "sh", tintDir, file, effectsBin, src, params, root.helm, output || ""];
    }

    property var applied: ({})          // screen name -> file skwd was last told to show
    property bool daemonUp: false
    property bool started: false        // this service started the daemon and owns stopping it

    function isMoving(path) {
        if (!path)
            return false;
        const ext = String(path).toLowerCase().split('.').pop();
        return videoExtensions.indexOf(ext) !== -1;
    }

    // Asked by VideoWallpaper before it plays `path` itself.
    function offloads(path) {
        return active && isMoving(path);
    }

    onDesiredChanged: syncDebounce.restart()

    // ── pausing ─────────────────────────────────────────────────────────
    // A screen showing a video pauses while a window covers it on the
    // workspace actually shown there (an open special workspace counts, a
    // hidden one does not). Game mode pauses every screen. Mode: fullscreen |
    // maximized (also a window filling the screen) | never. Scope: perScreen
    // pauses only that screen, allScreens pauses every screen.
    function coveredScreen(name) {
        const mons = AxctlService.monitors.values || [];
        const mon = mons.find(m => m.name === name);
        if (!mon)
            return false;
        const ws = mon.visibleWorkspace ? mon.visibleWorkspace.id : (mon.activeWorkspace ? mon.activeWorkspace.id : 0);
        const area = mon.width * mon.height;
        return (AxctlService.clients.values || []).some(c => {
            if (c.monitor !== mon.id || !c.workspace || c.workspace.id !== ws || c.hidden)
                return false;
            if (c.fullscreen)
                return true;
            return pauseMode === "maximized" && c.size && area > 0 && (c.size[0] * c.size[1]) >= area * 0.9;
        });
    }
    readonly property var pauses: {
        const out = {};
        const names = Object.keys(desired).filter(n => isMoving(desired[n]));
        // Ambxst's game mode pauses every video wallpaper, whatever the mode.
        if (GameModeClient.toggled) {
            names.forEach(n => out[n] = true);
            return out;
        }
        if (pauseMode === "never")
            return out;
        const wants = {};
        names.forEach(n => wants[n] = coveredScreen(n));
        const any = names.some(n => wants[n]);
        names.forEach(n => {
            if (pauseScope === "allScreens" ? any : wants[n])
                out[n] = true;
        });
        return out;
    }
    property var pauseSent: ({})        // output (or "*") -> paused state skwd was last told
    onPausesChanged: pauseDebounce.restart()

    Timer {
        id: pauseDebounce
        interval: 250
        onTriggered: root.sendPauses()
    }

    function sendPauses() {
        if (!active || !daemonUp)
            return;
        const names = Object.keys(desired).filter(n => isMoving(desired[n]));
        if (pauseScope === "allScreens") {
            const want = names.length > 0 && names.every(n => pauses[n] === true);
            if (pauseSent["*"] !== want)
                setPaused("*", want);
            return;
        }
        if (pauseSent["*"] === true)
            setPaused("*", false);
        names.forEach(n => {
            const want = pauses[n] === true;
            // Unpaused screens are only told when they were paused before:
            // a per-screen message makes skwd give each screen its own player.
            if ((pauseSent[n] === true) !== want)
                setPaused(n, want);
        });
    }

    // skwd-helm has no per-output pause; the daemon's RPC does (wall.set_paused).
    function setPaused(output, paused) {
        const next = Object.assign({}, pauseSent);
        next[output] = paused;
        pauseSent = next;
        const req = JSON.stringify({ jsonrpc: "2.0", id: 1, method: "wall.set_paused", params: { paused: paused, output: output } });
        run(["python3", "-c", "import os,socket,sys\ns=socket.socket(socket.AF_UNIX)\ns.settimeout(5)\ns.connect(os.environ.get('SKWD_WALL_V2_SOCK') or os.path.join(os.environ.get('XDG_RUNTIME_DIR','/tmp'),'skwd-wall-v2','wall.sock'))\ns.sendall(sys.argv[1].encode()+b'\\n')\nr=s.makefile().readline()\nsys.exit(1 if '\"error\"' in r else 0)", req], code => {
            if (code !== 0) {
                const again = Object.assign({}, root.pauseSent);
                delete again[output];
                root.pauseSent = again;
                console.warn("SkwdWall: could not", paused ? "pause" : "resume", output);
            }
        });
    }
    onActiveChanged: {
        syncDebounce.restart();
        if (active)
            writeSkwdConfig();
    }
    // Turning it back on gives skwd another chance after a failure.
    onEnabledChanged: if (enabled) failed = false

    Timer {
        id: syncDebounce
        interval: 300
        onTriggered: root.sync()
    }

    function sync() {
        if (!manager)
            return;
        if (!active) {
            if (started)
                stopDaemon();
            return;
        }
        if (!daemonUp) {
            startDaemon(0);
            return;
        }
        // The same file on every screen: one apply for all outputs, so skwd
        // decodes it once and shares the frames. Different files: per output.
        const names = Object.keys(shown);
        const files = names.map(n => shown[n]);
        const same = names.length > 0 && files.every(f => f === files[0]);
        if (same) {
            if (names.some(n => applied[n] !== files[0]))
                applyAll(files[0]);
            return;
        }
        for (const name in shown) {
            if (applied[name] !== shown[name])
                applyTo(name, shown[name]);
        }
    }

    function applyAll(file) {
        const next = {};
        for (const n in shown)
            next[n] = file;
        applied = next;
        run(applyCommand(file, ""), code => {
            if (code === 0)
                return;
            root.applied = ({});
            if (code === 3) {
                root.daemonUp = false;
                root.startDaemon(0);
                return;
            }
            console.warn("SkwdWall: skwd-helm apply failed with exit code", code, "for", file, "- Ambxst draws wallpapers itself");
            root.failed = true;
            root.stopDaemon();
        });
    }

    function applyTo(screenName, file) {
        const next = Object.assign({}, applied);
        next[screenName] = file;
        applied = next;
        run(applyCommand(file, screenName), code => {
            if (code === 0)
                return;
            const again = Object.assign({}, root.applied);
            delete again[screenName];
            root.applied = again;
            // Exit 3: the daemon is not answering (stopped, or still starting).
            if (code === 3) {
                root.daemonUp = false;
                root.startDaemon(0);
                return;
            }
            console.warn("SkwdWall: skwd-helm apply failed with exit code", code, "for", screenName, file, "- Ambxst draws wallpapers itself");
            root.failed = true;
            root.stopDaemon();
        });
    }

    property int startAttempts: 0
    function startDaemon(attempt) {
        if (attempt === 0 && startAttempts > 8) {
            console.warn("SkwdWall: skwd-walld keeps failing - Ambxst draws wallpapers itself");
            failed = true;
            stopDaemon();
            return;
        }
        startAttempts++;
        started = true;
        writeSkwdConfig();
        run(["systemctl", "--user", "start", root.unit], code => {
            if (code !== 0) {
                console.warn("SkwdWall: could not start", root.unit, "(exit", code + ") - Ambxst draws wallpapers itself");
                root.failed = true;
                root.started = false;
                return;
            }
            daemonWait.attempt = attempt;
            daemonWait.restart();
        });
    }

    Timer {
        id: daemonWait
        property int attempt: 0
        interval: 700
        onTriggered: root.readCurrent(attempt)
    }

    // skwd restores its own last wallpapers on start: read what it shows so
    // nothing is applied twice, then bring every screen in line.
    function readCurrent(attempt) {
        run([root.helm, "current"], (code, out) => {
            if (code === 3) {
                if (attempt < 10) {
                    daemonWait.attempt = attempt + 1;
                    daemonWait.restart();
                } else {
                    console.warn("SkwdWall: skwd-walld did not answer - Ambxst draws wallpapers itself");
                    root.failed = true;
                    root.stopDaemon();
                }
                return;
            }
            const seen = {};
            if (code === 0) {
                String(out).split("\n").forEach(line => {
                    const tab = line.indexOf("\t");
                    if (tab > 0)
                        seen[line.substring(0, tab)] = line.substring(tab + 1).trim();
                });
            }
            // skwd restores what it showed, possibly as one renderer per output.
            // With the same file everywhere, apply it once more for all outputs
            // so it is decoded once.
            const files = Object.keys(root.shown).map(n => root.shown[n]);
            const same = files.length > 1 && files.every(f => f === files[0]);
            root.applied = same ? ({}) : seen;
            root.daemonUp = true;
            root.startAttempts = 0;
            root.pauseSent = ({});
            pauseDebounce.restart();
            root.sync();
        });
    }

    function stopDaemon() {
        started = false;
        daemonUp = false;
        pauseSent = ({});
        applied = ({});
        run(["systemctl", "--user", "stop", root.unit], null);
    }

    // ── settings → skwd's config.json ──────────────────────────────────
    readonly property string transitionStyle: migrateStyle(GlobalStates.wallpaperTransitionStyle)
    readonly property int transitionDuration: Math.max(50, Math.min(10000, GlobalStates.wallpaperTransitionDuration))
    readonly property string pauseMode: GlobalStates.wallpaperPauseMode
    readonly property string pauseScope: GlobalStates.wallpaperPauseScope
    onTransitionStyleChanged: configDebounce.restart()
    onTransitionDurationChanged: configDebounce.restart()
    onPauseModeChanged: configDebounce.restart()
    onPauseScopeChanged: configDebounce.restart()

    Timer {
        id: configDebounce
        interval: 250
        onTriggered: root.writeSkwdConfig()
    }

    function writeSkwdConfig() {
        if (!available)
            return;
        skwdConfig.reload();
        let cfg = {};
        try {
            const text = skwdConfig.text();
            if (text && text.trim().length > 0)
                cfg = JSON.parse(text);
        } catch (e) {
            // A config skwd itself cannot read either: leave it alone.
            console.warn("SkwdWall: could not read skwd's config.json, not changing it:", e);
            return;
        }
        const before = JSON.stringify(cfg);
        function put(path, value) {
            const parts = path.split(".");
            let node = cfg;
            for (let i = 0; i < parts.length - 1; i++) {
                if (typeof node[parts[i]] !== "object" || node[parts[i]] === null || Array.isArray(node[parts[i]]))
                    node[parts[i]] = {};
                node = node[parts[i]];
            }
            node[parts[parts.length - 1]] = value;
        }
        const instant = transitionStyle === "instant";
        put("transition.enabled", !instant);
        if (!instant)
            put("transition.shader", transitionStyle);
        put("transition.durationMs", transitionDuration);
        // Pausing is decided here (see `pauses`), not by skwd: on Hyprland its
        // window watcher cannot see workspaces, so a fullscreen window parked
        // on a hidden (special) workspace paused that screen's video for good.
        put("playback.fullscreen", false);
        put("playback.maximized", false);
        put("playback.fullscreenScope", pauseScope === "allScreens" ? "all" : "display");
        if (JSON.stringify(cfg) === before)
            return;
        skwdConfig.setText(JSON.stringify(cfg, null, 2) + "\n");
    }

    FileView {
        id: skwdConfig
        path: Quickshell.env("HOME") + "/.config/skwd-wall-v2/config.json"
        blockLoading: true
        printErrors: false
    }

    // ── a small queue: one skwd-helm / systemctl call at a time ────────
    property var queue: []
    function run(command, onDone) {
        queue = queue.concat([{
                command: command,
                onDone: onDone
            }]);
        runNext();
    }
    function runNext() {
        if (queue.length === 0 || runner.running || runner.job)
            return;
        const job = queue[0];
        queue = queue.slice(1);
        runner.job = job;
        runner.exited = false;
        runner.outDone = false;
        runner.command = job.command;
        runner.running = true;
    }

    // A job finishes once the process has exited AND its output is read.
    Process {
        id: runner
        property var job: null
        property int exitCode: -1
        property bool exited: false
        property bool outDone: false
        stdout: StdioCollector {
            id: runnerOut
            onStreamFinished: {
                runner.outDone = true;
                runner.finish();
            }
        }
        onExited: (code, exitStatus) => {
            runner.exitCode = code;
            runner.exited = true;
            runner.finish();
        }
        function finish() {
            if (!exited || !outDone || !job)
                return;
            const done = job;
            job = null;
            if (done.onDone)
                done.onDone(exitCode, runnerOut.text);
            Qt.callLater(root.runNext);
        }
    }

    // Which skwd? Checked at start and after an install.
    function detect() {
        detectTimer.restart();
    }
    // Restarted on the next turn: switching `running` off and on in one go
    // does not start the process again.
    Timer {
        id: detectTimer
        interval: 50
        onTriggered: {
            if (probe.running) {
                restart();
                return;
            }
            probe.running = true;
        }
    }
    Process {
        id: probe
        // `source` option: "auto" prefers a system install, "local" always uses
        // Ambxst's own copy (installing it if needed).
        running: false   // started once the options are read (see `options`)
        command: ["sh", "-c", "local_ok() { [ -x \"$HOME/.local/share/ambxst/skwd-wall/current/bin/skwd-helm\" ]; }; " + (options.adapter.source === "local" ? "if local_ok; then echo local; else echo none; fi" : "if command -v skwd-helm >/dev/null && command -v skwd-walld >/dev/null; then echo system; elif local_ok; then echo local; else echo none; fi")]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.trim() || "none";
                const was = root.source;
                if (found !== was)
                    console.log("SkwdWall: using", found === "system" ? "the system's skwd-wall" : found === "local" ? "the copy in ~/.local/share/ambxst/skwd-wall" : "nothing (skwd-wall is not installed)");
                // Switching between the system's daemon and Ambxst's own: the
                // other one stops first (two would fight over the outputs).
                const oldUnit = was === "local" ? "ambxst-skwd-walld.service" : "skwd-walld.service";
                if ((was === "system" || was === "local") && was !== found && root.started) {
                    root.started = false;
                    root.daemonUp = false;
                    root.applied = ({});
                    root.run(["systemctl", "--user", "stop", oldUnit], null);
                }
                root.source = found;
                if (found === "none") {
                    console.log("SkwdWall: skwd-wall is not installed; Ambxst draws wallpapers itself until it is (Wallpapers > settings)");
                    root.checkLatest();
                    if (!options.adapter.installPrompted) {
                        options.adapter.installPrompted = true;
                        Quickshell.execDetached(["notify-send", "-a", "Ambxst", "skwd-wall", "skwd-wall is not installed yet. Open the Wallpapers tab, press the gear and choose Install skwd-wall."]);
                    }
                    return;
                }
                if (found === "local")
                    root.checkLatest();
                // A daemon left running by an earlier shell (a reload) is ours too.
                root.run(["systemctl", "--user", "is-active", "--quiet", root.unit], code => {
                    if (code === 0)
                        root.started = true;
                    syncDebounce.restart();
                });
                if (was !== found && found !== "none")
                    root.writeSkwdConfig();
            }
        }
    }

    // ── installing and updating Ambxst's own copy ──────────────────────
    property string installState: "idle"     // idle | running | done | failed
    property string installStep: ""
    property string installError: ""
    property var missingLibs: []              // [{ lib, pkg }]
    property string installedVersion: ""
    property string latestVersion: ""
    readonly property bool updateAvailable: source === "local" && latestVersion !== "" && installedVersion !== "" && latestVersion !== installedVersion

    function checkLatest() {
        if (!statusProc.running)
            statusProc.running = true;
    }
    Process {
        id: statusProc
        command: ["bash", root.installer, "status"]
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("VERSION "))
                    root.installedVersion = line.substring(8).trim();
                else if (line.startsWith("LATEST "))
                    root.latestVersion = line.substring(7).trim();
            }
        }
    }

    function install() {
        if (installProc.running || source === "system")
            return;
        installState = "running";
        installStep = "Starting";
        installError = "";
        missingLibs = [];
        installProc.running = true;
    }
    Process {
        id: installProc
        command: ["bash", root.installer, "install"]
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("STEP ")) {
                    root.installStep = line.substring(5);
                } else if (line.startsWith("MISSING ")) {
                    const parts = line.substring(8).split(" ");
                    root.missingLibs = root.missingLibs.concat([{
                            lib: parts[0],
                            pkg: parts[1] || "?"
                        }]);
                } else if (line.startsWith("DONE ")) {
                    root.installedVersion = line.substring(5).trim();
                    root.installState = "done";
                } else if (line.startsWith("FAIL ")) {
                    root.installError = line.substring(5);
                    root.installState = "failed";
                }
            }
        }
        onExited: code => {
            if (root.installState === "running") {
                root.installState = code === 0 ? "done" : "failed";
                if (code !== 0 && !root.installError)
                    root.installError = "the installer stopped (exit " + code + ")";
            }
            if (root.installState !== "done")
                return;
            // An update of a running copy: restart it on the new version.
            if (root.source === "local" && root.started) {
                root.daemonUp = false;
                root.applied = ({});
                root.run(["systemctl", "--user", "restart", root.unit], () => {
                    daemonWait.attempt = 0;
                    daemonWait.restart();
                });
            }
            root.failed = false;
            root.startAttempts = 0;
            root.detect();
        }
    }

    FileView {
        id: options
        path: Quickshell.env("HOME") + "/.config/ambxst/skwd-wall.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // Which skwd to use depends on `source`, so look only once it is read.
        onLoaded: if (root.source === "unknown") root.detect()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
            if (root.source === "unknown")
                root.detect();
        }

        adapter: JsonAdapter {
            property bool enabled: true
            property bool installPrompted: false
            property string source: "auto"
        }
        // A change of `source` picks the daemon again.
        property string watchedSource: adapter.source
        onWatchedSourceChanged: if (root.source !== "unknown") root.detect()
    }
}
