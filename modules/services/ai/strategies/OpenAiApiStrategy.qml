import QtQuick

ApiStrategy {
    supportsStreaming: true

    function getEndpoint(modelObj, apiKey) {
        let base = modelObj.endpoint || "https://api.openai.com";
        // Ensure we don't double-append /v1
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

    function _formatMessages(messages) {
        let formatted = [];
        for (let i = 0; i < messages.length; i++) {
            let msg = messages[i];
            if (msg.attachments && msg.attachments.length > 0) {
                let contentParts = [{type: "text", text: msg.content}];
                for (let j = 0; j < msg.attachments.length; j++) {
                    let att = msg.attachments[j];
                    if (att.type === "image") {
                        contentParts.push({
                            type: "image_url",
                            image_url: { url: "data:" + att.mimeType + ";base64," + att.base64 }
                        });
                    }
                }
                formatted.push({ role: msg.role, content: contentParts });
            } else {
                formatted.push({ role: msg.role, content: msg.content });
            }
        }
        return formatted;
    }
    function getBody(messages, model, tools) {
        let body = {
            model: model.model,
            messages: _formatMessages(messages),
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

        if (!trimmed.startsWith("data: "))
            return { content: "", done: false, error: null };

        try {
            let json = JSON.parse(trimmed.substring(6));
            if (json.choices && json.choices.length > 0) {
                let delta = json.choices[0].delta;
                if (delta && delta.content)
                    return { content: delta.content, done: false, error: null };

                // Check for tool calls in stream
                if (delta && delta.tool_calls) {
                    // Accumulate tool call data — handled by Ai.qml
                    return { content: "", done: false, error: null, toolCallDelta: delta.tool_calls };
                }

                // finish_reason check
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
