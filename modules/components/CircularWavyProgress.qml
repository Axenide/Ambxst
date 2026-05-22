import QtQuick

Item {
    id: root
    
    // -- Geometry (Normalized 0.0 - 1.0 relative to width/height) --
    property real radius: 0.45
    property real startAngleRad: Math.PI // Default 180 deg (left side)
    property real progressAngleRad: Math.PI // Default 180 deg span
    
    // -- Wave --
    property real amplitude: 0.01  // Normalized to radius
    property real frequency: 20
    property real phase: 0.0
    property real thickness: 0.02  // Normalized stroke width
    property color color: "white"
    
    // -- Animation control --
    property bool animating: false
    property real animationSpeed: 1.0 // Radians per second
    
    // Effective running state
    readonly property bool shouldAnimate: animating && visible && opacity > 0 && width > 0
    
    // Internal computed values
    readonly property real centerX: width / 2
    readonly property real centerY: height / 2
    readonly property real baseRadius: Math.min(width, height) * radius
    readonly property real strokeWidth: Math.min(width, height) * thickness
    readonly property real waveAmp: baseRadius * amplitude
    
    property real _phase: phase
    
    // Animation timer - only runs when shouldAnimate
    Timer {
        id: animTimer
        interval: 50
        running: root.shouldAnimate
        repeat: true
        onTriggered: {
            let dt = interval / 1000.0;
            root._phase = (root._phase + root.animationSpeed * dt) % (Math.PI * 2);
            canvas.requestPaint();
        }
    }
    
    // Sync internal phase with external when not animating
    onPhaseChanged: if (!shouldAnimate) { _phase = phase; _updateStatic(); }

    // =========================================================================
    // Static Image - shown when NOT animating (no GPU activity)
    // =========================================================================
    Image {
        mipmap: true
        id: staticImage
        anchors.fill: parent
        visible: !root.shouldAnimate && source !== ""
        cache: true
        asynchronous: false
    }
    
    onShouldAnimateChanged: {
        if (!shouldAnimate && width > 0 && height > 0) {
            canvas.visible = true;
            canvas.requestPaint();
            canvas.grabToImage(function(result) {
                staticImage.source = result.url;
                canvas.visible = false;
            });
        } else if (shouldAnimate) {
            canvas.visible = true;
        }
    }
    
    function _updateStatic() {
        if (!shouldAnimate && width > 0 && height > 0) {
            canvas.visible = true;
            canvas.requestPaint();
            grabTimer.restart();
        }
    }
    
    Timer {
        id: grabTimer
        interval: 16
        onTriggered: {
            canvas.grabToImage(function(result) {
                staticImage.source = result.url;
                if (!root.shouldAnimate) canvas.visible = false;
            });
        }
    }
    
    onColorChanged: _updateStatic()
    onThicknessChanged: _updateStatic()
    onRadiusChanged: _updateStatic()
    onStartAngleRadChanged: _updateStatic()
    onProgressAngleRadChanged: _updateStatic()
    onAmplitudeChanged: _updateStatic()
    onFrequencyChanged: _updateStatic()
    onWidthChanged: _updateStatic()
    onHeightChanged: _updateStatic()
    
    Component.onCompleted: {
        if (!shouldAnimate && width > 0 && height > 0) {
            _updateStatic();
        }
    }

    // =========================================================================
    // Canvas - only visible during animation
    // =========================================================================
    Canvas {
        id: canvas
        anchors.fill: parent
        visible: root.shouldAnimate
        
        renderStrategy: Canvas.Threaded
        renderTarget: Canvas.Image
        
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            
            let w = root.width;
            let h = root.height;
            if (w <= 0 || h <= 0) return;
            
            let cx = root.centerX;
            let cy = root.centerY;
            let r = root.baseRadius;
            let amp = root.waveAmp;
            let freq = root.frequency;
            let phase = root._phase;
            let startAngle = root.startAngleRad;
            let progressAngle = root.progressAngleRad;
            
            let arcLength = r * Math.abs(progressAngle);
            let pointCount = Math.max(Math.floor(arcLength / 6), 12);
            pointCount = Math.min(pointCount, 100);
            
            ctx.strokeStyle = root.color;
            ctx.lineWidth = root.strokeWidth;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            
            ctx.beginPath();
            
            for (let i = 0; i < pointCount; i++) {
                let t = i / (pointCount - 1);
                let angle = startAngle + t * progressAngle;
                let wavyRadius = r + Math.sin(angle * freq + phase) * amp;
                
                let x = cx + Math.cos(angle) * wavyRadius;
                let y = cy + Math.sin(angle) * wavyRadius;
                
                if (i === 0) {
                    ctx.moveTo(x, y);
                } else {
                    ctx.lineTo(x, y);
                }
            }
            
            ctx.stroke();
        }
    }
}
