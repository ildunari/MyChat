import SwiftUI
import WebKit

// Controller object used to send commands into the WebCanvas once ready.
@MainActor
final class ChatCanvasController: ObservableObject {
    fileprivate weak var webView: WKWebView?
    fileprivate var isReady: Bool = false
    fileprivate var pending: [() -> Void] = []

    func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    func markReady() {
        isReady = true
        let ops = pending
        pending.removeAll()
        for op in ops { op() }
    }

    private func callJS(_ script: String) {
        if isReady, let web = webView {
            web.evaluateJavaScript(script, completionHandler: nil)
        } else {
            pending.append { [weak self] in self?.webView?.evaluateJavaScript(script, completionHandler: nil) }
        }
    }

    func loadTranscript(_ messages: [CanvasMessage]) {
        guard let data = try? JSONEncoder().encode(messages), let json = String(data: data, encoding: .utf8) else { return }
        callJS("window.ChatCanvas && window.ChatCanvas.loadTranscript(\(json));")
    }

    func startStream(id: String) { callJS("window.ChatCanvas && window.ChatCanvas.startStream(\"\(escape(id))\");") }
    func appendDelta(id: String, delta: String) { callJS("window.ChatCanvas && window.ChatCanvas.appendDelta(\"\(escape(id))\", \"\(escape(delta))\");") }
    func endStream(id: String) { callJS("window.ChatCanvas && window.ChatCanvas.endStream(\"\(escape(id))\");") }
    func setTheme(_ theme: CanvasTheme) { callJS("window.ChatCanvas && window.ChatCanvas.setTheme(\"\(theme.rawValue)\");") }
    func scrollToBottom() { callJS("window.ChatCanvas && window.ChatCanvas.scrollToBottom();") }
    func appendToolCard(title: String, subtitle: String? = nil, status: String = "idle", request: String? = nil, response: String? = nil, open: Bool = false) {
        // Try ChatCanvas API first; fall back to ToolCard helper
        let sub = subtitle != nil ? "\"\(escape(subtitle!))\"" : "null"
        let req = request != nil ? "`\(escape(request!))`" : "null"
        let res = response != nil ? "`\(escape(response!))`" : "null"
        let js = "(window.ChatCanvas && ChatCanvas.appendToolCard ? ChatCanvas.appendToolCard : (window.ToolCard ? ToolCard.append : null)) && (window.ChatCanvas && ChatCanvas.appendToolCard ? ChatCanvas.appendToolCard({title: \"\(escape(title))\", subtitle: \(sub), status: \"\(escape(status))\", request: \(req), response: \(res), open: \(open ? "true" : "false")}) : (window.ToolCard && ToolCard.append({title: \"\(escape(title))\", subtitle: \(sub), status: \"\(escape(status))\", request: \(req), response: \(res), open: \(open ? "true" : "false")})));"
        callJS(js)
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
    }
}

struct CanvasMessage: Codable {
    let id: String
    let role: String // "user" | "assistant"
    let content: String
    let createdAt: TimeInterval
}

enum CanvasTheme: String, Codable { case light, dark }

struct ChatCanvasView: UIViewRepresentable {
    @ObservedObject var controller: ChatCanvasController
    var theme: CanvasTheme

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeUIView(context: Context) -> WKWebView {
        let conf = WKWebViewConfiguration()
        conf.defaultWebpagePreferences.allowsContentJavaScript = true
        conf.allowsInlineMediaPlayback = true
        let userContent = WKUserContentController()
        // JS → Swift bridge
        userContent.add(context.coordinator, contentWorld: WKContentWorld.page, name: "bridge")
        conf.userContentController = userContent

        let web = WKWebView(frame: .zero, configuration: conf)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        controller.attach(web)

        // Load local bundle HTML
        if let base = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "WebCanvas/dist") {
            // Allow read access to the whole app bundle so we can reference sibling assets like ../KaTeX/*
            let bundleRoot = Bundle.main.bundleURL
            web.loadFileURL(base, allowingReadAccessTo: bundleRoot)
        } else if let alt = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "ChatApp/WebCanvas/dist") {
            let bundleRoot = Bundle.main.bundleURL
            web.loadFileURL(alt, allowingReadAccessTo: bundleRoot)
        }

        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Keep theme in sync once ready
        controller.setTheme(theme)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let controller: ChatCanvasController
        init(controller: ChatCanvasController) { self.controller = controller }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "bridge" else { return }
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            switch type {
            case "ready":
                controller.markReady()
            case "error":
                // Optionally log errors coming from the WebCanvas
                // print("WebCanvas error: \(body)")
                break
            case "height":
                // could adjust container height if needed in future
                break
            default:
                break
            }
        }
    }
}
