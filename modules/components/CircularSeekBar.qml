import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.config

Item {
    id: root

    property real value: 0
    property color accentColor: Colors.primary
    property color trackColor: Colors.outline
    property real lineWidth: 8
    property real ringPadding: 12 // Increased to avoid handle clipping
    property bool enabled: true
    readonly property bool isDragging: mouseArea.isDragging

    signal valueEdited(real newValue)
    signal draggingChanged(bool dragging)

    width: 200
    height: 200

    property real startAngleDeg: 180 // 9 o'clock
    property real spanAngleDeg: 180 // Half circle clockwise to 3 o'clock
    
    // Internal drag state
    property real dragValue: 0
    property real animatedHandleOffset: isDragging ? 9 : 6 // Grow to 18px (9*2) instead of 24px
    property real animatedHandleWidth: isDragging ? lineWidth * 0.5 : lineWidth

    Behavior on animatedHandleOffset { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on animatedHandleWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        preventStealing: true

        property bool isDragging: false

        function updateValueFromMouse(mouseX, mouseY) {
            let centerX = width / 2;
            let centerY = height / 2;
            
            // Calculate angle in radians
            let angle = Math.atan2(mouseY - centerY, mouseX - centerX);
            
            // Normalize angle to [0, 2*PI) starting from 0 (3 o'clock)
            if (angle < 0) angle += 2 * Math.PI;

            // Convert inputs to radians
            let startRad = root.startAngleDeg * Math.PI / 180;
            let spanRad = root.spanAngleDeg * Math.PI / 180;

            // We need to map the mouse angle to our span.
            // Problem: Canvas angles can wrap. 180 to 360 is continuous.
            // But what if start is 270 and span is 180 (270 -> 90)?
            // Let's assume standard use case: 180 (left) -> 360 (right).
            
            // Shift angle so start is at 0
            // BUT, if we are in the "dead zone" (bottom half), we need to clamp.
            
            // Simple approach for 180->360 (Top Half):
            // 3 o'clock = 0/360. 9 o'clock = 180.
            // Mouse angle goes 0..PI..2PI.
            // We want inputs from PI to 2PI.
            // If angle is between 0 and PI (bottom half), we clamp to nearest end.
            
            let relativeAngle = angle - startRad;
            // Normalize relative angle
            while (relativeAngle < 0) relativeAngle += 2 * Math.PI;
            
            // If the angle is within the span, use it.
            // If it's outside, clamp to 0 or span.
            // This 'outside' is the dead zone (360 - span).
            
            let progress = 0;
            
            if (relativeAngle <= spanRad) {
                progress = relativeAngle / spanRad;
            } else {
                // Closer to start or end?
                // The "end" of the active arc is at `spanRad`. 
                // The "start" is at 0 (relative).
                // Distance to end: relativeAngle - spanRad
                // Distance to start (wrap around): 2*PI - relativeAngle
                
                let distToEnd = relativeAngle - spanRad;
                let distToStart = 2 * Math.PI - relativeAngle;
                
                if (distToEnd < distToStart) {
                    progress = 1.0;
                } else {
                    progress = 0.0;
                }
            }
            
            root.dragValue = progress;
            canvas.requestPaint();
        }

        onPressed: mouse => {
            isDragging = true;
            root.dragValue = root.value; // Initialize drag value
            root.draggingChanged(true);
            updateValueFromMouse(mouse.x, mouse.y);
        }

        onPositionChanged: mouse => {
            if (isDragging) {
                updateValueFromMouse(mouse.x, mouse.y);
            }
        }

        onReleased: {
            if (isDragging) {
                isDragging = false;
                root.draggingChanged(false);
                root.valueEdited(root.dragValue); // Commit value on release
            }
        }
    }

    property real handleSpacing: 10 // Increased to ensure gap is visible with thicker handle
    property real handleSize: 8 
    
    property bool wavy: false // New property to enable wavy progress
    property real wavePhase: 0
    property real waveFrequency: 12 // Adjust for visual density
    property real waveAmplitude: 2.5 // Pixel amplitude

    Behavior on waveAmplitude {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    // Animation for the wave - only when visible AND amplitude > 0 to save GPU
    property bool animationsEnabled: true
    NumberAnimation on wavePhase {
        from: 0
        to: Math.PI * 2
        duration: 2000
        loops: Animation.Infinite
        // Don't animate invisible waves (amplitude 0 = paused music)
        running: root.wavy && root.enabled && root.visible && root.animationsEnabled && root.waveAmplitude > 0
    }

    Item {
        id: progressCanvas
        anchors.centerIn: parent
        anchors.fill: parent

        // Use dragValue while dragging, otherwise bound value
        property real progress: root.isDragging ? root.dragValue : root.value

        CircularWavyProgress {
            id: wavyProgress
            anchors.fill: parent
            visible: root.wavy

            // Geometry Logic
            property real pixelRadius: (Math.min(parent.width, parent.height) / 2) - root.ringPadding
            radius: pixelRadius / parent.width
            
            startAngleRad: root.startAngleDeg * Math.PI / 180
            
            // Calculate progress angle relative to handle gap
            property real spanRad: root.spanAngleDeg * Math.PI / 180
            property real handleGapRad: root.handleSpacing / pixelRadius
            property real rawProgress: progressCanvas.progress
            
            // Effective progress angle (0 to span - gap)
            property real effectiveProgress: Math.max(0, (spanRad * rawProgress) - handleGapRad)
            
            progressAngleRad: effectiveProgress
            
            // Styling
            color: root.accentColor
            thickness: root.lineWidth / parent.width
            amplitude: root.waveAmplitude / parent.width // Convert px to normalized
            frequency: root.waveFrequency
            phase: root.wavePhase
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                let ctx = getContext("2d");
                ctx.reset();

                let centerX = width / 2;
                let centerY = height / 2;
                // Radius reduced by ringPadding to allow handle space
                let radius = (Math.min(width, height) / 2) - root.ringPadding;
                let lineWidth = root.lineWidth;

                ctx.lineCap = "round";

                let startRad = root.startAngleDeg * Math.PI / 180;
                let spanRad = root.spanAngleDeg * Math.PI / 180;
                let currentSpan = spanRad * progressCanvas.progress;
                
                // Calculate gap in radians based on handleSpacing (pixels)
                let handleGapRad = root.handleSpacing / radius;
                
                // Draw track (background part)
                // Starts after current position + gap
                let remainingStart = startRad + currentSpan + handleGapRad;
                let totalEnd = startRad + spanRad;

                if (remainingStart < totalEnd) {
                    ctx.strokeStyle = root.trackColor;
                    ctx.lineWidth = lineWidth;
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius, remainingStart, totalEnd, false);
                    ctx.stroke();
                }

                // Draw progress (Only if NOT wavy, or if wavy is failing/disabled)
                // Ends at current position - gap
                let progressEnd = startRad + currentSpan - handleGapRad;
                
                if (!root.wavy && progressCanvas.progress > 0 && progressEnd > startRad) {
                    ctx.strokeStyle = root.accentColor;
                    ctx.lineWidth = lineWidth;
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius, startRad, progressEnd, false);
                    ctx.stroke();
                }

                // Draw handle (radial line at current position)
                if (root.enabled) {
                    let handleAngle = startRad + currentSpan;
                    // Handle Dimensions
                    let innerRadius = radius - root.animatedHandleOffset;
                    let outerRadius = radius + root.animatedHandleOffset;

                    let innerX = centerX + innerRadius * Math.cos(handleAngle);
                    let innerY = centerY + innerRadius * Math.sin(handleAngle);
                    let outerX = centerX + outerRadius * Math.cos(handleAngle);
                    let outerY = centerY + outerRadius * Math.sin(handleAngle);

                    ctx.strokeStyle = Colors.overBackground;
                    ctx.lineWidth = root.animatedHandleWidth;
                    ctx.beginPath();
                    ctx.moveTo(innerX, innerY);
                    ctx.lineTo(outerX, outerY);
                    ctx.stroke();
                }
            }
            
            Connections {
                target: progressCanvas
                function onProgressChanged() { canvas.requestPaint(); }
            }
            
            Connections {
                target: root
                function onAccentColorChanged() { canvas.requestPaint(); }
                function onValueEdited() { canvas.requestPaint(); }
                function onAnimatedHandleOffsetChanged() { canvas.requestPaint(); }
                function onAnimatedHandleWidthChanged() { canvas.requestPaint(); }
                // Wave properties drive the shader, not canvas paint (unless fallback logic is needed)
            }
        }

        Behavior on progress {
            enabled: Config.animDuration > 0 && !root.isDragging
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }
}
