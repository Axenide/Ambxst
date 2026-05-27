import QtQuick

QtObject {
    id: root

    property var lastIpcObject: ({})
    
    property bool active: lastIpcObject.active ?? false
    property int strength: lastIpcObject.strength ?? 0
    property int frequency: lastIpcObject.frequency ?? 0
    property string ssid: lastIpcObject.ssid ?? ""
    property string bssid: lastIpcObject.bssid ?? ""
    property string security: lastIpcObject.security ?? ""
    
    property bool askingPassword: false
    
    readonly property bool isSecure: security.length > 0 && security !== "--"
    readonly property bool is5GHz: frequency > 4900
}
