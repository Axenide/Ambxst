import QtQuick
import qs.config

/**
 * GradientCanvas - A Canvas that renders a 1D gradient texture.
 * Used internally by GradientCache to generate shared gradient textures.
 */
Canvas {
    id: root

    width: 256
    height: 32  // Extra height avoids interpolation artifacts
    visible: false

    required property var gradientStops

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        const stops = root.gradientStops;
        if (!stops || stops.length === 0)
            return;

        const grad = ctx.createLinearGradient(0, 0, width, 0);
        for (let i = 0; i < stops.length; i++) {
            const s = stops[i];
            grad.addColorStop(s[1], Config.resolveColor(s[0]));
        }

        ctx.fillStyle = grad;
        ctx.fillRect(0, 0, width, height);
    }

    Component.onCompleted: requestPaint()
}
