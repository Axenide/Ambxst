import QtQuick

Item {
    required property Item source
    property color sourceColor: "transparent"
    property color colorizationColor: "transparent"

    ShaderEffectSource {
        id: sourceTexture
        anchors.fill: parent
        sourceItem: source
        hideSource: true
        live: true
        smooth: true
    }
}
