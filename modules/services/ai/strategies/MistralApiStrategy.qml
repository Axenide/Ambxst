import QtQuick

// Reuses OpenAI-compatible format — identical to OpenAiApiStrategy
// but with Mistral's default endpoint
ApiStrategy {
    supportsStreaming: true

    function getEndpoint(modelObj, apiKey) {
        let base = modelObj.endpoint || "https://api.mistral.ai/v1";
        // Remove /chat/completions if already present in endpoint
        if (base.endsWith("/chat/completions")) {
            base = base.substring(0, base.length - 17); // remove "/chat/completions"
        }
        if (base.endsWith("/v1"))
            return base + "/chat/completions";
        return base + "/v1/chat/completions";
    }

    function getHeaders(apiKey) {
        return [
            "Content-Type: application/json",
            "Authorization: Bearer " + apiKey
        ];
    }

    function getBody(messages, model, tools) {
        let body = {
            model: model.model,
            messages: messages,
            temperature: 0.7
        };
        if (tools && tools.length > 0) {
            body.tools = tools.map(t => ({
                type: "function",
                function: {
                    name: t.name,
                    description: t.description,
                    parameters: t.parameters
                }
            }));
        }
        return body;
    }

    function getStreamBody(messages, model, tools) {
        let body = getBody(messages, model, tools);
        body.stream = true;
        return body;
    }

    function parseResponse(response) {
        try {
            let json = JSON.parse(response);
            if (json.choices && json.choices.length > 0) {
                let msg = json.choices[0].message;
                if (msg.tool_calls && msg.tool_calls.length > 0) {
                    let tc = msg.tool_calls[0];
                    return {
                        content: msg.content || "",
                        functionCall: {
                            name: tc.function.name,
                            args: JSON.parse(tc.function.arguments)
                        }
                    };
                }
                return { content: msg.content };
            }
            if (json.error)
                return { content: "API Error: " + json.error.message };
            return { content: "Error: No content in response." };
        } catch (e) {
            return { content: "Error parsing response: " + e.message };
        }
    }

    function parseStreamChunk(line) {
        let trimmed = line.trim();
        if (trimmed === "" || trimmed.startsWith("event:"))
            return { content: "", done: false, error: null };

        if (trimmed === "data: [DONE]")
            return { content: "", done: true, error: null };

        // Check if this is a JSON error response (not SSE format)
        if (!trimmed.startsWith("data: ")) {
            try {
                let json = JSON.parse(trimmed);
                if (json.error) {
                    return { content: "", done: false, error: json.error.message || json.error };
                }
            } catch (e) {
                // Not JSON, ignore
            }
            return { content: "", done: false, error: null };
        }

        try {
            let json = JSON.parse(trimmed.substring(6));
            if (json.choices && json.choices.length > 0) {
                let delta = json.choices[0].delta;
                if (delta && delta.content)
                    return { content: delta.content, done: false, error: null };
                if (json.choices[0].finish_reason)
                    return { content: "", done: true, error: null };
            }
            if (json.error)
                return { content: "", done: false, error: json.error.message };
            return { content: "", done: false, error: null };
        } catch (e) {
            return { content: "", done: false, error: null };
        }
    }
}
