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

    property Loader loader: Loader {
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

    // Show loading state
    property bool isLoading: loader.status === Loader.Loading
    property bool hasError: loader.status === Loader.Error
    property bool isReady: loader.status === Loader.Ready

    // Fallback content when loading or error
    Rectangle {
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

    // Custom fallback item
    property Item fallbackContainer: Item {
        anchors.fill: parent
        visible: root.fallbackItem !== null && root.hasError
        z: 10
    }

    // Set fallback item from outside
    function setFallback(item) {
        root.fallbackItem = item;
    }

    // Retry loading
    function retry() {
        var current = loader.sourceComponent;
        loader.sourceComponent = null;
        loader.sourceComponent = current;
    }
}