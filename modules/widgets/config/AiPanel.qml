import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: Math.max(0, (width - contentWidth) / 2)

    Flickable {
        anchors.fill: parent
        contentHeight: contentColumn.implicitHeight + 40
        clip: true
        bottomMargin: 40

        ColumnLayout {
            id: contentColumn
            width: root.contentWidth
            x: root.sideMargin
            y: 20
            spacing: 24

            Text {
                text: I18n.t("ai.panel_title")
                font.family: Config.theme.font
                font.pixelSize: 24
                font.weight: Font.Bold
                color: Colors.overSurface
                Layout.fillWidth: true
                Layout.bottomMargin: 8
            }

            // Providers
            Repeater {
                model: ["gemini", "openai", "anthropic", "mistral", "groq", "ollama", "minimax"]
                delegate: StyledRect {
                    required property string modelData
                    Layout.fillWidth: true
                    variant: "surface"
                    radius: Styling.radius(8)
                    
                    // We need a wrapper to give it a height based on content
                    implicitHeight: providerCol.implicitHeight + 32

                    ColumnLayout {
                        id: providerCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                font.family: Config.theme.font
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: Colors.overSurface
                                Layout.fillWidth: true
                            }
                            Text {
                                text: KeyStore.hasKey(modelData) ? I18n.t("binds.key_configured") : I18n.t("binds.not_configured")
                                font.family: Config.theme.font
                                font.pixelSize: 12
                                color: KeyStore.hasKey(modelData) ? Colors.success : Colors.outline
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            TextField {
                                visible: modelData !== "ollama"
                                id: keyInput
                                Layout.fillWidth: true
                                placeholderText: I18n.t("ai.enter_api_key")
                                echoMode: TextInput.Password
                                font.family: Config.theme.font
                                color: Colors.overSurface
                                padding: 6
                                
                                background: StyledRect {
                                    variant: "internalbg"
                                    radius: Styling.radius(4)
                                    border.width: keyInput.activeFocus ? 2 : 0
                                    border.color: Styling.srItem("primary")
                                    anchors.fill: parent
                                    anchors.leftMargin: -parent.padding
                                    anchors.rightMargin: -parent.padding
                                    anchors.topMargin: -parent.padding
                                    anchors.bottomMargin: -parent.padding
                                }
                            }
                            Button {
                                id: saveButton
                                text: modelData === "ollama" ? (KeyStore.hasKey("ollama") ? "Configured" : "Enable") : I18n.t("common.save")
                                visible: modelData === "ollama" ? !KeyStore.hasKey("ollama") : true
                                hoverEnabled: true
                                leftPadding: 6
                                rightPadding: 6
                                topPadding: 4
                                bottomPadding: 4
                                onClicked: {
                                    if (modelData === "ollama") {
                                        KeyStore.setKey("ollama", "enabled")
                                    } else if (keyInput.text !== "") {
                                        KeyStore.setKey(modelData, keyInput.text)
                                        keyInput.text = ""
                                    }
                                }
                                background: StyledRect {
                                    variant: saveButton.down ? "overprimary" : (saveButton.hovered ? "primaryfocus" : "primary")
                                    radius: Styling.radius(4)
                                }
                                contentItem: Item {
                                    implicitWidth: saveButtonLabel.implicitWidth + saveButton.leftPadding + saveButton.rightPadding
                                    implicitHeight: saveButtonLabel.implicitHeight + saveButton.topPadding + saveButton.bottomPadding

                                    Text {
                                        id: saveButtonLabel
                                        text: saveButton.text
                                        color: Colors.overPrimary
                                        font.family: Config.theme.font
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        anchors.fill: parent
                                        anchors.leftMargin: saveButton.leftPadding
                                        anchors.rightMargin: saveButton.rightPadding
                                        anchors.topMargin: saveButton.topPadding
                                        anchors.bottomMargin: saveButton.bottomPadding
                                    }
                                }
                            }
                            Button {
                                id: clearButton
                                visible: KeyStore.hasKey(modelData)
                                text: modelData === "ollama" ? "Disable" : I18n.t("common.clear")
                                leftPadding: 6
                                rightPadding: 6
                                topPadding: 4
                                bottomPadding: 4
                                onClicked: KeyStore.deleteKey(modelData)
                                background: StyledRect {
                                    variant: "error"
                                    radius: Styling.radius(4)
                                }
                                contentItem: Item {
                                    implicitWidth: clearButtonLabel.implicitWidth + clearButton.leftPadding + clearButton.rightPadding
                                    implicitHeight: clearButtonLabel.implicitHeight + clearButton.topPadding + clearButton.bottomPadding

                                    Text {
                                        id: clearButtonLabel
                                        text: clearButton.text
                                        color: Colors.overError
                                        font.family: Config.theme.font
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        anchors.fill: parent
                                        anchors.leftMargin: clearButton.leftPadding
                                        anchors.rightMargin: clearButton.rightPadding
                                        anchors.topMargin: clearButton.topPadding
                                        anchors.bottomMargin: clearButton.bottomPadding
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Custom Provider
            Text {
                text: I18n.t("ai.custom_provider")
                font.family: Config.theme.font
                font.pixelSize: 20
                font.weight: Font.Bold
                color: Colors.overSurface
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.bottomMargin: 8
            }
            
            StyledRect {
                Layout.fillWidth: true
                variant: "surface"
                radius: Styling.radius(8)
                implicitHeight: customCol.implicitHeight + 32

                ColumnLayout {
                    id: customCol
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: I18n.t("ai.custom_provider_key")
                            font.family: Config.theme.font
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: Colors.overSurface
                            Layout.fillWidth: true
                        }
                        Text {
                            text: KeyStore.hasKey("custom") ? I18n.t("binds.key_configured") : I18n.t("binds.not_configured")
                            font.family: Config.theme.font
                            font.pixelSize: 12
                            color: KeyStore.hasKey("custom") ? Colors.success : Colors.outline
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        TextField {
                            id: customKeyInput
                            Layout.fillWidth: true
                            placeholderText: I18n.t("ai.enter_api_key")
                            echoMode: TextInput.Password
                            font.family: Config.theme.font
                            color: Colors.overSurface
                            padding: 6
                            
                            background: StyledRect {
                                variant: "internalbg"
                                radius: Styling.radius(4)
                                border.width: customKeyInput.activeFocus ? 2 : 0
                                border.color: Styling.srItem("primary")
                                anchors.fill: parent
                                anchors.leftMargin: -parent.padding
                                anchors.rightMargin: -parent.padding
                                anchors.topMargin: -parent.padding
                                anchors.bottomMargin: -parent.padding
                            }
                        }
                        Button {
                            id: customSaveButton
                            text: I18n.t("common.save")
                            hoverEnabled: true
                            leftPadding: 6
                            rightPadding: 6
                            topPadding: 4
                            bottomPadding: 4
                            onClicked: {
                                if (customKeyInput.text !== "") {
                                    KeyStore.setKey("custom", customKeyInput.text)
                                    customKeyInput.text = ""
                                }
                            }
                            background: StyledRect {
                                variant: customSaveButton.down ? "overprimary" : (customSaveButton.hovered ? "primaryfocus" : "primary")
                                radius: Styling.radius(4)
                            }
                            contentItem: Item {
                                implicitWidth: customSaveButtonLabel.implicitWidth + customSaveButton.leftPadding + customSaveButton.rightPadding
                                implicitHeight: customSaveButtonLabel.implicitHeight + customSaveButton.topPadding + customSaveButton.bottomPadding

                                Text {
                                    id: customSaveButtonLabel
                                    text: customSaveButton.text
                                    color: Colors.overPrimary
                                    font.family: Config.theme.font
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    anchors.fill: parent
                                    anchors.leftMargin: customSaveButton.leftPadding
                                    anchors.rightMargin: customSaveButton.rightPadding
                                    anchors.topMargin: customSaveButton.topPadding
                                    anchors.bottomMargin: customSaveButton.bottomPadding
                                }
                            }
                        }
                        Button {
                            id: customClearButton
                            visible: KeyStore.hasKey("custom")
                            text: I18n.t("common.clear")
                            leftPadding: 6
                            rightPadding: 6
                            topPadding: 4
                            bottomPadding: 4
                            onClicked: KeyStore.deleteKey("custom")
                            background: StyledRect {
                                variant: "error"
                                radius: Styling.radius(4)
                            }
                            contentItem: Item {
                                implicitWidth: customClearButtonLabel.implicitWidth + customClearButton.leftPadding + customClearButton.rightPadding
                                implicitHeight: customClearButtonLabel.implicitHeight + customClearButton.topPadding + customClearButton.bottomPadding

                                Text {
                                    id: customClearButtonLabel
                                    text: customClearButton.text
                                    color: Colors.overError
                                    font.family: Config.theme.font
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    anchors.fill: parent
                                    anchors.leftMargin: customClearButton.leftPadding
                                    anchors.rightMargin: customClearButton.rightPadding
                                    anchors.topMargin: customClearButton.topPadding
                                    anchors.bottomMargin: customClearButton.bottomPadding
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Colors.outline
                        opacity: 0.2
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                    }

                    Text {
                        text: I18n.t("ai.custom_endpoint")
                        font.family: Config.theme.font
                        font.pixelSize: 14
                        color: Colors.overSurface
                    }
                    
                    TextField {
                        id: endpointInput
                        Layout.fillWidth: true
                        text: Config.ai.customEndpoint !== undefined ? Config.ai.customEndpoint : ""
                        placeholderText: I18n.t("ai.endpoint_placeholder")
                        font.family: Config.theme.font
                        color: Colors.overSurface
                        padding: 6
                        
                        onTextChanged: {
                            if (Config.ai.customEndpoint !== undefined) {
                                Config.ai.customEndpoint = text;
                            }
                        }
                        
                        background: StyledRect {
                            variant: "internalbg"
                            radius: Styling.radius(4)
                            border.width: endpointInput.activeFocus ? 2 : 0
                            border.color: Styling.srItem("primary")
                            anchors.fill: parent
                            anchors.leftMargin: -parent.padding
                            anchors.rightMargin: -parent.padding
                            anchors.topMargin: -parent.padding
                            anchors.bottomMargin: -parent.padding
                        }
                    }

                    Text {
                        text: I18n.t("ai.custom_curl")
                        font.family: Config.theme.font
                        font.pixelSize: 14
                        color: Colors.overSurface
                        Layout.topMargin: 8
                    }
                    
                    Text {
                        text: I18n.t("ai.curl_placeholders")
                        font.family: Config.theme.font
                        font.pixelSize: 12
                        color: Colors.outline
                    }
                    
                    TextField {
                        id: curlInput
                        Layout.fillWidth: true
                        text: Config.ai.customCurlTemplate !== undefined ? Config.ai.customCurlTemplate : ""
                        placeholderText: I18n.t("ai.curl_placeholder")
                        font.family: "Monospace"
                        color: Colors.overSurface
                        padding: 6
                        
                        onTextChanged: {
                            if (Config.ai.customCurlTemplate !== undefined) {
                                Config.ai.customCurlTemplate = text;
                            }
                        }
                        
                        background: StyledRect {
                            variant: "internalbg"
                            radius: Styling.radius(4)
                            border.width: curlInput.activeFocus ? 2 : 0
                            border.color: Styling.srItem("primary")
                            anchors.fill: parent
                            anchors.leftMargin: -parent.padding
                            anchors.rightMargin: -parent.padding
                            anchors.topMargin: -parent.padding
                            anchors.bottomMargin: -parent.padding
                        }
                    }
                }
            }
        }
    }
}
