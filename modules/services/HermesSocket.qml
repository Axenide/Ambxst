import QtQuick
import QtWebSockets

// Loaded on demand by HermesGateway so the shell never imports QtWebSockets
// unless the Hermes backend is actually used: the module is an optional
// dependency (qt6-websockets / qt6-qtwebsockets).
QtObject {
    id: root

    // Empty until the handshake completes; never logged.
    readonly property string negotiatedProtocol: socket.negotiatedSubprotocol
    // A response is only worth dropping its prompt for if the socket can send it.
    readonly property bool isOpen: socket.status === WebSocket.Open

    signal opened()
    signal closed()
    signal frame(string text)
    signal failure(string message)

    function dial(url, protocols) {
        socket.url = url;
        socket.requestedSubprotocols = protocols;
        socket.active = true;
    }

    function send(text) {
        socket.sendTextMessage(text);
    }

    function close() {
        if (socket.active)
            socket.active = false;
    }

    property WebSocket socket: WebSocket {
        onStatusChanged: {
            if (socket.status === WebSocket.Open) {
                root.opened();
            } else if (socket.status === WebSocket.Closed) {
                root.closed();
            } else if (socket.status === WebSocket.Error) {
                root.failure(socket.errorString);
                root.closed();
            }
        }

        onTextMessageReceived: message => root.frame(message)
    }
}
