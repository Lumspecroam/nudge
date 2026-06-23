import Foundation

enum Analytics {
    private static let apiURL = "https://analytics.plumbug.studio/api/track"
    private static let clientId = "efe540d4-26a3-47a3-a816-bdc93b0ccd56"

    static func track(_ name: String, properties: [String: String] = [:]) {
        guard UserPreferences.shared.analyticsEnabled else { return }
        let body: [String: Any] = [
            "type": "track",
            "payload": [
                "name": name,
                "properties": properties
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }

        guard let url = URL(string: apiURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(clientId, forHTTPHeaderField: "openpanel-client-id")
        request.httpBody = data
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                FileLog.write("Analytics.track(\(name)) failed: \(error.localizedDescription)")
            }
        }.resume()
    }
}
