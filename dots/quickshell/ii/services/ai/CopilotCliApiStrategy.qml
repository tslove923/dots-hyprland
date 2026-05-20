import QtQuick
import qs.services.ai

/**
 * API strategy for GitHub Copilot CLI integration
 * Unlike other strategies that use HTTP APIs, this uses the gh copilot command
 */
ApiStrategy {
    id: root

    function buildEndpoint(model: AiModel): string {
        // Copilot CLI doesn't use an endpoint, but we return a placeholder
        return "copilot-cli";
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        // Convert messages to a format suitable for gh copilot
        // We'll concatenate user messages and assistant messages into a conversation
        let conversationText = "";
        
        if (systemPrompt && systemPrompt.length > 0) {
            conversationText += systemPrompt + "\n\n";
        }
        
        for (let i = 0; i < messages.length; i++) {
            const message = messages[i];
            if (message.role === "user") {
                conversationText += "User: " + message.rawContent + "\n\n";
            } else if (message.role === "assistant") {
                conversationText += "Assistant: " + message.rawContent + "\n\n";
            }
        }
        
        // Return data object with conversation
        return {
            "conversation": conversationText.trim(),
            "lastUserMessage": messages.length > 0 ? messages[messages.length - 1].rawContent : ""
        };
    }

    function buildAuthorizationHeader(apiKeyEnvVar: string): string {
        // Copilot CLI uses gh authentication, not API keys
        return "";
    }

    function buildScriptFileSetup(filePath: string): string {
        // No special file setup needed for Copilot CLI
        return "";
    }

    function finalizeScriptContent(scriptContent: string): string {
        // Override the curl-based script with gh copilot command
        // The script will be replaced in the Ai.qml when using this strategy
        return scriptContent;
    }

    function parseResponseLine(line: string, message) {
        // Copilot CLI outputs plain text, not JSON
        // Just append to the message content
        if (line.length === 0) return { finished: false };
        
        message.rawContent += line + "\n";
        message.content += line + "\n";
        
        return {
            delta: line,
            finished: false,
            functionCall: null,
            tokenUsage: null
        };
    }

    function onRequestFinished(message) {
        // Mark the message as finished when the process exits
        return {
            finished: true
        };
    }

    function reset() {
        // No state to reset for Copilot CLI
    }
}
