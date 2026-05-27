import QtQuick

ApiStrategy {
    supportsStreaming: true

    function getEndpoint(modelObj, apiKey) {
        return "https://generativelanguage.googleapis.com/v1beta/models/" + modelObj.model + ":generateContent?key=" + apiKey;
    }

    function _getStreamEndpoint(modelObj, apiKey) {
        return "https://generativelanguage.googleapis.com/v1beta/models/" + modelObj.model + ":streamGenerateContent?alt=sse&key=" + apiKey;
    }

    function getHeaders(apiKey) {
        return ["Content-Type: application/json"];
    }

    function _convertMessages(messages) {
        let contents = [];
        for (let i = 0; i < messages.length; i++) {
            let msg = messages[i];
            // Skip system messages — handled via systemInstruction
            if (msg.role === "system")
                continue;

            if (msg.role === "assistant") {
                if (msg.geminiParts) {
                    contents.push({ role: "model", parts: msg.geminiParts });
                } else if (msg.functionCall) {
                    contents.push({ role: "model", parts: [{ functionCall: msg.functionCall }] });
                } else {
                    contents.push({ role: "model", parts: [{ text: msg.content }] });
                }
            } else if (msg.role === "function") {
                contents.push({
                    role: "function",
                    parts: [{
                        functionResponse: {
                            name: msg.name,
                            response: { name: msg.name, content: msg.content }
                        }
                    }]
                });
            } else {
                let parts = [{ text: msg.content }];
                if (msg.attachments && msg.attachments.length > 0) {
                    for (let j = 0; j < msg.attachments.length; j++) {
                        let att = msg.attachments[j];
                        if (att.type === "image") {
                            parts.push({
                                inline_data: { mime_type: att.mimeType, data: att.base64 }
                            });
                        }
                    }
                }
                contents.push({ role: "user", parts: parts });
            }
        }
        return contents;
    }

    function _extractSystemPrompt(messages) {
        for (let i = 0; i < messages.length; i++) {
            if (messages[i].role === "system")
                return messages[i].content;
        }
        return "";
    }

    function getBody(messages, model, tools) {
        let body = {
            contents: _convertMessages(messages),
            generationConfig: {
                temperature: 0.7,
                maxOutputTokens: 8192
            }
        };

        let sysPrompt = _extractSystemPrompt(messages);
        if (sysPrompt) {
            body.systemInstruction = { parts: [{ text: sysPrompt }] };
        }

        if (tools && tools.length > 0) {
            body.tools = [{ function_declarations: tools }];
        }

        return body;
    }

    function getStreamBody(messages, model, tools) {
        // Gemini streaming uses a different endpoint, not a body flag
        return getBody(messages, model, tools);
    }

    function parseResponse(response) {
        try {
            if (!response || response.trim() === "")
                return { content: "Error: Empty response from API" };

            let json = JSON.parse(response);

            if (json.error)
                return { content: "API Error (" + json.error.code + "): " + json.error.message };

            if (json.candidates && json.candidates.length > 0) {
                let content = json.candidates[0].content;
                if (content && content.parts && content.parts.length > 0) {
                    let hasFunctionCall = false;
                    let textContent = "";
                    let funcCall = null;
                    let rawParts = content.parts;

                    for (let i = 0; i < content.parts.length; i++) {
                        let part = content.parts[i];
                        if (part.functionCall) {
                            hasFunctionCall = true;
                            funcCall = part.functionCall;
                        } else if (part.text) {
                            textContent += part.text + "\n";
                        }
                    }

                    if (hasFunctionCall) {
                        return {
                            functionCall: funcCall,
                            content: textContent.trim(),
                            geminiParts: rawParts
                        };
                    }

                    return { content: textContent.trim() || "Empty response" };
                }

                if (json.candidates[0].finishReason)
                    return { content: "Response finished with reason: " + json.candidates[0].finishReason };
            }

            return { content: "Error: Unexpected response format." };
        } catch (e) {
            return { content: "Error parsing response: " + e.message };
        }
    }

    function parseStreamChunk(line) {
        let trimmed = line.trim();
        if (trimmed === "" || trimmed.startsWith("event:"))
            return { content: "", done: false, error: null };

        if (!trimmed.startsWith("data: "))
            return { content: "", done: false, error: null };

        try {
            let json = JSON.parse(trimmed.substring(6));

            if (json.error)
                return { content: "", done: false, error: json.error.message };

            if (json.candidates && json.candidates.length > 0) {
                let content = json.candidates[0].content;
                if (content && content.parts) {
                    let text = "";
                    for (let i = 0; i < content.parts.length; i++) {
                        if (content.parts[i].text)
                            text += content.parts[i].text;
                    }
                    let done = json.candidates[0].finishReason === "STOP";
                    return { content: text, done: done, error: null };
                }
            }
            return { content: "", done: false, error: null };
        } catch (e) {
            return { content: "", done: false, error: null };
        }
    }
}
