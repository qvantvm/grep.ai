import Foundation

final class OpenAIClient {

    func generateRegex(apiKey: String,
                       userPrompt: String,
                       logSample: String) async throws -> String {

        let url = URL(string: "https://api.openai.com/v1/responses")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "input": [
                ["role": "system",
                 "content": "Return ONLY a valid NSRegularExpression pattern. No explanations."],
                ["role": "user",
                 "content": "Log sample:\n\(logSample)\n\nRequest:\n\(userPrompt)"]
            ]
        ]

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw AppError("OpenAI request failed")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let output = (json?["output"] as? [[String: Any]])?
            .first?["content"] as? [[String: Any]]

        let text = output?
            .first(where: { $0["type"] as? String == "output_text" })?["text"] as? String

        guard let result = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !result.isEmpty else {
            throw AppError("No regex returned")
        }

        return result
    }
}
