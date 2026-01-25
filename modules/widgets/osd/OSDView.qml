import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.notch 
import qs.config

Item {
    id: root

    // Individual visibility flags (controlled by NotchWindow)
    property bool showVolume: false
    property bool showMic: false
    property bool showBrightness: false
    
    // Values
    property real volumeValue: 0
    property real micValue: 0
    property real brightnessValue: 0

    onVolumeValueChanged: volumeSlider.value = volumeValue
    onMicValueChanged: micSlider.value = micValue
    onBrightnessValueChanged: brightnessSlider.value = brightnessValue

    property bool notchHovered: false

    // Layout constants
    readonly property int padding: 16
    readonly property int osdHeight: Config.showBackground ? (Config.notchTheme === "island" ? 36 : 44) : (Config.notchTheme === "island" ? 36 : 40)
    
    // Notification constants
    readonly property int notificationPadding: 16
    readonly property int notificationPaddingBottom: Config.notchTheme === "island" ? 20 : 16
    readonly property int notificationPaddingTop: 8
    readonly property bool hasActiveNotifications: Notifications.popupList.length > 0
    readonly property real notificationMinWidth: root.notchHovered ? 420 : 320
    readonly property real notificationContainerHeight: notificationView.implicitHeight + notificationPaddingTop + notificationPaddingBottom

    // Calculate total height of visible sliders
    readonly property int visibleSlidersCount: (showVolume ? 1 : 0) + (showMic ? 1 : 0) + (showBrightness ? 1 : 0)
    readonly property int slidersTotalHeight: visibleSlidersCount * osdHeight
    
    // Extra padding when multiple sliders are stacked (and no notification overrides it)
    readonly property int multiSliderPadding: (visibleSlidersCount > 1 && !hasActiveNotifications) ? 6 : 0

    // Dimensions
    implicitHeight: (hasActiveNotifications ? notificationContainerHeight : 0) + slidersTotalHeight + multiSliderPadding
    implicitWidth: Math.round(hasActiveNotifications ? Math.max(notificationMinWidth + (notificationPadding * 2), 300) : 300)
    
    Behavior on implicitWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }
    
    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    Column {
        anchors.fill: parent
        spacing: 0

        // --- VOLUME SLIDER ---
        Item {
            id: volumeContainer
            width: parent.width
            height: root.showVolume ? osdHeight : 0
            visible: root.showVolume
            clip: true
            
            StyledSlider {
                id: volumeSlider
                anchors.fill: parent
                anchors.margins: 4
                anchors.leftMargin: 12
                anchors.rightMargin: 18

                // Binding
                icon: Audio.volumeIcon(root.volumeValue, Audio.muted)
                value: root.volumeValue
                
                enabled: true
                iconPos: "start"
                wavy: false 
                
                backgroundColor: Colors.surfaceBright
                
                readonly property bool isMuted: Audio.muted
                progressColor: isMuted ? Colors.surfaceBright : Colors.primary
                
                tooltip: false

                onValueChanged: {
                    if (Math.abs(value - root.volumeValue) > 0.005) {
                        Audio.setVolume(value);
                        root.keepAlive();
                    }
                }
            }


            Behavior on height {
                 enabled: Config.animDuration > 0
                 NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
            }
        }

        // --- MIC SLIDER ---
        Item {
            id: micContainer
            width: parent.width
            height: root.showMic ? osdHeight : 0
            visible: root.showMic
            clip: true
            
            StyledSlider {
                id: micSlider
                anchors.fill: parent
                anchors.margins: 4
                anchors.leftMargin: 12
                anchors.rightMargin: 18

                icon: Audio.micMuted ? Icons.micSlash : Icons.mic
                value: root.micValue
                
                enabled: true
                iconPos: "start"
                wavy: false 
                
                backgroundColor: Colors.surfaceBright
                
                readonly property bool isMuted: Audio.micMuted
                progressColor: isMuted ? Colors.surfaceBright : Colors.secondary
                
                tooltip: false

                onValueChanged: {
                    if (Math.abs(value - root.micValue) > 0.005) {
                        Audio.setMicVolume(value);
                        root.keepAlive();
                    }
                }
            }


             Behavior on height {
                 enabled: Config.animDuration > 0
                 NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
            }
        }

        // --- BRIGHTNESS SLIDER ---
        Item {
            id: brightnessContainer
            width: parent.width
            height: root.showBrightness ? osdHeight : 0
            visible: root.showBrightness
            clip: true
            
            StyledSlider {
                id: brightnessSlider
                anchors.fill: parent
                anchors.margins: 4
                anchors.leftMargin: 12
                anchors.rightMargin: 18

                icon: Icons.sun
                value: root.brightnessValue
                
                enabled: true
                iconPos: "start"
                wavy: false 
                
                backgroundColor: Colors.surfaceBright
                progressColor: Colors.tertiary
                
                tooltip: false

                onValueChanged: {
                     if (Math.abs(value - root.brightnessValue) > 0.005) {
                         Brightness.monitors.forEach(m => {
                             if (m.ready) m.setBrightness(value);
                         });
                         root.keepAlive();
                     }
                }
            }


             Behavior on height {
                 enabled: Config.animDuration > 0
                 NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
            }
        }
        
        // --- NOTIFICATIONS ---
        Item {
            id: notificationContainer
            width: parent.width
            height: hasActiveNotifications ? notificationContainerHeight : 0
            visible: hasActiveNotifications
            clip: true

            NotchNotificationView {
                id: notificationView
                anchors.fill: parent
                anchors.topMargin: notificationPaddingTop
                anchors.leftMargin: notificationPadding
                anchors.rightMargin: notificationPadding
                anchors.bottomMargin: notificationPaddingBottom
                visible: hasActiveNotifications
                opacity: visible ? 1 : 0
                notchHovered: root.notchHovered

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }
        }
    }

    signal keepAlive()
}
