pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io

// PresetCommandService subscribes to the "preset" IPC service and forwards
// `preset.load` events into the existing PresetsService. Listing is
// answered server-side (in the Go daemon), so no QML work is required
// there.
//
// This file is part of the modules/services dir, but it can't import the
// `qs.modules.services` namespace from inside itself — Quickshell treats
// that as a self-reference during the scan-all-files phase and aborts
// the singleton resolution. The two consumers (BackendService,
// PresetsService) are referenced unqualified because the namespace is
// already flat at the call-site (we're loading this file from there).
Singleton {
    id: root

    Component.onCompleted: {
        BackendService.addSubscription(["preset"], (service, data) => {
            if (service === "preset.load" && data && typeof data.name === "string") {
                root.load(data.name);
            }
        });
    }

    function load(name) {
        if (!name) return;
        PresetsService.loadPreset(name);
    }
}
