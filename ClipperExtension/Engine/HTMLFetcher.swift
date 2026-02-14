import Foundation

enum HTMLFetcherError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
}

class HTMLFetcher {
    static func fetch(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTMLFetcherError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw HTMLFetcherError.httpError(httpResponse.statusCode)
            }

            // Try to detect encoding from response
            var encoding = String.Encoding.utf8

            if let encodingName = httpResponse.textEncodingName {
                let cfEncoding = CFStringConvertIANACharSetNameToEncoding(encodingName as CFString)
                if cfEncoding != kCFStringEncodingInvalidId {
                    encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
                }
            }

            guard let html = String(data: data, encoding: encoding) ?? String(data: data, encoding: .utf8) else {
                throw HTMLFetcherError.invalidResponse
            }

            return html
        } catch let error as HTMLFetcherError {
            throw error
        } catch {
            throw HTMLFetcherError.networkError(error)
        }
    }
}
