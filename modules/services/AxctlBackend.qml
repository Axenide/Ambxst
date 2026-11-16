pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.services

Singleton {
    id: root

    property list<var> applications: []
    property bool applicationsReady: false
    property var iconPaths: ({})
    property int applicationLoadSerial: 0
    property int requestSerial: 0
    property int subscriptionHandle: -1

    signal eventReceived(string service, var data)

    function call(method, params, callback) {
        BackendService.call("axctl.call", {
            method: method,
            params: params || {}
        }, callback);
    }

    function loadApplications(callback) {
        const serial = ++root.applicationLoadSerial;
        call("Application.Top", {limit: 0}, (entries, error) => {
            if (serial !== root.applicationLoadSerial) return;
            if (error) {
                console.warn("AxctlBackend: failed to list applications:", error);
                if (callback) callback([], error);
                return;
            }
            const names = [...new Set((entries || []).map(entry => entry.icon).filter(icon => !!icon))];
            call("Icon.ResolveMany", {
                names: names,
                size: 48,
                scale: 1
            }, (paths, iconError) => {
                if (serial !== root.applicationLoadSerial) return;
                if (iconError) console.warn("AxctlBackend: failed to resolve application icons:", iconError);
                root.iconPaths = Object.assign({}, root.iconPaths, paths || {});
                const mapped = (entries || []).map(entry => root.mapApplication(entry));
                root.applications = mapped;
                root.applicationsReady = true;
                if (callback) callback(mapped, "");
            });
        });
    }

    function searchApplications(query, callback) {
        const serial = ++root.requestSerial;
        call("Application.Search", {
            query: query,
            limit: 10
        }, (entries, error) => {
            if (serial !== root.requestSerial) return;
            if (error) {
                console.warn("AxctlBackend: application search failed:", error);
                if (callback) callback([], error);
                return;
            }
            const names = [...new Set((entries || []).map(entry => entry.icon).filter(icon => !!icon))];
            call("Icon.ResolveMany", {names: names, size: 48, scale: 1}, (paths, iconError) => {
                if (serial !== root.requestSerial) return;
                if (iconError) console.warn("AxctlBackend: failed to resolve search icons:", iconError);
                root.iconPaths = Object.assign({}, root.iconPaths, paths || {});
                if (callback) callback((entries || []).map(entry => root.mapApplication(entry)), "");
            });
        });
    }

    function mapApplication(entry) {
        const icon = entry.icon || "application-x-executable";
        return Object.assign({}, entry, {
            icon: icon,
            iconPath: root.iconPaths[icon] || "image://icon/" + icon,
            execString: entry.exec || "",
            runInTerminal: entry.terminal === true,
            execute: function () { root.launchApplication(entry.id); }
        });
    }

    function resolveIcon(name, size, callback) {
        if (!name) {
            if (callback) callback("");
            return;
        }
        if (Object.prototype.hasOwnProperty.call(root.iconPaths, name)) {
            if (callback) callback(root.iconPaths[name] || "");
            return;
        }
        call("Icon.Resolve", {name: name, size: size || 48, scale: 1}, (result, error) => {
            if (error) {
                if (callback) callback("");
                return;
            }
            const path = result?.path || "";
            root.iconPaths[name] = path;
            root.iconPaths = Object.assign({}, root.iconPaths);
            if (callback) callback(path);
        });
    }

    function launchApplication(id, actionId, uris, callback) {
        call("Application.Launch", {
            id: id,
            actionId: actionId || "",
            uris: uris || []
        }, (result, error) => {
            if (error) console.warn("AxctlBackend: application launch failed:", error);
            else root.loadApplications();
            if (callback) callback(result, error);
        });
    }

    Component.onCompleted: {
        subscriptionHandle = BackendService.addSubscription(["axctl"], (service, data) => {
            if (service === "applications.changed") root.loadApplications();
            root.eventReceived(service, data);
        });
        Qt.callLater(() => root.loadApplications());
    }

    Component.onDestruction: {
        if (subscriptionHandle >= 0) BackendService.removeSubscription(subscriptionHandle);
    }
}
