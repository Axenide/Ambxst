import QtQuick
import QtQuick.Controls
import qs.modules.globals
import qs.modules.theme
import qs.modules.components
import qs.modules.corners
import qs.config

Item {
    id: notchContainer

    z: 1000

    property Component defaultViewComponent
    property Component launcherViewComponent
    property Component dashboardViewComponent
    property Component overviewViewComponent
    property var stackView: stackViewInternal
    property bool isExpanded: stackViewInternal.currentItem !== stackViewInternal.initialItem

    // Screen-specific visibility properties passed from parent
    property var visibilities
    readonly property bool screenNotchOpen: visibilities ? (visibilities.launcher || visibilities.dashboard || visibilities.overview) : false

    implicitWidth: screenNotchOpen ? Math.max(stackContainer.width + 40, 290) : 290
    implicitHeight: Config.bar.showBackground ? (screenNotchOpen ? Math.max(stackContainer.height, 44) : 44) : (screenNotchOpen ? Math.max(stackContainer.height, 40) : 40)

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: isExpanded ? Easing.OutBack : Easing.OutQuart
            easing.overshoot: isExpanded ? 1.2 : 1.0
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: isExpanded ? Easing.OutBack : Easing.OutQuart
            easing.overshoot: isExpanded ? 1.2 : 1.0
        }
    }

    RoundCorner {
        id: leftCorner
        anchors.top: parent.top
        anchors.right: notchRect.left
        corner: RoundCorner.CornerEnum.TopRight
        size: Config.roundness > 0 ? Config.roundness + 4 : 0
        color: Colors.background
    }

    BgRect {
        id: notchRect
        anchors.centerIn: parent
        width: parent.implicitWidth - 40
        height: parent.implicitHeight
        layer.enabled: false

        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Config.roundness > 0 ? (screenNotchOpen ? Config.roundness + 20 : Config.roundness + 4) : 0
        bottomRightRadius: Config.roundness > 0 ? (screenNotchOpen ? Config.roundness + 20 : Config.roundness + 4) : 0
        clip: true

        Behavior on bottomLeftRadius {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: screenNotchOpen ? Easing.OutBack : Easing.OutQuart
                easing.overshoot: screenNotchOpen ? 1.2 : 1.0
            }
        }

        Behavior on bottomRightRadius {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: screenNotchOpen ? Easing.OutBack : Easing.OutQuart
                easing.overshoot: screenNotchOpen ? 1.2 : 1.0
            }
        }

        Item {
            id: stackContainer
            anchors.centerIn: parent
            width: stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitWidth + 32 : 32
            height: stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitHeight + 32 : 32
            clip: true

            StackView {
                id: stackViewInternal
                anchors.fill: parent
                anchors.margins: 16
                initialItem: defaultViewComponent

                pushEnter: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 0.8
                        to: 1
                        duration: Config.animDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }
                }

                pushExit: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 1
                        to: 1.05
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                popEnter: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 1.05
                        to: 1
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                popExit: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 1
                        to: 0.95
                        duration: Config.animDuration
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
        size: Config.roundness > 0 ? Config.roundness + 4 : 0
        color: Colors.background
    }
}
