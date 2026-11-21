pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.services
import qs.modules.globals
import "ai"
import "ai/strategies"

Singleton {
    id: root

    // ============================================
    // PROPERTIES
    // ============================================

    property string chatDir: Quickshell.env("HOME") + "/.local/share/ambxst/chats"
    property string tmpDir: "/tmp/ambxst-ai"

    property list<AiModel> models: []

    property AiModel currentModel: models.length > 0 ? models[0] : null
    property bool persistenceReady: false
    property string savedModelId: ""
    property bool isRestored: false

    // Hermes keeps its own catalog and selection so switching backends never
    // overwrites the API selection.
    property list<AiModel> hermesModels: []
    property AiModel currentHermesModel: hermesModels.length > 0 ? hermesModels[0] : null
    property bool fetchingHermesModels: false
    // Invalidates catalog answers that a newer refresh has superseded.
    property int hermesCatalogSeq: 0
    property bool hermesRestored: false
    property string hermesDefaultId: ""
    // The catalog arrives from model.options once the gateway is ready.
    property bool hermesCatalogPending: false

    readonly property bool hermesActive: Config.ai.backend === "hermes"
    // "unknown" until the resolver answers, then true/false.
    readonly property var hermesInstalled: HermesGateway.installed
    readonly property string hermesPath: HermesGateway.resolvedPath

    function checkHermes(force) {
        HermesGateway.detectInstalled(force === true);
    }

    readonly property var activeModels: hermesActive ? hermesModels : models
    readonly property AiModel activeModel: hermesActive ? currentHermesModel : currentModel
    readonly property bool fetchingActiveModels: hermesActive ? fetchingHermesModels : fetchingModels
    readonly property string defaultModelId: hermesActive ? (Config.ai.hermesDefaultModel || "") : (Config.ai.defaultModel || "")
    readonly property string defaultModelName: {
        if (defaultModelId === "")
            return "";

        // Hermes ids repeat across providers, so the default remembers which one.
        let found = hermesActive ? findHermesModel(activeModels, Config.ai.hermesDefaultProvider || "", defaultModelId) : findModel(activeModels, defaultModelId);
        return found ? found.name : defaultModelId;
    }

    onCurrentModelChanged: {
        if (persistenceReady && currentModel && isRestored) {
            StateService.set("lastAiModel", currentModel.model);
        }
        updateStrategy();
    }

    onCurrentHermesModelChanged: {
        if (persistenceReady && hermesRestored && currentHermesModel)
            StateService.set("lastHermesModel", currentHermesModel.model);
    }

    onHermesActiveChanged: {
        if (!hermesActive)
            return;

        checkHermes(false);
        if (Config.initialLoadComplete && hermesModels.length === 0)
            fetchHermesModels();
    }

    // Re-resolve when the command changes or the backend is switched back in.
    Connections {
        target: Config.ai

        function onHermesCommandChanged() {
            root.checkHermes(true);
        }

        function onBackendChanged() {
            if ((Config.ai.backend ?? "api") === "hermes")
                root.checkHermes(true);
        }
    }

    function findModel(list, id) {
        if (!id || id === "" || !list)
            return null;

        for (let i = 0; i < list.length; i++) {
            if (list[i].model === id)
                return list[i];
        }

        for (let i = 0; i < list.length; i++) {
            if (list[i].model.endsWith(id) || list[i].model.endsWith("/" + id))
                return list[i];
        }

        return null;
    }

    // The same id can exist under two providers; compare the pair, not the label.
    function sameModel(a, b) {
        if (!a || !b)
            return false;
        return a.model === b.model && a.provider === b.provider;
    }

    function hermesModelKey(m) {
        return m ? (m.provider || "") + "\u0000" + (m.model || "") : "";
    }

    function findHermesModel(list, provider, id) {
        if (!id || !list)
            return null;

        for (let i = 0; i < list.length; i++) {
            if (list[i].model !== id)
                continue;
            if (provider === "" || provider === undefined || list[i].provider === provider)
                return list[i];
        }

        return null;
    }

    function findHermesModelByKey(list, key) {
        if (!key || !list)
            return null;

        for (let i = 0; i < list.length; i++) {
            if (hermesModelKey(list[i]) === key)
                return list[i];
        }

        return null;
    }

    function restoreModel() {
        savedModelId = StateService.get("lastAiModel", "");
        tryRestore();
        persistenceReady = true;
    }

    function tryRestore() {
        if (isRestored || models.length === 0 || !Config.aiReady)
            return;

        // The configured default wins, then the model used last.
        let configured = Config.ai.defaultModel || "";
        let target = findModel(models, configured);

        // Providers answer at different times: wait for the complete list
        // instead of locking in the last used model without the default.
        if (!target && configured !== "" && fetchingModels)
            return;

        if (!target)
            target = findModel(models, savedModelId);

        if (target) {
            currentModel = target;
            isRestored = true;
        }
    }

    // ============================================
    // MODEL PREFERENCES
    // ============================================

    function modelKey(m) {
        return m ? (m.provider + ":" + m.model) : "";
    }

    function isFavorite(m) {
        if (!m)
            return false;

        let favorites = Config.ai.favoriteModels || [];
        return favorites.indexOf(modelKey(m)) !== -1;
    }

    function toggleFavorite(m) {
        if (!m)
            return;

        let favorites = Array.from(Config.ai.favoriteModels || []);
        let key = modelKey(m);
        let index = favorites.indexOf(key);

        if (index === -1)
            favorites.push(key);
        else
            favorites.splice(index, 1);

        // Assign a new array so the adapter sees a changed list.
        Config.ai.favoriteModels = favorites;
    }

    function withFavorites(list) {
        let favorites = [];
        let rest = [];

        for (let i = 0; i < list.length; i++)
            (isFavorite(list[i]) ? favorites : rest).push(list[i]);

        return favorites.concat(rest);
    }

    function isDefault(m) {
        if (!m)
            return false;

        if (m.api_format === "hermes") {
            let id = Config.ai.hermesDefaultModel || "";
            if (id === "" || id !== m.model)
                return false;
            // An empty provider is an older config that only stored the id.
            let provider = Config.ai.hermesDefaultProvider || "";
            return provider === "" || provider === m.provider;
        }

        let id = Config.ai.defaultModel || "";
        return id !== "" && id === m.model;
    }

    function setDefault(m) {
        if (!m)
            return;

        if (m.api_format === "hermes") {
            Config.ai.hermesDefaultModel = m.model;
            Config.ai.hermesDefaultProvider = m.provider || "";
        } else {
            Config.ai.defaultModel = m.model;
        }
    }

    // The model decides the backend: a popup opened before a backend switch
    // must not clear the other backend's default.
    function clearDefault(m) {
        if (m ? m.api_format === "hermes" : hermesActive) {
            Config.ai.hermesDefaultModel = "";
            Config.ai.hermesDefaultProvider = "";
        } else {
            Config.ai.defaultModel = "";
        }
    }

    property bool _restored: false
    Connections {
        target: StateService
        function onInitializedChanged() {
            root._restore();
        }
    }
    Connections {
        target: KeyStore
        function onKeysChanged() {
            fetchAvailableModels();
        }
    }

    Connections {
        target: Config

        // Restoring before the config is read would fall back to the last used
        // model and ignore the configured default.
        function onAiReadyChanged() {
            root.tryRestore();

            if (root.hermesModels.length > 0) {
                let id = Config.ai.hermesDefaultModel || "";
                let target = root.findHermesModel(root.hermesModels, Config.ai.hermesDefaultProvider || "", id);
                if (!target && id !== "")
                    target = root.findHermesModel(root.hermesModels, "", id);
                if (target)
                    root.currentHermesModel = target;
            }
        }
    }

    Component.onCompleted: root._restore()

    function _restore() {
        if (StateService.initialized && !root._restored) {
            root._restored = true;
            restoreModel();
        }
    }

    // Lazy init: trigger fetchAvailableModels/reloadHistory/createNewChat
    // when AI sidebar is opened for the first time.
    property bool _aiInitialized: false
    function _ensureInit() {
        if (_aiInitialized) return;
        _aiInitialized = true;
        if (hermesActive) {
            if (hermesModels.length === 0)
                fetchHermesModels();
        } else if (models.length === 0) {
            fetchAvailableModels();
        }
        reloadHistory();
        createNewChat();
    }

    // Trigger lazy init when AI sidebar is opened
    Connections {
        target: GlobalStates
        function onAssistantVisibleChanged() {
            if (!GlobalStates.assistantVisible)
                return;

            root._ensureInit();
            // Opening the sidebar is a good moment to retry a missing install.
            if (root.hermesActive && root.hermesInstalled !== true)
                root.checkHermes(true);
        }
    }

    Connections {
        target: HermesGateway

        function onReady() {
            if (root.hermesCatalogPending)
                root.requestHermesCatalog();

            if (!root.hermesGatewayPending)
                return;

            let text = root.hermesPendingText;
            root.hermesPendingText = "";
            root.hermesGatewayPending = false;
            root.submitHermesPrompt(text);
        }

        // An attach failure or a missing QtWebSockets module used to leave the
        // spinner running and an empty bubble in the chat.
        function onStatusChanged() {
            if (HermesGateway.status !== "error")
                return;

            // Session ids belong to the connection that created them.
            root.hermesSessionId = "";
            root.hermesSubscriptionId = "";
            root.hermesCatalogPending = false;
            root.fetchingHermesModels = false;
            root.hermesCatalogSeq++;
            root.hermesNotedPrompts = [];

            if (!root.hermesGatewayPending && !root.isLoading)
                return;

            let message = HermesGateway.lastError !== "" ? root.hermesErrorMessage({
                "message": HermesGateway.lastError
            }) : "Hermes gateway connection failed.";
            root.hermesPendingText = "";
            root.hermesGatewayPending = false;
            root.hermesFail(message);
        }

        function onGatewayEvent(type, sessionId, payload) {
            if (!root.hermesActive)
                return;

            // Events may arrive after the chat was reset; ignore stale sessions.
            if (root.hermesSessionId !== "" && sessionId !== "" && sessionId !== root.hermesSessionId)
                return;

            if (type === "message.delta") {
                root.hermesAppendDelta(payload.text);
            } else if (type === "message.complete") {
                root.hermesFinishTurn(payload);
            } else if (type === "error") {
                root.showError(payload.message || "Hermes reported an error.");
            }
        }

        function onPromptsChanged() {
            root.syncHermesPrompts();
        }
    }

    // ============================================
    // STRATEGIES
    // ============================================

    property OpenAiApiStrategy openaiStrategy: OpenAiApiStrategy {}
    property GeminiApiStrategy geminiStrategy: GeminiApiStrategy {}
    property AnthropicApiStrategy anthropicStrategy: AnthropicApiStrategy {}
    property MistralApiStrategy mistralStrategy: MistralApiStrategy {}
    property GroqApiStrategy groqStrategy: GroqApiStrategy {}
    property OllamaApiStrategy ollamaStrategy: OllamaApiStrategy {}
    property MiniMaxApiStrategy minimaxStrategy: MiniMaxApiStrategy {}

    property ApiStrategy currentStrategy: openaiStrategy

    function getStrategyForProvider(providerName) {
        switch (providerName) {
        case "openai": return openaiStrategy;
        case "gemini": return geminiStrategy;
        case "anthropic": return anthropicStrategy;
        case "mistral": return mistralStrategy;
        case "groq": return groqStrategy;
        case "ollama": return ollamaStrategy;
        case "minimax": return minimaxStrategy;
        case "custom": return openaiStrategy; // custom endpoints use OpenAI-compatible format by default
        default: return openaiStrategy;
        }
    }

    function updateStrategy() {
        if (currentModel)
            currentStrategy = getStrategyForProvider(currentModel.provider);
        else
            currentStrategy = openaiStrategy;
    }

    // ============================================
    // STATE
    // ============================================

    property bool isLoading: false
    property string lastError: ""
    property string responseBuffer: ""
    property string rawOutputBuffer: ""
    property string hermesSessionId: ""
    property string hermesSubscriptionId: ""
    property string hermesPendingText: ""
    property bool hermesGatewayPending: false
    property var hermesNotedPrompts: []

    readonly property string noModelMessage: "No model selected. Add an API key in Settings > AI, or switch the backend to Hermes"

    // Drops the empty assistant bubble a request pushed, then reports the error
    // in its place, so a failed turn reads as one answer instead of two bubbles.
    function hermesFail(text) {
        let chat = Array.from(currentChat);
        while (chat.length > 0 && chat[chat.length - 1].role === "assistant" && chat[chat.length - 1].content === "")
            chat.pop();
        currentChat = chat;
        showError(text);
    }

    function showError(text) {
        lastError = text;
        isLoading = false;

        let newChat = Array.from(currentChat);
        // Reuse the empty assistant placeholder when there is one (streaming paths).
        if (newChat.length > 0 && newChat[newChat.length - 1].role === "assistant" && newChat[newChat.length - 1].content === "") {
            newChat[newChat.length - 1].content = "Error: " + text;
        } else {
            newChat.push({
                role: "assistant",
                content: "Error: " + text
            });
        }
        currentChat = newChat;
        saveCurrentChat();
    }

    function stripAnsi(text) {
        return (text || "").replace(/\u001b\[[0-9;?]*[A-Za-z]/g, "").replace(/\u001b\][^\u0007]*(\u0007|\u001b\\)/g, "");
    }

    // Current Chat
    property var currentChat: []
    property string currentChatId: ""

    // Chat History List (files)
    property var chatHistory: []

    FileView {
        id: chatFileView
        printErrors: false
    }

    FileView {
        id: bodyFileView
        printErrors: false
        // Writes must be on disk before curl reads the body (no async write race).
        blockWrites: true
    }

    // ============================================
    // TOOLS
    // ============================================

    function regenerateResponse(index) {
        if (index < 0 || index >= currentChat.length)
            return;

        let newChat = currentChat.slice(0, index);
        currentChat = newChat;

        isLoading = true;
        lastError = "";
        makeRequest();
    }

    function updateMessage(index, newContent) {
        if (index < 0 || index >= currentChat.length)
            return;

        let newChat = Array.from(currentChat);
        let msg = newChat[index];
        msg.content = newContent;
        newChat[index] = msg;

        currentChat = newChat;
        saveCurrentChat();
    }

    property var systemTools: [
        {
            name: "run_shell_command",
            description: "Execute a shell command on the user's system (Linux). Use this to list files, control the system, or run utilities. Output will be returned.",
            parameters: {
                type: "object",
                properties: {
                    command: {
                        type: "string",
                        description: "The shell command to run (e.g. 'ls -la', 'ip addr')"
                    }
                },
                required: ["command"]
            }
        }
    ]

    // ============================================
    // CHAT MANAGEMENT
    // ============================================

    function deleteChat(id) {
        if (id === currentChatId)
            createNewChat();

        let filename = chatDir + "/" + id + ".json";
        deleteChatProcess.command = ["rm", filename];
        deleteChatProcess.running = true;
    }

    // ============================================
    // LOGIC
    // ============================================

    function setModel(modelName, providerSlug) {
        let list = activeModels;

        for (let i = 0; i < list.length; i++) {
            if (list[i].name !== modelName)
                continue;
            // Hermes can list the same id under several providers.
            if (providerSlug !== undefined && providerSlug !== "" && list[i].provider !== providerSlug)
                continue;

            if (hermesActive) {
                let previous = currentHermesModel;
                currentHermesModel = list[i];
                hermesRestored = true;
                // Hermes refuses -m on a resume, so a switch starts a fresh session.
                // A same-id model from another provider is a different selection.
                if (previous && (previous.model !== list[i].model || previous.provider !== list[i].provider) && hermesSessionId !== "")
                    createNewChat();
            } else {
                currentModel = list[i];
            }
            return;
        }
    }

    function getApiKey(model) {
        if (!model || !model.requires_key)
            return "";

        // Try KeyStore first
        let ksKey = KeyStore.getKey(model.provider);
        if (ksKey)
            return ksKey;

        return "";
    }

    function processCommand(text) {
        let cmd = text.trim();
        if (!cmd.startsWith("/"))
            return false;

        let parts = cmd.split(" ");
        let command = parts[0].toLowerCase();
        let args = parts.slice(1).join(" ");

        switch (command) {
        case "/new":
            createNewChat();
            return true;
        case "/model":
            if (args) {
                let found = false;
                for (let i = 0; i < activeModels.length; i++) {
                    if (activeModels[i].name.toLowerCase().includes(args.toLowerCase()) || activeModels[i].model.toLowerCase() === args.toLowerCase()) {
                        setModel(activeModels[i].name);
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    pushSystemMessage(I18n.t("ai.model_not_found").replace("%1", args));
                } else {
                    pushSystemMessage(I18n.t("ai.switched_to_model").replace("%1", activeModel ? activeModel.name : args));
                }
            } else {
                modelSelectionRequested();
            }
            return true;
        case "/help":
            pushSystemMessage(I18n.t("ai.help_message"));
            return true;
        }

        return false;
    }

    function pushSystemMessage(text) {
        let newChat = Array.from(currentChat);
        newChat.push({
            role: "system",
            content: text
        });
        currentChat = newChat;
    }

    // Function Call Handling
    function approveCommand(index, choice) {
        let msg = currentChat[index];
        if (!msg)
            return;

        // Hermes approvals are answered on the gateway; the card is only the
        // renderer, so the pending request survives a closed sidebar.
        if (msg.approvalId) {
            let picked = choice || "once";
            HermesGateway.respond(msg.approvalId, {
                "choice": picked
            });

            let answered = Array.from(currentChat);
            answered[index] = hermesCopyObject(answered[index]);
            answered[index].functionPending = false;
            answered[index].functionApproved = picked !== "deny";
            answered[index].approvalExpired = false;
            currentChat = answered;
            saveCurrentChat();
            return;
        }

        if (!msg.functionCall)
            return;

        let newChat = Array.from(currentChat);
        newChat[index].functionPending = false;
        newChat[index].functionApproved = true;
        currentChat = newChat;
        saveCurrentChat();

        let args = msg.functionCall.args;
        if (msg.functionCall.name === "run_shell_command") {
            commandExecutionProc.command = ["bash", "-c", args.command];
            commandExecutionProc.targetIndex = index;
            commandExecutionProc.running = true;
        }
    }

    function rejectCommand(index) {
        let msg = currentChat[index];
        if (!msg)
            return;

        if (msg.approvalId) {
            HermesGateway.respond(msg.approvalId, {
                "choice": "deny"
            });

            let denied = Array.from(currentChat);
            denied[index] = hermesCopyObject(denied[index]);
            denied[index].functionPending = false;
            denied[index].functionApproved = false;
            denied[index].approvalExpired = false;
            currentChat = denied;
            saveCurrentChat();
            return;
        }

        let newChat = Array.from(currentChat);
        newChat[index].functionPending = false;
        newChat[index].functionApproved = false;

        newChat.push({
            role: "function",
            name: newChat[index].functionCall.name,
            content: "User rejected the command execution."
        });

        currentChat = newChat;
        saveCurrentChat();
        makeRequest();
    }

    function hermesCopyObject(source) {
        let copy = {};
        for (let key in source)
            copy[key] = source[key];
        return copy;
    }

    function sendMessage(text, attachments) {
        if (text.trim() === "" && (!attachments || attachments.length === 0))
            return;
        if (processCommand(text))
            return;
        if (Config.ai.backend === "hermes" && HermesGateway.installed === false)
            return;
        isLoading = true;
        lastError = "";
        let userMsg = {
            role: "user",
            content: text
        };
        if (attachments && attachments.length > 0)
            userMsg.attachments = attachments;
        let newChat = Array.from(currentChat);
        newChat.push(userMsg);
        currentChat = newChat;
        saveCurrentChat();

        if (Config.ai.backend !== "hermes" && !currentModel) {
            showError(noModelMessage);
            return;
        }

        makeRequest();
    }

    function makeRequest() {
        if (Config.ai.backend === "hermes") {
            makeHermesRequest();
            return;
        }

        if (!currentModel) {
            showError(noModelMessage);
            return;
        }

        let apiKey = getApiKey(currentModel);
        if (!apiKey && currentModel.requires_key) {
            showError(I18n.t("ai.api_key_missing").replace("%1", currentModel.name).replace("%2", currentModel.key_id || I18n.t("ai.env_variable")));
            return;
        }

        // Determine endpoint — Gemini streaming uses a different endpoint
        let endpoint;
        let isGemini = currentModel.provider === "gemini";
        if (isGemini && geminiStrategy._getStreamEndpoint) {
            endpoint = geminiStrategy._getStreamEndpoint(currentModel, apiKey);
        } else {
            endpoint = currentStrategy.getEndpoint(currentModel, apiKey);
        }

        let headers = currentStrategy.getHeaders(apiKey);

        // Build messages array
        let messages = [];
        if (Config.ai.systemPrompt) {
            messages.push({
                role: "system",
                content: Config.ai.systemPrompt
            });
        }

        for (let i = 0; i < currentChat.length; i++) {
            let msg = currentChat[i];
            let apiMsg = {
                role: msg.role,
                content: msg.content
            };
            if (msg.attachments)
                apiMsg.attachments = msg.attachments;
            if (msg.functionCall)
                apiMsg.functionCall = msg.functionCall;
            if (msg.geminiParts)
                apiMsg.geminiParts = msg.geminiParts;
            if (msg.name)
                apiMsg.name = msg.name;
            messages.push(apiMsg);
        }

        // Build body — always use streaming.
        // Tool calling is not implemented: send no tools (some providers 400 on them).
        let body = currentStrategy.getStreamBody(messages, currentModel, []);

        // Reset streaming buffers
        responseBuffer = "";
        rawOutputBuffer = "";

        // Add placeholder assistant message for streaming
        let streamChat = Array.from(currentChat);
        streamChat.push({
            role: "assistant",
            content: "",
            model: currentModel ? currentModel.name : "Unknown"
        });
        currentChat = streamChat;

        writeTempBody(JSON.stringify(body), headers, endpoint);
    }

    function writeTempBody(jsonBody, headers, endpoint) {
        requestProcess.command = ["/usr/bin/mkdir", "-p", tmpDir];
        requestProcess.step = "mkdir";
        requestProcess.payload = {
            body: jsonBody,
            headers: headers,
            endpoint: endpoint
        };
        requestProcess.running = true;
    }

    function executeRequest(payload) {
        let bodyPath = tmpDir + "/body.json";
        bodyFileView.path = bodyPath;
        bodyFileView.setText(payload.body);
        Qt.callLater(() => runCurl(payload));
    }

    function runCurl(payload) {
        let bodyPath = tmpDir + "/body.json";
        let headerArgs = payload.headers.map(h => "-H \"" + h + "\"").join(" ");

        // Check for custom curl template
        let customCurl = "";
        if (currentModel && currentModel.customCurlTemplate) {
            customCurl = currentModel.customCurlTemplate;
        } else if (currentModel && KeyStore.getCustomCurl(currentModel.provider)) {
            customCurl = KeyStore.getCustomCurl(currentModel.provider);
        }

        let curlCmd;
        if (customCurl) {
            // Replace placeholders in custom curl
            curlCmd = customCurl
                .replace("{{BODY_PATH}}", bodyPath)
                .replace("{{ENDPOINT}}", payload.endpoint)
                .replace("{{API_KEY}}", getApiKey(currentModel));
        } else {
            curlCmd = "curl -s --no-buffer -N -X POST \"" + payload.endpoint + "\" " + headerArgs + " -d @" + bodyPath;
        }

        curlProcess.command = ["/usr/bin/bash", "-c", curlCmd];
        curlProcess.running = true;
    }

    // ============================================
    // PROCESSES
    // ============================================

    Process {
        id: requestProcess
        property string step: ""
        property var payload: ({})

        onExited: exitCode => {
            if (exitCode === 0 && step === "mkdir") {
                executeRequest(payload);
            } else if (exitCode !== 0) {
                root.lastError = "Failed to create temp directory";
                root.isLoading = false;
            }
        }
    }

    Process {
        id: writeBodyProcess
        property var payload: ({})
        stderr: StdioCollector {
            id: writeBodyStderr
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                runCurl(payload);
            } else {
                root.lastError = "Failed to write request body: " + writeBodyStderr.text;
                root.isLoading = false;
            }
        }
    }

    Process {
        id: curlProcess

        // Use SplitParser for streaming — emits onRead per line
        stdout: SplitParser {
            onRead: data => {
                let line = (data || "").trim();
                // Non-SSE output (provider error bodies) is kept for the exit handler.
                if (line !== "" && !line.startsWith("data:") && !line.startsWith("event:"))
                    root.rawOutputBuffer += line + "\n";

                let result = root.currentStrategy.parseStreamChunk(data);

                if (result.error) {
                    root.lastError = result.error;
                    root.isLoading = false;
                    root.responseBuffer += (root.responseBuffer ? "\n\n" : "") + "Error: " + result.error;

                    let errChat = Array.from(root.currentChat);
                    if (errChat.length > 0) {
                        errChat[errChat.length - 1].content = root.responseBuffer;
                        root.currentChat = errChat;
                    }
                    return;
                }

                if (result.content) {
                    root.responseBuffer += result.content;
                    // Update the last message in currentChat with accumulated text
                    let newChat = Array.from(root.currentChat);
                    if (newChat.length > 0) {
                        newChat[newChat.length - 1].content = root.responseBuffer;
                        root.currentChat = newChat;
                    }
                }

                // Note: done is handled in onExited
            }
        }

        stderr: StdioCollector {
            id: curlStderr
        }

        onExited: exitCode => {
            root.isLoading = false;

            if (exitCode === 0) {
                // Nothing was streamed: providers that reject the request (401/404/429)
                // answer with a plain JSON body that the SSE parsers drop.
                if (root.responseBuffer === "" && root.currentChat.length > 0) {
                    let text = "";
                    let raw = root.rawOutputBuffer.trim();

                    if (raw !== "") {
                        try {
                            let parsed = JSON.parse(raw);
                            let errObj = parsed.error !== undefined ? parsed.error : parsed;
                            text = typeof errObj === "string" ? errObj : (errObj.message || JSON.stringify(errObj));
                        } catch (e) {
                            text = raw.substring(0, 300);
                        }
                        if (!text)
                            text = raw.substring(0, 300);
                    }

                    let newChat = Array.from(root.currentChat);
                    newChat[newChat.length - 1].content = text !== "" ? "Error: " + text : I18n.t("ai.no_response");
                    root.currentChat = newChat;
                }

                root.saveCurrentChat();
            } else {
                root.lastError = I18n.t("ai.network_failed").replace("%1", curlStderr.text);

                // Update the placeholder message with error
                let errChat = Array.from(root.currentChat);
                if (errChat.length > 0) {
                    errChat[errChat.length - 1].content = "Error: " + root.lastError;
                }
                root.currentChat = errChat;
                root.saveCurrentChat();
            }

            root.responseBuffer = "";
            root.rawOutputBuffer = "";
        }
    }

    // ============================================
    // HERMES BACKEND
    // ============================================

    // Gateway errors can echo request data; keep credentials out of the UI.
    function hermesErrorMessage(err) {
        let text = err && err.message ? String(err.message) : "unknown error";
        text = text.replace(/sk-[A-Za-z0-9_-]{8,}/g, "sk-***").replace(/Bearer\s+[^\s"',;]+/gi, "Bearer ***").replace(/(api[_-]?key|access[_-]?token|secret)\s*[:=]\s*[^\s,;"']+/gi, "$1: ***");
        return text.length > 300 ? text.substring(0, 300) + "…" : text;
    }

    // session.create's accepted fields come from runtime.describe; a field the
    // gateway does not advertise is never sent.
    function hermesSessionParams() {
        let params = {
            "source": "tui"
        };
        let model = currentHermesModel;
        if (model && model.model !== "")
            params.model = model.model;

        let info = HermesGateway.runtimeInfo;
        let parameters = info && info.parameters ? info.parameters : [];
        if (model && model.provider !== "" && parameters.indexOf("provider") !== -1)
            params.provider = model.provider;

        // Older owners do not take a client label; sending it unasked is refused.
        if (parameters.indexOf("client") !== -1)
            params.client = {
                "name": "ambxst",
                "version": "1"
            };

        return params;
    }

    function makeHermesRequest() {
        // The sidebar explains a missing binary instead of posting an error.
        if (HermesGateway.installed === false)
            return;

        let lastUserMessage = "";
        for (let i = currentChat.length - 1; i >= 0; i--) {
            if (currentChat[i].role === "user") {
                lastUserMessage = currentChat[i].content || "";
                break;
            }
        }

        if (lastUserMessage === "") {
            showError("Nothing to send to Hermes.");
            return;
        }

        responseBuffer = "";
        lastError = "";
        isLoading = true;

        let streamChat = Array.from(currentChat);
        streamChat.push({
            role: "assistant",
            content: "",
            model: currentHermesModel ? currentHermesModel.name : "Hermes"
        });
        currentChat = streamChat;

        // The transport attaches on demand; the prompt goes out once the
        // gateway is ready (the first attach can take a few seconds).
        if (HermesGateway.connected) {
            submitHermesPrompt(lastUserMessage);
            return;
        }

        hermesPendingText = lastUserMessage;
        hermesGatewayPending = true;
        HermesGateway.ensureStarted();
    }

    function submitHermesPrompt(text) {
        if (hermesSessionId !== "") {
            submitHermesText(text);
            return;
        }

        let params = hermesSessionParams();

        HermesGateway.request("session.create", params, (err, result) => {
            if (err) {
                hermesFail("Hermes could not start a session: " + hermesErrorMessage(err));
                return;
            }

            hermesSessionId = result && result.session_id ? result.session_id : "";
            hermesSubscriptionId = result && result.subscription_id ? result.subscription_id : "";
            if (hermesSessionId === "") {
                hermesFail("Hermes did not return a session id.");
                return;
            }

            submitHermesText(text);
        });
    }

    function hermesSubmissionId() {
        // prompt.submit wants a client-generated request identity.
        return "ambxst-" + Date.now().toString(36) + "-" + Math.random().toString(36).substring(2, 10);
    }

    function submitHermesText(text) {
        if (HermesGateway.installed === false)
            return;

        if (!HermesGateway.connected) {
            hermesPendingText = text;
            hermesGatewayPending = true;
            return;
        }

        HermesGateway.request("prompt.submit", {
            "session_id": hermesSessionId,
            "text": text,
            "submission_id": hermesSubmissionId()
        }, (err, result) => {
            if (err)
                hermesFail("Hermes could not accept the message: " + hermesErrorMessage(err));
        });
    }

    function detachHermesSession() {
        if (hermesSessionId === "")
            return;

        // The shared gateway refuses session.close; detach needs the subscription.
        HermesGateway.request("session.detach", {
            "session_id": hermesSessionId,
            "subscription_id": hermesSubscriptionId
        }, null);
        hermesSessionId = "";
        hermesSubscriptionId = "";
    }

    function hermesReplyIndex() {
        for (let i = currentChat.length - 1; i >= 0; i--) {
            if (currentChat[i].role === "assistant")
                return i;
        }
        return -1;
    }

    function hermesAppendDelta(text) {
        if (typeof text !== "string" || text === "")
            return;

        let index = hermesReplyIndex();
        if (index === -1)
            return;

        responseBuffer += text;
        let newChat = Array.from(currentChat);
        newChat[index] = hermesCopyObject(newChat[index]);
        newChat[index].content = responseBuffer;
        currentChat = newChat;
    }

    function hermesFinishTurn(payload) {
        let index = hermesReplyIndex();
        let finalText = payload && typeof payload.text === "string" ? payload.text : "";

        if (index !== -1) {
            let newChat = Array.from(currentChat);
            newChat[index] = hermesCopyObject(newChat[index]);
            // message.complete carries the authoritative text; an empty one
            // means the streamed text stands.
            if (finalText !== "")
                newChat[index].content = finalText;
            if (newChat[index].content === "")
                newChat[index].content = I18n.t("ai.no_response");
            currentChat = newChat;
        }

        responseBuffer = "";
        isLoading = false;
        saveCurrentChat();
    }

    // Approval cards live in the chat, but the pending request lives in the
    // gateway service so a reopened sidebar still shows it.
    function syncHermesPrompts() {
        let prompts = HermesGateway.prompts;
        let newChat = Array.from(currentChat);
        let changed = false;

        for (let i = 0; i < prompts.length; i++) {
            let prompt = prompts[i];

            if (prompt.method === "approval") {
                let known = false;
                for (let j = 0; j < newChat.length; j++) {
                    // The same id on an older connection is a different request.
                    if (newChat[j].approvalId === prompt.id && newChat[j].approvalEpoch === prompt.epoch && newChat[j].functionPending === true) {
                        known = true;
                        break;
                    }
                }
                if (known)
                    continue;

                let params = prompt.params || {};
                newChat.push({
                    role: "system",
                    content: "",
                    functionCall: {
                        name: "run_shell_command",
                        args: {
                            "command": params.command || ""
                        }
                    },
                    approvalId: prompt.id,
                    approvalEpoch: prompt.epoch,
                    approvalDescription: params.description || "",
                    approvalChoices: params.choices || ["once", "deny"],
                    functionPending: true
                });
                changed = true;
                continue;
            }

            // Only record that a secret was requested, never its value.
            let noteKey = String(prompt.epoch) + ":" + String(prompt.id);
            if ((prompt.method === "sudo" || prompt.method === "secret") && hermesNotedPrompts.indexOf(noteKey) === -1) {
                let note = Array.from(hermesNotedPrompts);
                note.push(noteKey);
                hermesNotedPrompts = note;
                newChat.push({
                    role: "system",
                    content: I18n.t(prompt.method === "sudo" ? "ai.sudo_requested" : "ai.secret_requested")
                });
                changed = true;
            }
        }

        for (let i = 0; i < newChat.length; i++) {
            let msg = newChat[i];
            if (!msg.approvalId || !msg.functionPending)
                continue;
            if (HermesGateway.findPrompt(msg.approvalId, msg.approvalEpoch) !== null)
                continue;

            newChat[i] = hermesCopyObject(msg);
            newChat[i].functionPending = false;
            newChat[i].approvalExpired = true;
            changed = true;
        }

        if (changed) {
            currentChat = newChat;
            saveCurrentChat();
        }
    }

    Process {
        id: commandExecutionProc
        property int targetIndex: -1

        stdout: StdioCollector {
            id: cmdStdout
        }
        stderr: StdioCollector {
            id: cmdStderr
        }

        onExited: exitCode => {
            let output = cmdStdout.text + "\n" + cmdStderr.text;
            if (output.trim() === "")
                output = I18n.t("ai.cmd_no_output");

            let msg = currentChat[targetIndex];
            let newChat = Array.from(currentChat);

            newChat.push({
                role: "function",
                name: msg.functionCall.name,
                content: output
            });

            root.currentChat = newChat;
            root.saveCurrentChat();
            root.makeRequest();
        }
    }

    // ============================================
    // CHAT STORAGE
    // ============================================

    function createNewChat() {
        // A new chat always starts a fresh Hermes session; the old one is
        // detached, not closed (the shared gateway refuses session.close).
        detachHermesSession();
        hermesPendingText = "";
        hermesGatewayPending = false;
        responseBuffer = "";
        isLoading = false;

        currentChat = [];
        currentChatId = Date.now().toString();
        chatModelChanged();
    }

    function saveCurrentChat() {
        if (currentChat.length === 0)
            return;

        let filename = chatDir + "/" + currentChatId + ".json";
        let data = JSON.stringify(currentChat, null, 2);

        saveChatProcess.filePath = filename;
        saveChatProcess.data = data;
        saveChatProcess.command = ["/usr/bin/mkdir", "-p", chatDir];
        saveChatProcess.running = true;
    }

    function reloadHistory() {
        listHistoryProcess.command = ["ambxst", "chatlist", chatDir];
        listHistoryProcess.running = true;
    }

    function loadChat(id) {
        // A saved chat gets a fresh session; the old one is detached, not left
        // bound to the transcript.
        detachHermesSession();
        let filename = chatDir + "/" + id + ".json";
        loadChatProcess.targetId = id;
        loadChatProcess.command = ["cat", filename];
        loadChatProcess.running = true;
    }

    Process {
        id: saveChatProcess
        property string filePath: ""
        property string data: ""
        onExited: exitCode => {
            if (exitCode === 0) {
                if (filePath.length > 0)
                    chatFileView.path = filePath;
                if (data.length > 0)
                    chatFileView.setText(data);
                reloadHistory();
            } else {
                console.warn("Failed to create chat directory");
            }
        }
    }

    Process {
        id: deleteChatProcess
        onExited: reloadHistory()
    }

    Process {
        id: listHistoryProcess
        stdout: StdioCollector {
            id: listHistoryStdout
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                let lines = listHistoryStdout.text.trim().split("\n");
                let history = [];
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i];
                    if (line === "")
                        continue;
                    let parts = line.split("|");
                    if (parts.length >= 2) {
                        history.push({
                            id: parts[0],
                            title: parts.slice(1).join("|"),
                            path: chatDir + "/" + parts[0] + ".json"
                        });
                    }
                }
                root.chatHistory = history;
                root.historyModelChanged();
            }
        }
    }

    Process {
        id: loadChatProcess
        property string targetId: ""
        stdout: StdioCollector {
            id: loadChatStdout
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    root.currentChat = JSON.parse(loadChatStdout.text);
                    root.currentChatId = targetId;
                    root.hermesSessionId = "";
                    root.hermesSubscriptionId = "";
                    root.chatModelChanged();
                } catch (e) {
                    console.log("Error loading chat: " + e);
                }
            }
        }
    }

    // ============================================
    // DYNAMIC MODEL FETCHING
    // ============================================

    property bool fetchingModels: false
    property int pendingFetches: 0

    function fetchActiveModels() {
        if (hermesActive)
            fetchHermesModels();
        else
            fetchAvailableModels();
    }

    // ============================================
    // HERMES MODEL CATALOG
    // ============================================

    // The gateway owns the provider/model inventory. Nothing here reads Hermes'
    // env files, keys or caches; model.options is the only source.
    function fetchHermesModels() {
        if (fetchingHermesModels || HermesGateway.installed === false)
            return;

        fetchingHermesModels = true;

        if (HermesGateway.connected) {
            requestHermesCatalog();
            return;
        }

        // The transport attaches on demand; model.options is asked once ready.
        hermesCatalogPending = true;
        HermesGateway.ensureStarted();
    }

    function requestHermesCatalog() {
        hermesCatalogPending = false;
        let seq = ++hermesCatalogSeq;
        HermesGateway.request("model.options", {}, (err, result) => {
            // A newer refresh already answered; this list would be stale.
            if (seq !== root.hermesCatalogSeq)
                return;

            root.fetchingHermesModels = false;

            if (err || !result) {
                root.lastError = "Hermes could not list models: " + root.hermesErrorMessage(err);
                // Keep the last good catalog; only the first load needs a stand-in.
                if (root.hermesModels.length === 0)
                    root.finishHermesFetch([]);
                return;
            }

            root.lastError = "";
            root.applyHermesCatalog(result);
        });
    }

    // model.options: { providers: [{ slug, name, is_current, models: [id|{}] }], model, provider }
    function applyHermesCatalog(result) {
        let providers = result && Array.isArray(result.providers) ? result.providers : [];
        let currentProvider = result ? (result.provider || "") : "";
        let newModels = [];
        let seen = {};

        // The active provider comes first so its models read as the default set.
        let ordered = [];
        for (let i = 0; i < providers.length; i++) {
            let provider = providers[i];
            if (!provider || isExplicitlyUnusable(provider))
                continue;
            if (provider.is_current === true || (currentProvider !== "" && provider.slug === currentProvider))
                ordered.push(provider);
        }
        for (let i = 0; i < providers.length; i++) {
            let provider = providers[i];
            if (!provider || isExplicitlyUnusable(provider))
                continue;
            if (ordered.indexOf(provider) === -1)
                ordered.push(provider);
        }

        for (let i = 0; i < ordered.length; i++) {
            let provider = ordered[i];
            let slug = provider.slug || provider.id || "";
            let label = provider.name || slug || "Hermes";
            if (slug === "")
                slug = label;

            let items = Array.isArray(provider.models) ? provider.models : [];
            for (let j = 0; j < items.length; j++) {
                let item = items[j];
                let id = typeof item === "string" ? item : (item && (item.id || item.model || item.name) ? (item.id || item.model || item.name) : "");
                if (id === "")
                    continue;
                if (item && typeof item === "object" && isExplicitlyUnusable(item))
                    continue;

                // Two providers can expose the same id; the identity is the pair.
                let key = slug + "\u0000" + id;
                if (seen[key])
                    continue;
                seen[key] = true;
                newModels.push(createHermesModel(id, slug, label));
            }
        }

        hermesDefaultId = result && result.model ? result.model : "";
        finishHermesFetch(newModels);
    }

    // Only flags the gateway actually sends matter; nothing here assumes a
    // provider has the same metadata as the next one.
    function isExplicitlyUnusable(entry) {
        if (!entry || typeof entry !== "object")
            return false;
        if (entry.available === false || entry.enabled === false || entry.usable === false || entry.disabled === true)
            return true;
        return ["unavailable", "disabled", "unconfigured", "unauthenticated"].indexOf(entry.status) !== -1;
    }

    function createHermesModel(id, providerSlug, providerName) {
        let slug = providerSlug !== undefined && providerSlug !== "" ? providerSlug : "hermes";
        return aiModelFactory.createObject(root, {
            name: id,
            icon: "",
            description: providerName || slug,
            endpoint: "",
            model: id,
            // The slug, not "hermes": the same id can come from two providers.
            provider: slug,
            requires_key: false,
            api_format: "hermes"
        });
    }

    // Keeps the current selection across a refresh, then the configured
    // default, then the last used id, then the first usable model.
    function pickHermesModel(previous) {
        if (hermesModels.length === 0)
            return null;

        if (previous) {
            let kept = findHermesModelByKey(hermesModels, hermesModelKey(previous));
            if (kept)
                return kept;
        }

        let defaultId = Config.ai.hermesDefaultModel || "";
        let target = findHermesModel(hermesModels, Config.ai.hermesDefaultProvider || "", defaultId);
        if (!target && defaultId !== "")
            target = findHermesModel(hermesModels, "", defaultId);
        if (!target)
            target = findHermesModel(hermesModels, "", StateService.get("lastHermesModel", ""));

        return target ? target : hermesModels[0];
    }

    function finishHermesFetch(newModels) {
        if (newModels.length === 0 && hermesDefaultId !== "")
            newModels.push(createHermesModel(hermesDefaultId, "hermes", "Hermes"));

        let previous = currentHermesModel;
        let oldModels = hermesModels;

        hermesModels = newModels;
        hermesRestored = true;
        currentHermesModel = pickHermesModel(previous);
        fetchingHermesModels = false;

        disposeHermesModels(oldModels);
    }

    // Models created here are children of this singleton, so replacing the
    // list without destroying them leaks a full catalog per refresh.
    function disposeHermesModels(oldModels) {
        if (!oldModels || oldModels.length === 0)
            return;

        // Let delegates rebind to the new list before the old objects go.
        Qt.callLater(function () {
            for (let i = 0; i < oldModels.length; i++) {
                let model = oldModels[i];
                if (!model)
                    continue;
                if (model === currentHermesModel || model === currentModel)
                    continue;
                if (hermesModels.indexOf(model) !== -1)
                    continue;
                model.destroy();
            }
        });
    }

    function fetchAvailableModels() {
        fetchingModels = false; // Force refresh
        if (fetchingModels)
            return;

        fetchingModels = true;
        pendingFetches = 0;

        // Gemini
        let geminiKey = KeyStore.getKey("gemini");
        if (geminiKey) {
            pendingFetches++;
            fetchProcessGemini.command = ["bash", "-c", "curl -s 'https://generativelanguage.googleapis.com/v1beta/models?key=" + geminiKey + "'"];
            fetchProcessGemini.running = true;
        }

        // OpenAI
        let openaiKey = KeyStore.getKey("openai");
        if (openaiKey) {
            pendingFetches++;
            fetchProcessOpenAI.command = ["bash", "-c", "curl -s https://api.openai.com/v1/models -H 'Authorization: Bearer " + openaiKey + "'"];
            fetchProcessOpenAI.running = true;
        }

        // Anthropic
        let anthropicKey = KeyStore.getKey("anthropic");
        if (anthropicKey) {
            pendingFetches++;
            fetchProcessAnthropic.command = ["bash", "-c", "curl -s https://api.anthropic.com/v1/models -H 'x-api-key: " + anthropicKey + "' -H 'anthropic-version: 2023-06-01'"];
            fetchProcessAnthropic.running = true;
        }

        // Mistral
        let mistralKey = KeyStore.getKey("mistral");
        if (mistralKey) {
            pendingFetches++;
            fetchProcessMistral.command = ["bash", "-c", "curl -s https://api.mistral.ai/v1/models -H 'Authorization: Bearer " + mistralKey + "'"];
            fetchProcessMistral.running = true;
        }

        // Groq
        let groqKey = KeyStore.getKey("groq");
        if (groqKey) {
            pendingFetches++;
            fetchProcessGroq.command = ["bash", "-c", "curl -s https://api.groq.com/openai/v1/models -H 'Authorization: Bearer " + groqKey + "'"];
            fetchProcessGroq.running = true;
        }

        // Ollama (local)
        let ollamaEnabled = KeyStore.hasKey("ollama");
        if (ollamaEnabled) {
            pendingFetches++;
            fetchProcessOllama.command = ["bash", "-c", "curl -s http://127.0.0.1:11434/api/tags"];
            fetchProcessOllama.running = true;
        }

        // MiniMax
        let minimaxKey = KeyStore.getKey("minimax");
        if (minimaxKey) {
            pendingFetches++;
            fetchProcessMiniMax.command = ["bash", "-c", "echo 'done'"];
            fetchProcessMiniMax.running = true;
        }

        if (pendingFetches === 0) {
            fetchingModels = false;
        }
    }

    Process {
        id: fetchProcessGemini
        stdout: StdioCollector {
            id: fetchGeminiOut
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    let data = JSON.parse(fetchGeminiOut.text);
                    if (data.models) {
                        let newModels = [];
                        for (let i = 0; i < data.models.length; i++) {
                            let item = data.models[i];
                            let id = item.name.replace("models/", "");
                            if (id.includes("gemini") || id.includes("flash") || id.includes("pro")) {
                                let m = aiModelFactory.createObject(root, {
                                    name: item.displayName || id,
                                    icon: Qt.resolvedUrl("../../../assets/aiproviders/google.svg"),
                                    description: item.description || I18n.t("ai.desc_google"),
                                    endpoint: "https://generativelanguage.googleapis.com/v1beta",
                                    model: id,
                                    provider: "gemini",
                                    requires_key: true,
                                    key_id: "GEMINI_API_KEY"
                                });
                                if (m) newModels.push(m);
                            }
                        }
                        mergeModels(newModels);
                    }
                } catch (e) {
                    console.log("Gemini fetch error: " + e);
                }
            }
            checkFetchCompletion();
        }
    }

    Process {
        id: fetchProcessOpenAI
        stdout: StdioCollector {
            id: fetchOpenAIOut
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    let data = JSON.parse(fetchOpenAIOut.text);
                    if (data.data) {
                        let newModels = [];
                        let allowed = ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-4", "o1", "o1-mini", "o1-preview", "o3-mini"];
                        for (let i = 0; i < data.data.length; i++) {
                            let item = data.data[i];
                            let id = item.id;
                            let isAllowed = false;
                            for (let j = 0; j < allowed.length; j++) {
                                if (id === allowed[j] || id.startsWith(allowed[j] + "-")) {
                                    isAllowed = true;
                                    break;
                                }
                            }
                            if (isAllowed) {
                                let m = aiModelFactory.createObject(root, {
                                    name: id,
                                    icon: Qt.resolvedUrl("../../../assets/aiproviders/openai.svg"),
                                    description: I18n.t("ai.desc_openai"),
                                    endpoint: "https://api.openai.com",
                                    model: id,
                                    provider: "openai",
                                    requires_key: true,
                                    key_id: "OPENAI_API_KEY"
                                });
                                if (m) newModels.push(m);
                            }
                        }
                        mergeModels(newModels);
                    }
                } catch (e) {
                    console.log("OpenAI fetch error: " + e);
                }
            }
            checkFetchCompletion();
        }
    }

    Process {
        id: fetchProcessMistral
        stdout: StdioCollector {
            id: fetchMistralOut
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    let data = JSON.parse(fetchMistralOut.text);
                    if (data.data) {
                        let newModels = [];
                        for (let i = 0; i < data.data.length; i++) {
                            let item = data.data[i];
                            let id = item.id;
                            let m = aiModelFactory.createObject(root, {
                                name: id,
                                icon: Qt.resolvedUrl("../../../assets/aiproviders/mistral.svg"),
                                description: I18n.t("ai.desc_mistral"),
                                endpoint: "https://api.mistral.ai/v1",
                                model: id,
                                provider: "mistral",
                                requires_key: true,
                                key_id: "MISTRAL_API_KEY"
                            });
                            if (m) newModels.push(m);
                        }
                        mergeModels(newModels);
                    }
                } catch (e) {
                    console.log("Mistral fetch error: " + e);
                }
            }
            checkFetchCompletion();
        }
    }

    Process {
        id: fetchProcessGroq
        stdout: StdioCollector {
            id: fetchGroqOut
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    let data = JSON.parse(fetchGroqOut.text);
                    if (data.data) {
                        let newModels = [];
                        for (let i = 0; i < data.data.length; i++) {
                            let item = data.data[i];
                            let id = item.id;
                            let m = aiModelFactory.createObject(root, {
                                name: id,
                                icon: Qt.resolvedUrl("../../../assets/aiproviders/groq.svg"),
                                description: I18n.t("ai.desc_groq"),
                                endpoint: "https://api.groq.com/openai/v1",
                                model: id,
                                provider: "groq",
                                requires_key: true,
                                key_id: "GROQ_API_KEY"
                            });
                            if (m) newModels.push(m);
                        }
                        mergeModels(newModels);
                    }
                } catch (e) {
                    console.log("Groq fetch error: " + e);
                }
            }
            checkFetchCompletion();
        }
    }

    Process {
        id: fetchProcessAnthropic
        stdout: StdioCollector {
            id: fetchAnthropicOut
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    let data = JSON.parse(fetchAnthropicOut.text);
                    if (data.data) {
                        let newModels = [];
                        for (let i = 0; i < data.data.length; i++) {
                            let item = data.data[i];
                            let id = item.id;
                            let m = aiModelFactory.createObject(root, {
                                name: item.display_name || id,
                                icon: Qt.resolvedUrl("../../../assets/aiproviders/anthropic.svg"),
                                description: item.description || I18n.t("ai.desc_anthropic"),
                                endpoint: "https://api.anthropic.com/v1/messages",
                                model: id,
                                provider: "anthropic",
                                requires_key: true,
                                key_id: "ANTHROPIC_API_KEY"
                            });
                            if (m) newModels.push(m);
                        }
                        mergeModels(newModels);
                    }
                } catch (e) {
                    console.log("Anthropic fetch error: " + e);
                }
            }
            checkFetchCompletion();
        }
    }

    Process {
        id: fetchProcessOllama
        stdout: StdioCollector {
            id: fetchOllamaOut
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    let data = JSON.parse(fetchOllamaOut.text);
                    if (data.models) {
                        let newModels = [];
                        for (let i = 0; i < data.models.length; i++) {
                            let item = data.models[i];
                            let m = aiModelFactory.createObject(root, {
                                name: item.name,
                                icon: Qt.resolvedUrl("../../../assets/aiproviders/ollama.svg"),
                                description: I18n.t("ai.desc_ollama"),
                                endpoint: "http://127.0.0.1:11434",
                                model: item.name,
                                provider: "ollama",
                                requires_key: false
                            });
                            if (m) newModels.push(m);
                        }
                        mergeModels(newModels);
                    }
                } catch (e) {
                    console.log("Ollama fetch error: " + e);
                }
            }
            checkFetchCompletion();
        }
    }

    Process {
        id: fetchProcessMiniMax
        onExited: exitCode => {
            if (exitCode === 0) {
                let newModels = [];
                
                let models = [
                    { name: "MiniMax-M2.7", model: "MiniMax-M2.7", description: "Latest model with recursive self-improvement, SOTA coding capabilities", endpoint: "https://api.minimax.io" },
                    { name: "MiniMax-M2.7-highspeed", model: "MiniMax-M2.7-highspeed", description: "Same performance as M2.7, faster inference (~100 tps)", endpoint: "https://api.minimax.io" },
                    { name: "MiniMax-M2.5", model: "MiniMax-M2.5", description: "Peak performance, ultimate value, master the complex", endpoint: "https://api.minimax.io" },
                    { name: "MiniMax-M2.5-highspeed", model: "MiniMax-M2.5-highspeed", description: "Same performance as M2.5, faster inference (~100 tps)", endpoint: "https://api.minimax.io" },
                    { name: "MiniMax-M2.1", model: "MiniMax-M2.1", description: "Powerful multi-language programming, enhanced reasoning", endpoint: "https://api.minimax.io" },
                    { name: "MiniMax-M2.1-highspeed", model: "MiniMax-M2.1-highspeed", description: "Same performance as M2.1, faster inference (~100 tps)", endpoint: "https://api.minimax.io" },
                    { name: "MiniMax-M2", model: "MiniMax-M2", description: "Agentic capabilities, advanced reasoning, 200k context", endpoint: "https://api.minimax.io" },
                    { name: "M2-her", model: "M2-her", description: "Role-playing, multi-turn conversations, emotional expression", endpoint: "https://api.minimax.io" }
                ];
                
                for (let i = 0; i < models.length; i++) {
                    let item = models[i];
                    let m = aiModelFactory.createObject(root, {
                        name: item.name,
                        icon: Qt.resolvedUrl("../../../assets/aiproviders/minimax.svg"),
                        description: item.description,
                        endpoint: item.endpoint,
                        model: item.model,
                        provider: "minimax",
                        requires_key: true,
                        key_id: "MINIMAX_API_KEY"
                    });
                    if (m) newModels.push(m);
                }
                
                mergeModels(newModels);
            }
            checkFetchCompletion();
        }
    }


    function checkFetchCompletion() {
        pendingFetches--;
        if (pendingFetches <= 0) {
            fetchingModels = false;
            pendingFetches = 0;

            // Wait for the config: restoring against the defaults in
            // Config.qml would ignore the configured default model.
            if (!Config.aiReady)
                return;

            tryRestore();

            if (!isRestored && models.length > 0) {
                currentModel = models[0];
                isRestored = true;
            } else if (!isRestored && currentModel) {
                isRestored = true;
            }
        }
    }

    function mergeModels(newModels) {
        let updatedList = [];
        for (let i = 0; i < models.length; i++)
            updatedList.push(models[i]);

        for (let i = 0; i < newModels.length; i++) {
            let m = newModels[i];
            let isDuplicate = false;
            for (let j = 0; j < updatedList.length; j++) {
                if (updatedList[j].model === m.model) {
                    isDuplicate = true;
                    break;
                }
            }
            if (!isDuplicate)
                updatedList.push(m);
        }

        models = updatedList;

        if (!isRestored)
            tryRestore();
    }

    // Signals
    signal chatModelChanged
    signal historyModelChanged
    signal modelSelectionRequested

    Component {
        id: aiModelFactory
        AiModel {}
    }
}
