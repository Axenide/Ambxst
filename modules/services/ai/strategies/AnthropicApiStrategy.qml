import QtQuick

ApiStrategy {
    supportsStreaming: true

    function getEndpoint(modelObj, apiKey) {
        return modelObj.endpoint || "https://api.anthropic.com/v1/messages";
    }

    function getHeaders(apiKey) {
        return [
            "Content-Type: application/json",
            "x-api-key: " + apiKey,
            "anthropic-version: 2023-06-01",
            "anthropic-beta: prompt-caching-2024-07-31"
        ];
    }

    function _extractSystemPrompt(messages) {
        for (let i = 0; i < messages.length; i++) {
            if (messages[i].role === "system")
                return messages[i].content;
        }
        return "";
    }

    function _filterMessages(messages) {
        let filtered = [];
        for (let i = 0; i < messages.length; i++) {
            if (messages[i].role === "system")
                continue;
            let role = messages[i].role;
            if (role === "function")
                role = "user";
            let msg = messages[i];
            if (msg.attachments && msg.attachments.length > 0) {
                let contentParts = [];
                for (let j = 0; j < msg.attachments.length; j++) {
                    let att = msg.attachments[j];
                    if (att.type === "image") {
                        contentParts.push({
                            type: "image",
                            source: {
                                type: "base64",
                                media_type: att.mimeType,
                                data: att.base64
                            }
                        });
                    }
                }
                contentParts.push({ type: "text", text: msg.content || "" });
                filtered.push({ role: role, content: contentParts });
            } else {
                filtered.push({
                    role: role,
                    content: msg.content || ""
                });
            }
        }
        return filtered;
    }

    function getBody(messages, model, tools) {
        let body = {
            model: model.model,
            messages: _filterMessages(messages),
            max_tokens: 4096,
            temperature: 0.7
        };

        let sysPrompt = _extractSystemPrompt(messages);
        if (sysPrompt) {
            // Prompt caching: use cache_control on system message
            body.system = [{
                type: "text",
                text: sysPrompt,
                cache_control: { type: "ephemeral" }
            }];
        }

        if (tools && tools.length > 0) {
            body.tools = tools.map(t => ({
                name: t.name,
                description: t.description,
                input_schema: t.parameters
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

            if (json.error)
                return { content: "API Error: " + json.error.message };

            if (json.type === "error")
                return { content: "API Error: " + (json.error ? json.error.message : "Unknown error") };

            if (json.content && json.content.length > 0) {
                let textContent = "";
                let funcCall = null;

                for (let i = 0; i < json.content.length; i++) {
                    let block = json.content[i];
                    if (block.type === "text")
                        textContent += block.text;
                    if (block.type === "tool_use") {
                        funcCall = {
                            name: block.name,
                            args: block.input
                        };
                    }
                }

                if (funcCall)
                    return { content: textContent, functionCall: funcCall };
                return { content: textContent };
            }

            return { content: "Error: No content in response." };
        } catch (e) {
            return { content: "Error parsing response: " + e.message };
        }
    }

    function parseStreamChunk(line) {
        let trimmed = line.trim();
        if (trimmed === "")
            return { content: "", done: false, error: null };

        // Anthropic SSE uses "event:" lines followed by "data:" lines
        if (trimmed.startsWith("event:")) {
            let eventType = trimmed.substring(7).trim();
            if (eventType === "message_stop")
                return { content: "", done: true, error: null };
            if (eventType === "error")
                return { content: "", done: false, error: "Stream error" };
            return { content: "", done: false, error: null };
        }

        if (!trimmed.startsWith("data: "))
            return { content: "", done: false, error: null };

        try {
            let json = JSON.parse(trimmed.substring(6));

            if (json.type === "content_block_delta") {
                if (json.delta && json.delta.type === "text_delta")
                    return { content: json.delta.text || "", done: false, error: null };
            }

            if (json.type === "message_delta") {
                if (json.delta && json.delta.stop_reason)
                    return { content: "", done: true, error: null };
            }

            if (json.type === "error")
                return { content: "", done: false, error: json.error ? json.error.message : "Unknown error" };

            return { content: "", done: false, error: null };
        } catch (e) {
            return { content: "", done: false, error: null };
        }
    }
}
