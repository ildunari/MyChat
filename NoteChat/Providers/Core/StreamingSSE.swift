import Foundation

struct OpenAIStreamEnvelope: Decodable {
    let type: String
    let delta: String?
    let text: String?
    let error: StreamError?
    struct StreamError: Decodable { let message: String? }
}

final class SSEDecoder {
    private var buffer = Data()
    func feed(_ chunk: Data, onEvent: (String, Data) -> Void) {
        buffer.append(chunk)
        let boundary = Data([0x0A, 0x0A]) // \n\n
        while let range = buffer.range(of: boundary) {
            let frame = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)

            var eventName = "message"
            var eventData = Data()
            for line in frame.split(separator: 0x0A) { // split on \n
                if line.starts(with: Data("event:".utf8)) {
                    let value = line.dropFirst(6).drop(while: { $0 == 0x20 })
                    eventName = String(decoding: value, as: UTF8.self)
                } else if line.starts(with: Data("data:".utf8)) {
                    let value = line.dropFirst(5).drop(while: { $0 == 0x20 })
                    eventData.append(value)
                    eventData.append(0x0A)
                }
            }
            onEvent(eventName, eventData)
        }
    }
}

