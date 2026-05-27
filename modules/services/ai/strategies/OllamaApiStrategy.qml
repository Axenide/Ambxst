import QtQuick

ApiStrategy {
    supportsStreaming: true

    function getEndpoint(modelObj, apiKey) {
        let base = modelObj.endpoint || "http://localhost:11434";
        return base + "/api/chat";
    }

    function getHeaders(apiKey) {
        return ["Content-Type: application/json"];
    }

    function getBody(messages, model, tools) {
        return {
            model: model.model,
            messages: messages,
            stream: false
        };
    }

    function getStreamBody(messages, model, tools) {
        return {
            model: model.model,
            messages: messages,
            stream: true
        };
    }

    function parseResponse(response) {
        try {
            let json = JSON.parse(response);
            if (json.message && json.message.content)
                return { content: json.message.content };
            if (json.error)
                return { content: "Ollama Error: " + json.error };
            return { content: "Error: No content in response." };
        } catch (e) {
            return { content: "Error parsing response: " + e.message };
        }
    }

    // Ollama uses NDJSON, not SSE — each line is a JSON object
    function parseStreamChunk(line) {
        let trimmed = line.trim();
        if (trimmed === "")
            return { content: "", done: false, error: null };

        try {
            let json = JSON.parse(trimmed);
            if (json.done)
                return { content: json.message ? json.message.content || "" : "", done: true, error: null };
            if (json.message && json.message.content)
                return { content: json.message.content, done: false, error: null };
            if (json.error)
                return { content: "", done: false, error: json.error };
            return { content: "", done: false, error: null };
        } catch (e) {
            return { content: "", done: false, error: null };
        }
    }
}
