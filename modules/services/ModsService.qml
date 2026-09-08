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
    property string statusMessageKey: ""
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
        // The backend owns this flag. Latching it to true locally kept the
        // restart banner on screen after the daemon had already cleared it.
        root.restartRequired = result?.restartRequired ?? false;
        root.loaded = true;
    }

    function request(method, params, successMessage, requiresRestart, onSuccess) {
        if (root.busy)
            return;
        root.busy = true;
        root.errorMessage = "";
        root.statusMessage = "";
        root.statusMessageKey = "";
        BackendService.call(method, params ?? {}, (result, error) => {
            root.busy = false;
            if (error) {
                root.errorMessage = String(error);
                return;
            }
            root.applyStatus(result);
            root.statusMessageKey = successMessage ?? "";
            if (requiresRestart && (result?.restartRequired === undefined))
                root.restartRequired = true;
            if (onSuccess)
                onSuccess(result);
        });
    }

    function refresh() {
        root.request("mods.status", {}, "", false);
    }

    function install(source) {
        root.request("mods.install", { source }, "mods.status_installed", false,
            () => root.installed(source));
    }

    function installDependencies(id) {
        root.request("mods.installDependencies", { id }, "mods.status_dependencies_installed", true);
    }

    function setEnabled(id, enabled) {
        root.request("mods.setEnabled", { id, enabled }, enabled ? "mods.status_enabled" : "mods.status_disabled", true);
    }

    function update(id, enabled) {
        root.request("mods.update", { id }, "mods.status_updated", enabled);
    }

    function remove(id, enabled) {
        root.request("mods.remove", { id }, "mods.status_removed", enabled);
    }

    function move(id, direction) {
        root.request("mods.move", { id, direction }, "mods.status_order_updated", root.activeGeneration !== "");
    }

    function moveTo(id, position) {
        root.request("mods.move", { id, position }, "mods.status_order_updated", root.activeGeneration !== "");
    }

    function rebuild() {
        root.request("mods.rebuild", {}, "mods.status_rebuilt", true);
    }

    function rollback() {
        root.request("mods.rollback", {}, "mods.status_rolled_back", true);
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
            root.statusMessageKey = "mods.status_setting_saved";
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
