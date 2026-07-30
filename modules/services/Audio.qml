pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.modules.services
import qs.modules.theme

/**
 * Default Pipewire audio sink/source wrapper.
 * Handles volume, mute, app nodes, and devices.
 *
 * macOS-style volume curve: slider_to_gain uses a 40 dB exponential
 * range (0.01–1.0 linear gain), so each of the 16 grid steps adds
 * exactly 2.5 dB — equal perceptual loudness per tick.
 *
 * Includes "ear-bang" protection against volume spikes.
 */
Singleton {
    id: root

    property bool ready: Pipewire.defaultAudioSink?.ready ?? false
    property PwNode sink: Pipewire.defaultAudioSink
    property PwNode source: Pipewire.defaultAudioSource
    readonly property real hardMaxValue: 2.00
    property real value: sink?.audio?.volume ?? 0

    // macOS 16-step grid constants
    readonly property real gridSteps: 16
    readonly property real tick: 1.0 / 16           // 0.0625
    readonly property real fineTick: 1.0 / 64       // 0.015625 (quarter-step)

    // Volume protection (persisted)
    property bool protectionEnabled: true
    readonly property real maxVolumeJump: 0.15  // 15% max jump in slider-space
    property bool protectionTriggered: false

    // Load state
    Connections {
        target: StateService
        function onStateLoaded() {
            root.protectionEnabled = StateService.get("volumeProtectionEnabled", true);
        }
    }

    // Persist protection
    function setProtectionEnabled(enabled: bool) {
        root.protectionEnabled = enabled;
        StateService.set("volumeProtectionEnabled", enabled);
    }

    signal sinkProtectionTriggered(string reason);
    signal volumeChanged(real volume, bool muted, var node);
    signal micVolumeChanged(real volume, bool muted, var node);

    PwObjectTracker {
        objects: [sink, source]
    }

    // Volume signals for OSD
    Connections {
        target: root.sink?.audio ?? null
        ignoreUnknownSignals: true
        function onVolumeChanged() {
            if (root.sink?.ready) {
                root.volumeChanged(root.sink.audio.volume, root.sink.audio.muted, root.sink);
            }
        }
        function onMutedChanged() {
            if (root.sink?.ready) {
                root.volumeChanged(root.sink.audio.volume, root.sink.audio.muted, root.sink);
            }
        }
    }

    Connections {
        target: root.source?.audio ?? null
        ignoreUnknownSignals: true
        function onVolumeChanged() {
            if (root.source?.ready) {
                root.micVolumeChanged(root.source.audio.volume, root.source.audio.muted, root.source);
            }
        }
        function onMutedChanged() {
            if (root.source?.ready) {
                root.micVolumeChanged(root.source.audio.volume, root.source.audio.muted, root.source);
            }
        }
    }

    // Helpers
    function friendlyDeviceName(node) {
        return (node?.nickname || node?.description || "Unknown");
    }

    function appNodeDisplayName(node) {
        return (node?.properties?.["application.name"] || node?.description || node?.name || "Unknown");
    }

    // Node filters
    function correctType(node, isSink) {
        return (node?.isSink === isSink) && node?.audio;
    }

    function appNodes(isSink) {
        return Pipewire.nodes.values.filter((node) => {
            return root.correctType(node, isSink) && node.isStream;
        });
    }

    function devices(isSink) {
        return Pipewire.nodes.values.filter(node => {
            return root.correctType(node, isSink) && !node.isStream;
        });
    }

    // IO lists
    readonly property list<var> outputAppNodes: root.appNodes(true)
    readonly property list<var> inputAppNodes: root.appNodes(false)
    readonly property list<var> outputDevices: root.devices(true)
    readonly property list<var> inputDevices: root.devices(false)

    // ── macOS volume curve ──────────────────────────────────────────

    // Maps perceptual slider position (0-1) to linear gain.
    // 40 dB range: each of the 16 steps adds exactly 2.5 dB.
    // gain = 10 ^ (minDB * (1 - slider) / 20)
    // slider 0 → gain 0.01  (−40 dB)
    // slider 1 → gain 1.00  ( 0 dB)
    function sliderToGain(sliderValue: real): real {
        const v = Math.max(0, Math.min(1, sliderValue));
        const minDB = -40;
        const dB = minDB * (1 - v);
        return Math.pow(10, dB / 20);
    }

    // Reverse: linear gain → perceptual slider position (0-1).
    // Clamped so gain values above 1.0 map to slider 1.0.
    function gainToSlider(gain: real): real {
        if (gain <= 0.001) return 0;
        if (gain >= 1.0) return 1.0;
        const minDB = -40;
        const dB = 20 * Math.log10(gain);
        return Math.max(0, Math.min(1, 1 - dB / minDB));
    }

    // ── Volume jump limiter (applied in gain-space) ─────────────────

    function protectedSetVolume(node, targetGain: real, currentGain: real) {
        if (!root.protectionEnabled) {
            return targetGain;
        }

        const jump = targetGain - currentGain;

        if (jump <= 0) {
            root.protectionTriggered = false;
            return targetGain;
        }

        if (jump > root.maxVolumeJump) {
            root.protectionTriggered = true;
            root.sinkProtectionTriggered("Volume jump limited");
            protectionResetTimer.restart();
            return currentGain + root.maxVolumeJump;
        }

        root.protectionTriggered = false;
        return targetGain;
    }

    Timer {
        id: protectionResetTimer
        interval: 1500
        onTriggered: root.protectionTriggered = false
    }

    // ── Controls ──────────────────────────────────────────────────

    function toggleMute() {
        if (sink?.audio) {
            sink.audio.muted = !sink.audio.muted;
        }
    }

    function toggleMicMute() {
        if (source?.audio) {
            source.audio.muted = !source.audio.muted;
        }
    }

    // Perceptual slider-based helpers (macOS grid)
    function currentSlider(): real {
        return sink?.audio ? gainToSlider(sink.audio.volume) : 0;
    }

    function incrementVolume() {
        if (sink?.audio) {
            const newSlider = Math.min(1, currentSlider() + tick);
            const targetGain = sliderToGain(newSlider);
            const currentGain = sink.audio.volume;
            const safeGain = protectedSetVolume(sink, targetGain, currentGain);
            sink.audio.volume = Math.max(0, Math.min(hardMaxValue, safeGain));
        }
    }

    function decrementVolume() {
        if (sink?.audio) {
            const newSlider = Math.max(0, currentSlider() - tick);
            const targetGain = sliderToGain(newSlider);
            const currentGain = sink.audio.volume;
            const safeGain = protectedSetVolume(sink, targetGain, currentGain);
            sink.audio.volume = Math.max(0, Math.min(hardMaxValue, safeGain));
        }
    }

    // Master output: accepts a perceptual slider position (0-1).
    function setVolume(sliderValue: real) {
        if (sink?.audio) {
            const targetGain = sliderToGain(sliderValue);
            const currentGain = sink.audio.volume;
            const safeGain = protectedSetVolume(sink, targetGain, currentGain);
            sink.audio.volume = Math.max(0, Math.min(hardMaxValue, safeGain));
        }
    }

    // Mic input: maps perceptual slider → gain.
    function setMicVolume(sliderValue: real) {
        if (source?.audio) {
            const gain = sliderToGain(sliderValue);
            source.audio.volume = Math.max(0, Math.min(hardMaxValue, gain));
        }
    }

    // Per-app node: maps perceptual slider → gain.
    function setNodeVolume(node, sliderValue: real) {
        if (node?.audio) {
            const targetGain = sliderToGain(sliderValue);
            const currentGain = node.audio.volume;
            const safeGain = protectedSetVolume(node, targetGain, currentGain);
            node.audio.volume = Math.max(0, Math.min(hardMaxValue, safeGain));
        }
    }

    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    // Icon helper
    function volumeIcon(volume: real, muted: bool): string {
        if (muted) return Icons.speakerX;
        if (volume <= 0) return Icons.speakerNone;
        if (volume < 0.33) return Icons.speakerLow;
        return Icons.speakerHigh;
    }
}
