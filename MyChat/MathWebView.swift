import SwiftUI
import WebKit

// Lightweight KaTeX-based math renderer using WKWebView.
// - No network required if you later bundle local KaTeX assets.
// - For now, it pulls from jsDelivr CDN as a stopgap.
// - Height auto-sizes to fit rendered content.

struct MathWebView: UIViewRepresentable {
    let latex: String
    var displayMode: Bool = true // true = block, false = inline

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let conf = WKWebViewConfiguration()
        conf.defaultWebpagePreferences.allowsContentJavaScript = true
        conf.limitsNavigationsToAppBoundDomains = false
        let web = WKWebView(frame: .zero, configuration: conf)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.isScrollEnabled = true // allow horizontal scroll if needed
        web.navigationDelegate = context.coordinator

        // Prefer local KaTeX assets if bundled: ChatApp.app/KaTeX/{katex.min.js, auto-render.min.js, katex.min.css}
        let assetsURL = Bundle.main.url(forResource: "KaTeX", withExtension: nil)
        let html = Self.htmlTemplate(forLatex: latex, displayMode: displayMode, useLocalAssets: assetsURL != nil)
        web.loadHTMLString(html, baseURL: assetsURL)
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Re-render when latex changes
        let js = "renderLatex(\"\(Self.escapeForJS(latex))\", \(displayMode ? "true" : "false"));"
        uiView.evaluateJavaScript(js, completionHandler: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Resize after initial render
            webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                if let h = result as? CGFloat, h > 0 {
                    var f = webView.frame
                    f.size.height = h
                    webView.frame = f
                }
            }
        }
    }
}

private extension MathWebView {
    static func escapeForJS(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
    }

    static func htmlTemplate(forLatex latex: String, displayMode: Bool, useLocalAssets: Bool) -> String {
        // If local assets exist, we reference relative paths and load with baseURL = KaTeX bundle path.
        // Otherwise, we fall back to CDN URLs.
        let css = useLocalAssets ? "katex.min.css" : "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css"
        let js  = useLocalAssets ? "katex.min.js" : "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"
        let auto = useLocalAssets ? "auto-render.min.js" : "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js"
        let escaped = escapeForJS(latex)
        let dm = displayMode ? "true" : "false"
        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name=\"viewport\" content=\"width=device-width, initial-scale=1, maximum-scale=1\">
          <link rel=\"stylesheet\" href=\"\(css)\">
          <style>
            body { margin: 0; padding: 0; background: transparent; color: inherit; }
            #math { padding: 4px 0; font-size: 16px; }
          </style>
        </head>
        <body>
          <div id=\"math\"></div>
          <script src=\"\(js)\"></script>
          <script src=\"\(auto)\"></script>
          <script>
            function renderLatex(lx, disp) {
              try {
                const el = document.getElementById('math');
                el.innerHTML = '';
                katex.render(lx, el, { throwOnError: false, displayMode: disp });
                setTimeout(function(){ if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.size) { try { window.webkit.messageHandlers.size.postMessage(document.body.scrollHeight); } catch(e){} } }, 0);
              } catch (e) { console.error(e); }
            }
            renderLatex(\"\(escaped)\", \(dm));
          </script>
        </body>
        </html>
        """
    }
}
