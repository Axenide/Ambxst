import QtQuick
import QtQuick.Shapes
import qs.config
import qs.modules.theme

Item {
    id: root

    // =========================================================================
    // API Properties
    // =========================================================================

    property real value: 0           // 0.0 to 1.0
    property real startAngleDeg: 180 // 9 o'clock
    property real spanAngleDeg: 180  // Clockwise sweep
    
    property color accentColor: Colors.primary
    property color trackColor: Colors.outline
    
    property real lineWidth: 6
    property real ringPadding: 12    // Padding from edge
    
    property bool enabled: true
    property bool dashed: false      // Enable dashed style for progress
    property bool dashedActive: false// Animate dashes (breathing/marquee)
    
    // Wavy properties kept for compatibility (ignored in Shape version)
    property bool wavy: false
    property real waveAmplitude: 0
    property real waveFrequency: 0

    // =========================================================================
    // Signals
    // =========================================================================

    signal valueEdited(real newValue)
    signal draggingChanged(bool dragging)

    // =========================================================================
    // Internal Logic
    // =========================================================================

    readonly property bool isDragging: mouseArea.isDragging
    property real dragValue: 0
    
    // Handle Animation
    property real animatedHandleOffset: isDragging ? 9 : 6
    property real animatedHandleWidth: isDragging ? lineWidth * 0.5 : lineWidth
    Behavior on animatedHandleOffset { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on animatedHandleWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // Dash Configuration (Matches CarouselProgress logic)
    property real dotSize: lineWidth
    property real baseDashLength: dotSize * 2.5
    property real targetSpacing: 6
    
    // Dynamic Dash/Gap
    // Active:   Dash = base, Gap = target
    // Inactive: Dash = base + target, Gap = 0 (Solid)
    
    property real currentDashLen: dashedActive ? baseDashLength : (baseDashLength + targetSpacing)
    property real currentGapLen: dashedActive ? targetSpacing : 0
    
    Behavior on currentDashLen { NumberAnimation { duration: Config.animDuration; easing.type: Easing.InOutQuad } }
    Behavior on currentGapLen { NumberAnimation { duration: Config.animDuration; easing.type: Easing.InOutQuad } }

    // Marquee Animation
    property real phase: 0
    readonly property real cycleLength: baseDashLength + targetSpacing
    
    NumberAnimation on phase {
        running: (root.dashedActive || root.wavy) && root.visible
        from: 0
        to: -root.cycleLength // Move forward along path
        duration: 1000 // Adjust speed
        loops: Animation.Infinite
    }

    // Wave Animation
    property real wavePhase: 0
    
    // Animate phase using a Timer to control framerate (30 FPS) for performance
    // Full 60 FPS shape regeneration can be too heavy
    Timer {
        id: waveTimer
        interval: 32 // ~30 FPS
        running: root.wavy && root.visible && (root.value > 0 || root.isDragging)
        repeat: true
        onTriggered: {
            root.wavePhase = (root.wavePhase + 0.1) % (Math.PI * 2)
        }
    }

    // Geometry Helpers
    readonly property real radius: (Math.min(width, height) / 2) - ringPadding
    readonly property real effectiveValue: isDragging ? dragValue : value
    
    // Handle Position & Gaps
    property real handleSpacing: 10 
    
    readonly property real gapAngleRad: (handleSpacing / 2) / Math.max(1, radius)
    readonly property real gapAngleDeg: gapAngleRad * 180 / Math.PI
    
    readonly property real currentAngleRad: (startAngleDeg + (spanAngleDeg * effectiveValue)) * Math.PI / 180

    // Wavy Radius at Handle - Simplified for static wave
    // Handle stays on track, does not follow wave
    readonly property real waveOffsetAtHandle: 0 
    readonly property real effectiveRadiusAtHandle: root.radius

    // Generate Wavy Arc Points
    function generateWavyArcPoints(startDeg, endDeg, phase) {
        if (phase === undefined) phase = 0;
        
        if (startDeg >= endDeg - 0.1) return []; // Too small or invalid

        let points = [];
        let step = 0.5; // Smooth enough for static
        
        let centerX = root.width / 2;
        let centerY = root.height / 2;
        let baseR = root.radius;
        let waveFreq = root.waveFrequency;
        let waveAmp = root.waveAmplitude;

        for (let angleDeg = startDeg; angleDeg <= endDeg + 0.001; angleDeg += step) {
             let clampedDeg = Math.min(angleDeg, endDeg);
             let angleRad = clampedDeg * Math.PI / 180;
             
             let waveOffset = Math.sin((angleRad * waveFreq) + phase) * waveAmp;
             let r = baseR + waveOffset;
             
             points.push(Qt.point(centerX + r * Math.cos(angleRad), centerY + r * Math.sin(angleRad)));
             
             if (clampedDeg >= endDeg) break;
        }
        return points;
    }

    // =========================================================================

    // Input Handling
    // =========================================================================

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
            let angle = Math.atan2(mouseY - centerY, mouseX - centerX);
            if (angle < 0) angle += 2 * Math.PI;

            let startRad = root.startAngleDeg * Math.PI / 180;
            let spanRad = root.spanAngleDeg * Math.PI / 180;
            
            // Normalize angle relative to start
            let relAngle = angle - startRad;
            while (relAngle < 0) relAngle += 2 * Math.PI;
            
            let progress = 0;
            if (relAngle <= spanRad) {
                progress = relAngle / spanRad;
            } else {
                // Snap to nearest end
                let distToEnd = relAngle - spanRad;
                let distToStart = 2 * Math.PI - relAngle;
                progress = (distToEnd < distToStart) ? 1.0 : 0.0;
            }
            
            root.dragValue = progress;
        }

        onPressed: mouse => {
            isDragging = true;
            root.dragValue = root.value;
            root.draggingChanged(true);
            updateValueFromMouse(mouse.x, mouse.y);
        }

        onPositionChanged: mouse => {
            if (isDragging) updateValueFromMouse(mouse.x, mouse.y);
        }

        onReleased: {
            if (isDragging) {
                isDragging = false;
                root.draggingChanged(false);
                root.valueEdited(root.dragValue);
            }
        }
    }


    // =========================================================================
    // Rendering (QtQuick.Shapes)
    // =========================================================================

    Shape {
        id: shapeRenderer
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // 1. Progress Arc (Dashed or Solid) - NORMAL
        ShapePath {
            strokeColor: (!root.wavy) ? root.accentColor : "transparent"
            strokeWidth: root.lineWidth
            
            strokeStyle: root.dashed ? ShapePath.DashLine : ShapePath.SolidLine
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            
            dashPattern: [
                Math.max(0.001, root.currentDashLen / root.lineWidth),
                Math.max(0.001, root.currentGapLen / root.lineWidth)
            ]
            dashOffset: root.phase / root.lineWidth
            
            fillColor: "transparent"
            
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.startAngleDeg
                sweepAngle: Math.max(0, (root.spanAngleDeg * root.effectiveValue) - root.gapAngleDeg)
            }
        }

        // 1b. Progress Arc - WAVY
        ShapePath {
            strokeColor: root.wavy ? root.accentColor : "transparent"
            strokeWidth: root.lineWidth
            
            strokeStyle: root.dashed ? ShapePath.DashLine : ShapePath.SolidLine
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            
            dashPattern: [
                Math.max(0.001, root.currentDashLen / root.lineWidth),
                Math.max(0.001, root.currentGapLen / root.lineWidth)
            ]
            dashOffset: root.phase / root.lineWidth
            
            fillColor: "transparent"
            
            startX: wavyProgressPoly.path.length > 0 ? wavyProgressPoly.path[0].x : 0
            startY: wavyProgressPoly.path.length > 0 ? wavyProgressPoly.path[0].y : 0

            PathPolyline {
                id: wavyProgressPoly
                path: root.generateWavyArcPoints(
                    root.startAngleDeg, 
                    root.startAngleDeg + Math.max(0, (root.spanAngleDeg * root.effectiveValue) - root.gapAngleDeg),
                    root.wavePhase // Force dependency
                )
            }
        }

        // 2. Track (Background) - NORMAL
        ShapePath {
            strokeColor: (!root.wavy) ? root.trackColor : "transparent"
            strokeWidth: root.lineWidth
            strokeStyle: ShapePath.SolidLine
            capStyle: ShapePath.RoundCap
            
            fillColor: "transparent"
            
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.startAngleDeg + (root.spanAngleDeg * root.effectiveValue) + root.gapAngleDeg
                sweepAngle: Math.max(0, (root.spanAngleDeg * (1.0 - root.effectiveValue)) - root.gapAngleDeg)
            }
        }

        // 2b. Track (Background) - WAVY
        ShapePath {
            // Reverted to flat background per request
            strokeColor: root.wavy ? root.trackColor : "transparent"
            strokeWidth: root.lineWidth
            strokeStyle: ShapePath.SolidLine
            capStyle: ShapePath.RoundCap
            
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.startAngleDeg + (root.spanAngleDeg * root.effectiveValue) + root.gapAngleDeg
                sweepAngle: Math.max(0, (root.spanAngleDeg * (1.0 - root.effectiveValue)) - root.gapAngleDeg)
            }
        }
        
        // 3. Handle (Line)
        ShapePath {
            strokeColor: Colors.overBackground
            strokeWidth: root.animatedHandleWidth
            strokeStyle: ShapePath.SolidLine
            capStyle: ShapePath.RoundCap
            
            fillColor: "transparent"
            
            // Line points
            // Start: radius - offset
            // End: radius + offset
            
            startX: (root.width / 2) + (root.effectiveRadiusAtHandle - root.animatedHandleOffset) * Math.cos(root.currentAngleRad)
            startY: (root.height / 2) + (root.effectiveRadiusAtHandle - root.animatedHandleOffset) * Math.sin(root.currentAngleRad)
            
            PathLine {
                x: (root.width / 2) + (root.effectiveRadiusAtHandle + root.animatedHandleOffset) * Math.cos(root.currentAngleRad)
                y: (root.height / 2) + (root.effectiveRadiusAtHandle + root.animatedHandleOffset) * Math.sin(root.currentAngleRad)
            }
        }
    }
}
