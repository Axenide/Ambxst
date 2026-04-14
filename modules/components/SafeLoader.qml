import QtQuick

/**
 * SafeLoader - A Loader with built-in error handling and fallback UI
 * Use this instead of plain Loader for components that may fail to load
 */
Item {
    id: root

    property var sourceComponent
    property string placeholderText: "Loading..."
    property bool showPlaceholder: true
    property color placeholderColor: "#808080"
    property var fallbackItem

    // Internal loader — not exposed as public API to prevent callers from
    // bypassing root.sourceComponent and writing to it directly.
    Loader {
        id: internalLoader
        anchors.fill: parent
        sourceComponent: root.sourceComponent
        asynchronous: true

        onStatusChanged: {
            if (internalLoader.status === Loader.Error) {
                console.error("[SafeLoader] Failed to load component:", internalLoader.errorString);
                root.handleError(internalLoader.errorString);
            }
        }
    }

    signal loadError(string errorString)

    function handleError(errorString) {
        root.loadError(errorString);
    }

    // Read-only state properties
    readonly property bool isLoading: internalLoader.status === Loader.Loading
    readonly property bool hasError:  internalLoader.status === Loader.Error
    readonly property bool isReady:   internalLoader.status === Loader.Ready

    // Fallback content when loading or error
    Rectangle {
    // Fallback content shown while loading or on error (when no custom fallback)
    StyledRect {
        (fix(SafeLoader): fix fallbackContainer parent assignment, make loader internal)
        id: placeholder
        anchors.fill: parent
        visible: root.showPlaceholder && (root.isLoading || root.hasError) && !root.fallbackItem
        color: root.hasError ? "#20000000" : "transparent"

        Text {
            anchors.centerIn: parent
            text: root.hasError ? "Failed to load" : root.placeholderText
            color: root.placeholderColor
            font.pixelSize: 14
        }
    }

    // Container for a caller-supplied fallback item; shown on error only.
    Item {
        id: fallbackContainer
        anchors.fill: parent
        visible: root.fallbackItem !== null && root.hasError
        z: 10
    }

    // Reparent a caller-supplied item into the fallback container so it
    // becomes visible when the load fails.
    function setFallback(item) {
        root.fallbackItem = item;
        item.parent = fallbackContainer;
    }

    // Retry loading by null-cycling sourceComponent (standard QML pattern).
    function retry() {
        var current = root.sourceComponent;
        internalLoader.sourceComponent = null;
        internalLoader.sourceComponent = current;
    }
}
