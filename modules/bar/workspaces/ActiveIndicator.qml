import QtQuick
import qs.config
import qs.modules.components

StyledRect {
    id: root

    required property int activeWsId
    required property Repeater workspaces
    required property Item mask
    required property int itemSize

    readonly property int currentWsIdx: {
        let i = activeWsId - 1;
        while (i < 0)
            i += Config.workspaces.shown;
        return i % Config.workspaces.shown;
    }

    property real leading: workspaces.count > 0 ? workspaces.itemAt(currentWsIdx)?.x ?? 0 : 0
    property real trailing: workspaces.count > 0 ? workspaces.itemAt(currentWsIdx)?.x ?? 0 : 0
    property real currentSize: workspaces.count > 0 ? workspaces.itemAt(currentWsIdx)?.size ?? itemSize : itemSize
    property real offset: Math.min(leading, trailing)
    property real size: Math.abs(leading - trailing) + currentSize

    property int cWs
    property int lastWs

    onCurrentWsIdxChanged: {
        lastWs = cWs;
        cWs = currentWsIdx;
    }

    clip: true
    x: offset + mask.x
    implicitWidth: size
    implicitHeight: itemSize
    radius: Appearance.rounding.full
    color: Colours.palette.m3primary

    Behavior on x { Anim {} }

    Colouriser {
        source: root.mask
        sourceColor: Colours.palette.m3onSurface
        colorizationColor: Colours.palette.m3onPrimary

        x: -parent.offset
        y: 0
        implicitWidth: root.mask.implicitWidth
        implicitHeight: root.mask.implicitHeight

        anchors.verticalCenter: parent.verticalCenter
    }

    Behavior on leading { Anim {} }
    Behavior on trailing { Anim {} }
    Behavior on currentSize { Anim {} }
    Behavior on offset { Anim {} }
    Behavior on size { Anim {} }
}
