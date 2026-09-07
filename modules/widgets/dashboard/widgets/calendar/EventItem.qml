import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

StyledRect {
    id: root

    required property var event
    signal editRequested()

    variant: itemMouse.containsMouse ? "focus" : "common"
    radius: Styling.radius(-2)
    implicitHeight: itemContent.implicitHeight + 16

    RowLayout {
        id: itemContent
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Calendar color bar
        Rectangle {
            Layout.preferredWidth: 3
            Layout.fillHeight: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            radius: 2
            color: CalendarService.calendarColor(root.event.calendarId)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.event.title || "Untitled"
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.Medium
                color: Colors.overSurface
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: {
                    let parts = [];
                    if (root.event.allDay) {
                        parts.push("All day");
                    } else {
                        const s = root.event.start || "";
                        const e = root.event.end || "";
                        const startTime = s.includes("T") ? s.split("T")[1].substring(0, 5) : "";
                        const endTime = e.includes("T") ? e.split("T")[1].substring(0, 5) : "";
                        if (startTime) parts.push(startTime + (endTime ? " – " + endTime : ""));
                    }
                    const calName = CalendarService.calendarName(root.event.calendarId);
                    if (calName) parts.push(calName);
                    return parts.join(" · ");
                }
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-3)
                color: Colors.outline
                elide: Text.ElideRight
            }

            // Link buttons row
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: (root.event.location || "") !== "" || (root.event.meetLink || "") !== ""

                StyledRect {
                    visible: (root.event.meetLink || "") !== "" && root.event.meetLink !== "request"
                    variant: meetBtnMouse.containsMouse ? "primaryfocus" : "primary"
                    implicitWidth: meetBtnText.implicitWidth + 12
                    implicitHeight: 20
                    radius: Styling.radius(-4)

                    Text {
                        id: meetBtnText
                        anchors.centerIn: parent
                        text: "Meet"
                        font.family: Config.defaultFont
                        font.pixelSize: Styling.fontSize(-4)
                        font.weight: Font.Medium
                        color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                    }

                    MouseArea {
                        id: meetBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const link = root.event.meetLink || "";
                            if (link.startsWith("https://")) Qt.openUrlExternally(link);
                        }
                    }
                }

                StyledRect {
                    visible: (root.event.location || "") !== ""
                    variant: linkBtnMouse.containsMouse ? "focus" : "common"
                    implicitWidth: linkBtnText.implicitWidth + 12
                    implicitHeight: 20
                    radius: Styling.radius(-4)

                    Text {
                        id: linkBtnText
                        anchors.centerIn: parent
                        text: (root.event.location || "").startsWith("http") ? "Link" : "Location"
                        font.family: Config.defaultFont
                        font.pixelSize: Styling.fontSize(-4)
                        color: Colors.overSurface
                    }

                    MouseArea {
                        id: linkBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const loc = root.event.location || "";
                            if (loc.startsWith("http")) Qt.openUrlExternally(loc);
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: itemMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.editRequested()
    }
}
