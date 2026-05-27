import QtQuick

/**
 * Individual metrics group in the notch metrics overlay.
 * Shows a colored dot, label, value with small unit, optional sub value/unit.
 * e.g. "CPU 51°C 40W" → label=CPU, valueText=51, valueUnit=°C, subValue=40, subUnit=W
 */
Item {
    id: root

    required property string label
    required property color labelColor
    property string valueText: ""
    property string valueUnit: ""
    property string subValue: ""
    property string subUnit: ""

    implicitHeight: parent ? parent.height : 32
    implicitWidth: innerRow.implicitWidth

    Row {
        id: innerRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        spacing: 5

        // Label
        Text {
            text: root.label
            color: root.labelColor
            font.pixelSize: 11
            font.weight: Font.Bold
            font.family: "sans-serif"
            anchors.verticalCenter: parent.verticalCenter
        }

        // Value number (large)
        Text {
            text: root.valueText
            color: "#FFFFFF"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.family: "sans-serif"
            anchors.verticalCenter: parent.verticalCenter
            visible: root.valueText !== ""
        }

        // Value unit (small, e.g. °C)
        Text {
            text: root.valueUnit
            color: "#CCFFFFFF"
            font.pixelSize: 8
            font.weight: Font.Normal
            font.family: "sans-serif"
            anchors.verticalCenter: parent.verticalCenter
            visible: root.valueUnit !== ""
        }

        // Sub value (large, e.g. watts)
        Text {
            text: root.subValue
            color: "#FFFFFF"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.family: "sans-serif"
            anchors.verticalCenter: parent.verticalCenter
            visible: root.subValue !== ""
        }

        // Sub unit (small, e.g. W)
        Text {
            text: root.subUnit
            color: "#CCFFFFFF"
            font.pixelSize: 8
            font.weight: Font.Normal
            font.family: "sans-serif"
            anchors.verticalCenter: parent.verticalCenter
            visible: root.subUnit !== ""
        }
    }
}
