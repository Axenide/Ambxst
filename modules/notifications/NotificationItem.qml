import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.services
import qs.config
import "./notification_utils.js" as NotificationUtils

Item {
    id: root
    property var notificationObject
    property bool expanded: false
    property bool onlyNotification: false
    property real fontSize: 12
    property real padding: onlyNotification ? 0 : 8

    property real dragConfirmThreshold: 70
    property real dismissOvershoot: notificationIcon.implicitWidth + 20
    property var qmlParent: root?.parent?.parent
    property var parentDragIndex: qmlParent?.dragIndex ?? -1
    property var parentDragDistance: qmlParent?.dragDistance ?? 0
    property var dragIndexDiff: Math.abs(parentDragIndex - (index ?? 0))
    property real xOffset: dragIndexDiff == 0 ? Math.max(0, parentDragDistance) : parentDragDistance > dragConfirmThreshold ? 0 : dragIndexDiff == 1 ? Math.max(0, parentDragDistance * 0.3) : dragIndexDiff == 2 ? Math.max(0, parentDragDistance * 0.1) : 0

    implicitHeight: background.implicitHeight

    function processNotificationBody(body, appName) {
        let processedBody = body;

        // Clean Chromium-based browsers notifications - remove first line
        if (appName) {
            const lowerApp = appName.toLowerCase();
            const chromiumBrowsers = ["brave", "chrome", "chromium", "vivaldi", "opera", "microsoft edge"];

            if (chromiumBrowsers.some(name => lowerApp.includes(name))) {
                const lines = body.split('\n\n');

                if (lines.length > 1 && lines[0].startsWith('<a')) {
                    processedBody = lines.slice(1).join('\n\n');
                }
            }
        }

        return processedBody;
    }

    function destroyWithAnimation() {
        if (root.qmlParent && root.qmlParent.resetDrag)
            root.qmlParent.resetDrag();
        background.anchors.leftMargin = background.anchors.leftMargin;
        destroyAnimation.running = true;
    }

    SequentialAnimation {
        id: destroyAnimation
        running: false

        NumberAnimation {
            target: background.anchors
            property: "leftMargin"
            to: root.width + root.dismissOvershoot
            duration: 300
            easing.type: Easing.OutCubic
        }
        onFinished: () => {
            Notifications.discardNotification(notificationObject.id);
        }
    }

    MouseArea {
        id: dragManager
        anchors.fill: root
        anchors.leftMargin: root.expanded ? -notificationIcon.implicitWidth : 0
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        property bool dragging: false
        property real dragDiffX: 0

        onPressed: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.destroyWithAnimation();
            }
        }

        function resetDrag() {
            dragging = false;
            dragDiffX = 0;
        }
    }

    NotificationAppIcon {
        id: notificationIcon
        opacity: (!onlyNotification && notificationObject.image != "" && expanded) ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        image: notificationObject.image
        anchors.right: background.left
        anchors.top: background.top
        anchors.rightMargin: 10
    }

    Rectangle {
        id: background
        width: parent.width
        anchors.left: parent.left
        radius: 8
        anchors.leftMargin: root.xOffset

        Behavior on anchors.leftMargin {
            enabled: !dragManager.dragging
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        color: (expanded && !onlyNotification) ? (notificationObject.urgency == NotificationUrgency.Critical) ? Colors.adapter.error : Colors.surfaceContainerLow : "transparent"

        implicitHeight: expanded ? (contentColumn.implicitHeight + padding * 2) : summaryRow.implicitHeight

        Behavior on implicitHeight {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: expanded ? root.padding : 0
            spacing: 3

            Behavior on anchors.margins {
                NumberAnimation {
                    duration: 200
                }
            }

            RowLayout {
                id: summaryRow
                visible: !root.onlyNotification || !root.expanded
                Layout.fillWidth: true
                implicitHeight: summaryText.implicitHeight

                Text {
                    id: summaryText
                    visible: !root.onlyNotification
                    font.family: Config.theme.font
                    font.pixelSize: root.fontSize
                    color: Colors.adapter.primary
                    elide: Text.ElideRight
                    text: root.notificationObject.summary || ""
                }
                Text {
                    opacity: !root.expanded ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                    Layout.fillWidth: true
                    font.family: Config.theme.font
                    font.pixelSize: root.fontSize
                    color: Colors.adapter.overBackground
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.StyledText
                    text: {
                        return processNotificationBody(notificationObject.body, notificationObject.appName || notificationObject.summary).replace(/\n/g, "<br/>");
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                opacity: root.expanded ? 1 : 0
                visible: opacity > 0

                Text {
                    id: notificationBodyText
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                    Layout.fillWidth: true
                    font.pixelSize: 14
                    color: Colors.adapter.overBackground
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    textFormat: Text.RichText
                    text: {
                        return `<style>img{max-width:${notificationBodyText.width}px;}</style>` + `${processNotificationBody(notificationObject.body, notificationObject.appName || notificationObject.summary).replace(/\n/g, "<br/>")}`;
                    }

                    onLinkActivated: link => {
                        Qt.openUrlExternally(link);
                    }
                }

                Flickable {
                    id: actionsFlickable
                    Layout.fillWidth: true
                    implicitHeight: actionRowLayout.implicitHeight
                    contentWidth: actionRowLayout.implicitWidth
                    clip: !onlyNotification

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                    Behavior on implicitHeight {
                        NumberAnimation {
                            duration: 200
                        }
                    }

                    RowLayout {
                        id: actionRowLayout
                        Layout.alignment: Qt.AlignBottom

                        NotificationActionButton {
                            Layout.fillWidth: true
                            buttonText: qsTr("Close")
                            urgency: notificationObject.urgency
                            implicitWidth: (notificationObject.actions.length == 0) ? ((actionsFlickable.width - actionRowLayout.spacing) / 2) : (contentItem.implicitWidth + leftPadding + rightPadding)

                            onClicked: {
                                root.destroyWithAnimation();
                            }

                            contentItem: Text {
                                font.family: Config.theme.font
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                color: (notificationObject.urgency == NotificationUrgency.Critical) ? "#d32f2f" : "#424242"
                                text: "✕"
                            }
                        }

                        Repeater {
                            id: actionRepeater
                            model: notificationObject.actions
                            NotificationActionButton {
                                Layout.fillWidth: true
                                buttonText: modelData.text
                                urgency: notificationObject.urgency
                                onClicked: {
                                    Notifications.attemptInvokeAction(notificationObject.id, modelData.identifier);
                                }
                            }
                        }

                        NotificationActionButton {
                            Layout.fillWidth: true
                            urgency: notificationObject.urgency
                            implicitWidth: (notificationObject.actions.length == 0) ? ((actionsFlickable.width - actionRowLayout.spacing) / 2) : (contentItem.implicitWidth + leftPadding + rightPadding)

                            onClicked: {
                                // Copy notification body to clipboard
                                // Note: Quickshell.clipboardText might not be available, using alternative
                                console.log("Copy:", notificationObject.body);
                            }

                            contentItem: Text {
                                id: copyIcon
                                font.family: Config.theme.font
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                color: (notificationObject.urgency == NotificationUrgency.Critical) ? "#d32f2f" : "#424242"
                                text: "📋"
                            }
                        }
                    }
                }
            }
        }
    }
}
