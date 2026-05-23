import QtQuick

// DeepSeek API strategy — uses OpenAI-compatible format
// endpoint: https://api.deepseek.com/v1/chat/completions
ApiStrategy {
    supportsStreaming: true

    function getEndpoint(modelObj, apiKey) {
        let base = modelObj.endpoint || "https://api.deepseek.com";
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
                            image_url: { url: att.url }
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

    function buildRequestBody(modelObj, messages, systemPrompt, options) {
        let body = {
            model: modelObj.model || "deepseek-chat",
            messages: []
        };

        if (systemPrompt) {
            body.messages.push({ role: "system", content: systemPrompt });
        }

        let formatted = _formatMessages(messages);
        for (let i = 0; i < formatted.length; i++) {
            body.messages.push(formatted[i]);
        }

        if (options?.temperature != null) body.temperature = options.temperature;
        if (options?.maxTokens) body.max_tokens = options.maxTokens;
        if (options?.stream != null) body.stream = options.stream;

        return body;
    }

    function parseResponse(data) {
        try {
            let json = JSON.parse(data);
            if (json.choices && json.choices.length > 0) {
                let content = json.choices[0].delta?.content || json.choices[0].message?.content || "";
                return { content, done: json.choices[0].finish_reason != null };
            }
        } catch (e) {}
        return { content: "", done: false };
    }

    function parseFullResponse(data) {
        try {
            let json = JSON.parse(data);
            if (json.choices && json.choices.length > 0) {
                let content = json.choices[0].message?.content || "";
                return { content, model: json.model };
            }
        } catch (e) {}
        return { content: "", model: "" };
    }
}
