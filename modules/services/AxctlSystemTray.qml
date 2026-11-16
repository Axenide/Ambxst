pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services

Singleton {
    id: root

    property list<var> items: []
    property bool ready: false

    Connections {
        target: AxctlBackend
        function onEventReceived(service, _data) {
            if (service === "tray.changed" || service === "tray.removed")
                root.loadItems();
        }
    }

    function call(method, params, callback) {
        AxctlBackend.call(method, params || {}, callback);
    }

    function loadItems(callback) {
        call("Tray.List", {}, (entries, error) => {
            if (error) {
                console.warn("AxctlSystemTray: failed to list tray items:", error);
                if (callback) callback([], error);
                return;
            }
            const names = [...new Set((entries || []).map(item => item.iconName).filter(Boolean))];
            call("Icon.ResolveMany", {names: names, size: 48, scale: 1}, (paths, iconError) => {
                if (iconError) console.warn("AxctlSystemTray: failed to resolve tray icons:", iconError);
                root.items = (entries || []).map(item => Object.assign({}, item, {
                    iconPath: item.iconPath || (paths || {})[item.iconName] || "",
                    hasMenu: !!item.menu || item.itemIsMenu
                }));
                root.ready = true;
                if (callback) callback(root.items, "");
            });
        });
    }

    function activate(id, callback) {
        call("Tray.Activate", {id: id}, callback);
    }

    function secondaryActivate(id, callback) {
        call("Tray.SecondaryActivate", {id: id}, callback);
    }

    function contextMenu(id, x, y, callback) {
        call("Tray.ContextMenu", {id: id, x: x || 0, y: y || 0}, callback);
    }

    function scroll(id, delta, orientation) {
        call("Tray.Scroll", {id: id, delta: delta, orientation: orientation || "vertical"});
    }

    function loadMenu(id, callback) {
        call("Tray.Menu", {id: id}, (result, error) => {
            if (error) {
                if (callback) callback([], error);
                return;
            }
            const items = result?.items || [];
            const iconNames = [];
            const collect = nodes => {
                for (let i = 0; i < nodes.length; i++) {
                    if (nodes[i].iconName) iconNames.push(nodes[i].iconName);
                    collect(nodes[i].children || []);
                }
            };
            collect(items);
            const names = [...new Set(iconNames)];
            call("Icon.ResolveMany", {names: names, size: 32, scale: 1}, (paths, iconError) => {
                if (iconError) console.warn("AxctlSystemTray: failed to resolve menu icons:", iconError);
                const mapIcons = nodes => nodes.map(item => Object.assign({}, item, {
                    iconPath: item.iconData || (paths || {})[item.iconName] || (item.iconName ? "image://icon/" + item.iconName : ""),
                    children: mapIcons(item.children || [])
                }));
                if (callback) callback(mapIcons(items), "");
            });
        });
    }

    function menuEvent(id, menuId, event) {
        call("Tray.MenuEvent", {id: id, menuId: menuId, event: event || "clicked"});
    }

    Component.onCompleted: {
        root.loadItems();
    }
}
