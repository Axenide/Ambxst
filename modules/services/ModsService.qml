pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    signal settingChanged(string modId, string key, var value)
    signal installed(string source)

    property var mods: []
    property string basePath: ""
    property string baseVersion: ""
    property string baseRevision: ""
    property string activeGeneration: ""
    property string previousGeneration: ""
    property bool generationCurrent: true
    property string generationError: ""
    property bool busy: false
    property bool loaded: false
    property bool restartRequired: false
    property string errorMessage: ""
    property string statusMessage: ""
    property string settingsModId: ""
    property var settingsFields: []
    property var settingsValues: ({})
    property bool settingsBusy: false

    function applyStatus(result) {
        root.mods = result?.mods ?? [];
        root.basePath = result?.basePath ?? "";
        root.baseVersion = result?.baseVersion ?? "";
        root.baseRevision = result?.baseRevision ?? "";
        root.activeGeneration = result?.activeGeneration ?? "";
        root.previousGeneration = result?.previousGeneration ?? "";
        root.generationCurrent = result?.generationCurrent ?? true;
        root.generationError = result?.generationError ?? "";
        root.loaded = true;
    }

    function request(method, params, successMessage, requiresRestart, onSuccess) {
        if (root.busy)
            return;
        root.busy = true;
        root.errorMessage = "";
        root.statusMessage = "";
        BackendService.call(method, params ?? {}, (result, error) => {
            root.busy = false;
            if (error) {
                root.errorMessage = String(error);
                return;
            }
            root.applyStatus(result);
            root.statusMessage = successMessage ?? "";
            if (result?.restartRequired ?? requiresRestart)
                root.restartRequired = true;
            if (onSuccess)
                onSuccess(result);
        });
    }

    function refresh() {
        root.request("mods.status", {}, "", false);
    }

    function install(source) {
        root.request("mods.install", { source }, "Mod installed in the disabled state.", false,
            () => root.installed(source));
    }

    function setEnabled(id, enabled) {
        root.request("mods.setEnabled", { id, enabled }, enabled ? "Mod enabled." : "Mod disabled.", true);
    }

    function update(id, enabled) {
        root.request("mods.update", { id }, "Mod updated.", enabled);
    }

    function remove(id, enabled) {
        root.request("mods.remove", { id }, "Mod removed.", enabled);
    }

    function move(id, direction) {
        root.request("mods.move", { id, direction }, "Load order updated.", root.activeGeneration !== "");
    }

    function rebuild() {
        root.request("mods.rebuild", {}, "Generation rebuilt.", true);
    }

    function rollback() {
        root.request("mods.rollback", {}, "Previous generation restored.", true);
    }

    function loadSettings(id) {
        root.settingsModId = id ?? "";
        root.settingsFields = [];
        root.settingsValues = ({});
        if (!id)
            return;
        root.settingsBusy = true;
        BackendService.call("mods.settings", { id }, (result, error) => {
            root.settingsBusy = false;
            if (root.settingsModId !== id)
                return;
            if (error) {
                root.errorMessage = String(error);
                return;
            }
            root.settingsFields = result?.fields ?? [];
            root.settingsValues = result?.values ?? ({});
        });
    }

    function getSettings(id, callback) {
        BackendService.call("mods.settings", { id }, (result, error) => {
            callback(result ?? null, error ? String(error) : "");
        });
    }

    function setSetting(id, key, value) {
        if (root.settingsBusy)
            return;
        root.settingsBusy = true;
        root.errorMessage = "";
        BackendService.call("mods.setSetting", { id, key, value }, (result, error) => {
            root.settingsBusy = false;
            if (error) {
                root.errorMessage = String(error);
                return;
            }
            root.settingsFields = result?.fields ?? [];
            root.settingsValues = result?.values ?? ({});
            root.statusMessage = "Setting saved.";
            root.settingChanged(id, key, result?.values?.[key] ?? value);
            if (result?.restartRequired)
                root.restartRequired = true;
        });
    }

    function restart() {
        root.restartRequired = false;
        Quickshell.execDetached(["ambxst", "reload"]);
    }
}
