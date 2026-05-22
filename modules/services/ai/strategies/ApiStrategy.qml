import QtQuick

QtObject {
    property bool supportsStreaming: true

    function getEndpoint(modelObj, apiKey) { return ""; }
    function getHeaders(apiKey) { return []; }
    function getBody(messages, model, tools) { return {}; }
    function getStreamBody(messages, model, tools) {
        let body = getBody(messages, model, tools);
        body.stream = true;
        return body;
    }
    function parseResponse(response) { return { content: "" }; }
    function parseStreamChunk(line) {
        // Override in subclasses. Returns: { content: "token", done: false, error: null }
        return { content: "", done: true, error: null };
    }
}
