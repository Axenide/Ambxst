import QtQuick
import "TransitionIconArt.js" as Art

// A line drawing of one skwd-wall transition for the
// Transition Style carousel. Still (a frame half way through) until
// `animating`, when it plays the transition on a loop. Only an animating icon
// repaints, so a carousel of them costs nothing at rest.
Canvas {
    id: icon

    property string transition: "crossfade"
    property bool animating: false
    property color lineColor: "white"
    property color accentColor: "white"
    property real progress: 0.55

    renderStrategy: Canvas.Cooperative
    antialiasing: true

    onProgressChanged: requestPaint()
    onTransitionChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onAccentColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onAnimatingChanged: if (!animating) progress = 0.55

    SequentialAnimation on progress {
        running: icon.animating
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 0; duration: 250 }
        NumberAnimation { from: 0; to: 1; duration: 1300; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 650 }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        Art.draw(ctx, icon.transition, Math.max(0, Math.min(1, icon.progress)), width, height, String(icon.lineColor), String(icon.accentColor));
    }
}
