import QtQuick
import QtQuick.Controls
import "../globals"
import "../theme"
import "../corners"

Item {
    id: notchContainer

    property Component defaultViewComponent
    property Component launcherViewComponent
    property Component dashboardViewComponent
    property var stackView: stackViewInternal
    property bool isExpanded: stackViewInternal.currentItem !== stackViewInternal.initialItem

    // implicitWidth: Math.max(stackContainer.width, 250)
    implicitWidth: (GlobalStates.launcherOpen || GlobalStates.dashboardOpen) ? Math.max(stackContainer.width + 40, 290) : 290
    // implicitHeight: Math.max(stackContainer.height, 40)
    implicitHeight: (GlobalStates.launcherOpen || GlobalStates.dashboardOpen) ? Math.max(stackContainer.height, 40) : 40

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 250
            easing.type: isExpanded ? Easing.OutBack : Easing.OutQuart
            easing.overshoot: isExpanded ? 1.2 : 1.0
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 250
            easing.type: isExpanded ? Easing.OutBack : Easing.OutQuart
            easing.overshoot: isExpanded ? 1.2 : 1.0
        }
    }

    RoundCorner {
        id: leftCorner
        anchors.top: parent.top
        anchors.right: notchRect.left
        corner: RoundCorner.CornerEnum.TopRight
        size: GlobalStates.roundness > 0 ? GlobalStates.roundness + 4 : 0
        color: Colors.background
    }

    Rectangle {
        id: notchRect
        anchors.centerIn: parent
        width: parent.implicitWidth - 40
        height: parent.implicitHeight

        color: Colors.background
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: GlobalStates.roundness > 0 ? GlobalStates.roundness + 4 : 0
        bottomRightRadius: GlobalStates.roundness > 0 ? GlobalStates.roundness + 4 : 0

        Item {
            id: stackContainer
            anchors.centerIn: parent
            width: stackViewInternal.currentItem ? stackViewInternal.currentItem.width : 0
            height: stackViewInternal.currentItem ? stackViewInternal.currentItem.height : 0

            StackView {
                id: stackViewInternal
                anchors.fill: parent
                initialItem: defaultViewComponent

                pushEnter: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 250
                        easing.type: Easing.OutQuart
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 0.8
                        to: 1
                        duration: 250
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }
                }

                pushExit: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: 250
                        easing.type: Easing.OutQuart
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 1
                        to: 1.05
                        duration: 250
                        easing.type: Easing.OutQuart
                    }
                }

                popEnter: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 250
                        easing.type: Easing.OutQuart
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 1.05
                        to: 1
                        duration: 250
                        easing.type: Easing.OutQuart
                    }
                }

                popExit: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: 200
                        easing.type: Easing.OutQuart
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 1
                        to: 0.95
                        duration: 200
                        easing.type: Easing.OutQuart
                    }
                }
            }
        }
    }

    RoundCorner {
        id: rightCorner
        anchors.top: parent.top
        anchors.left: notchRect.right
        corner: RoundCorner.CornerEnum.TopLeft
        size: GlobalStates.roundness > 0 ? GlobalStates.roundness + 4 : 0
        color: Colors.background
    }
}
