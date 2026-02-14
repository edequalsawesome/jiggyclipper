import Foundation
import JavaScriptCore

/// Protocol for exporting Swift functionality to JavaScript
@objc protocol ClipperBridgeExport: JSExport {
    /// Log a message from JavaScript
    func log(_ message: String)

    /// Fetch content from a URL (synchronous bridge for JS)
    func fetchURL(_ url: String) -> String?

    /// Get a setting value
    func getSetting(_ key: String) -> String?

    /// Set a setting value
    func setSetting(_ key: String, _ value: String)
}

/// Bridge class that exposes Swift functionality to JavaScript
@objc class ClipperBridge: NSObject, ClipperBridgeExport {

    func log(_ message: String) {
        print("[JSBridge] \(message)")
    }

    func fetchURL(_ url: String) -> String? {
        // Note: This is a synchronous call which isn't ideal
        // In production, you'd want to handle this differently
        guard let url = URL(string: url) else {
            return nil
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result: String?

        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data {
                result = String(data: data, encoding: .utf8)
            }
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .now() + 10)
        return result
    }

    func getSetting(_ key: String) -> String? {
        return AppGroupManager.shared.getString(forKey: key)
    }

    func setSetting(_ key: String, _ value: String) {
        AppGroupManager.shared.setString(value, forKey: key)
    }
}

/// LLM Bridge for handling AI provider calls from JavaScript
@objc protocol LLMBridgeExport: JSExport {
    /// Send prompts to LLM and get responses
    func sendPrompts(_ promptsJSON: String) -> String
}

@objc class LLMBridge: NSObject, LLMBridgeExport {

    func sendPrompts(_ promptsJSON: String) -> String {
        // Parse the prompts
        guard let data = promptsJSON.data(using: .utf8),
              let prompts = try? JSONDecoder().decode([PromptRequest].self, from: data) else {
            return "{\"error\": \"Invalid prompts JSON\"}"
        }

        // Get the default provider
        guard let provider = LLMProviderStorage.shared.getDefaultProvider() else {
            return "{\"error\": \"No LLM provider configured\"}"
        }

        // This is a synchronous call - not ideal but necessary for JS bridge
        let semaphore = DispatchSemaphore(value: 0)
        var responseJSON = "{\"error\": \"Request timeout\"}"

        Task {
            do {
                let responses = try await self.executePrompts(prompts, with: provider)
                let encoded = try JSONEncoder().encode(responses)
                responseJSON = String(data: encoded, encoding: .utf8) ?? "{}"
            } catch {
                responseJSON = "{\"error\": \"\(error.localizedDescription)\"}"
            }
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 30)
        return responseJSON
    }

    private func executePrompts(_ prompts: [PromptRequest], with provider: LLMProvider) async throws -> [String: String] {
        // Build the request based on provider type
        var request = URLRequest(url: URL(string: provider.baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch provider.providerId {
        case "anthropic":
            request.url = URL(string: "\(provider.baseURL)/v1/messages")
            request.setValue(provider.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

            let body: [String: Any] = [
                "model": provider.modelId,
                "max_tokens": 4096,
                "messages": [
                    [
                        "role": "user",
                        "content": buildPromptContent(prompts)
                    ]
                ]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

        case "openai":
            request.url = URL(string: "\(provider.baseURL)/v1/chat/completions")
            request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")

            let body: [String: Any] = [
                "model": provider.modelId,
                "messages": [
                    [
                        "role": "user",
                        "content": buildPromptContent(prompts)
                    ]
                ]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

        default:
            throw ClippingEngineError.jsError("Unsupported provider: \(provider.providerId)")
        }

        let (data, _) = try await URLSession.shared.data(for: request)

        // Parse response and extract prompt responses
        // This is simplified - real implementation would parse provider-specific response format
        return try parseResponse(data, provider: provider.providerId, prompts: prompts)
    }

    private func buildPromptContent(_ prompts: [PromptRequest]) -> String {
        var content = "Please respond to the following prompts. Return your response as JSON in this exact format:\n"
        content += "{\"prompts_responses\": {\"prompt_1\": \"response1\", \"prompt_2\": \"response2\", ...}}\n\n"

        for (index, prompt) in prompts.enumerated() {
            content += "prompt_\(index + 1): \(prompt.prompt)\n"
        }

        return content
    }

    private func parseResponse(_ data: Data, provider: String, prompts: [PromptRequest]) throws -> [String: String] {
        // Parse based on provider
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClippingEngineError.jsError("Invalid JSON response")
        }

        var content: String?

        switch provider {
        case "anthropic":
            if let contentArray = json["content"] as? [[String: Any]],
               let firstContent = contentArray.first,
               let text = firstContent["text"] as? String {
                content = text
            }

        case "openai":
            if let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let text = message["content"] as? String {
                content = text
            }

        default:
            break
        }

        guard let responseContent = content else {
            throw ClippingEngineError.jsError("No content in response")
        }

        // Try to parse as JSON
        if let jsonStart = responseContent.firstIndex(of: "{"),
           let jsonEnd = responseContent.lastIndex(of: "}") {
            let jsonString = String(responseContent[jsonStart...jsonEnd])
            if let jsonData = jsonString.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let responses = parsed["prompts_responses"] as? [String: String] {
                return responses
            }
        }

        // Fallback: return raw content for first prompt
        var result: [String: String] = [:]
        for (index, _) in prompts.enumerated() {
            result["prompt_\(index + 1)"] = index == 0 ? responseContent : ""
        }
        return result
    }
}

struct PromptRequest: Codable {
    let key: String
    let prompt: String
}
