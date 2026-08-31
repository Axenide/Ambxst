import QtQuick
import Quickshell
import qs.modules.theme

pragma Singleton

Singleton {
    id: root

    property var availableProfiles: []
    property string currentProfile: ""
    property bool isAvailable: false
    property string backendType: ""
    property int subHandle: -1

    function refresh() {
        BackendService.call("powerprofile.current", {}, (cur, cerr) => {
            if (cerr || !cur) return;
            Qt.callLater(() => {
                root.isAvailable = cur.available === true;
                root.backendType = cur.backend || "";
                root.currentProfile = cur.profile || "";
            });
        });
        BackendService.call("powerprofile.available", {}, (avail, aerr) => {
            if (aerr || !avail) return;
            Qt.callLater(() => {
                root.isAvailable = avail.available === true;
                root.backendType = avail.backend || "";
                root.availableProfiles = avail.profiles || [];
                if (!root.currentProfile && avail.profile)
                    root.currentProfile = avail.profile;
            });
        });
    }

    function setProfile(profile) {
        BackendService.call("powerprofile.set", {profile: profile});
    }

    function getProfileIcon(name) {
        if (name === "power-saver") return Icons.powerSave;
        if (name === "balanced") return Icons.balanced;
        if (name === "performance") return Icons.performance;
        return Icons.balanced;
    }

    function getProfileDisplayName(name) {
        if (name === "power-saver") return "Power Save";
        if (name === "balanced") return "Balanced";
        if (name === "performance") return "Performance";
        return name || "";
    }

    Component.onCompleted: {
        root.refresh();
        root.subHandle = BackendService.addSubscription(["powerprofile"], (service, data) => {
            if (service !== "powerprofile.state" || !data) return;
            Qt.callLater(() => {
                root.isAvailable = data.available === true;
                root.backendType = data.backend || "";
                root.currentProfile = data.profile || "";
                root.availableProfiles = data.profiles || [];
            });
        });
    }
}