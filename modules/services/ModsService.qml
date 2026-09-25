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
    property bool bypassVersionCheck: false
    property bool modsEnabled: true
    property string errorMessage: ""
    property string errorDetails: ""
    property string statusMessage: ""
    property string statusMessageKey: ""
    property string settingsModId: ""
    property var settingsFields: []
    property var settingsValues: ({})
    property bool settingsBusy: false

    property bool autoUpdate: false
    property bool periodicChecks: false
    property int updateIntervalHours: 24
    property var updates: ({})
    property string diagnosticText: ""
    property var compatibilityReport: null
    property int subscription: -1

    Component.onCompleted: {
        root.subscription = BackendService.addSubscription(["mods"], (service, data) => {
            Qt.callLater(() => root.applyStatus(data));
        });
    }
    Component.onDestruction: {
        if (root.subscription >= 0)
            BackendService.removeSubscription(root.subscription);
    }

    function applyStatus(result) {
        root.mods = result?.mods ?? [];
        root.basePath = result?.basePath ?? "";
        root.baseVersion = result?.baseVersion ?? "";
        root.baseRevision = result?.baseRevision ?? "";
        root.activeGeneration = result?.activeGeneration ?? "";
        root.previousGeneration = result?.previousGeneration ?? "";
        root.generationCurrent = result?.generationCurrent ?? true;
        root.generationError = result?.generationError ?? "";
        root.bypassVersionCheck = result?.bypassVersionCheck ?? false;
        root.modsEnabled = !(result?.modsDisabled ?? false);
        // The backend owns this flag. Latching it to true locally kept the
        // restart banner on screen after the daemon had already cleared it.
        root.restartRequired = result?.restartRequired ?? false;
        root.loaded = true;
        root.autoUpdate = result?.autoUpdate ?? false;
        root.periodicChecks = result?.periodicChecks ?? false;
        root.updateIntervalHours = result?.updateIntervalHours ?? 24;
        root.updates = result?.updates ?? ({});
    }

    function showError(error) {
        root.errorMessage = I18n.t("mods.operation_failed");
        root.errorDetails = String(error);
    }

    function request(method, params, successMessage, requiresRestart, onSuccess) {
        if (root.busy)
            return;
        root.busy = true;
        root.errorMessage = "";
        root.errorDetails = "";
        root.statusMessage = "";
        root.statusMessageKey = "";
        BackendService.call(method, params ?? {}, (result, error) => {
            root.busy = false;
            if (error) {
                root.showError(error);
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

    function previewArchive(source, onSuccess) {
        if (root.busy)
            return;
        root.busy = true;
        root.errorMessage = "";
        root.errorDetails = "";
        root.statusMessage = "";
        root.statusMessageKey = "";
        BackendService.call("mods.previewArchive", { source }, (result, error) => {
            root.busy = false;
            if (error) {
                root.showError(error);
                return;
            }
            if (onSuccess)
                onSuccess(result);
        });
    }

    function installArchive(source, sha256) {
        root.request("mods.installArchive", { source, sha256 }, "mods.status_installed", false,
            () => root.installed(source));
    }

    function installDependencies(id) {
        root.request("mods.installDependencies", { id }, "mods.status_dependencies_installed", true);
    }

    function setEnabled(id, enabled) {
        root.request("mods.setEnabled", { id, enabled }, enabled ? "mods.status_enabled" : "mods.status_disabled", true);
    }

    function update(id, enabled) {
        root.checkUpdates([id]);
    }

    function checkUpdates(ids, onSuccess) {
        root.request("mods.checkUpdates", { ids: ids ?? [] }, "", false, onSuccess);
    }

    function applyUpdates(planId, onSuccess) {
        root.request("mods.applyUpdates", { planId: planId ?? root.updates.planId, reviewed: true }, "mods.status_updated", false, onSuccess);
    }

    function discardUpdates() {
        root.request("mods.discardUpdates", {}, "", false);
    }

    function setUpdatePolicy(id, policy) {
        root.request("mods.setUpdatePolicy", { id, policy }, "mods.update_policy_saved", false);
    }

    function setUpdateInterval(hours) {
        root.request("mods.setUpdateInterval", { hours }, "mods.update_interval_saved", false);
    }

    function setPeriodicChecks(enabled) {
        root.request("mods.setPeriodicChecks", { enabled }, "mods.check_schedule_saved", false);
    }

    function loadDiagnostics() {
        BackendService.call("mods.diagnostics", {}, (result, error) => {
            if (error) { root.showError(error); return; }
            root.diagnosticText = result?.text ?? "";
        });
    }

    function checkCompatibility(base) {
        root.busy = true;
        root.compatibilityReport = null;
        BackendService.call("mods.checkCompatibility", { base: base ?? "" }, (result, error) => {
            root.busy = false;
            if (error) { root.showError(error); return; }
            root.compatibilityReport = result;
        });
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

    // Places a mod's Dashboard tab or bar widget apart from load order. A null
    // position returns it to its load-order place. The backend rebuilds when
    // the mod is enabled and reports whether a restart is needed.
    function setPosition(id, kind, position) {
        root.request("mods.setPosition", { id, kind, position }, "mods.status_position_updated", false);
    }

    function setMenuIndex(id, position) {
        root.request("mods.setMenuIndex", { id, position }, "mods.status_menu_index_updated", false);
    }

    function settingsMenuPosition(id) {
        const menuMods = (root.mods ?? []).filter(mod => mod.enabled && mod.hasSettingsMenu);
        const entries = root.settingsMenuEntries(menuMods);
        const positions = root.resolveSettingsMenuPositions(11 + entries.length, entries);
        const modPositions = entries.filter(entry => entry.modId === id)
            .map(entry => Number(positions[entry.id] ?? -1))
            .filter(position => position >= 0);
        return modPositions.length > 0 ? Math.min(...modPositions) : -1;
    }

    function settingsMenuEntries(menuMods) {
        const entries = [];
        for (const mod of menuMods) {
            const sections = (mod.settingsSections ?? []).length > 0
                ? mod.settingsSections : [mod.settingsSection];
            for (let index = 0; index < sections.length; index++) {
                entries.push({
                    id: mod.id + "#" + index,
                    modId: mod.id,
                    section: sections[index],
                    settingsMenuIndex: Number(mod.settingsMenuIndex ?? 0) + index,
                    order: Number(mod.order ?? 0) * 1000 + index
                });
            }
        }
        return entries;
    }

    function resolveSettingsMenuPositions(total, menuMods) {
        const occupied = new Array(total).fill(false);
        const positions = {};
        const byPriority = menuMods.slice().sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
        for (const mod of byPriority) {
            let target = Number(mod.settingsMenuIndex ?? 0);
            if (target < 0)
                target = total + target;
            target = Math.max(0, Math.min(total - 1, target));
            let slot = target;
            while (slot >= 0 && occupied[slot])
                slot--;
            if (slot < 0) {
                slot = target + 1;
                while (slot < total && occupied[slot])
                    slot++;
            }
            if (slot < total) {
                occupied[slot] = true;
                positions[mod.id] = slot;
            }
        }
        return positions;
    }

    function orderSettingsSections(sections) {
        const source = (sections ?? []).slice();
        const menuMods = (root.mods ?? []).filter(mod => mod.enabled && mod.hasSettingsMenu
            && (mod.settingsSections ?? [mod.settingsSection]).some(section => source.some(item => item.section === section)));
        if (menuMods.length === 0)
            return source;

        const entries = root.settingsMenuEntries(menuMods)
            .filter(entry => source.some(item => item.section === entry.section));
        const modSections = new Set(entries.map(entry => entry.section));
        const core = source.filter(item => !modSections.has(item.section));
        const result = new Array(source.length).fill(null);
        const positions = root.resolveSettingsMenuPositions(source.length, entries);
        for (const entry of entries)
            result[positions[entry.id]] = source.find(item => item.section === entry.section);
        let coreIndex = 0;
        for (let index = 0; index < result.length; index++) {
            if (result[index] === null)
                result[index] = core[coreIndex++];
        }
        return result;
    }

    function rebuild() {
        root.request("mods.rebuild", {}, "mods.status_rebuilt", true);
    }

    function setBypassVersionCheck(enabled) {
        root.request("mods.setBypassVersionCheck", { enabled }, "mods.status_bypass_saved", false);
    }

    function setModsEnabled(enabled) {
        // Go always serializes restartRequired (false here — no pending
        // activation), so request()'s undefined-check would never fire
        // the banner. A restart is what makes the toggle take effect.
        root.request("mods.setModsEnabled", { enabled }, "mods.status_mods_toggled", false,
            () => { root.restartRequired = true; });
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
                root.showError(error);
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
        root.errorDetails = "";
        BackendService.call("mods.setSetting", { id, key, value }, (result, error) => {
            root.settingsBusy = false;
            if (error) {
                root.showError(error);
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
