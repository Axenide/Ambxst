pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

ClippingRectangle {
    id: root

    // Configurable properties
    property bool showDebugControls: true
    
    // GPU optimization: animations only run when this widget is actually visible to user
    // Parent components (popups, loaders) should bind this to their open/visible state
    property bool animationsEnabled: true

    // Internal alias for celestial body position (used by sun rays)
    readonly property alias celestialBodyItem: celestialBody

    radius: Styling.radius(0)
    clip: true
    color: "transparent"

    // Request weather update when widget becomes visible if no data
    onVisibleChanged: {
        if (visible && !WeatherService.dataAvailable && !WeatherService.isLoading) {
            WeatherService.updateWeather();
        }
    }

    // Color blending helper function
    function blendColors(color1, color2, color3, blend) {
        var r = color1.r * blend.day + color2.r * blend.evening + color3.r * blend.night;
        var g = color1.g * blend.day + color2.g * blend.evening + color3.g * blend.night;
        var b = color1.b * blend.day + color2.b * blend.evening + color3.b * blend.night;
        return Qt.rgba(r, g, b, 1);
    }

    // Color definitions for each time of day
    // Day colors (sky blue)
    readonly property color dayTop: "#87CEEB"
    readonly property color dayMid: "#B0E0E6"
    readonly property color dayBot: "#E0F6FF"

    // Evening colors (sunset)
    readonly property color eveningTop: "#1a1a2e"
    readonly property color eveningMid: "#e94560"
    readonly property color eveningBot: "#ffeaa7"

    // Night colors (dark blue)
    readonly property color nightTop: "#0f0f23"
    readonly property color nightMid: "#1a1a3a"
    readonly property color nightBot: "#2d2d5a"

    // Blended colors based on time
    readonly property var blend: WeatherService.effectiveTimeBlend
    readonly property color topColor: blendColors(dayTop, eveningTop, nightTop, blend)
    readonly property color midColor: blendColors(dayMid, eveningMid, nightMid, blend)
    readonly property color botColor: blendColors(dayBot, eveningBot, nightBot, blend)

    // Dynamic gradient based on time of day (smooth interpolation)
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: root.topColor
            }
            GradientStop {
                position: 0.5
                color: root.midColor
            }
            GradientStop {
                position: 1.0
                color: root.botColor
            }
        }
    }

    // Weather effect properties
    readonly property string weatherEffect: WeatherService.effectiveWeatherEffect
    readonly property real weatherIntensity: WeatherService.effectiveWeatherIntensity

    // Check if weather is overcast (clouds, rain, drizzle, snow, thunderstorm, fog)
    readonly property bool isOvercast: weatherEffect === "clouds" || weatherEffect === "rain" || weatherEffect === "drizzle" || weatherEffect === "snow" || weatherEffect === "thunderstorm" || weatherEffect === "fog"

    // Overcast overlay - darkens/grays the sky based on weather
    Rectangle {
        id: overcastOverlay
        anchors.fill: parent
        radius: Styling.radius(0)
        visible: root.isOvercast
        opacity: root.weatherIntensity * 0.7

        // Gray gradient that adapts to time of day
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: root.blend.night > 0.5 ? Qt.rgba(0.15, 0.15, 0.2, 0.9)   // Dark gray-blue at night
                : root.blend.evening > 0.3 ? Qt.rgba(0.3, 0.25, 0.3, 0.85)  // Purple-gray at evening
                : Qt.rgba(0.5, 0.52, 0.55, 0.8)  // Light gray during day
            }
            GradientStop {
                position: 0.6
                color: root.blend.night > 0.5 ? Qt.rgba(0.2, 0.2, 0.25, 0.7) : root.blend.evening > 0.3 ? Qt.rgba(0.35, 0.3, 0.35, 0.6) : Qt.rgba(0.6, 0.62, 0.65, 0.5)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(0.5, 0.5, 0.5, 0.2)  // Fade out at bottom
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 500
                easing.type: Easing.InOutQuad
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // AMBIENT EFFECTS (stars, sun rays)
    // ═══════════════════════════════════════════════════════════

    // Stars at night (twinkling)
    Item {
        id: starsEffect
        anchors.fill: parent
        // Show stars when night blend > 0.3 and weather is clear
        opacity: (root.blend.night > 0.3 && root.weatherEffect === "clear") ? Math.min(1, (root.blend.night - 0.3) / 0.4) : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 1000
                easing.type: Easing.InOutQuad
            }
        }

        Repeater {
            model: 20

            Rectangle {
                id: star
                property real baseX: Math.random() * starsEffect.width
                property real baseY: Math.random() * (starsEffect.height * 0.7)  // Upper 70%
                property real baseSize: 1 + Math.random() * 2
                property real twinkleSpeed: 1500 + Math.random() * 2000
                property real baseOpacity: 0.4 + Math.random() * 0.4

                x: baseX
                y: baseY
                width: baseSize
                height: baseSize
                radius: baseSize / 2
                color: "#FFFFFF"
                opacity: baseOpacity

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: starsEffect.visible && root.animationsEnabled

                    NumberAnimation {
                        to: star.baseOpacity * 0.3
                        duration: star.twinkleSpeed / 2
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: star.baseOpacity
                        duration: star.twinkleSpeed / 2
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }

    // Sun rays during clear day - follows celestialBody position
    Item {
        id: sunRaysEffect

        // Follow the visual position of celestialBody (after animation)
        x: celestialBody.x + celestialBody.width / 2
        y: celestialBody.y + celestialBody.height / 2
        width: 0
        height: 0

        // Show rays when day blend > 0.3 and weather is clear
        opacity: (root.blend.day > 0.3 && root.weatherEffect === "clear") ? Math.min(1.0, (root.blend.day - 0.3) * 1.5) : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 800
                easing.type: Easing.InOutQuad
            }
        }

        Repeater {
            model: 8

            Rectangle {
                id: ray
                required property int index
                property real angle: (index * 45) * Math.PI / 180
                property real rayLength: 60 + Math.random() * 30
                property real pulseSpeed: 3000 + Math.random() * 1500

                x: Math.cos(ray.angle) * 15
                y: Math.sin(ray.angle) * 15
                width: rayLength
                height: 2
                radius: 1
                rotation: ray.angle * 180 / Math.PI
                transformOrigin: Item.Left

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(1, 0.95, 0.7, 0.9)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(1, 0.95, 0.7, 0)
                    }
                }

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: sunRaysEffect.visible && root.animationsEnabled

                    NumberAnimation {
                        to: 0.5
                        duration: ray.pulseSpeed / 2
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1.0
                        duration: ray.pulseSpeed / 2
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // WEATHER EFFECTS
    // ═══════════════════════════════════════════════════════════

    // Cloud effect (improved with layering)
    Item {
        id: cloudEffect
        anchors.fill: parent
        visible: root.weatherEffect === "clouds" || root.weatherEffect === "rain" || root.weatherEffect === "drizzle" || root.weatherEffect === "snow" || root.weatherEffect === "thunderstorm"
        opacity: root.weatherEffect === "clouds" ? root.weatherIntensity : 0.8

        // Cloud color based on time of day and weather
        // Darker gray for stormy weather, lighter for just cloudy
        property bool isStormy: root.weatherEffect === "rain" || root.weatherEffect === "thunderstorm" || root.weatherEffect === "drizzle"

        // Cloud base color adapts to time of day
        property color cloudColorDark: root.blend.night > 0.5 ? Qt.rgba(0.2, 0.2, 0.25, 1)      // Dark blue-gray at night
        : root.blend.evening > 0.3 ? Qt.rgba(0.35, 0.3, 0.35, 1)  // Purple-gray at evening
        : isStormy ? Qt.rgba(0.4, 0.42, 0.45, 1)  // Dark gray for storms during day
        : Qt.rgba(0.85, 0.87, 0.9, 1)  // Light gray-white for fair clouds

        property color cloudColorLight: root.blend.night > 0.5 ? Qt.rgba(0.3, 0.3, 0.35, 1) : root.blend.evening > 0.3 ? Qt.rgba(0.45, 0.4, 0.45, 1) : isStormy ? Qt.rgba(0.5, 0.52, 0.55, 1) : Qt.rgba(0.92, 0.94, 0.96, 1)

        // Background layer - larger, slower, more transparent clouds
        Repeater {
            model: 4

            Item {
                id: bgCloud
                required property int index
                property real speed: 0.15 + (index * 0.05)
                property real totalDistance: cloudEffect.width + width + 100
                property real cycleDuration: 40000 / speed  // 40 seconds base, adjusted by speed

                // Start already positioned across the screen
                x: (index * totalDistance / 4) % (cloudEffect.width + width) - width
                y: 5 + (index * 15)
                width: 160 + (index * 40)
                height: 60 + (index * 16)

                // Cloud shape - multiple overlapping circles
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.8
                    height: parent.height * 0.6
                    radius: height / 2
                    color: Qt.rgba(cloudEffect.cloudColorDark.r, cloudEffect.cloudColorDark.g, cloudEffect.cloudColorDark.b, 0.5)
                }
                Rectangle {
                    x: parent.width * 0.1
                    y: parent.height * 0.2
                    width: parent.width * 0.4
                    height: parent.height * 0.5
                    radius: height / 2
                    color: Qt.rgba(cloudEffect.cloudColorLight.r, cloudEffect.cloudColorLight.g, cloudEffect.cloudColorLight.b, 0.4)
                }
                Rectangle {
                    x: parent.width * 0.5
                    y: parent.height * 0.15
                    width: parent.width * 0.45
                    height: parent.height * 0.55
                    radius: height / 2
                    color: Qt.rgba(cloudEffect.cloudColorLight.r, cloudEffect.cloudColorLight.g, cloudEffect.cloudColorLight.b, 0.4)
                }

                // Continuous movement animation
                SequentialAnimation on x {
                    running: cloudEffect.visible && root.animationsEnabled
                    loops: Animation.Infinite

                    // Move across screen
                    NumberAnimation {
                        to: cloudEffect.width + 50
                        duration: bgCloud.cycleDuration
                        easing.type: Easing.Linear
                    }

                    // Reset to start position smoothly
                    NumberAnimation {
                        to: -bgCloud.width - 50
                        duration: 0  // Instant reset when off-screen
                    }
                }

                // Fade in/out when entering/leaving screen
                PropertyAnimation on opacity {
                    running: cloudEffect.visible && root.animationsEnabled
                    from: 0
                    to: 0.8
                    duration: 2000
                    easing.type: Easing.InOutQuad
                }
            }
        }

        // Foreground layer - smaller, faster, more opaque clouds
        Repeater {
            model: 6

            Item {
                id: fgCloud
                required property int index
                property real speed: 0.25 + (index * 0.1)
                property real totalDistance: cloudEffect.width + width + 100
                property real cycleDuration: 25000 / speed  // 25 seconds base, adjusted by speed

                // Start already positioned across the screen
                x: (index * totalDistance / 6) % (cloudEffect.width + width) - width
                y: 20 + (index * 15)
                width: 90 + (index * 24)
                height: 36 + (index * 10)

                // Cloud shape
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.7
                    height: parent.height * 0.7
                    radius: height / 2
                    color: Qt.rgba(cloudEffect.cloudColorDark.r, cloudEffect.cloudColorDark.g, cloudEffect.cloudColorDark.b, 0.65 - (fgCloud.index * 0.08))
                }
                Rectangle {
                    x: parent.width * 0.05
                    y: parent.height * 0.25
                    width: parent.width * 0.35
                    height: parent.height * 0.5
                    radius: height / 2
                    color: Qt.rgba(cloudEffect.cloudColorLight.r, cloudEffect.cloudColorLight.g, cloudEffect.cloudColorLight.b, 0.55 - (fgCloud.index * 0.06))
                }
                Rectangle {
                    x: parent.width * 0.55
                    y: parent.height * 0.2
                    width: parent.width * 0.4
                    height: parent.height * 0.55
                    radius: height / 2
                    color: Qt.rgba(cloudEffect.cloudColorLight.r, cloudEffect.cloudColorLight.g, cloudEffect.cloudColorLight.b, 0.55 - (fgCloud.index * 0.06))
                }

                // Continuous movement animation
                SequentialAnimation on x {
                    running: cloudEffect.visible && root.animationsEnabled
                    loops: Animation.Infinite

                    // Move across screen
                    NumberAnimation {
                        to: cloudEffect.width + 50
                        duration: fgCloud.cycleDuration
                        easing.type: Easing.Linear
                    }

                    // Reset to start position smoothly
                    NumberAnimation {
                        to: -fgCloud.width - 50
                        duration: 0  // Instant reset when off-screen
                    }
                }

                // Fade in/out when entering/leaving screen
                PropertyAnimation on opacity {
                    running: cloudEffect.visible && root.animationsEnabled
                    from: 0
                    to: 0.9
                    duration: 1500
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }

    // Fog effect
    Rectangle {
        id: fogEffect
        anchors.fill: parent
        visible: root.weatherEffect === "fog"
        opacity: root.weatherIntensity * 0.5

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(1, 1, 1, 0.1)
            }
            GradientStop {
                position: 0.5
                color: Qt.rgba(1, 1, 1, 0.3)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(1, 1, 1, 0.4)
            }
        }

        // Animated fog wisps
        Repeater {
            model: 4

            Rectangle {
                id: fogWisp
                required property int index
                property real baseY: index * (parent.height / 4)

                x: -width / 2
                y: baseY
                width: parent.width * 1.5
                height: 25 + (index * 5)
                color: Qt.rgba(1, 1, 1, 0.15)
                radius: height / 2

                NumberAnimation on x {
                    from: -fogWisp.width / 2
                    to: 0
                    duration: 8000 + (fogWisp.index * 2000)
                    loops: Animation.Infinite
                    running: fogEffect.visible && root.animationsEnabled
                    easing.type: Easing.InOutSine
                }

                NumberAnimation on opacity {
                    from: 0.1
                    to: 0.25
                    duration: 4000 + (fogWisp.index * 1000)
                    loops: Animation.Infinite
                    running: fogEffect.visible && root.animationsEnabled
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    // Rain effect
    Item {
        id: rainEffect
        anchors.fill: parent
        visible: root.weatherEffect === "rain" || root.weatherEffect === "drizzle"

        property int dropCount: Math.round(20 * root.weatherIntensity)
        property real angle: 15  // degrees from vertical
        property real angleRad: angle * Math.PI / 180

        Repeater {
            model: rainEffect.dropCount

            Rectangle {
                id: rainDrop
                property real initialX: Math.random() * (rainEffect.width + 50) - 25
                property real fallDistance: rainEffect.height + 40
                property real horizontalDrift: fallDistance * Math.tan(rainEffect.angleRad)
                property real fallSpeed: 400 + Math.random() * 200
                property real delay: Math.random() * fallSpeed

                x: initialX
                y: -20
                width: root.weatherEffect === "drizzle" ? 1 : 2
                height: root.weatherEffect === "drizzle" ? 8 : 12
                radius: 1
                color: Qt.rgba(0.7, 0.85, 1, 0.6)
                rotation: -rainEffect.angle

                SequentialAnimation {
                    loops: Animation.Infinite
                    running: rainEffect.visible && root.animationsEnabled

                    PauseAnimation {
                        duration: rainDrop.delay
                    }

                    ParallelAnimation {
                        NumberAnimation {
                            target: rainDrop
                            property: "y"
                            from: -20
                            to: rainDrop.fallDistance - 20
                            duration: rainDrop.fallSpeed
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: rainDrop
                            property: "x"
                            from: rainDrop.initialX
                            to: rainDrop.initialX + rainDrop.horizontalDrift
                            duration: rainDrop.fallSpeed
                            easing.type: Easing.Linear
                        }
                    }

                    ScriptAction {
                        script: {
                            rainDrop.initialX = Math.random() * (rainEffect.width + 50) - 25;
                        }
                    }
                }
            }
        }
    }

    // Snow effect
    Item {
        id: snowEffect
        anchors.fill: parent
        visible: root.weatherEffect === "snow"

        property int flakeCount: Math.round(25 * root.weatherIntensity)

        Repeater {
            model: snowEffect.flakeCount

            Rectangle {
                id: snowFlake
                property real startX: Math.random() * snowEffect.width
                property real startY: -10
                property real fallSpeed: 3000 + Math.random() * 2000
                property real swayAmount: 20 + Math.random() * 30

                x: startX
                y: startY
                width: 3 + Math.random() * 3
                height: width
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.7 + Math.random() * 0.3)

                SequentialAnimation on y {
                    loops: Animation.Infinite
                    running: snowEffect.visible && root.animationsEnabled

                    PropertyAction {
                        value: -10 - Math.random() * 30
                    }
                    NumberAnimation {
                        to: snowEffect.height + 10
                        duration: snowFlake.fallSpeed
                        easing.type: Easing.Linear
                    }
                }

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    running: snowEffect.visible && root.animationsEnabled

                    PropertyAction {
                        value: Math.random() * snowEffect.width
                    }
                    NumberAnimation {
                        to: snowFlake.startX + snowFlake.swayAmount
                        duration: snowFlake.fallSpeed / 2
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: snowFlake.startX - snowFlake.swayAmount
                        duration: snowFlake.fallSpeed / 2
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }

    // Thunderstorm effect (rain + lightning)
    Item {
        id: thunderstormEffect
        anchors.fill: parent
        visible: root.weatherEffect === "thunderstorm"

        property real angle: 20  // degrees from vertical (stronger wind)
        property real angleRad: angle * Math.PI / 180

        // Rain component
        Repeater {
            model: 25

            Rectangle {
                id: stormRainDrop
                property real initialX: Math.random() * (thunderstormEffect.width + 60) - 30
                property real fallDistance: thunderstormEffect.height + 50
                property real horizontalDrift: fallDistance * Math.tan(thunderstormEffect.angleRad)
                property real fallSpeed: 500 + Math.random() * 300
                property real delay: Math.random() * fallSpeed

                x: initialX
                y: -25
                width: 2
                height: 15
                radius: 1
                color: Qt.rgba(0.7, 0.85, 1, 0.7)
                rotation: -thunderstormEffect.angle

                SequentialAnimation {
                    loops: Animation.Infinite
                    running: thunderstormEffect.visible && root.animationsEnabled

                    PauseAnimation {
                        duration: stormRainDrop.delay
                    }

                    ParallelAnimation {
                        NumberAnimation {
                            target: stormRainDrop
                            property: "y"
                            from: -25
                            to: stormRainDrop.fallDistance - 25
                            duration: stormRainDrop.fallSpeed
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: stormRainDrop
                            property: "x"
                            from: stormRainDrop.initialX
                            to: stormRainDrop.initialX + stormRainDrop.horizontalDrift
                            duration: stormRainDrop.fallSpeed
                            easing.type: Easing.Linear
                        }
                    }

                    ScriptAction {
                        script: {
                            stormRainDrop.initialX = Math.random() * (thunderstormEffect.width + 60) - 30;
                        }
                    }
                }
            }
        }

        // Lightning flash
        Rectangle {
            id: lightningFlash
            anchors.fill: parent
            radius: Styling.radius(0)
            color: Qt.rgba(1, 1, 0.9, 0.8)
            opacity: 0
            visible: opacity > 0

            SequentialAnimation {
                loops: Animation.Infinite
                running: thunderstormEffect.visible && root.animationsEnabled

                PauseAnimation {
                    duration: 3000 + Math.random() * 5000
                }

                NumberAnimation {
                    target: lightningFlash
                    property: "opacity"
                    to: 0.9
                    duration: 50
                }
                NumberAnimation {
                    target: lightningFlash
                    property: "opacity"
                    to: 0
                    duration: 100
                }
                NumberAnimation {
                    target: lightningFlash
                    property: "opacity"
                    to: 0.7
                    duration: 50
                }
                NumberAnimation {
                    target: lightningFlash
                    property: "opacity"
                    to: 0
                    duration: 150
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // SUN/MOON ARC
    // ═══════════════════════════════════════════════════════════

    // Sun arc container
    Item {
        id: arcContainer
        anchors.fill: parent

        // Arc dimensions - elliptical arc that fits within the container
        property real arcWidth: width - 40  // Horizontal span
        property real arcHeight: Math.min(70, height * 0.5)  // Vertical height of the arc
        property real arcCenterX: width / 2
        property real arcCenterY: height - 12  // Position at bottom edge

        // The arc path (upper half of ellipse only) with gradient
        Canvas {
            id: arcCanvas
            anchors.fill: parent

            // Arc color based on time of day
            property color arcColor: WeatherService.effectiveIsDay ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(1, 1, 1, 0.4)

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();

                var cx = arcContainer.arcCenterX;
                var cy = arcContainer.arcCenterY;
                var rx = arcContainer.arcWidth / 2;
                var ry = arcContainer.arcHeight;
                var lineWidth = 20;  // Same as celestialBody diameter

                // Create horizontal gradient for the arc (left to right)
                var gradient = ctx.createLinearGradient(cx - rx, cy, cx + rx, cy);
                gradient.addColorStop(0, Qt.rgba(arcColor.r, arcColor.g, arcColor.b, 0));
                gradient.addColorStop(0.5, Qt.rgba(arcColor.r, arcColor.g, arcColor.b, arcColor.a));
                gradient.addColorStop(1, Qt.rgba(arcColor.r, arcColor.g, arcColor.b, 0));

                // Draw the arc as a single continuous path
                ctx.beginPath();
                var steps = 60;
                for (var i = 0; i <= steps; i++) {
                    var angle = Math.PI - (Math.PI * i / steps);  // PI to 0
                    var x = cx + rx * Math.cos(angle);
                    var y = cy - ry * Math.sin(angle);

                    if (i === 0) {
                        ctx.moveTo(x, y);
                    } else {
                        ctx.lineTo(x, y);
                    }
                }

                ctx.strokeStyle = gradient;
                ctx.lineWidth = lineWidth;
                ctx.lineCap = "round";
                ctx.stroke();
            }

            Component.onCompleted: requestPaint()

            Connections {
                target: WeatherService
                function onEffectiveIsDayChanged() {
                    arcCanvas.requestPaint();
                }
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onArcColorChanged: requestPaint()
        }

        // Sun/Moon indicator
        Rectangle {
            id: celestialBody
            width: 20
            height: 20
            radius: 10

            property real progress: WeatherService.effectiveSunProgress

            // Elliptical arc position calculation
            property real angle: Math.PI * (1 - progress)  // PI to 0
            property real posX: arcContainer.arcCenterX + (arcContainer.arcWidth / 2) * Math.cos(angle) - width / 2
            property real posY: arcContainer.arcCenterY - arcContainer.arcHeight * Math.sin(angle) - height / 2

            x: posX
            y: posY

            Behavior on x {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutQuad
                }
            }

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: WeatherService.effectiveIsDay ? "#FFF9C4" : "#FFFFFF"
                }
                GradientStop {
                    position: 0.5
                    color: WeatherService.effectiveIsDay ? "#FFE082" : "#E8E8E8"
                }
                GradientStop {
                    position: 1.0
                    color: WeatherService.effectiveIsDay ? "#FFB74D" : "#C0C0C0"
                }
            }

            // Outer glow
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 12
                height: parent.height + 12
                radius: width / 2
                color: "transparent"
                border.color: WeatherService.effectiveIsDay ? Qt.rgba(1, 0.95, 0.7, 0.4) : Qt.rgba(1, 1, 1, 0.2)
                border.width: 3
                z: -1
            }

            // Inner glow
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 6
                height: parent.height + 6
                radius: width / 2
                color: "transparent"
                border.color: WeatherService.effectiveIsDay ? Qt.rgba(1, 0.95, 0.7, 0.6) : Qt.rgba(1, 1, 1, 0.3)
                border.width: 2
                z: -1
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // TEXT CONTENT
    // ═══════════════════════════════════════════════════════════

    // Temperature (top left)
    Item {
        id: tempContainer
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 12
        width: tempText.width
        height: tempText.height

        // Temperature or error icon
        Text {
            id: tempText
            visible: WeatherService.dataAvailable
            text: Math.round(WeatherService.currentTemp) + "°" + Config.weather.unit
            color: "#FFFFFF"
            font.family: "Noto Sans"
            font.pixelSize: Config.theme.fontSize + 10
            font.weight: Font.Bold
        }

        // Error icon when no data
        Text {
            visible: !WeatherService.dataAvailable
            text: Icons.alert
            font.family: Icons.font
            font.pixelSize: Config.theme.fontSize + 10
            color: "#FFFFFF"
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowBlur: 0.4
            shadowHorizontalOffset: 1
            shadowVerticalOffset: 1
        }
    }

    // Weather description (top right)
    Item {
        id: descContainer
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        width: descText.width
        height: descText.height

        Text {
            id: descText
            text: WeatherService.dataAvailable ? WeatherService.effectiveWeatherDescription : "Error"
            color: Qt.rgba(1, 1, 1, 0.85)
            font.family: "Noto Sans"
            font.pixelSize: Config.theme.fontSize - 2
            font.weight: Font.Bold
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowBlur: 0.4
            shadowHorizontalOffset: 1
            shadowVerticalOffset: 1
        }
    }

    // ═══════════════════════════════════════════════════════════
    // DEBUG CONTROLS
    // ═══════════════════════════════════════════════════════════

    // Debug toggle button (hidden easter egg - visible on hover)
    Rectangle {
        id: debugToggleButton
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 8
        width: 20
        height: 20
        radius: 10
        color: WeatherService.debugMode ? Styling.srItem("overprimary") : "#555"
        opacity: (debugButtonHover.containsMouse || WeatherService.debugMode) ? 0.8 : 0
        visible: root.showDebugControls

        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.InOutQuad
            }
        }

        Text {
            anchors.centerIn: parent
            text: "D"
            font.pixelSize: 10
            font.bold: true
            color: "#fff"
        }

        MouseArea {
            id: debugButtonHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: WeatherService.debugMode = !WeatherService.debugMode
        }
    }
}
