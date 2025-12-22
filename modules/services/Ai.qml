pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "ai"
import "ai/strategies"

Singleton {
    id: root

    // ============================================ 
    // PROPERTIES
    // ============================================ 

    property string dataDir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/Ambxst"
    property string chatDir: dataDir + "/chats"
    property string tmpDir: "/tmp/ambxst-ai"

    property list<AiModel> models: [
        AiModel {
            name: "Gemini Pro"
            icon: "sparkles"
            description: "Google's most capable AI model"
            endpoint: "https://generativelanguage.googleapis.com/v1beta/models/"
            model: "gemini-pro"
            api_format: "gemini"
            requires_key: true
            key_id: "GEMINI_API_KEY"
        },
        AiModel {
            name: "GPT-4o"
            icon: "openai"
            description: "OpenAI's latest flagship model"
            endpoint: "https://api.openai.com/v1"
            model: "gpt-4o"
            api_format: "openai"
            requires_key: true
            key_id: "OPENAI_API_KEY"
        },
        AiModel {
            name: "Mistral Large"
            icon: "wind"
            description: "Mistral's flagship model"
            endpoint: "https://api.mistral.ai/v1"
            model: "mistral-large-latest"
            api_format: "mistral"
            requires_key: true
            key_id: "MISTRAL_API_KEY"
        }
    ]

    property AiModel currentModel: models[0]
    property ApiStrategy currentStrategy: geminiStrategy

    // Strategies
    property GeminiApiStrategy geminiStrategy: GeminiApiStrategy {}
    property OpenAiApiStrategy openaiStrategy: OpenAiApiStrategy {}
    property MistralApiStrategy mistralStrategy: MistralApiStrategy {}

    // State
    property bool isLoading: false
    property string lastError: ""
    property string responseBuffer: ""

    // Current Chat
    property var currentChat: [] // Array of { role: "user"|"assistant", content: "..." }
    property string currentChatId: ""
    
    // Chat History List (files)
    property var chatHistory: [] 

    // ============================================ 
    // INIT
    // ============================================ 
    function deleteChat(id) {
        if (id === currentChatId) {
            createNewChat();
        }
        
        let filename = chatDir + "/" + id + ".json";
        deleteChatProcess.command = ["rm", filename];
        deleteChatProcess.running = true;
    }

    Component.onCompleted: {
        reloadHistory();
        createNewChat();
    }

    // ============================================ 
    // LOGIC
    // ============================================ 

    function setModel(modelName) {
        for (let i = 0; i < models.length; i++) {
            if (models[i].name === modelName) {
                currentModel = models[i];
                updateStrategy();
                return;
            }
        }
    }

    function updateStrategy() {
        if (!currentModel) return;
        switch (currentModel.api_format) {
            case "gemini": currentStrategy = geminiStrategy; break;
            case "openai": currentStrategy = openaiStrategy; break;
            case "mistral": currentStrategy = mistralStrategy; break;
            default: currentStrategy = geminiStrategy;
        }
    }

    function getApiKey(model) {
        if (!model.requires_key) return "";
        return Quickshell.env(model.key_id) || "";
    }

    function processCommand(text) {
        let cmd = text.trim();
        if (!cmd.startsWith("/")) return false;
        
        let parts = cmd.split(" ");
        let command = parts[0].toLowerCase();
        let args = parts.slice(1).join(" ");
        
        switch (command) {
            case "/clear":
                createNewChat();
                return true;
            case "/model":
                if (args) {
                    // Fuzzy search or exact match
                    let found = false;
                    for (let i = 0; i < models.length; i++) {
                         if (models[i].name.toLowerCase().includes(args.toLowerCase()) || 
                             models[i].model.toLowerCase() === args.toLowerCase()) {
                             setModel(models[i].name);
                             found = true;
                             break;
                         }
                    }
                    if (!found) {
                        pushSystemMessage("Model '" + args + "' not found.");
                    } else {
                        pushSystemMessage("Switched to model: " + currentModel.name);
                    }
                } else {
                    pushSystemMessage("Current model: " + currentModel.name + "\nAvailable models:\n" + models.map(m => "- " + m.name).join("\n"));
                }
                return true;
            case "/help":
                pushSystemMessage("Available commands:\n/clear - Start new chat\n/model [name] - Switch AI model\n/help - Show this help");
                return true;
        }
        
        return false;
    }

    function pushSystemMessage(text) {
        let newChat = Array.from(currentChat);
        newChat.push({ role: "system", content: text });
        currentChat = newChat;
    }

    function sendMessage(text) {
        if (text.trim() === "") return;
        
        if (processCommand(text)) return;

        isLoading = true;
        lastError = "";
        
        // Add user message to UI immediately
        let userMsg = { role: "user", content: text };
        let newChat = Array.from(currentChat);
        newChat.push(userMsg);
        currentChat = newChat;
        
        // Prepare Request
        let apiKey = getApiKey(currentModel);
        if (!apiKey && currentModel.requires_key) {
            lastError = "API Key missing for " + currentModel.name;
            isLoading = false;
            
            let errChat = Array.from(currentChat);
            errChat.push({ role: "assistant", content: "Error: " + lastError });
            currentChat = errChat;
            return;
        }

        let endpoint = currentStrategy.getEndpoint(currentModel, apiKey);
        let headers = currentStrategy.getHeaders(apiKey);
        
        // Include system prompt
        let messages = [];
        if (Config.ai.systemPrompt) {
            messages.push({ role: "system", content: Config.ai.systemPrompt });
        }
        // Add history (simple version: all messages)
        // Note: Gemini doesn't support 'system' role in messages list the same way, handled in strategy
        for (let i = 0; i < currentChat.length; i++) {
            messages.push(currentChat[i]);
        }
        
        let body = currentStrategy.getBody(messages, currentModel, []);
        
        // Write body to temp file
        writeTempBody(JSON.stringify(body), headers, endpoint);
    }

    function writeTempBody(jsonBody, headers, endpoint) {
        // Create tmp dir
        requestProcess.command = ["mkdir", "-p", tmpDir];
        requestProcess.step = "mkdir";
        requestProcess.payload = { body: jsonBody, headers: headers, endpoint: endpoint };
        requestProcess.running = true;
    }

    function executeRequest(payload) {
        let bodyPath = tmpDir + "/body.json";
        
        // Write body.json
        // We use a separate process call for writing to avoid command line length limits
        writeBodyProcess.command = ["sh", "-c", "echo '" + payload.body.replace(/'/g, "'\\''") + "' > " + bodyPath];
        writeBodyProcess.payload = payload; // pass through
        writeBodyProcess.running = true;
    }
    
    function runCurl(payload) {
        let bodyPath = tmpDir + "/body.json";
        let headerArgs = payload.headers.map(h => "-H \"" + h + "\"").join(" ");
        
        let curlCmd = "curl -s -X POST \"" + payload.endpoint + "\" " + headerArgs + " -d @" + bodyPath;
        
        curlProcess.command = ["bash", "-c", curlCmd];
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
            }
        }
    }

    Process {
        id: writeBodyProcess
        property var payload: ({})
        
        onExited: exitCode => {
            if (exitCode === 0) {
                runCurl(payload);
            } else {
                root.lastError = "Failed to write request body";
                root.isLoading = false;
            }
        }
    }

    Process {
        id: curlProcess
        
        stdout: StdioCollector { id: curlStdout }
        stderr: StdioCollector { id: curlStderr }
        
        onExited: exitCode => {
            root.isLoading = false;
            if (exitCode === 0) {
                let responseText = curlStdout.text;
                // Debug log
                console.log("[Ai] Response: " + responseText);
                
                let reply = root.currentStrategy.parseResponse(responseText);
                
                // Add assistant message
                let newChat = Array.from(root.currentChat);
                newChat.push({ role: "assistant", content: reply });
                root.currentChat = newChat;
                
                root.saveCurrentChat();
            } else {
                root.lastError = "Network Request Failed: " + curlStderr.text;
                
                let errChat = Array.from(root.currentChat);
                errChat.push({ role: "assistant", content: "Error: " + root.lastError });
                root.currentChat = errChat;
            }
        }
    }

    // ============================================ 
    // CHAT STORAGE
    // ============================================ 
    
    function createNewChat() {
        currentChat = [];
        currentChatId = Date.now().toString();
        chatModelChanged();
    }
    
    function saveCurrentChat() {
        if (currentChat.length === 0) return;
        
        let filename = chatDir + "/" + currentChatId + ".json";
        let data = JSON.stringify(currentChat, null, 2);
        
        saveChatProcess.command = ["sh", "-c", "mkdir -p " + chatDir + " && echo '" + data.replace(/'/g, "'\\''") + "' > " + filename];
        saveChatProcess.running = true;
    }
    
    function reloadHistory() {
        // List files in chatDir
        listHistoryProcess.command = ["sh", "-c", "mkdir -p " + chatDir + " && ls -t " + chatDir + "/*.json"];
        listHistoryProcess.running = true;
    }

    function loadChat(id) {
        let filename = chatDir + "/" + id + ".json";
        loadChatProcess.targetId = id;
        loadChatProcess.command = ["cat", filename];
        loadChatProcess.running = true;
    }

    Process {
        id: saveChatProcess
        onExited: reloadHistory()
    }

    Process {
        id: deleteChatProcess
        onExited: reloadHistory()
    }
    
    Process {
        id: listHistoryProcess
        stdout: StdioCollector { id: listHistoryStdout }
        onExited: exitCode => {
            if (exitCode === 0) {
                let lines = listHistoryStdout.text.trim().split("\n");
                let history = [];
                for (let i = 0; i < lines.length; i++) {
                    let path = lines[i];
                    if (path === "") continue;
                    let filename = path.split("/").pop();
                    let id = filename.replace(".json", "");
                    history.push({ id: id, path: path });
                }
                root.chatHistory = history;
                root.historyModelChanged();
            }
        }
    }
    
    Process {
        id: loadChatProcess
        property string targetId: ""
        stdout: StdioCollector { id: loadChatStdout }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    root.currentChat = JSON.parse(loadChatStdout.text);
                    root.currentChatId = targetId;
                    root.chatModelChanged();
                } catch(e) {
                    console.log("Error loading chat: " + e);
                }
            }
        }
    }
    
    // Signals
    signal chatModelChanged()
    signal historyModelChanged()
}
