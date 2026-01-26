import QtQuick
import qs.config
import qs.modules.components

Item {
    id: root

    required property Repeater workspaces
    required property var occupied
    required property int groupOffset
    required property int itemSize

    property list<var> pills: []

    onOccupiedChanged: {
        if (!occupied)
            return;
        let count = 0;
        const start = groupOffset;
        const end = start + Config.workspaces.shown;
        for (const [ws, occ] of Object.entries(occupied)) {
            if (ws > start && ws <= end && occ) {
                const isFirstInGroup = Number(ws) === start + 1;
                const isLastInGroup = Number(ws) === end;
                if (isFirstInGroup || !occupied[ws - 1]) {
                    if (pills[count])
                        pills[count].start = ws;
                    else
                        pills.push(pillComp.createObject(root, { start: ws }));
                    count++;
                }
                if ((isLastInGroup || !occupied[ws + 1]) && pills[count - 1])
                    pills[count - 1].end = ws;
            }
        }
        if (pills.length > count)
            pills.splice(count, pills.length - count).forEach(p => p.destroy());
    }

    Repeater {
        model: root.pills.filter(p => p)

        StyledRect {
            id: rect

            required property var modelData

            readonly property Workspace start: root.workspaces.count > 0 ? root.workspaces.itemAt(getWsIdx(modelData.start)) ?? null : null
            readonly property Workspace end: root.workspaces.count > 0 ? root.workspaces.itemAt(getWsIdx(modelData.end)) ?? null : null

            function getWsIdx(ws) {
                let i = ws - 1;
                while (i < 0)
                    i += Config.workspaces.shown;
                return i % Config.workspaces.shown;
            }

            anchors.verticalCenter: root.verticalCenter

            x: (start?.x ?? 0) - 1
            implicitWidth: start && end ? end.x + end.size - start.x + 2 : 0
            implicitHeight: itemSize + 2

            color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
            radius: Appearance.rounding.full

            scale: 0
            Component.onCompleted: scale = 1

            Behavior on scale { Anim {} }
            Behavior on x { Anim {} }
            Behavior on implicitWidth { Anim {} }
        }
    }

    component Pill: QtObject {
        property int start
        property int end
    }

    Component {
        id: pillComp
        Pill {}
    }
}
