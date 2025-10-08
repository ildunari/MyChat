import Foundation

enum SSEStreamEvent {
    case message(event: String?, data: Data)
    case completed
}

final class SSEStream {
    private let session: URLSession

    init(session: URLSession = NetworkClient.shared.session) {
        self.session = session
    }

    func connect(urlRequest: URLRequest) async throws -> AsyncThrowingStream<SSEStreamEvent, Error> {
        let (bytes, response) = try await session.bytes(for: urlRequest)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "SSEStream", code: code, userInfo: [NSLocalizedDescriptionKey: "Unexpected status code: \(code)"])
        }
        let task = bytes.task

        return AsyncThrowingStream<SSEStreamEvent, Error>(bufferingPolicy: .unbounded) { continuation in
            let reader = Task {
                do {
                    var eventName: String?
                    var dataBuffer = Data()

                   func flushEventIfNeeded() {
                       guard dataBuffer.isEmpty == false else { return }
                       if dataBuffer.last == 0x0A { dataBuffer.removeLast() }
                        continuation.yield(SSEStreamEvent.message(event: eventName, data: dataBuffer))
                        dataBuffer.removeAll(keepingCapacity: true)
                        eventName = nil
                   }

                    for try await line in bytes.lines {
                        if line.isEmpty {
                            flushEventIfNeeded()
                            continue
                        }
                       if line.hasPrefix(":") {
                           continue
                       }
                       if line.hasPrefix("event:") {
                            flushEventIfNeeded()
                            let value = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                            eventName = value.isEmpty ? nil : value
                            continue
                       }
                       if line.hasPrefix("data:") {
                            var value = line.dropFirst(5)
                            if value.first == " " { value = value.dropFirst() }
                            if let chunk = value.data(using: .utf8) {
                                dataBuffer.append(chunk)
                                dataBuffer.append(0x0A)
                            }
                            continue
                        }
                        // Unknown field -> ignore per SSE spec
                    }

                    flushEventIfNeeded()
                    continuation.yield(SSEStreamEvent.completed)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { termination in
                switch termination {
                case .cancelled:
                    task.cancel()
                    reader.cancel()
                case .finished:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}
