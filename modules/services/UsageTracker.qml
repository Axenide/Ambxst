pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services

Singleton {
    id: root

    readonly property bool dataLoaded: AxctlBackend.applicationsReady
    signal usageDataReady

    onDataLoadedChanged: {
        if (dataLoaded) usageDataReady();
    }

    function recordUsage(appId) {
        if (!appId) return;
        AxctlBackend.call("Application.RecordUsage", {id: appId});
    }

    function getUsageScore(_appId) {
        return 0;
    }
}
