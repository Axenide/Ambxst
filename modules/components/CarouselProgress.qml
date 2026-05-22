import QtQuick
import qs.config
import qs.modules.theme

WavyLine {
    id: root

    // API Compatibility for CarouselProgress users
    property real dotSize: 4
    property real spacing: 6
    property real targetSpacing: 6
    property bool active: true

    // Map Carousel properties to WavyLine properties
    lineWidth: dotSize
    
    // Default WavyLine properties are already set in WavyLine.qml
    // Users can override frequency, amplitude etc.
}
